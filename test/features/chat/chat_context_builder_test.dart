import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/application/chat_context_builder.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';

void main() {
  test('keeps latest 12 completed messages and summarizes older text', () {
    final now = DateTime.utc(2026, 5, 30);
    final messages = [
      for (var index = 0; index < 15; index++)
        _message(
          id: 'message-$index',
          role: index.isEven ? ChatRole.user : ChatRole.assistant,
          text: ' text   $index ',
          createdAt: now.add(Duration(minutes: index)),
        ),
    ];

    final result = const ChatContextBuilder().build(
      _document(messages: messages),
    );

    expect(result.summary, contains('- user: text 0'));
    expect(result.summary, contains('- assistant: text 1'));
    expect(result.summary, contains('- user: text 2'));
    expect(result.summaryUpdatedAt, isNotNull);
    expect(result.summaryUpdatedAt!.isUtc, isTrue);
    expect(result.messages.first.id, 'context-summary');
    expect(result.messages.first.role, ChatRole.system);
    expect(result.messages.first.state, MessageState.completed);
    expect(
      result.messages.first.fullText,
      'Earlier conversation summary:\n${result.summary}',
    );
    expect(
      result.messages.skip(1).map((message) => message.id),
      [for (var index = 3; index < 15; index++) 'message-$index'],
    );
  });

  test('strips old images and preserves latest user images only', () {
    final oldImage = _attachment('old-image');
    final assistantImage = _attachment('assistant-image');
    final latestUserImage = _attachment('latest-user-image');
    final laterAssistantImage = _attachment('later-assistant-image');
    final result = ChatContextBuilder(recentMessageLimit: 4).build(
      _document(
        messages: [
          _message(
            id: 'old-user',
            role: ChatRole.user,
            text: 'old user',
            parts: [
              const MessagePart.text('old user'),
              MessagePart.image(oldImage),
            ],
          ),
          _message(
            id: 'assistant-with-image',
            role: ChatRole.assistant,
            text: 'assistant',
            parts: [
              const MessagePart.text('assistant'),
              MessagePart.image(assistantImage),
            ],
          ),
          _message(
            id: 'latest-user',
            role: ChatRole.user,
            text: 'latest user',
            parts: [
              const MessagePart.text('latest user'),
              MessagePart.image(latestUserImage),
            ],
          ),
          _message(
            id: 'later-assistant',
            role: ChatRole.assistant,
            text: 'later assistant',
            parts: [
              const MessagePart.text('later assistant'),
              MessagePart.image(laterAssistantImage),
            ],
          ),
        ],
      ),
    );

    final providerParts = result.messages.expand((message) => message.parts);
    final imageIds = providerParts
        .where((part) => part.type == MessagePartType.image)
        .map((part) => part.attachment!.id)
        .toList();

    expect(imageIds, ['latest-user-image']);
  });

  test('adds quote preface to every recent replied user turn only', () {
    final result = ChatContextBuilder(recentMessageLimit: 4).build(
      _document(
        messages: [
          _message(
            id: 'older-reply',
            role: ChatRole.user,
            text: 'older why?',
            replyPreview: 'Berlin',
          ),
          _message(
            id: 'assistant',
            role: ChatRole.assistant,
            text: 'answer',
            replyPreview: 'Question',
          ),
          _message(
            id: 'current-reply',
            role: ChatRole.user,
            text: 'why?',
            replyPreview: 'Paris',
          ),
        ],
      ),
    );

    expect(
      result.messages
          .singleWhere((message) => message.id == 'older-reply')
          .fullText,
      'The user is replying to this earlier message:\n'
      '"Berlin"\n\n'
      'User message:\n'
      'older why?',
    );
    expect(
      result.messages
          .singleWhere((message) => message.id == 'assistant')
          .fullText,
      'answer',
    );
    expect(
      result.messages
          .singleWhere((message) => message.id == 'current-reply')
          .fullText,
      'The user is replying to this earlier message:\n'
      '"Paris"\n\n'
      'User message:\n'
      'why?',
    );
  });

  test('preserves metadata on copied provider messages', () {
    final editedAt = DateTime.utc(2026, 5, 30, 1, 2, 3);
    final firstEditAt = DateTime.utc(2026, 5, 30, 0, 30);
    final editHistory = [
      MessageEditEntry(text: 'original message', editedAt: firstEditAt),
    ];

    final result = const ChatContextBuilder().build(
      _document(
        messages: [
          _message(
            id: 'replying-user',
            role: ChatRole.user,
            text: 'edited message',
            replyToMessageId: 'assistant-1',
            replyPreview: 'Earlier answer',
            editedAt: editedAt,
            editHistory: editHistory,
          ),
        ],
      ),
    );

    final providerMessage = result.messages.single;

    expect(providerMessage.replyToMessageId, 'assistant-1');
    expect(providerMessage.replyPreview, 'Earlier answer');
    expect(providerMessage.editedAt, editedAt);
    expect(providerMessage.editHistory, hasLength(1));
    expect(providerMessage.editHistory.single.text, 'original message');
    expect(providerMessage.editHistory.single.editedAt, firstEditAt);
  });

  test('excludes streaming failed cancelled interrupted and system messages',
      () {
    final result = const ChatContextBuilder().build(
      _document(
        messages: [
          _message(id: 'system', role: ChatRole.system, text: 'system'),
          _message(
            id: 'streaming',
            role: ChatRole.user,
            state: MessageState.streaming,
            text: 'streaming',
          ),
          _message(
            id: 'failed',
            role: ChatRole.assistant,
            state: MessageState.failed,
            text: 'failed',
          ),
          _message(
            id: 'cancelled',
            role: ChatRole.assistant,
            state: MessageState.cancelled,
            text: 'cancelled',
          ),
          _message(
            id: 'interrupted',
            role: ChatRole.assistant,
            state: MessageState.interrupted,
            text: 'interrupted',
          ),
          _message(id: 'user', role: ChatRole.user, text: 'hello'),
          _message(id: 'assistant', role: ChatRole.assistant, text: 'hi'),
        ],
      ),
    );

    expect(
      result.messages.map((message) => message.id),
      ['user', 'assistant'],
    );
    expect(result.summary, isNull);
    expect(result.summaryUpdatedAt, isNull);
  });

  test(
      'preserves existing summary without changing timestamp when no older additions',
      () {
    final summaryUpdatedAt = DateTime.utc(2026, 5, 30, 1, 2, 3);
    final result = const ChatContextBuilder().build(
      _document(
        messages: [
          _message(id: 'user', role: ChatRole.user, text: 'hello'),
          _message(id: 'assistant', role: ChatRole.assistant, text: 'hi'),
        ],
        contextSummary: 'Existing summary.',
        contextSummaryUpdatedAt: summaryUpdatedAt,
      ),
    );

    expect(result.summary, 'Existing summary.');
    expect(result.summaryUpdatedAt, summaryUpdatedAt);
    expect(result.messages.first.id, 'context-summary');
    expect(
      result.messages.first.fullText,
      'Earlier conversation summary:\nExisting summary.',
    );
    expect(
      result.messages.skip(1).map((message) => message.id),
      ['user', 'assistant'],
    );
  });

  test('fills missing timestamp when unchanged summary exists', () {
    final result = const ChatContextBuilder().build(
      _document(
        messages: [
          _message(id: 'user', role: ChatRole.user, text: 'hello'),
          _message(id: 'assistant', role: ChatRole.assistant, text: 'hi'),
        ],
        contextSummary: 'Existing summary.',
      ),
    );

    expect(result.summary, 'Existing summary.');
    expect(result.summaryUpdatedAt, isNotNull);
    expect(result.summaryUpdatedAt!.isUtc, isTrue);
  });
}

ChatSessionDocument _document({
  required List<ChatMessage> messages,
  String? contextSummary,
  DateTime? contextSummaryUpdatedAt,
}) {
  final now = DateTime.utc(2026, 5, 30);
  return ChatSessionDocument(
    id: 'session-1',
    title: 'Session',
    providerId: 'provider-1',
    modelId: 'model-1',
    systemPrompt: '',
    messages: messages,
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
    contextSummary: contextSummary,
    contextSummaryUpdatedAt: contextSummaryUpdatedAt,
  );
}

ChatMessage _message({
  required String id,
  required ChatRole role,
  String text = '',
  MessageState state = MessageState.completed,
  List<MessagePart>? parts,
  String? replyToMessageId,
  String? replyPreview,
  DateTime? editedAt,
  List<MessageEditEntry> editHistory = const [],
  DateTime? createdAt,
}) =>
    ChatMessage(
      id: id,
      role: role,
      state: state,
      parts: parts ?? [MessagePart.text(text)],
      createdAt: createdAt ?? DateTime.utc(2026, 5, 30),
      updatedAt: createdAt ?? DateTime.utc(2026, 5, 30),
      replyToMessageId: replyToMessageId,
      replyPreview: replyPreview,
      editedAt: editedAt,
      editHistory: editHistory,
    );

AttachmentRef _attachment(String id) => AttachmentRef(
      id: id,
      localPath: '/private/$id.jpg',
      mimeType: 'image/jpeg',
    );
