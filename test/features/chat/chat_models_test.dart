import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';

void main() {
  test('session document round trips message parts and attachments', () {
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
          createdAt: DateTime.utc(2026, 5, 30),
          updatedAt: DateTime.utc(2026, 5, 30),
        ),
      ],
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
      schemaVersion: 1,
    );

    final copy = ChatSessionDocument.fromJson(document.toJson());

    expect(copy.id, 'session-1');
    expect(copy.messages.single.parts.length, 2);
    expect(copy.messages.single.parts.last.type, MessagePartType.image);
    expect(copy.systemPrompt, 'Be concise.');
  });
}
