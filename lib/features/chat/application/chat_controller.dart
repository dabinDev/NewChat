import 'dart:async';

import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/chat/data/session_repository.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/domain/chat_provider.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';
import 'package:uuid/uuid.dart';

class ChatController {
  ChatController({
    required SessionRepository repository,
    required ChatProvider chatProvider,
  })  : _repository = repository,
        _chatProvider = chatProvider;

  final SessionRepository _repository;
  final ChatProvider _chatProvider;
  final Uuid _uuid = const Uuid();

  ChatSessionDocument? _currentDocument;
  StreamSubscription<ChatStreamEvent>? _streamSubscription;
  Completer<void>? _streamCompleter;
  String? _streamingAssistantId;
  bool _terminalStreamEventSeen = false;

  ChatSessionDocument? get currentDocument => _currentDocument;

  Future<void> createSession({
    required String providerId,
    required String modelId,
    required String title,
  }) async {
    final now = DateTime.now().toUtc();
    final document = ChatSessionDocument(
      id: _uuid.v4(),
      title: title,
      providerId: providerId,
      modelId: modelId,
      systemPrompt: '',
      messages: const [],
      createdAt: now,
      updatedAt: now,
      schemaVersion: AppConstants.schemaVersion,
    );
    _currentDocument = document;
    await _repository.saveDocument(document);
  }

  Future<void> loadSession(String sessionId) async {
    final document = await _repository.loadDocument(sessionId);
    if (document == null) {
      throw StateError('Chat session not found: $sessionId');
    }
    _currentDocument = document;
  }

  Future<void> sendMessage({
    required String text,
    required List<AttachmentRef> attachments,
  }) async {
    final document = _requireDocument();
    final now = DateTime.now().toUtc();
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      state: MessageState.completed,
      parts: [
        MessagePart.text(text),
        ...attachments.map(MessagePart.image),
      ],
      createdAt: now,
      updatedAt: now,
    );

    _currentDocument = _copyDocument(
      document,
      messages: [...document.messages, userMessage],
      updatedAt: now,
    );
    await _repository.saveDocument(_currentDocument!);

    await _streamAssistantResponse();
  }

  Future<void> stopGeneration() async {
    final subscription = _streamSubscription;
    final assistantId = _streamingAssistantId;
    final document = _currentDocument;
    if (subscription == null || assistantId == null || document == null) {
      return;
    }

    await subscription.cancel();
    _streamSubscription = null;
    _streamingAssistantId = null;
    final now = DateTime.now().toUtc();
    _currentDocument = _replaceMessage(
      document,
      assistantId,
      (message) => _copyMessage(
        message,
        state: MessageState.cancelled,
        updatedAt: now,
      ),
      updatedAt: now,
    );
    await _repository.saveDocument(_currentDocument!);
    _completeStream();
  }

  Future<void> retryLastFailed() async {
    final document = _requireDocument();
    if (document.messages.length < 2 ||
        document.messages.last.state != MessageState.failed ||
        document.messages.last.role != ChatRole.assistant) {
      return;
    }

    final previous = document.messages[document.messages.length - 2];
    if (previous.role != ChatRole.user) {
      return;
    }

    final now = DateTime.now().toUtc();
    _currentDocument = _copyDocument(
      document,
      messages: document.messages.take(document.messages.length - 1).toList(),
      updatedAt: now,
    );
    await _repository.saveDocument(_currentDocument!);
    await _streamAssistantResponse();
  }

  Future<void> _streamAssistantResponse() async {
    final document = _requireDocument();
    final now = DateTime.now().toUtc();
    final assistant = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      state: MessageState.streaming,
      parts: const [],
      createdAt: now,
      updatedAt: now,
    );
    _currentDocument = _copyDocument(
      document,
      messages: [...document.messages, assistant],
      updatedAt: now,
    );
    await _repository.saveDocument(_currentDocument!);

    final completer = Completer<void>();
    _streamCompleter = completer;
    _streamingAssistantId = assistant.id;
    _terminalStreamEventSeen = false;

    _streamSubscription =
        _chatProvider.sendStream(_requestFor(_currentDocument!)).listen(
      (event) => _handleStreamEvent(assistant.id, event),
      onError: (Object error) async {
        await _markAssistantFailed(assistant.id, error.toString());
        _completeStream();
      },
      onDone: () {
        if (!_terminalStreamEventSeen) {
          _completeStream();
        }
      },
      cancelOnError: true,
    );

    await completer.future;
  }

  Future<void> _handleStreamEvent(
    String assistantId,
    ChatStreamEvent event,
  ) async {
    switch (event) {
      case ChatStreamDelta(:final text):
        _appendAssistantPart(assistantId, MessagePart.text(text));
      case ChatStreamDone():
        _terminalStreamEventSeen = true;
        _streamSubscription?.pause();
        await _markAssistantCompleted(assistantId);
        await _streamSubscription?.cancel();
        _completeStream();
      case ChatStreamFailed(:final error):
        _terminalStreamEventSeen = true;
        _streamSubscription?.pause();
        await _markAssistantFailed(assistantId, error.message);
        await _streamSubscription?.cancel();
        _completeStream();
    }
  }

  void _appendAssistantPart(String assistantId, MessagePart part) {
    final document = _requireDocument();
    final now = DateTime.now().toUtc();
    _currentDocument = _replaceMessage(
      document,
      assistantId,
      (message) => _copyMessage(
        message,
        parts: [...message.parts, part],
        updatedAt: now,
      ),
      updatedAt: now,
    );
  }

  Future<void> _markAssistantCompleted(String assistantId) async {
    final document = _requireDocument();
    final now = DateTime.now().toUtc();
    _currentDocument = _replaceMessage(
      document,
      assistantId,
      (message) => _copyMessage(
        message,
        state: MessageState.completed,
        updatedAt: now,
      ),
      updatedAt: now,
    );
    await _repository.saveDocument(_currentDocument!);
  }

  Future<void> _markAssistantFailed(String assistantId, String message) async {
    final document = _requireDocument();
    final now = DateTime.now().toUtc();
    _currentDocument = _replaceMessage(
      document,
      assistantId,
      (chatMessage) => _copyMessage(
        chatMessage,
        state: MessageState.failed,
        parts: [...chatMessage.parts, MessagePart.error(message)],
        updatedAt: now,
      ),
      updatedAt: now,
    );
    await _repository.saveDocument(_currentDocument!);
  }

  void _completeStream() {
    _streamSubscription = null;
    _streamingAssistantId = null;
    _terminalStreamEventSeen = false;
    final completer = _streamCompleter;
    _streamCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  ChatSessionDocument _requireDocument() {
    final document = _currentDocument;
    if (document == null) {
      throw StateError('No chat session is loaded.');
    }
    return document;
  }

  ChatRequest _requestFor(ChatSessionDocument document) {
    final now = DateTime.now().toUtc();
    return ChatRequest(
      provider: ProviderConfig(
        id: document.providerId,
        name: document.providerId,
        protocol: ProviderProtocol.openai,
        baseUrl: '',
        defaultModelId: document.modelId,
        createdAt: now,
        updatedAt: now,
      ),
      model: ModelConfig(
        id: document.modelId,
        displayName: document.modelId,
        protocol: ProviderProtocol.openai,
        supportsStreaming: true,
        supportsImages: true,
      ),
      systemPrompt: document.systemPrompt,
      messages: document.messages,
      stream: true,
    );
  }
}

ChatSessionDocument _copyDocument(
  ChatSessionDocument document, {
  String? title,
  List<ChatMessage>? messages,
  DateTime? updatedAt,
}) =>
    ChatSessionDocument(
      id: document.id,
      title: title ?? document.title,
      providerId: document.providerId,
      modelId: document.modelId,
      systemPrompt: document.systemPrompt,
      messages: messages ?? document.messages,
      createdAt: document.createdAt,
      updatedAt: updatedAt ?? document.updatedAt,
      schemaVersion: document.schemaVersion,
    );

ChatSessionDocument _replaceMessage(
  ChatSessionDocument document,
  String messageId,
  ChatMessage Function(ChatMessage message) replace, {
  required DateTime updatedAt,
}) =>
    _copyDocument(
      document,
      messages: [
        for (final message in document.messages)
          if (message.id == messageId) replace(message) else message,
      ],
      updatedAt: updatedAt,
    );

ChatMessage _copyMessage(
  ChatMessage message, {
  MessageState? state,
  List<MessagePart>? parts,
  DateTime? updatedAt,
}) =>
    ChatMessage(
      id: message.id,
      role: message.role,
      state: state ?? message.state,
      parts: parts ?? message.parts,
      createdAt: message.createdAt,
      updatedAt: updatedAt ?? message.updatedAt,
    );
