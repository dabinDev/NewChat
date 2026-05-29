import 'dart:async';

import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/chat/data/session_repository.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/domain/chat_provider.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:newchat/features/providers/application/provider_controller.dart';

final chatControllerProvider = Provider<ChatController>((ref) {
  return ChatController(
    repository: ref.watch(sessionRepositoryProvider),
    chatProvider: ref.watch(chatProviderProvider),
    providerRepository: ref.watch(providerRepositoryProvider),
  );
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return InMemorySessionRepository();
});

class ChatController {
  ChatController({
    required SessionRepository repository,
    required ChatProvider chatProvider,
    ProviderRepository? providerRepository,
  })  : _repository = repository,
        _chatProvider = chatProvider,
        _providerRepository = providerRepository;

  final SessionRepository _repository;
  final ChatProvider _chatProvider;
  final ProviderRepository? _providerRepository;
  final Uuid _uuid = const Uuid();

  ChatSessionDocument? _currentDocument;
  StreamIterator<ChatStreamEvent>? _streamIterator;
  bool _generationInProgress = false;
  String? _streamingSessionId;
  String? _streamingAssistantId;

  ChatSessionDocument? get currentDocument => _currentDocument;

  Future<void> createSession({
    required String providerId,
    required String modelId,
    required String title,
  }) async {
    _throwIfGenerationActive();
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

  Future<void> createSessionFromDefaultProvider({
    required String title,
  }) async {
    final repository = _providerRepository;
    if (repository == null) {
      throw StateError('Provider repository is not configured.');
    }
    final providers = await repository.listProviders();
    if (providers.isEmpty) {
      throw StateError('Provider not found.');
    }
    final provider = providers.first;
    await createSession(
      providerId: provider.id,
      modelId: provider.defaultModelId,
      title: title,
    );
  }

  Future<void> loadSession(String sessionId) async {
    _throwIfGenerationActive();
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
    _throwIfGenerationActive();
    final document = _requireDocument();
    _generationInProgress = true;
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

    try {
      await _streamAssistantResponse(
        hasImageAttachments: attachments.isNotEmpty,
      );
    } finally {
      _generationInProgress = false;
    }
  }

  Future<void> stopGeneration() async {
    final iterator = _streamIterator;
    final sessionId = _streamingSessionId;
    final assistantId = _streamingAssistantId;
    final document = _currentDocument;
    if (iterator == null ||
        sessionId == null ||
        assistantId == null ||
        document == null) {
      return;
    }

    await iterator.cancel();
    final currentDocument = _currentDocument;
    if (currentDocument?.id != sessionId) {
      _clearGeneration();
      _generationInProgress = false;
      return;
    }
    final now = DateTime.now().toUtc();
    _currentDocument = _replaceMessage(
      currentDocument!,
      assistantId,
      (message) => _copyMessage(
        message,
        state: MessageState.cancelled,
        updatedAt: now,
      ),
      updatedAt: now,
    );
    await _repository.saveDocument(_currentDocument!);
    _clearGeneration();
    _generationInProgress = false;
  }

  Future<void> retryLastFailed() async {
    _throwIfGenerationActive();
    final document = _requireDocument();
    _generationInProgress = true;
    try {
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
      await _streamAssistantResponse(hasImageAttachments: false);
    } finally {
      _generationInProgress = false;
    }
  }

  Future<void> _streamAssistantResponse({
    required bool hasImageAttachments,
  }) async {
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

    _streamingSessionId = document.id;
    _streamingAssistantId = assistant.id;

    try {
      final request = await _requestFor(
        _currentDocument!,
        hasImageAttachments: hasImageAttachments,
      );
      final stream = _chatProvider.sendStream(request);
      final iterator = StreamIterator(stream);
      _streamIterator = iterator;

      while (await iterator.moveNext()) {
        if (!_isCurrentGeneration(document.id, assistant.id)) {
          await iterator.cancel();
          return;
        }

        final shouldContinue = await _handleStreamEvent(
          document.id,
          assistant.id,
          iterator.current,
        );
        if (!shouldContinue) {
          await iterator.cancel();
          return;
        }
      }
    } on _ChatRequestValidationException catch (error) {
      if (_isCurrentGeneration(document.id, assistant.id)) {
        await _markAssistantFailed(assistant.id, error.message);
      }
    } on Object {
      if (_isCurrentGeneration(document.id, assistant.id)) {
        await _markAssistantFailed(assistant.id, 'Generation failed.');
      }
    } finally {
      if (_isCurrentGeneration(document.id, assistant.id)) {
        _clearGeneration();
      }
    }
  }

  Future<bool> _handleStreamEvent(
    String sessionId,
    String assistantId,
    ChatStreamEvent event,
  ) async {
    if (!_isCurrentGeneration(sessionId, assistantId)) {
      return false;
    }

    switch (event) {
      case ChatStreamDelta(:final text):
        await _appendAssistantPart(assistantId, MessagePart.text(text));
        return true;
      case ChatStreamDone():
        await _markAssistantCompleted(assistantId);
        return false;
      case ChatStreamFailed(:final error):
        await _markAssistantFailed(assistantId, error.message);
        return false;
    }
  }

  Future<void> _appendAssistantPart(
    String assistantId,
    MessagePart part,
  ) async {
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
    await _repository.saveDocument(_currentDocument!);
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

  void _clearGeneration() {
    _streamIterator = null;
    _streamingSessionId = null;
    _streamingAssistantId = null;
  }

  ChatSessionDocument _requireDocument() {
    final document = _currentDocument;
    if (document == null) {
      throw StateError('No chat session is loaded.');
    }
    return document;
  }

  void _throwIfGenerationActive() {
    if (_generationInProgress) {
      throw StateError('Generation is already in progress.');
    }
  }

  bool _isCurrentGeneration(String sessionId, String assistantId) =>
      _streamingSessionId == sessionId &&
      _streamingAssistantId == assistantId &&
      _currentDocument?.id == sessionId;

  Future<ChatRequest> _requestFor(
    ChatSessionDocument document, {
    required bool hasImageAttachments,
  }) async {
    final configured = await _configuredRequestParts(document);
    if (configured != null) {
      final (:provider, :model) = configured;
      _validateRequest(provider, model, hasImageAttachments);
      return ChatRequest(
        provider: provider,
        model: model,
        systemPrompt: document.systemPrompt,
        messages: document.messages,
        stream: true,
      );
    }

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

  Future<({ProviderConfig provider, ModelConfig model})?>
      _configuredRequestParts(
    ChatSessionDocument document,
  ) async {
    final repository = _providerRepository;
    if (repository == null) {
      return null;
    }

    final providers = await repository.listProviders();
    final models = await repository.listModels();
    ProviderConfig? provider;
    for (final candidate in providers) {
      if (candidate.id == document.providerId) {
        provider = candidate;
        break;
      }
    }
    if (provider == null) {
      throw StateError('Provider not found.');
    }
    ModelConfig? model;
    for (final candidate in models) {
      if (candidate.id == document.modelId) {
        model = candidate;
        break;
      }
    }
    if (model == null) {
      throw StateError('Model not found.');
    }
    return (provider: provider, model: model);
  }

  void _validateRequest(
    ProviderConfig provider,
    ModelConfig model,
    bool hasImageAttachments,
  ) {
    if (provider.protocol != model.protocol) {
      throw const _ChatRequestValidationException(
        'Provider and model protocols differ.',
      );
    }
    if (hasImageAttachments && !model.supportsImages) {
      throw const _ChatRequestValidationException(
        'The selected model does not support images.',
      );
    }
  }
}

class _ChatRequestValidationException implements Exception {
  const _ChatRequestValidationException(this.message);

  final String message;
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
