import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/errors/chat_error.dart';
import 'package:newchat/features/chat/application/chat_context_builder.dart';
import 'package:newchat/features/chat/application/chat_controller.dart';
import 'package:newchat/features/chat/application/session_list_controller.dart';
import 'package:newchat/features/chat/data/session_repository.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/domain/chat_provider.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';

void main() {
  test('sendMessage appends user message and streamed assistant text',
      () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider([
      const ChatStreamDelta('hello'),
      const ChatStreamDelta(' world'),
      const ChatStreamDone(),
    ]);
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    await controller.sendMessage(text: 'hi', attachments: const []);

    final document = controller.currentDocument!;
    expect(document.messages.length, 2);
    expect(document.messages.last.fullText, 'hello world');
    expect(document.messages.last.parts, hasLength(1));
    expect(document.messages.last.parts.single.text, 'hello world');
  });

  test('sendMessage appends generated image as assistant image part', () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider([
      ChatStreamImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      ),
      const ChatStreamDone(),
    ]);
    final outputDir = await Directory.systemTemp.createTemp('newchat-test-');
    addTearDown(() => outputDir.delete(recursive: true));
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
      imageOutputDirectory: () async => outputDir,
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-image-2',
      title: 'New Chat',
    );
    await controller
        .sendMessage(text: 'draw a red kite', attachments: const []);

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.state, MessageState.completed);
    expect(assistant.parts, hasLength(1));
    final imagePart = assistant.parts.single;
    expect(imagePart.type, MessagePartType.image);
    expect(imagePart.attachment!.mimeType, 'image/png');
    expect(imagePart.attachment!.fileSize, 3);
    expect(
      await File(imagePart.attachment!.localPath).readAsBytes(),
      [1, 2, 3],
    );
  });

  test('sendMessage stores reply metadata and sends quote preface', () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider(const [ChatStreamDone()]);
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    await controller.sendMessage(
      text: 'why?',
      attachments: const [],
      replyToMessageId: 'assistant-1',
      replyPreview: 'Paris',
    );

    final userMessage = controller.currentDocument!.messages.first;
    expect(userMessage.replyToMessageId, 'assistant-1');
    expect(userMessage.replyPreview, 'Paris');
    expect(fakeProvider.requests.single.messages.first.fullText, '''
The user is replying to this earlier message:
"Paris"

User message:
why?''');
  });

  test('sendMessage stores rich reply ref for quoted image message', () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider(const [ChatStreamDone()]);
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
    );
    final now = DateTime.utc(2026, 5, 30, 8);
    final image = AttachmentRef(
      id: 'image-1',
      localPath: '/tmp/image.png',
      mimeType: 'image/png',
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    await controller.sendMessage(
      text: 'what should I change?',
      attachments: const [],
      replyRef: MessageReplyRef(
        messageId: 'assistant-image',
        role: ChatRole.assistant,
        textPreview: 'product screenshot',
        imageAttachment: image,
        createdAt: now,
      ),
    );

    final userMessage = controller.currentDocument!.messages.first;
    expect(userMessage.replyRef!.messageId, 'assistant-image');
    expect(userMessage.replyRef!.role, ChatRole.assistant);
    expect(userMessage.replyRef!.textPreview, 'product screenshot');
    expect(userMessage.replyRef!.imageAttachment!.id, 'image-1');
    expect(userMessage.replyToMessageId, 'assistant-image');
    expect(userMessage.replyPreview, 'product screenshot');
    expect(fakeProvider.requests.single.messages.first.fullText, '''
The user is replying to this earlier image message:
"[Image] product screenshot"

User message:
what should I change?''');
  });

  test('quoted image is validated as image input before provider call',
      () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider(const [ChatStreamDone()]);
    final quotedImage = const AttachmentRef(
      id: 'quoted-image',
      localPath: '/tmp/quoted.png',
      mimeType: 'image/png',
    );
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
      providerRepository: InMemoryProviderRepository(
        providers: [
          _provider(
            id: 'provider-1',
            protocol: ProviderProtocol.openai,
            defaultModelId: 'text-only',
          ),
        ],
        models: [
          _model(
            'text-only',
            ProviderProtocol.openai,
            supportsImages: false,
          ),
        ],
      ),
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'text-only',
      title: 'New Chat',
    );
    await controller.sendMessage(
      text: 'edit this image',
      attachments: const [],
      replyRef: MessageReplyRef(
        messageId: 'assistant-image',
        role: ChatRole.assistant,
        textPreview: 'original image',
        imageAttachment: quotedImage,
        createdAt: DateTime.utc(2026, 5, 30, 8),
      ),
    );

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.role, ChatRole.assistant);
    expect(assistant.state, MessageState.failed);
    expect(
      assistant.parts.single.text,
      'The selected model does not support images.',
    );
    expect(fakeProvider.requests, isEmpty);
  });

  test('failed stream marks assistant failed and stores error part', () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider([
      const ChatStreamDelta('partial'),
      const ChatStreamFailed(
        ChatError(type: ChatErrorType.network, message: 'network failed'),
      ),
    ]);
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    await controller.sendMessage(text: 'hi', attachments: const []);

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.state, MessageState.failed);
    expect(assistant.fullText, 'partial');
    expect(assistant.parts.last.type, MessagePartType.error);
    expect(assistant.parts.last.text, 'network failed');
  });

  test('stream ending without done completes assistant instead of hanging',
      () async {
    final repository = InMemorySessionRepository();
    final controller = ChatController(
      repository: repository,
      chatProvider: FakeChatProvider([
        const ChatStreamDelta('partial answer'),
      ]),
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    await controller.sendMessage(text: 'hi', attachments: const []);

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.fullText, 'partial answer');
    expect(assistant.state, MessageState.completed);
  });

  test('loadSession loads existing session', () async {
    final repository = InMemorySessionRepository();
    final document = _document(id: 'session-1', title: 'Existing Chat');
    await repository.saveDocument(document);
    final controller = ChatController(
      repository: repository,
      chatProvider: FakeChatProvider(const []),
    );

    await controller.loadSession('session-1');

    expect(controller.currentDocument!.id, 'session-1');
    expect(controller.currentDocument!.title, 'Existing Chat');
  });

  test('loadSession converts trailing streaming assistant to interrupted',
      () async {
    final repository = InMemorySessionRepository();
    await repository.saveDocument(
      _document(
        id: 'session-1',
        messages: [
          ChatMessage(
            id: 'user-1',
            role: ChatRole.user,
            state: MessageState.completed,
            parts: const [MessagePart.text('hello')],
            createdAt: DateTime.utc(2026, 5, 30, 8),
            updatedAt: DateTime.utc(2026, 5, 30, 8),
          ),
          ChatMessage(
            id: 'assistant-1',
            role: ChatRole.assistant,
            state: MessageState.streaming,
            parts: const [MessagePart.text('partial')],
            createdAt: DateTime.utc(2026, 5, 30, 8, 1),
            updatedAt: DateTime.utc(2026, 5, 30, 8, 1),
          ),
        ],
      ),
    );
    final controller = ChatController(
      repository: repository,
      chatProvider: FakeChatProvider(const []),
    );

    await controller.loadSession('session-1');

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.state, MessageState.interrupted);
    expect(assistant.fullText, 'partial');
    expect(
      (await repository.loadDocument('session-1'))!.messages.last.state,
      MessageState.interrupted,
    );
  });

  test('switchModel preserves loaded session context summary metadata',
      () async {
    final repository = InMemorySessionRepository();
    final summaryUpdatedAt = DateTime.utc(2026, 5, 30, 8, 15);
    final document = _document(
      id: 'session-1',
      contextSummary: 'User prefers short answers.',
      contextSummaryUpdatedAt: summaryUpdatedAt,
    );
    await repository.saveDocument(document);
    final controller = ChatController(
      repository: repository,
      chatProvider: FakeChatProvider(const []),
    );

    await controller.loadSession('session-1');
    await controller.switchModel(
      providerId: 'provider-2',
      modelId: 'gpt-4.1',
    );

    final currentDocument = controller.currentDocument!;
    expect(currentDocument.contextSummary, 'User prefers short answers.');
    expect(currentDocument.contextSummaryUpdatedAt, summaryUpdatedAt);
    final savedDocument = (await repository.loadDocument('session-1'))!;
    expect(savedDocument.contextSummary, 'User prefers short answers.');
    expect(savedDocument.contextSummaryUpdatedAt, summaryUpdatedAt);
  });

  test('loadSession throws StateError when session is missing', () async {
    final controller = ChatController(
      repository: InMemorySessionRepository(),
      chatProvider: FakeChatProvider(const []),
    );

    expect(
      () => controller.loadSession('missing'),
      throwsA(isA<StateError>()),
    );
  });

  test('stopGeneration marks current streaming assistant cancelled', () async {
    final repository = InMemorySessionRepository();
    final events = StreamController<ChatStreamEvent>();
    final controller = ChatController(
      repository: repository,
      chatProvider: ControlledChatProvider(events.stream),
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    final sendFuture =
        controller.sendMessage(text: 'hi', attachments: const []);
    await pumpEventQueue();

    await controller.stopGeneration();
    await sendFuture;

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.state, MessageState.cancelled);
    await events.close();
  });

  test('retryLastFailed preserves retained user reply and edit metadata',
      () async {
    final repository = InMemorySessionRepository();
    final editedAt = DateTime.utc(2026, 5, 30, 9, 10);
    final firstEditAt = DateTime.utc(2026, 5, 30, 9);
    final user = ChatMessage(
      id: 'message-1',
      role: ChatRole.user,
      state: MessageState.completed,
      parts: const [MessagePart.text('hello')],
      createdAt: DateTime.utc(2026, 5, 30, 8),
      updatedAt: DateTime.utc(2026, 5, 30, 8),
      replyToMessageId: 'previous-message',
      replyPreview: 'previous question',
      editedAt: editedAt,
      editHistory: [
        MessageEditEntry(text: 'helo', editedAt: firstEditAt),
      ],
    );
    await repository.saveDocument(
      _document(
        id: 'session-1',
        messages: [
          user,
          ChatMessage(
            id: 'assistant-1',
            role: ChatRole.assistant,
            state: MessageState.failed,
            parts: const [MessagePart.text('old answer')],
            createdAt: DateTime.utc(2026, 5, 30, 8),
            updatedAt: DateTime.utc(2026, 5, 30, 8),
          ),
        ],
      ),
    );
    final controller = ChatController(
      repository: repository,
      chatProvider: FakeChatProvider(const [
        ChatStreamDelta('retry answer'),
        ChatStreamDone(),
      ]),
    );

    await controller.loadSession('session-1');
    await controller.retryLastFailed();

    final retainedUser = controller.currentDocument!.messages.first;
    expect(retainedUser.replyToMessageId, 'previous-message');
    expect(retainedUser.replyPreview, 'previous question');
    expect(retainedUser.editedAt, editedAt);
    expect(retainedUser.editHistory, hasLength(1));
    expect(retainedUser.editHistory.single.text, 'helo');
    expect(retainedUser.editHistory.single.editedAt, firstEditAt);
  });

  test('retryLastFailed retries interrupted and cancelled trailing assistants',
      () async {
    for (final state in [MessageState.interrupted, MessageState.cancelled]) {
      final repository = InMemorySessionRepository();
      await repository.saveDocument(
        _document(
          id: 'session-${state.name}',
          messages: [
            ChatMessage(
              id: 'user-1',
              role: ChatRole.user,
              state: MessageState.completed,
              parts: const [MessagePart.text('hello')],
              createdAt: DateTime.utc(2026, 5, 30, 8),
              updatedAt: DateTime.utc(2026, 5, 30, 8),
            ),
            ChatMessage(
              id: 'assistant-1',
              role: ChatRole.assistant,
              state: state,
              parts: const [MessagePart.text('partial')],
              createdAt: DateTime.utc(2026, 5, 30, 8, 1),
              updatedAt: DateTime.utc(2026, 5, 30, 8, 1),
            ),
          ],
        ),
      );
      final controller = ChatController(
        repository: repository,
        chatProvider: FakeChatProvider(const [
          ChatStreamDelta('retried'),
          ChatStreamDone(),
        ]),
      );

      await controller.loadSession('session-${state.name}');
      await controller.retryLastFailed();

      final messages = controller.currentDocument!.messages;
      expect(messages, hasLength(2));
      expect(messages.first.fullText, 'hello');
      expect(messages.last.state, MessageState.completed);
      expect(messages.last.fullText, 'retried');
    }
  });

  test(
      'editUserMessageAndRegenerate records history and removes later messages',
      () async {
    final repository = InMemorySessionRepository();
    final image = AttachmentRef(
      id: 'image-1',
      localPath: '/tmp/current.png',
      mimeType: 'image/png',
    );
    final user = ChatMessage(
      id: 'user-1',
      role: ChatRole.user,
      state: MessageState.completed,
      parts: [
        const MessagePart.text('original prompt'),
        MessagePart.image(image),
      ],
      createdAt: DateTime.utc(2026, 5, 30, 8),
      updatedAt: DateTime.utc(2026, 5, 30, 8),
    );
    await repository.saveDocument(
      _document(
        id: 'session-1',
        messages: [
          user,
          ChatMessage(
            id: 'assistant-old',
            role: ChatRole.assistant,
            state: MessageState.completed,
            parts: const [MessagePart.text('old answer')],
            createdAt: DateTime.utc(2026, 5, 30, 8, 1),
            updatedAt: DateTime.utc(2026, 5, 30, 8, 1),
          ),
          ChatMessage(
            id: 'user-later',
            role: ChatRole.user,
            state: MessageState.completed,
            parts: const [MessagePart.text('later prompt')],
            createdAt: DateTime.utc(2026, 5, 30, 8, 2),
            updatedAt: DateTime.utc(2026, 5, 30, 8, 2),
          ),
        ],
      ),
    );
    final fakeProvider = FakeChatProvider(const [
      ChatStreamDelta('new answer'),
      ChatStreamDone(),
    ]);
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
    );

    await controller.loadSession('session-1');
    await controller.editUserMessageAndRegenerate(
      messageId: 'user-1',
      text: '  edited prompt  ',
    );

    final messages = controller.currentDocument!.messages;
    expect(messages.map((message) => message.id), ['user-1', messages.last.id]);
    expect(messages.first.fullText, 'edited prompt');
    expect(
      messages.first.parts.where((part) => part.type == MessagePartType.image),
      hasLength(1),
    );
    expect(messages.first.editedAt, isNotNull);
    expect(messages.first.editHistory, hasLength(1));
    expect(messages.first.editHistory.single.text, 'original prompt');
    expect(messages.last.role, ChatRole.assistant);
    expect(messages.last.fullText, 'new answer');
    final providerUser = fakeProvider.requests.single.messages
        .lastWhere((message) => message.role == ChatRole.user);
    expect(providerUser.fullText, 'edited prompt');
    expect(
      providerUser.parts.where((part) => part.type == MessagePartType.image),
      hasLength(1),
    );
  });

  test('edit image prompt sends new user message without overwriting image',
      () async {
    final repository = InMemorySessionRepository();
    final oldImage = AttachmentRef(
      id: 'image-old',
      localPath: '/tmp/old.png',
      mimeType: 'image/png',
    );
    final oldImageMessage = ChatMessage(
      id: 'assistant-image',
      role: ChatRole.assistant,
      state: MessageState.completed,
      parts: [MessagePart.image(oldImage)],
      createdAt: DateTime.utc(2026, 5, 30, 8, 1),
      updatedAt: DateTime.utc(2026, 5, 30, 8, 1),
    );
    final outputDir = await Directory.systemTemp.createTemp('newchat-test-');
    addTearDown(() => outputDir.delete(recursive: true));
    await repository.saveDocument(
      _document(
        id: 'session-1',
        modelId: 'gpt-image-2',
        messages: [
          ChatMessage(
            id: 'user-original',
            role: ChatRole.user,
            state: MessageState.completed,
            parts: const [MessagePart.text('draw a red kite')],
            createdAt: DateTime.utc(2026, 5, 30, 8),
            updatedAt: DateTime.utc(2026, 5, 30, 8),
          ),
          oldImageMessage,
        ],
      ),
    );
    final fakeProvider = FakeChatProvider([
      ChatStreamImage(
        bytes: Uint8List.fromList([7, 8, 9]),
        mimeType: 'image/png',
      ),
      const ChatStreamDone(),
    ]);
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
      imageOutputDirectory: () async => outputDir,
    );

    await controller.loadSession('session-1');
    await controller.sendImageEditPrompt(
      imageMessage: oldImageMessage,
      prompt: 'make it blue',
    );

    final messages = controller.currentDocument!.messages;
    expect(messages.map((message) => message.id), [
      'user-original',
      'assistant-image',
      messages[2].id,
      messages[3].id,
    ]);
    expect(messages[1].parts.single.attachment!.id, 'image-old');
    expect(messages[2].role, ChatRole.user);
    expect(messages[2].fullText, 'make it blue');
    expect(messages[3].role, ChatRole.assistant);
    expect(messages[3].parts.single.type, MessagePartType.image);
    expect(messages[3].parts.single.attachment!.id, isNot('image-old'));
    expect(
      fakeProvider.requests.single.messages
          .lastWhere((message) => message.role == ChatRole.user)
          .fullText,
      '''
The user is replying to this earlier image message:
"[Image]"

User message:
make it blue''',
    );
  });

  test('sendImageEditPrompt sends referenced image in provider request',
      () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider(const [ChatStreamDone()]);
    final image = const AttachmentRef(
      id: 'image-old',
      localPath: '/tmp/old.png',
      mimeType: 'image/png',
    );
    final imageMessage = ChatMessage(
      id: 'assistant-image',
      role: ChatRole.assistant,
      state: MessageState.completed,
      parts: [
        const MessagePart.text('original product shot'),
        MessagePart.image(image),
      ],
      createdAt: DateTime.utc(2026, 5, 30, 8, 1),
      updatedAt: DateTime.utc(2026, 5, 30, 8, 1),
    );
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
    );
    await repository.saveDocument(
      _document(
        id: 'session-1',
        messages: [
          ChatMessage(
            id: 'user-original',
            role: ChatRole.user,
            state: MessageState.completed,
            parts: const [MessagePart.text('draw product')],
            createdAt: DateTime.utc(2026, 5, 30, 8),
            updatedAt: DateTime.utc(2026, 5, 30, 8),
          ),
          imageMessage,
        ],
      ),
    );

    await controller.loadSession('session-1');
    await controller.sendImageEditPrompt(
      imageMessage: imageMessage,
      prompt: 'change the background to night',
    );

    final providerUser = fakeProvider.requests.single.messages.lastWhere(
      (message) => message.role == ChatRole.user,
    );
    expect(providerUser.replyRef!.messageId, 'assistant-image');
    expect(providerUser.replyRef!.imageAttachment!.id, 'image-old');
    expect(
      providerUser.parts
          .where((part) => part.type == MessagePartType.image)
          .map((part) => part.attachment!.id),
      ['image-old'],
    );
  });

  test('editUserMessageAndRegenerate throws during generation', () async {
    final repository = InMemorySessionRepository();
    final events = StreamController<ChatStreamEvent>();
    final controller = ChatController(
      repository: repository,
      chatProvider: ControlledChatProvider(events.stream),
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    final sendFuture =
        controller.sendMessage(text: 'hi', attachments: const []);
    await pumpEventQueue();
    final userMessageId = controller.currentDocument!.messages.first.id;

    await expectLater(
      controller.editUserMessageAndRegenerate(
        messageId: userMessageId,
        text: 'edited',
      ),
      throwsA(isA<StateError>()),
    );

    events.add(const ChatStreamDone());
    await sendFuture;
    await events.close();
  });

  test('edit save failure clears generation lock for later edits', () async {
    final repository = ThrowingSaveSessionRepository();
    final user = ChatMessage(
      id: 'user-1',
      role: ChatRole.user,
      state: MessageState.completed,
      parts: const [MessagePart.text('original prompt')],
      createdAt: DateTime.utc(2026, 5, 30, 8),
      updatedAt: DateTime.utc(2026, 5, 30, 8),
    );
    repository.seed(
      _document(
        id: 'session-1',
        messages: [
          user,
          ChatMessage(
            id: 'assistant-old',
            role: ChatRole.assistant,
            state: MessageState.completed,
            parts: const [MessagePart.text('old answer')],
            createdAt: DateTime.utc(2026, 5, 30, 8, 1),
            updatedAt: DateTime.utc(2026, 5, 30, 8, 1),
          ),
        ],
      ),
    );
    final controller = ChatController(
      repository: repository,
      chatProvider: FakeChatProvider(const [ChatStreamDone()]),
    );

    await controller.loadSession('session-1');
    repository.throwOnSave = true;
    await expectLater(
      controller.editUserMessageAndRegenerate(
        messageId: 'user-1',
        text: 'edited prompt',
      ),
      throwsA(isA<StateError>()),
    );

    repository.throwOnSave = false;
    await controller.editUserMessageAndRegenerate(
      messageId: 'user-1',
      text: 'edited prompt after failure',
    );

    expect(
      controller.currentDocument!.messages.first.fullText,
      'edited prompt after failure',
    );
  });

  test('editUserMessageAndRegenerate rejects non-completed user messages',
      () async {
    for (final state in [
      MessageState.cancelled,
      MessageState.interrupted,
      MessageState.failed,
      MessageState.streaming,
    ]) {
      final repository = InMemorySessionRepository();
      await repository.saveDocument(
        _document(
          id: 'session-$state',
          messages: [
            ChatMessage(
              id: 'user-1',
              role: ChatRole.user,
              state: state,
              parts: const [MessagePart.text('hello')],
              createdAt: DateTime.utc(2026, 5, 30),
              updatedAt: DateTime.utc(2026, 5, 30),
            ),
          ],
        ),
      );
      final controller = ChatController(
        repository: repository,
        chatProvider: FakeChatProvider(const [ChatStreamDone()]),
      );

      await controller.loadSession('session-$state');

      await expectLater(
        controller.editUserMessageAndRegenerate(
          messageId: 'user-1',
          text: 'edited',
        ),
        throwsA(isA<StateError>()),
      );
    }
  });

  test('editUserMessageAndRegenerate rejects assistant messages', () async {
    final repository = InMemorySessionRepository();
    await repository.saveDocument(
      _document(
        id: 'session-1',
        messages: [
          ChatMessage(
            id: 'assistant-1',
            role: ChatRole.assistant,
            state: MessageState.completed,
            parts: const [MessagePart.text('answer')],
            createdAt: DateTime.utc(2026, 5, 30),
            updatedAt: DateTime.utc(2026, 5, 30),
          ),
        ],
      ),
    );
    final controller = ChatController(
      repository: repository,
      chatProvider: FakeChatProvider(const [ChatStreamDone()]),
    );

    await controller.loadSession('session-1');

    await expectLater(
      controller.editUserMessageAndRegenerate(
        messageId: 'assistant-1',
        text: 'edited',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('editUserMessageAndRegenerate rejects empty text and missing ids',
      () async {
    final repository = InMemorySessionRepository();
    await repository.saveDocument(
      _document(
        id: 'session-1',
        messages: [
          ChatMessage(
            id: 'user-1',
            role: ChatRole.user,
            state: MessageState.completed,
            parts: const [MessagePart.text('hello')],
            createdAt: DateTime.utc(2026, 5, 30),
            updatedAt: DateTime.utc(2026, 5, 30),
          ),
        ],
      ),
    );
    final controller = ChatController(
      repository: repository,
      chatProvider: FakeChatProvider(const [ChatStreamDone()]),
    );

    await controller.loadSession('session-1');

    await expectLater(
      controller.editUserMessageAndRegenerate(messageId: 'user-1', text: '  '),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      controller.editUserMessageAndRegenerate(
        messageId: 'missing',
        text: 'edited',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
      'requestFor persists generated context summary and uses compact messages',
      () async {
    final repository = InMemorySessionRepository();
    final oldImage = AttachmentRef(
      id: 'old-image',
      localPath: '/tmp/old.png',
      mimeType: 'image/png',
    );
    final latestImage = AttachmentRef(
      id: 'latest-image',
      localPath: '/tmp/latest.png',
      mimeType: 'image/png',
    );
    await repository.saveDocument(
      _document(
        id: 'session-1',
        messages: [
          ChatMessage(
            id: 'old-user',
            role: ChatRole.user,
            state: MessageState.completed,
            parts: [
              const MessagePart.text('old image prompt'),
              MessagePart.image(oldImage),
            ],
            createdAt: DateTime.utc(2026, 5, 30, 8),
            updatedAt: DateTime.utc(2026, 5, 30, 8),
          ),
          ChatMessage(
            id: 'old-assistant',
            role: ChatRole.assistant,
            state: MessageState.completed,
            parts: const [MessagePart.text('old answer')],
            createdAt: DateTime.utc(2026, 5, 30, 8, 1),
            updatedAt: DateTime.utc(2026, 5, 30, 8, 1),
          ),
        ],
      ),
    );
    final fakeProvider = FakeChatProvider(const [ChatStreamDone()]);
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
      contextBuilder: const ChatContextBuilder(recentMessageLimit: 2),
    );

    await controller.loadSession('session-1');
    await controller.sendMessage(
      text: 'latest image prompt',
      attachments: [latestImage],
    );

    final savedDocument = (await repository.loadDocument('session-1'))!;
    expect(savedDocument.contextSummary, contains('- user: old image prompt'));
    expect(savedDocument.contextSummaryUpdatedAt, isNotNull);
    final request = fakeProvider.requests.single;
    expect(request.messages.first.role, ChatRole.system);
    expect(request.messages.first.fullText, contains('Earlier conversation'));
    expect(
      request.messages.map((message) => message.id),
      ['context-summary', 'old-assistant', request.messages.last.id],
    );
    final imageIds = request.messages
        .expand((message) => message.parts)
        .where((part) => part.type == MessagePartType.image)
        .map((part) => part.attachment!.id);
    expect(imageIds, ['latest-image']);
  });

  test('concurrent sendMessage throws while first stream completes', () async {
    final repository = InMemorySessionRepository();
    final events = StreamController<ChatStreamEvent>();
    final controller = ChatController(
      repository: repository,
      chatProvider: ControlledChatProvider(events.stream),
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    final firstSend =
        controller.sendMessage(text: 'first', attachments: const []);
    await pumpEventQueue();

    expect(
      () => controller.sendMessage(text: 'second', attachments: const []),
      throwsA(isA<StateError>()),
    );

    events
      ..add(const ChatStreamDelta('done'))
      ..add(const ChatStreamDone());
    await firstSend;

    final document = controller.currentDocument!;
    expect(document.messages, hasLength(2));
    expect(document.messages.first.fullText, 'first');
    expect(document.messages.last.fullText, 'done');
  });

  test('loadSession throws during generation without switching document',
      () async {
    final repository = InMemorySessionRepository();
    final events = StreamController<ChatStreamEvent>();
    final otherDocument = _document(id: 'session-2', title: 'Other Chat');
    await repository.saveDocument(otherDocument);
    final controller = ChatController(
      repository: repository,
      chatProvider: ControlledChatProvider(events.stream),
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    final originalSessionId = controller.currentDocument!.id;
    final sendFuture =
        controller.sendMessage(text: 'hi', attachments: const []);
    await pumpEventQueue();

    await expectLater(
      controller.loadSession('session-2'),
      throwsA(isA<StateError>()),
    );
    expect(controller.currentDocument!.id, originalSessionId);

    events.add(const ChatStreamDone());
    await sendFuture;
    await events.close();
  });

  test('loadSession keeps active same-session generation running', () async {
    final repository = InMemorySessionRepository();
    final events = StreamController<ChatStreamEvent>();
    final controller = ChatController(
      repository: repository,
      chatProvider: ControlledChatProvider(events.stream),
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    final sessionId = controller.currentDocument!.id;
    final sendFuture =
        controller.sendMessage(text: 'slow task', attachments: const []);
    await pumpEventQueue();

    await controller.loadSession(sessionId);

    final streamingAssistant = controller.currentDocument!.messages.last;
    expect(streamingAssistant.state, MessageState.streaming);

    events
      ..add(const ChatStreamDelta('finished later'))
      ..add(const ChatStreamDone());
    await sendFuture;

    final savedDocument = (await repository.loadDocument(sessionId))!;
    expect(savedDocument.messages.last.state, MessageState.completed);
    expect(savedDocument.messages.last.fullText, 'finished later');
    await events.close();
  });

  test('createSession throws during generation', () async {
    final events = StreamController<ChatStreamEvent>();
    final controller = ChatController(
      repository: InMemorySessionRepository(),
      chatProvider: ControlledChatProvider(events.stream),
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    final originalSessionId = controller.currentDocument!.id;
    final sendFuture =
        controller.sendMessage(text: 'hi', attachments: const []);
    await pumpEventQueue();

    await expectLater(
      controller.createSession(
        providerId: 'provider-1',
        modelId: 'gpt-4o-mini',
        title: 'Other Chat',
      ),
      throwsA(isA<StateError>()),
    );
    expect(controller.currentDocument!.id, originalSessionId);

    events.add(const ChatStreamDone());
    await sendFuture;
    await events.close();
  });

  test('createSessionFromDefaultProvider replaces stale current document',
      () async {
    final repository = InMemorySessionRepository();
    final controller = ChatController(
      repository: repository,
      chatProvider: FakeChatProvider(const [ChatStreamDone()]),
      providerRepository: InMemoryProviderRepository(
        providers: [
          _provider(
            id: 'real-provider',
            protocol: ProviderProtocol.openai,
            defaultModelId: 'real-model',
          ),
        ],
        models: [_model('real-model', ProviderProtocol.openai)],
      ),
    );
    await controller.createSession(
      providerId: 'old-provider',
      modelId: 'old-model',
      title: 'Old',
    );
    final oldSessionId = controller.currentDocument!.id;

    await controller.createSessionFromDefaultProvider(title: 'New');

    expect(controller.currentDocument!.id, isNot(oldSessionId));
    expect(controller.currentDocument!.providerId, 'real-provider');
    expect(controller.currentDocument!.modelId, 'real-model');
  });

  test('createSessionFromDefaultProvider throws when no provider exists',
      () async {
    final controller = ChatController(
      repository: InMemorySessionRepository(),
      chatProvider: FakeChatProvider(const []),
      providerRepository: InMemoryProviderRepository(
        providers: const [],
        models: const [],
      ),
    );

    await expectLater(
      controller.createSessionFromDefaultProvider(title: 'New'),
      throwsA(isA<StateError>()),
    );
  });

  test('sendStream setup throw marks assistant failed with error part',
      () async {
    final controller = ChatController(
      repository: InMemorySessionRepository(),
      chatProvider: ThrowingChatProvider(StateError('api key secret leaked')),
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    await controller.sendMessage(text: 'hi', attachments: const []);

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.state, MessageState.failed);
    expect(assistant.parts.single.type, MessagePartType.error);
    expect(assistant.parts.single.text, 'Generation failed.');
  });

  test('retryLastFailed retries failed assistant without duplicating user',
      () async {
    final provider = SequentialChatProvider([
      [
        const ChatStreamFailed(
          ChatError(type: ChatErrorType.network, message: 'network failed'),
        ),
      ],
      [
        const ChatStreamDelta('retry ok'),
        const ChatStreamDone(),
      ],
    ]);
    final controller = ChatController(
      repository: InMemorySessionRepository(),
      chatProvider: provider,
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    await controller.sendMessage(text: 'hi', attachments: const []);
    await controller.retryLastFailed();

    final messages = controller.currentDocument!.messages;
    expect(messages, hasLength(2));
    expect(messages.first.role, ChatRole.user);
    expect(messages.first.fullText, 'hi');
    expect(messages.last.role, ChatRole.assistant);
    expect(messages.last.state, MessageState.completed);
    expect(messages.last.fullText, 'retry ok');
  });

  test('retryLastFailed validates retained user images before provider call',
      () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider(const [ChatStreamDone()]);
    await repository.saveDocument(
      _document(
        id: 'session-1',
        providerId: 'provider-1',
        modelId: 'text-only',
        messages: [
          ChatMessage(
            id: 'user-1',
            role: ChatRole.user,
            state: MessageState.completed,
            parts: [
              const MessagePart.text('describe this'),
              MessagePart.image(
                const AttachmentRef(
                  id: 'image-1',
                  localPath: '/tmp/image.png',
                  mimeType: 'image/png',
                ),
              ),
            ],
            createdAt: DateTime.utc(2026, 5, 30, 8),
            updatedAt: DateTime.utc(2026, 5, 30, 8),
          ),
          ChatMessage(
            id: 'assistant-1',
            role: ChatRole.assistant,
            state: MessageState.failed,
            parts: const [MessagePart.error('Generation failed.')],
            createdAt: DateTime.utc(2026, 5, 30, 8, 1),
            updatedAt: DateTime.utc(2026, 5, 30, 8, 1),
          ),
        ],
      ),
    );
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
      providerRepository: InMemoryProviderRepository(
        providers: [
          _provider(
            id: 'provider-1',
            protocol: ProviderProtocol.openai,
            defaultModelId: 'text-only',
          ),
        ],
        models: [
          _model(
            'text-only',
            ProviderProtocol.openai,
            supportsImages: false,
          ),
        ],
      ),
    );

    await controller.loadSession('session-1');
    await controller.retryLastFailed();

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.role, ChatRole.assistant);
    expect(assistant.state, MessageState.failed);
    expect(
      assistant.parts.single.text,
      'The selected model does not support images.',
    );
    expect(fakeProvider.requests, isEmpty);
  });

  test('retryLastFailed validates retained quoted images before provider call',
      () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider(const [ChatStreamDone()]);
    const quotedImage = AttachmentRef(
      id: 'quoted-image',
      localPath: '/tmp/quoted.png',
      mimeType: 'image/png',
    );
    await repository.saveDocument(
      _document(
        id: 'session-1',
        providerId: 'provider-1',
        modelId: 'text-only',
        messages: [
          ChatMessage(
            id: 'user-1',
            role: ChatRole.user,
            state: MessageState.completed,
            parts: const [MessagePart.text('edit this')],
            createdAt: DateTime.utc(2026, 5, 30, 8),
            updatedAt: DateTime.utc(2026, 5, 30, 8),
            replyRef: MessageReplyRef(
              messageId: 'assistant-image',
              role: ChatRole.assistant,
              textPreview: 'original image',
              imageAttachment: quotedImage,
              createdAt: DateTime.utc(2026, 5, 30, 7, 59),
            ),
          ),
          ChatMessage(
            id: 'assistant-1',
            role: ChatRole.assistant,
            state: MessageState.failed,
            parts: const [MessagePart.error('Generation failed.')],
            createdAt: DateTime.utc(2026, 5, 30, 8, 1),
            updatedAt: DateTime.utc(2026, 5, 30, 8, 1),
          ),
        ],
      ),
    );
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
      providerRepository: InMemoryProviderRepository(
        providers: [
          _provider(
            id: 'provider-1',
            protocol: ProviderProtocol.openai,
            defaultModelId: 'text-only',
          ),
        ],
        models: [
          _model(
            'text-only',
            ProviderProtocol.openai,
            supportsImages: false,
          ),
        ],
      ),
    );

    await controller.loadSession('session-1');
    await controller.retryLastFailed();

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.role, ChatRole.assistant);
    expect(assistant.state, MessageState.failed);
    expect(
      assistant.parts.single.text,
      'The selected model does not support images.',
    );
    expect(fakeProvider.requests, isEmpty);
  });

  test('retryLastFailed throws while generation is active', () async {
    final events = StreamController<ChatStreamEvent>();
    final controller = ChatController(
      repository: InMemorySessionRepository(),
      chatProvider: ControlledChatProvider(events.stream),
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    final sendFuture =
        controller.sendMessage(text: 'hi', attachments: const []);
    await pumpEventQueue();

    await expectLater(
      controller.retryLastFailed(),
      throwsA(isA<StateError>()),
    );

    events.add(const ChatStreamDone());
    await sendFuture;
    await events.close();
  });

  test('protocol/model mismatch blocks chat send before provider call',
      () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider([const ChatStreamDone()]);
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
      providerRepository: InMemoryProviderRepository(
        providers: [
          _provider(
            id: 'provider-1',
            protocol: ProviderProtocol.openai,
            defaultModelId: 'claude-3-5-sonnet-latest',
          ),
        ],
        models: [
          _model('claude-3-5-sonnet-latest', ProviderProtocol.claude),
        ],
      ),
    );
    await repository.saveDocument(
      _document(
        id: 'session-1',
        providerId: 'provider-1',
        modelId: 'claude-3-5-sonnet-latest',
      ),
    );

    await controller.loadSession('session-1');
    await controller.sendMessage(text: 'hi', attachments: const []);

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.role, ChatRole.assistant);
    expect(assistant.state, MessageState.failed);
    expect(assistant.parts.single.text, 'Provider and model protocols differ.');
    expect(fakeProvider.requests, isEmpty);
  });

  test('model without image support blocks image send before provider call',
      () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider([const ChatStreamDone()]);
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
      providerRepository: InMemoryProviderRepository(
        providers: [
          _provider(
            id: 'provider-1',
            protocol: ProviderProtocol.openai,
            defaultModelId: 'text-only',
          ),
        ],
        models: [
          _model(
            'text-only',
            ProviderProtocol.openai,
            supportsImages: false,
          ),
        ],
      ),
    );
    await repository.saveDocument(
      _document(
        id: 'session-1',
        providerId: 'provider-1',
        modelId: 'text-only',
      ),
    );

    await controller.loadSession('session-1');
    await controller.sendMessage(
      text: 'describe this',
      attachments: const [
        AttachmentRef(
          id: 'image-1',
          localPath: '/tmp/image.png',
          mimeType: 'image/png',
        ),
      ],
    );

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.role, ChatRole.assistant);
    expect(assistant.state, MessageState.failed);
    expect(
      assistant.parts.single.text,
      'The selected model does not support images.',
    );
    expect(fakeProvider.requests, isEmpty);
  });

  test('switchModel persists selection and sends images with new model',
      () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider([const ChatStreamDone()]);
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
      providerRepository: InMemoryProviderRepository(
        providers: [
          _provider(
            id: 'provider-1',
            protocol: ProviderProtocol.openai,
            defaultModelId: 'text-only',
          ),
        ],
        models: [
          _model(
            'text-only',
            ProviderProtocol.openai,
            supportsImages: false,
          ),
          _model(
            'vision-model',
            ProviderProtocol.openai,
            supportsImages: true,
          ),
        ],
      ),
    );
    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'text-only',
      title: 'New Chat',
    );

    await controller.switchModel(
      providerId: 'provider-1',
      modelId: 'vision-model',
    );
    await controller.sendMessage(
      text: 'describe this',
      attachments: const [
        AttachmentRef(
          id: 'image-1',
          localPath: '/tmp/image.png',
          mimeType: 'image/png',
        ),
      ],
    );

    final document = controller.currentDocument!;
    expect(document.providerId, 'provider-1');
    expect(document.modelId, 'vision-model');
    expect(
      (await repository.loadDocument(document.id))!.modelId,
      'vision-model',
    );
    expect(fakeProvider.requests, hasLength(1));
    expect(fakeProvider.requests.single.provider.id, 'provider-1');
    expect(fakeProvider.requests.single.model.id, 'vision-model');
    expect(
      fakeProvider.requests.single.messages
          .where((message) => message.role == ChatRole.user)
          .last
          .parts
          .any((part) => part.type == MessagePartType.image),
      isTrue,
    );
  });

  group('SessionListController', () {
    test('load reads repository metas', () async {
      final repository = InMemorySessionRepository();
      await repository.saveDocument(_document(id: 'session-1'));
      final controller = SessionListController(repository: repository);

      await controller.load();

      expect(controller.sessions.single.id, 'session-1');
    });

    test('renameSession updates the document title and reloads metas',
        () async {
      final repository = InMemorySessionRepository();
      await repository.saveDocument(_document(id: 'session-1', title: 'Old'));
      final controller = SessionListController(repository: repository);

      await controller.renameSession('session-1', 'New');

      expect((await repository.loadDocument('session-1'))!.title, 'New');
      expect(controller.sessions.single.title, 'New');
    });

    test('deleteSession removes the session and reloads metas', () async {
      final repository = InMemorySessionRepository();
      await repository.saveDocument(_document(id: 'session-1'));
      final controller = SessionListController(repository: repository);

      await controller.deleteSession('session-1');

      expect(await repository.loadDocument('session-1'), isNull);
      expect(controller.sessions, isEmpty);
    });

    test('pins marks unread and soft deletes sessions', () async {
      final repository = InMemorySessionRepository();
      await repository.saveDocument(_document(id: 'session-1'));
      final controller = SessionListController(repository: repository);

      await controller.pinSession('session-1');

      var document = (await repository.loadDocument('session-1'))!;
      expect(document.isPinned, isTrue);
      expect(document.pinnedAt, isNotNull);
      expect(controller.sessions.single.isPinned, isTrue);

      await controller.markUnread('session-1');
      document = (await repository.loadDocument('session-1'))!;
      expect(document.isUnread, isTrue);
      expect(controller.sessions.single.isUnread, isTrue);

      await controller.markRead('session-1');
      document = (await repository.loadDocument('session-1'))!;
      expect(document.isUnread, isFalse);

      await controller.unpinSession('session-1');
      document = (await repository.loadDocument('session-1'))!;
      expect(document.isPinned, isFalse);
      expect(document.pinnedAt, isNull);

      await controller.softDeleteSession('session-1');
      expect(await repository.loadDocument('session-1'), isNull);
      expect(controller.sessions, isEmpty);
    });
  });
}

class FakeChatProvider implements ChatProvider {
  FakeChatProvider(this.events);

  final List<ChatStreamEvent> events;
  final requests = <ChatRequest>[];

  @override
  Stream<ChatStreamEvent> sendStream(ChatRequest request) async* {
    requests.add(request);
    for (final event in events) {
      yield event;
    }
  }

  @override
  Future<ConnectionTestResult> testConnection(
    ConnectionTestRequest request,
  ) async {
    return const ConnectionTestResult.success();
  }
}

class ControlledChatProvider implements ChatProvider {
  const ControlledChatProvider(this.events);

  final Stream<ChatStreamEvent> events;

  @override
  Stream<ChatStreamEvent> sendStream(ChatRequest request) => events;

  @override
  Future<ConnectionTestResult> testConnection(
    ConnectionTestRequest request,
  ) async {
    return const ConnectionTestResult.success();
  }
}

class ThrowingChatProvider implements ChatProvider {
  const ThrowingChatProvider(this.error);

  final Object error;

  @override
  Stream<ChatStreamEvent> sendStream(ChatRequest request) {
    throw error;
  }

  @override
  Future<ConnectionTestResult> testConnection(
    ConnectionTestRequest request,
  ) async {
    return const ConnectionTestResult.success();
  }
}

class SequentialChatProvider implements ChatProvider {
  SequentialChatProvider(this.eventBatches);

  final List<List<ChatStreamEvent>> eventBatches;
  var _index = 0;

  @override
  Stream<ChatStreamEvent> sendStream(ChatRequest request) async* {
    final events = eventBatches[_index++];
    for (final event in events) {
      yield event;
    }
  }

  @override
  Future<ConnectionTestResult> testConnection(
    ConnectionTestRequest request,
  ) async {
    return const ConnectionTestResult.success();
  }
}

class ThrowingSaveSessionRepository implements SessionRepository {
  final _delegate = InMemorySessionRepository();
  var throwOnSave = false;

  Future<void> seed(ChatSessionDocument document) =>
      _delegate.saveDocument(document);

  @override
  Future<void> deleteSession(String id) => _delegate.deleteSession(id);

  @override
  Future<void> softDeleteSession(String id) => _delegate.softDeleteSession(id);

  @override
  Future<ChatSessionDocument?> loadDocument(String id) =>
      _delegate.loadDocument(id);

  @override
  Future<List<ChatSessionMeta>> listMetas() => _delegate.listMetas();

  @override
  Future<void> saveDocument(ChatSessionDocument document) {
    if (throwOnSave) {
      throw StateError('save failed');
    }
    return _delegate.saveDocument(document);
  }
}

ChatSessionDocument _document({
  required String id,
  String title = 'Title',
  String providerId = 'provider-1',
  String modelId = 'gpt-4o-mini',
  List<ChatMessage>? messages,
  String? contextSummary,
  DateTime? contextSummaryUpdatedAt,
}) {
  final now = DateTime.utc(2026, 5, 30);
  return ChatSessionDocument(
    id: id,
    title: title,
    providerId: providerId,
    modelId: modelId,
    systemPrompt: '',
    messages: messages ??
        [
          ChatMessage(
            id: 'message-1',
            role: ChatRole.user,
            state: MessageState.completed,
            parts: const [MessagePart.text('hello')],
            createdAt: now,
            updatedAt: now,
          ),
        ],
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
    contextSummary: contextSummary,
    contextSummaryUpdatedAt: contextSummaryUpdatedAt,
  );
}

ProviderConfig _provider({
  required String id,
  required ProviderProtocol protocol,
  required String defaultModelId,
}) {
  final now = DateTime.utc(2026);
  return ProviderConfig(
    id: id,
    name: id,
    protocol: protocol,
    baseUrl: 'https://api.example.com',
    defaultModelId: defaultModelId,
    createdAt: now,
    updatedAt: now,
  );
}

ModelConfig _model(
  String id,
  ProviderProtocol protocol, {
  bool supportsImages = true,
}) =>
    ModelConfig(
      id: id,
      displayName: id,
      protocol: protocol,
      supportsStreaming: true,
      supportsImages: supportsImages,
    );
