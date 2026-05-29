import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:newchat/core/routing/app_routes.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:newchat/features/chat/presentation/widgets/message_bubble.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  static final ChatSessionDocument _demoSession = ChatSessionDocument(
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = sessionId == 'new'
        ? _demoSession
        : ChatSessionDocument(
            id: sessionId,
            title: _demoSession.title,
            providerId: _demoSession.providerId,
            modelId: _demoSession.modelId,
            systemPrompt: _demoSession.systemPrompt,
            messages: _demoSession.messages,
            createdAt: _demoSession.createdAt,
            updatedAt: _demoSession.updatedAt,
            schemaVersion: _demoSession.schemaVersion,
          );
    final isStreaming = session.messages.any(
      (message) => message.state == MessageState.streaming,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.title.isEmpty ? l10n.newChat : session.title),
            Text(
              '${session.providerId} / ${session.modelId}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_ChatAction>(
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ChatAction.rename,
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Rename'),
                ),
              ),
              PopupMenuItem(
                value: _ChatAction.systemPrompt,
                child: ListTile(
                  leading: Icon(Icons.tune_outlined),
                  title: Text('System Prompt'),
                ),
              ),
              PopupMenuItem(
                value: _ChatAction.switchModel,
                child: ListTile(
                  leading: Icon(Icons.swap_horiz_outlined),
                  title: Text('Switch Model'),
                ),
              ),
              PopupMenuItem(
                value: _ChatAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete'),
                ),
              ),
            ],
            onSelected: (action) {
              if (action == _ChatAction.systemPrompt) {
                context.go(AppRoutes.systemPromptPath(sessionId));
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: session.messages.length,
        itemBuilder: (context, index) {
          return MessageBubble(message: session.messages[index]);
        },
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isStreaming)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(l10n.stop),
              ),
            ),
          ChatInputBar(
            supportsImages: true,
            onSend: (_, __) {},
          ),
        ],
      ),
    );
  }
}

enum _ChatAction { rename, systemPrompt, switchModel, delete }
