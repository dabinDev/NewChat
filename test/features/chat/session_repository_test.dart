import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/data/session_repository.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';

void main() {
  test('in-memory repository saves and lists session documents', () async {
    final repository = InMemorySessionRepository();
    final createdAt = DateTime.utc(2026, 5, 30);
    final document = _document(
      id: 'session-1',
      title: 'Hello',
      updatedAt: createdAt,
      messages: [
        _message(
          id: 'message-1',
          parts: const [MessagePart.text('hello')],
          at: createdAt,
        ),
      ],
    );

    await repository.saveDocument(document);

    final loaded = await repository.loadDocument('session-1');
    final metas = await repository.listMetas();

    expect(loaded!.title, 'Hello');
    expect(metas.single.lastMessagePreview, 'hello');
  });

  test('listMetas sorts sessions by updatedAt descending', () async {
    final repository = InMemorySessionRepository();
    await repository.saveDocument(
      _document(id: 'old', updatedAt: DateTime.utc(2026, 5, 30, 1)),
    );
    await repository.saveDocument(
      _document(id: 'new', updatedAt: DateTime.utc(2026, 5, 30, 3)),
    );
    await repository.saveDocument(
      _document(id: 'middle', updatedAt: DateTime.utc(2026, 5, 30, 2)),
    );

    final metas = await repository.listMetas();

    expect(metas.map((meta) => meta.id), ['new', 'middle', 'old']);
  });

  test('deleteSession removes a saved session', () async {
    final repository = InMemorySessionRepository();
    await repository.saveDocument(_document(id: 'session-1'));

    await repository.deleteSession('session-1');

    expect(await repository.loadDocument('session-1'), isNull);
    expect(await repository.listMetas(), isEmpty);
  });

  test('loadDocument returns null when session is missing', () async {
    final repository = InMemorySessionRepository();

    final loaded = await repository.loadDocument('missing');

    expect(loaded, isNull);
  });

  test('preview skips non-text error and image-only messages', () async {
    final repository = InMemorySessionRepository();
    final document = _document(
      id: 'session-1',
      messages: [
        _message(
          id: 'text',
          parts: const [MessagePart.text('visible text')],
          at: DateTime.utc(2026, 5, 30, 1),
        ),
        _message(
          id: 'image',
          parts: [
            MessagePart.image(
              const AttachmentRef(
                id: 'attachment-1',
                localPath: '/tmp/image.png',
                mimeType: 'image/png',
              ),
            ),
          ],
          at: DateTime.utc(2026, 5, 30, 2),
        ),
        _message(
          id: 'error',
          parts: const [MessagePart.error('error details')],
          at: DateTime.utc(2026, 5, 30, 3),
        ),
      ],
    );

    await repository.saveDocument(document);

    final metas = await repository.listMetas();

    expect(metas.single.lastMessagePreview, 'visible text');
  });
}

ChatSessionDocument _document({
  required String id,
  String title = 'Title',
  DateTime? updatedAt,
  List<ChatMessage>? messages,
}) {
  final createdAt = DateTime.utc(2026, 5, 30);
  return ChatSessionDocument(
    id: id,
    title: title,
    providerId: 'provider-1',
    modelId: 'gpt-4o-mini',
    systemPrompt: '',
    messages: messages ??
        [
          _message(
            id: 'message-1',
            parts: const [MessagePart.text('hello')],
            at: updatedAt ?? createdAt,
          ),
        ],
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    schemaVersion: 1,
  );
}

ChatMessage _message({
  required String id,
  required List<MessagePart> parts,
  required DateTime at,
}) =>
    ChatMessage(
      id: id,
      role: ChatRole.user,
      state: MessageState.completed,
      parts: parts,
      createdAt: at,
      updatedAt: at,
    );
