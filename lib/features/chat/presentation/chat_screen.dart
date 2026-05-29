import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:newchat/core/routing/app_routes.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:newchat/features/chat/presentation/widgets/message_bubble.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ChatScreen extends StatefulWidget {
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
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late String _title;
  late String _providerId;
  late String _modelId;

  @override
  void initState() {
    super.initState();
    _title = ChatScreen._demoSession.title;
    _providerId = ChatScreen._demoSession.providerId;
    _modelId = ChatScreen._demoSession.modelId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = widget.sessionId == 'new'
        ? ChatScreen._demoSession
        : ChatSessionDocument(
            id: widget.sessionId,
            title: ChatScreen._demoSession.title,
            providerId: ChatScreen._demoSession.providerId,
            modelId: ChatScreen._demoSession.modelId,
            systemPrompt: ChatScreen._demoSession.systemPrompt,
            messages: ChatScreen._demoSession.messages,
            createdAt: ChatScreen._demoSession.createdAt,
            updatedAt: ChatScreen._demoSession.updatedAt,
            schemaVersion: ChatScreen._demoSession.schemaVersion,
          );
    final isStreaming = session.messages.any(
      (message) => message.state == MessageState.streaming,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title.isEmpty ? l10n.newChat : _title),
            Text(
              '$_providerId / $_modelId',
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
            onSelected: _handleAction,
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

  Future<void> _handleAction(_ChatAction action) async {
    switch (action) {
      case _ChatAction.rename:
        await _showRenameDialog();
      case _ChatAction.systemPrompt:
        if (mounted) {
          context.go(AppRoutes.systemPromptPath(widget.sessionId));
        }
      case _ChatAction.switchModel:
        await _showSwitchModelSheet();
      case _ChatAction.delete:
        await _showDeleteDialog();
    }
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: _title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newTitle != null && newTitle.isNotEmpty && mounted) {
      setState(() => _title = newTitle);
    }
  }

  Future<void> _showSwitchModelSheet() async {
    final selectedModel = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('GPT-4o mini'),
              subtitle: const Text('Demo OpenAI'),
              selected: _modelId == 'GPT-4o mini',
              onTap: () => Navigator.of(context).pop('GPT-4o mini'),
            ),
            ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: const Text('Claude 3.5 Sonnet'),
              subtitle: const Text('Demo Claude'),
              selected: _modelId == 'Claude 3.5 Sonnet',
              onTap: () => Navigator.of(context).pop('Claude 3.5 Sonnet'),
            ),
          ],
        ),
      ),
    );

    if (selectedModel != null && mounted) {
      setState(() {
        _modelId = selectedModel;
        _providerId =
            selectedModel.startsWith('Claude') ? 'Demo Claude' : 'Demo OpenAI';
      });
    }
  }

  Future<void> _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat?'),
        content: const Text('This demo chat will be marked deleted locally.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat deleted locally')),
      );
    }
  }
}

enum _ChatAction { rename, systemPrompt, switchModel, delete }
