import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';

void main() {
  test('session meta round trips preview and deleted state', () {
    final createdAt = DateTime.utc(2026, 5, 30, 1, 2, 3);
    final updatedAt = DateTime.utc(2026, 5, 30, 4, 5, 6);
    final meta = ChatSessionMeta(
      id: 'session-1',
      title: 'Hello',
      lastMessagePreview: 'hello',
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: true,
      schemaVersion: 1,
    );

    final json = meta.toJson();
    final copy = ChatSessionMeta.fromJson(json);

    expect(json['lastMessagePreview'], 'hello');
    expect(json['isDeleted'], isTrue);
    expect(copy.id, 'session-1');
    expect(copy.title, 'Hello');
    expect(copy.lastMessagePreview, 'hello');
    expect(copy.providerId, 'provider-1');
    expect(copy.modelId, 'gpt-4o-mini');
    expect(copy.createdAt, createdAt);
    expect(copy.updatedAt, updatedAt);
    expect(copy.isDeleted, isTrue);
    expect(copy.schemaVersion, 1);
  });

  test('session document round trips message parts and attachments', () {
    final createdAt = DateTime.utc(2026, 5, 30, 1, 2, 3);
    final updatedAt = DateTime.utc(2026, 5, 30, 4, 5, 6);
    final document = ChatSessionDocument(
      id: 'session-1',
      title: 'Vision test',
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      systemPrompt: 'Be concise.',
      messages: [
        ChatMessage(
          id: 'message-1',
          role: ChatRole.user,
          state: MessageState.completed,
          parts: [
            const MessagePart.text('what is in this image?'),
            MessagePart.image(
              AttachmentRef(
                id: 'attachment-1',
                localPath: '/private/image.jpg',
                mimeType: 'image/jpeg',
                width: 1280,
                height: 720,
                fileSize: 2048,
              ),
            ),
          ],
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      ],
      createdAt: createdAt,
      updatedAt: updatedAt,
      schemaVersion: 1,
    );

    final json = document.toJson();
    final copy = ChatSessionDocument.fromJson(document.toJson());

    expect(copy.id, 'session-1');
    expect(copy.title, 'Vision test');
    expect(copy.providerId, 'provider-1');
    expect(copy.modelId, 'gpt-4o-mini');
    expect(copy.createdAt, createdAt);
    expect(copy.updatedAt, updatedAt);
    expect(copy.schemaVersion, 1);
    expect(json['createdAt'], createdAt.toIso8601String());
    expect(json['schemaVersion'], 1);
    expect(copy.messages.single.role, ChatRole.user);
    expect(copy.messages.single.state, MessageState.completed);
    expect(copy.messages.single.parts.length, 2);
    expect(copy.messages.single.parts.first.type, MessagePartType.text);
    expect(copy.messages.single.parts.first.text, 'what is in this image?');
    expect(copy.messages.single.parts.last.type, MessagePartType.image);
    expect(copy.messages.single.parts.last.attachment?.id, 'attachment-1');
    expect(
      copy.messages.single.parts.last.attachment?.localPath,
      '/private/image.jpg',
    );
    expect(copy.messages.single.parts.last.attachment?.mimeType, 'image/jpeg');
    expect(copy.messages.single.parts.last.attachment?.width, 1280);
    expect(copy.messages.single.parts.last.attachment?.height, 720);
    expect(copy.messages.single.parts.last.attachment?.fileSize, 2048);
    expect(copy.systemPrompt, 'Be concise.');
    expect(
      (json['messages']! as List<Object?>).single,
      isA<Map<String, Object?>>(),
    );
    expect(
      (((json['messages']! as List<Object?>).single
              as Map<String, Object?>)['parts']! as List<Object?>)
          .last,
      containsPair('type', 'image'),
    );
  });

  test('chat message reply and edit metadata round trips', () {
    final createdAt = DateTime.utc(2026, 5, 30, 1, 2, 3);
    final updatedAt = DateTime.utc(2026, 5, 30, 4, 5, 6);
    final editedAt = DateTime.utc(2026, 5, 30, 5, 6, 7);
    final firstEditAt = DateTime.utc(2026, 5, 30, 4, 30);
    final editHistory = [
      MessageEditEntry(text: 'hello', editedAt: firstEditAt),
    ];
    final message = ChatMessage(
      id: 'message-2',
      role: ChatRole.assistant,
      state: MessageState.completed,
      parts: const [MessagePart.text('hello there')],
      createdAt: createdAt,
      updatedAt: updatedAt,
      replyToMessageId: 'message-1',
      replyPreview: 'original question',
      editedAt: editedAt,
      editHistory: editHistory,
    );

    editHistory.add(
      MessageEditEntry(text: 'mutated', editedAt: DateTime.utc(2026, 5, 31)),
    );

    final json = message.toJson();
    final copy = ChatMessage.fromJson(json);

    expect(json['replyToMessageId'], 'message-1');
    expect(json['replyPreview'], 'original question');
    expect(json['editedAt'], editedAt.toIso8601String());
    expect(json['editHistory'], [
      {'text': 'hello', 'editedAt': firstEditAt.toIso8601String()},
    ]);
    expect(copy.replyToMessageId, 'message-1');
    expect(copy.replyPreview, 'original question');
    expect(copy.editedAt, editedAt);
    expect(copy.editHistory, hasLength(1));
    expect(copy.editHistory.single.text, 'hello');
    expect(copy.editHistory.single.editedAt, firstEditAt);
    expect(
      () => copy.editHistory.add(
        MessageEditEntry(text: 'direct mutation', editedAt: editedAt),
      ),
      throwsUnsupportedError,
    );
  });

  test('chat message JSON remains backward compatible', () {
    final createdAt = DateTime.utc(2026, 5, 30, 1, 2, 3);
    final updatedAt = DateTime.utc(2026, 5, 30, 4, 5, 6);
    final message = ChatMessage.fromJson({
      'id': 'message-1',
      'role': 'user',
      'state': 'completed',
      'parts': [
        {'type': 'text', 'text': 'hello', 'attachment': null},
      ],
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    });

    expect(message.replyToMessageId, isNull);
    expect(message.replyPreview, isNull);
    expect(message.editedAt, isNull);
    expect(message.editHistory, isEmpty);
    expect(
      () => message.editHistory.add(
        MessageEditEntry(text: 'direct mutation', editedAt: updatedAt),
      ),
      throwsUnsupportedError,
    );
  });

  test('chat session context summary round trips and old JSON defaults', () {
    final createdAt = DateTime.utc(2026, 5, 30, 1, 2, 3);
    final updatedAt = DateTime.utc(2026, 5, 30, 4, 5, 6);
    final summaryUpdatedAt = DateTime.utc(2026, 5, 30, 6, 7, 8);
    final document = ChatSessionDocument(
      id: 'session-1',
      title: 'Summary test',
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      systemPrompt: 'Be concise.',
      messages: const [],
      createdAt: createdAt,
      updatedAt: updatedAt,
      schemaVersion: 1,
      contextSummary: 'User prefers short answers.',
      contextSummaryUpdatedAt: summaryUpdatedAt,
    );

    final json = document.toJson();
    final copy = ChatSessionDocument.fromJson(json);
    final oldCopy = ChatSessionDocument.fromJson({
      'id': 'session-2',
      'title': 'Old session',
      'providerId': 'provider-1',
      'modelId': 'gpt-4o-mini',
      'systemPrompt': '',
      'messages': <Object?>[],
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'schemaVersion': 1,
    });

    expect(json['contextSummary'], 'User prefers short answers.');
    expect(
      json['contextSummaryUpdatedAt'],
      summaryUpdatedAt.toIso8601String(),
    );
    expect(copy.contextSummary, 'User prefers short answers.');
    expect(copy.contextSummaryUpdatedAt, summaryUpdatedAt);
    expect(oldCopy.contextSummary, isNull);
    expect(oldCopy.contextSummaryUpdatedAt, isNull);
  });

  test('constructors defensively copy and expose immutable lists', () {
    final messageParts = [const MessagePart.text('hello')];
    final message = ChatMessage(
      id: 'message-1',
      role: ChatRole.user,
      state: MessageState.completed,
      parts: messageParts,
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
    );

    messageParts.add(const MessagePart.text('mutated'));

    expect(message.parts, hasLength(1));
    expect(
      () => message.parts.add(const MessagePart.text('direct mutation')),
      throwsUnsupportedError,
    );

    final messages = [message];
    final document = ChatSessionDocument(
      id: 'session-1',
      title: 'Title',
      providerId: 'provider-1',
      modelId: 'model-1',
      systemPrompt: '',
      messages: messages,
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
      schemaVersion: 1,
    );

    messages.add(
      ChatMessage(
        id: 'message-2',
        role: ChatRole.assistant,
        state: MessageState.completed,
        parts: const [MessagePart.text('later')],
        createdAt: DateTime.utc(2026, 5, 30),
        updatedAt: DateTime.utc(2026, 5, 30),
      ),
    );

    expect(document.messages, hasLength(1));
    expect(
      () => document.messages.add(message),
      throwsUnsupportedError,
    );
  });

  test('message part JSON rejects invalid payloads', () {
    expect(
      () => MessagePart.fromJson({
        'type': 'text',
        'attachment': {
          'id': 'attachment-1',
          'localPath': '/private/image.jpg',
          'mimeType': 'image/jpeg',
        },
      }),
      throwsFormatException,
    );
    expect(
      () => MessagePart.fromJson({'type': 'image', 'text': 'not an image'}),
      throwsFormatException,
    );
    expect(
      () => MessagePart.fromJson({
        'type': 'image',
        'text': 'contradiction',
        'attachment': {
          'id': 'attachment-1',
          'localPath': '/private/image.jpg',
          'mimeType': 'image/jpeg',
        },
      }),
      throwsFormatException,
    );
    expect(
      () => MessagePart.fromJson({'type': 'error'}),
      throwsFormatException,
    );
  });

  test('fullText includes only normal text parts', () {
    final message = ChatMessage(
      id: 'message-1',
      role: ChatRole.assistant,
      state: MessageState.failed,
      parts: [
        const MessagePart.text('visible'),
        const MessagePart.error('diagnostic'),
        MessagePart.fromJson({'type': 'info', 'text': 'metadata'}),
        MessagePart.fromJson({'type': 'reasoning', 'text': 'hidden'}),
      ],
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
    );

    expect(message.fullText, 'visible');
  });

  test('provider config JSON round trips all fields', () {
    final createdAt = DateTime.utc(2026, 5, 30, 1, 2, 3);
    final updatedAt = DateTime.utc(2026, 5, 30, 4, 5, 6);
    final provider = ProviderConfig(
      id: 'provider-1',
      name: 'Gateway',
      protocol: ProviderProtocol.openai,
      baseUrl: 'https://example.test/v1',
      defaultModelId: 'model-1',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final json = provider.toJson();
    final copy = ProviderConfig.fromJson(json);

    expect(json['protocol'], 'openai');
    expect(copy.id, provider.id);
    expect(copy.name, provider.name);
    expect(copy.protocol, provider.protocol);
    expect(copy.baseUrl, provider.baseUrl);
    expect(copy.defaultModelId, provider.defaultModelId);
    expect(copy.createdAt, createdAt);
    expect(copy.updatedAt, updatedAt);
  });

  test('model config JSON round trips all fields', () {
    const model = ModelConfig(
      id: 'model-1',
      displayName: 'Fast model',
      protocol: ProviderProtocol.claude,
      supportsStreaming: true,
      supportsImages: true,
      contextLength: 200000,
    );

    final json = model.toJson();
    final copy = ModelConfig.fromJson(json);

    expect(json['protocol'], 'claude');
    expect(copy.id, model.id);
    expect(copy.displayName, model.displayName);
    expect(copy.protocol, model.protocol);
    expect(copy.supportsStreaming, isTrue);
    expect(copy.supportsImages, isTrue);
    expect(copy.contextLength, 200000);
  });

  test(
      'model effective image support treats OpenAI GPT models as vision capable',
      () {
    const staleFetchedModel = ModelConfig(
      id: 'gpt-5.5',
      displayName: 'gpt-5.5',
      protocol: ProviderProtocol.openai,
      supportsStreaming: true,
      supportsImages: false,
    );
    const manualTextOnlyModel = ModelConfig(
      id: 'codex-auto-review',
      displayName: 'codex-auto-review',
      protocol: ProviderProtocol.openai,
      supportsStreaming: true,
      supportsImages: false,
    );

    expect(staleFetchedModel.effectiveSupportsImages, isTrue);
    expect(manualTextOnlyModel.effectiveSupportsImages, isFalse);
  });
}
