import 'package:newchat/features/chat/domain/chat_models.dart';

final demoChatSession = ChatSessionDocument(
  id: 'demo-session',
  title: 'Planning notes',
  providerId: 'Demo OpenAI',
  modelId: 'GPT-4o mini',
  systemPrompt: 'Be concise and practical.',
  messages: [
    ChatMessage(
      id: 'm1',
      role: ChatRole.user,
      state: MessageState.completed,
      parts: const [MessagePart.text('Draft a concise rollout checklist.')],
      createdAt: DateTime(2026, 1, 1, 9),
      updatedAt: DateTime(2026, 1, 1, 9),
    ),
    ChatMessage(
      id: 'm2',
      role: ChatRole.assistant,
      state: MessageState.completed,
      parts: const [
        MessagePart.text(
          '- Confirm provider settings\n- Test streaming\n- Verify fallback errors\n\n```dart\nfinal ready = true;\n```',
        ),
      ],
      createdAt: DateTime(2026, 1, 1, 9, 1),
      updatedAt: DateTime(2026, 1, 1, 9, 1),
    ),
  ],
  createdAt: DateTime(2026, 1, 1, 9),
  updatedAt: DateTime(2026, 1, 1, 9, 1),
  schemaVersion: 1,
);

final demoSessionMetas = [
  ChatSessionMeta(
    id: demoChatSession.id,
    title: demoChatSession.title,
    lastMessagePreview: 'Summarize the rollout checklist.',
    providerId: 'demo-openai',
    modelId: 'gpt-4o-mini',
    createdAt: DateTime(2026, 1, 1, 9),
    updatedAt: DateTime(2026, 1, 1, 9, 30),
    isDeleted: false,
    schemaVersion: demoChatSession.schemaVersion,
  ),
];

extension DemoChatSessionCopy on ChatSessionDocument {
  ChatSessionDocument copyWith({
    String? id,
    String? title,
    String? providerId,
    String? modelId,
    String? systemPrompt,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    return ChatSessionDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      providerId: providerId ?? this.providerId,
      modelId: modelId ?? this.modelId,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}
