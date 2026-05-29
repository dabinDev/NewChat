import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/data/session_repository.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';

void main() {
  test('in-memory repository saves and lists session documents', () async {
    final repository = InMemorySessionRepository();
    final createdAt = DateTime.utc(2026, 5, 30);
    final document = ChatSessionDocument(
      id: 'session-1',
      title: 'Hello',
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      systemPrompt: '',
      messages: [
        ChatMessage(
          id: 'message-1',
          role: ChatRole.user,
          state: MessageState.completed,
          parts: const [MessagePart.text('hello')],
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      ],
      createdAt: createdAt,
      updatedAt: createdAt,
      schemaVersion: 1,
    );

    await repository.saveDocument(document);

    final loaded = await repository.loadDocument('session-1');
    final metas = await repository.listMetas();

    expect(loaded!.title, 'Hello');
    expect(metas.single.lastMessagePreview, 'hello');
  });
}
