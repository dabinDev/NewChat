import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/core/routing/app_back_button.dart';
import 'package:newchat/core/routing/app_routes.dart';
import 'package:newchat/features/chat/application/chat_controller.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/presentation/image_viewer_screen.dart';
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
  final ScrollController _scrollController = ScrollController();
  late String _title;
  late String _providerId;
  late String _modelId;
  ChatSessionDocument? _session;
  ChatController? _observedController;
  int _lastRenderedMessageCount = 0;
  String _lastRenderedText = '';
  bool _isLoading = false;
  bool _isSending = false;
  bool _hasProvider = true;
  ChatQuoteDraft? _quote;

  @override
  void initState() {
    super.initState();
    final session = widget.demoSession ?? _emptySession(widget.sessionId);
    _title = session.title;
    _providerId = session.providerId;
    _modelId = session.modelId;
    _session = session;
    if (widget.demoSession == null) {
      if (widget.sessionId == 'new') {
        _loadNewSessionDefaults();
      } else {
        _loadSession();
      }
    }
  }

  @override
  void dispose() {
    _observedController?.removeListener(_syncFromController);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _observeController(ref.watch(chatControllerProvider));
    final l10n = AppLocalizations.of(context);
    final models = ref.watch(modelListProvider).valueOrNull ?? const [];
    final model = _firstModelWithId(models, _modelId);
    final baseSession =
        _session ?? widget.demoSession ?? _emptySession(widget.sessionId);
    final session =
        widget.sessionId == 'new' || _session?.id == widget.sessionId
            ? baseSession
            : baseSession.copyWith(id: widget.sessionId);
    final isStreaming = session.messages.any(
      (message) => message.state == MessageState.streaming,
    );
    _scheduleScrollIfMessagesChanged(session);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        leading: const AppBackButton(fallbackPath: AppRoutes.home),
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
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: session.messages.length,
              itemBuilder: (context, index) {
                return MessageBubble(
                  message: session.messages[index],
                  onReply: _setReplyQuote,
                  onEdit: _showEditMessageDialog,
                  onImageTap: (attachment) => _openImageViewer(
                    attachment: attachment,
                    imageMessage: session.messages[index],
                  ),
                );
              },
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_hasProvider)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Add a provider in Settings before starting a new chat.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (isStreaming)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        ref.read(chatControllerProvider).stopGeneration();
                      },
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: Text(l10n.stop),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ),
              ChatInputBar(
                supportsImages: model?.effectiveSupportsImages ?? true,
                enabled: !_isLoading && !_isSending && _hasProvider,
                quote: _quote,
                onCancelQuote: () => setState(() => _quote = null),
                onSend: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _observeController(ChatController controller) {
    if (_observedController == controller) {
      return;
    }
    _observedController?.removeListener(_syncFromController);
    _observedController = controller;
    controller.addListener(_syncFromController);
  }

  void _syncFromController() {
    final document = _observedController?.currentDocument;
    if (document == null) {
      return;
    }
    if (widget.sessionId != 'new' && document.id != _session?.id) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _session = document;
      _title = document.title;
      _providerId = document.providerId;
      _modelId = document.modelId;
    });
  }

  void _scheduleScrollIfMessagesChanged(ChatSessionDocument session) {
    final textSnapshot = session.messages.map((message) {
      return '${message.id}:${message.state.name}:${message.fullText}';
    }).join('|');
    if (_lastRenderedMessageCount == session.messages.length &&
        _lastRenderedText == textSnapshot) {
      return;
    }
    _lastRenderedMessageCount = session.messages.length;
    _lastRenderedText = textSnapshot;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
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

  Future<void> _loadNewSessionDefaults() async {
    setState(() => _isLoading = true);
    try {
      final providers =
          await ref.read(providerControllerProvider).listProviders();
      if (!mounted) {
        return;
      }
      if (providers.isEmpty) {
        setState(() {
          _title = AppLocalizations.of(context).newChat;
          _providerId = '';
          _modelId = '';
          _session = null;
          _hasProvider = false;
        });
        return;
      }
      final provider = providers.first;
      setState(() {
        _title = AppLocalizations.of(context).newChat;
        _providerId = provider.id;
        _modelId = provider.defaultModelId;
        _session = null;
        _hasProvider = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage(ChatSendPayload payload) async {
    final quote = _quote;
    setState(() => _isSending = true);
    try {
      final controller = ref.read(chatControllerProvider);
      if (widget.sessionId == 'new' && _session == null) {
        if (_providerId.isNotEmpty && _modelId.isNotEmpty) {
          await controller.createSession(
            providerId: _providerId,
            modelId: _modelId,
            title: l10nTitle(payload.text),
          );
        } else {
          await controller.createSessionFromDefaultProvider(
            title: l10nTitle(payload.text),
          );
        }
      }
      await controller.sendMessage(
        text: payload.text,
        attachments: payload.attachments,
        replyToMessageId: payload.replyToMessageId,
        replyPreview: payload.replyPreview,
        replyRef: payload.replyRef,
      );
      if (mounted) {
        setState(() {
          if (_quote == quote) {
            _quote = null;
          }
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

  void _setReplyQuote(ChatMessage message) {
    setState(() {
      _quote = ChatQuoteDraft(
        ref: MessageReplyRef(
          messageId: message.id,
          role: message.role,
          textPreview: _compactPreview(message.fullText),
          imageAttachment: _firstImageAttachment(message),
          createdAt: message.createdAt,
        ),
      );
    });
  }

  Future<void> _showEditMessageDialog(ChatMessage message) async {
    final controller = TextEditingController(text: message.fullText);
    final editedText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Message',
            alignLabelWithHint: true,
          ),
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

    if (editedText == null || editedText.isEmpty || !mounted) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final chatController = ref.read(chatControllerProvider);
      await chatController.editUserMessageAndRegenerate(
        messageId: message.id,
        text: editedText,
      );
      if (mounted) {
        setState(() {
          _quote = null;
          _session = chatController.currentDocument;
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

  Future<void> _openImageViewer({
    required AttachmentRef attachment,
    required ChatMessage imageMessage,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(
          attachment: attachment,
          initialPrompt: _nearestPromptFor(imageMessage),
          onEditPrompt: (prompt) {
            Navigator.of(context).pop();
            _sendImageEditPrompt(imageMessage: imageMessage, prompt: prompt);
          },
        ),
      ),
    );
  }

  Future<void> _sendImageEditPrompt({
    required ChatMessage imageMessage,
    required String prompt,
  }) async {
    if (!mounted) {
      return;
    }
    setState(() => _isSending = true);
    try {
      final chatController = ref.read(chatControllerProvider);
      await chatController.sendImageEditPrompt(
        imageMessage: imageMessage,
        prompt: prompt,
      );
      if (mounted) {
        setState(() {
          _quote = null;
          _session = chatController.currentDocument;
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

  String _nearestPromptFor(ChatMessage imageMessage) {
    final messages = _session?.messages ?? const <ChatMessage>[];
    final index =
        messages.indexWhere((message) => message.id == imageMessage.id);
    if (index > 0) {
      for (var i = index - 1; i >= 0; i -= 1) {
        final message = messages[i];
        if (message.role == ChatRole.user &&
            message.fullText.trim().isNotEmpty) {
          return message.fullText.trim();
        }
      }
    }
    return imageMessage.fullText.trim();
  }

  AttachmentRef? _firstImageAttachment(ChatMessage message) {
    for (final part in message.parts) {
      if (part.type == MessagePartType.image && part.attachment != null) {
        return part.attachment;
      }
    }
    return null;
  }

  String _compactPreview(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 120) {
      return normalized;
    }
    return '${normalized.substring(0, 117)}...';
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
    final providers =
        await ref.read(providerControllerProvider).listProviders();
    final models = await ref.read(providerControllerProvider).listModels();
    final selections = _modelSelections(providers, models);
    if (!mounted) {
      return;
    }

    if (selections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No compatible models are configured.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<_ModelSelection>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: selections.length,
          itemBuilder: (context, index) {
            final selection = selections[index];
            final model = selection.model;
            final provider = selection.provider;
            return ListTile(
              leading: Icon(
                model.effectiveSupportsImages
                    ? Icons.image_outlined
                    : Icons.notes_outlined,
              ),
              title: Text(model.displayName),
              subtitle: Text(
                '${provider.name} / ${model.id}'
                '${model.effectiveSupportsImages ? ' / Images' : ' / Text only'}',
              ),
              selected: provider.id == _providerId && model.id == _modelId,
              onTap: () => Navigator.of(context).pop(selection),
            );
          },
        ),
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    final controller = ref.read(chatControllerProvider);
    final document = controller.currentDocument;
    if (document != null && document.id == _session?.id) {
      await controller.switchModel(
        providerId: selected.provider.id,
        modelId: selected.model.id,
      );
    }

    if (mounted) {
      setState(() {
        _modelId = selected.model.id;
        _providerId = selected.provider.id;
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

class _ModelSelection {
  const _ModelSelection({
    required this.provider,
    required this.model,
  });

  final ProviderConfig provider;
  final ModelConfig model;
}

List<_ModelSelection> _modelSelections(
  List<ProviderConfig> providers,
  List<ModelConfig> models,
) {
  return [
    for (final provider in providers)
      for (final model in models)
        if (provider.protocol == model.protocol)
          _ModelSelection(provider: provider, model: model),
  ];
}

ChatSessionDocument _emptySession(String sessionId) {
  final now = DateTime.now().toUtc();
  return ChatSessionDocument(
    id: sessionId,
    title: '',
    providerId: '',
    modelId: '',
    systemPrompt: '',
    messages: const [],
    createdAt: now,
    updatedAt: now,
    schemaVersion: AppConstants.schemaVersion,
  );
}
