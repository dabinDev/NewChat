import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:newchat/core/routing/app_routes.dart';
import 'package:newchat/features/chat/application/chat_controller.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:newchat/features/chat/presentation/widgets/message_bubble.dart';
import 'package:newchat/features/demo/demo_data.dart';
import 'package:newchat/features/providers/application/provider_controller.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.sessionId,
    this.demoSession,
  });

  final String sessionId;
  final ChatSessionDocument? demoSession;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late String _title;
  late String _providerId;
  late String _modelId;
  ChatSessionDocument? _session;
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final session = widget.demoSession ?? demoChatSession;
    _title = session.title;
    _providerId = session.providerId;
    _modelId = session.modelId;
    _session = session;
    if (widget.demoSession == null && widget.sessionId != 'new') {
      _loadSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final models = ref.watch(modelListProvider).valueOrNull ?? const [];
    final model = _firstModelWithId(models, _modelId);
    final baseSession = _session ?? widget.demoSession ?? demoChatSession;
    final session =
        widget.sessionId == 'new' || _session?.id == widget.sessionId
            ? baseSession
            : baseSession.copyWith(id: widget.sessionId);
    final isStreaming = session.messages.any(
      (message) => message.state == MessageState.streaming,
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _title.isEmpty ? l10n.newChat : _title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '$_providerId / $_modelId',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
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
            supportsImages: model?.supportsImages ?? true,
            enabled: !_isLoading && !_isSending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  Future<void> _loadSession() async {
    setState(() => _isLoading = true);
    try {
      final controller = ref.read(chatControllerProvider);
      await controller.loadSession(widget.sessionId);
      final session = controller.currentDocument!;
      if (mounted) {
        setState(() {
          _session = session;
          _title = session.title;
          _providerId = session.providerId;
          _modelId = session.modelId;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage(
    String text,
    List<AttachmentRef> attachments,
  ) async {
    setState(() => _isSending = true);
    try {
      final controller = ref.read(chatControllerProvider);
      if (widget.sessionId == 'new' && controller.currentDocument == null) {
        await controller.createSession(
          providerId: _providerId,
          modelId: _modelId,
          title: l10nTitle(text),
        );
      }
      await controller.sendMessage(text: text, attachments: attachments);
      if (mounted) {
        setState(() {
          _session = controller.currentDocument;
          _title = _session?.title ?? _title;
          _providerId = _session?.providerId ?? _providerId;
          _modelId = _session?.modelId ?? _modelId;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String l10nTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return AppLocalizations.of(context).newChat;
    }
    return trimmed.length <= 40 ? trimmed : trimmed.substring(0, 40);
  }

  ModelConfig? _firstModelWithId(List<ModelConfig> models, String modelId) {
    for (final model in models) {
      if (model.id == modelId) {
        return model;
      }
    }
    return null;
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
