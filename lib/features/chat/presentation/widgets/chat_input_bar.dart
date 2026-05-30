import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ChatQuoteDraft {
  const ChatQuoteDraft({
    this.messageId = '',
    this.preview = '',
    this.ref,
  });

  final String messageId;
  final String preview;
  final MessageReplyRef? ref;
}

class ChatSendPayload {
  const ChatSendPayload({
    required this.text,
    required this.attachments,
    this.replyToMessageId,
    this.replyPreview,
    this.replyRef,
  });

  final String text;
  final List<AttachmentRef> attachments;
  final String? replyToMessageId;
  final String? replyPreview;
  final MessageReplyRef? replyRef;
}

typedef ChatSendCallback = void Function(ChatSendPayload payload);

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.supportsImages,
    required this.onSend,
    this.enabled = true,
    this.quote,
    this.onCancelQuote,
    ImagePicker? imagePicker,
  }) : _imagePicker = imagePicker;

  final bool supportsImages;
  final bool enabled;
  final ChatSendCallback onSend;
  final ChatQuoteDraft? quote;
  final VoidCallback? onCancelQuote;
  final ImagePicker? _imagePicker;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final List<AttachmentRef> _attachments = [];

  ImagePicker get _imagePicker => widget._imagePicker ?? ImagePicker();

  bool get _canSend =>
      widget.enabled &&
      (_controller.text.trim().isNotEmpty || _attachments.isNotEmpty);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    if (!widget.supportsImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.imageUnsupported)),
      );
      return;
    }

    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (!mounted || image == null) {
      return;
    }

    setState(() {
      _attachments.add(
        AttachmentRef(
          id: image.name,
          localPath: image.path,
          mimeType: image.mimeType ?? 'image/*',
        ),
      );
    });
  }

  void _send() {
    if (!_canSend) {
      return;
    }

    final quote = widget.quote;
    widget.onSend(
      ChatSendPayload(
        text: _controller.text.trim(),
        attachments: List.unmodifiable(_attachments),
        replyToMessageId: quote?.ref?.messageId ?? quote?.messageId,
        replyPreview: quote?.ref?.textPreview ?? quote?.preview,
        replyRef: quote?.ref,
      ),
    );
    setState(() {
      _controller.clear();
      _attachments.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.quote != null)
                  _QuotePreview(
                    quote: widget.quote!,
                    onCancel: widget.onCancelQuote,
                  ),
                if (_attachments.isNotEmpty)
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _attachments.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return InputChip(
                          label: Text('Image ${index + 1}'),
                          onDeleted: () {
                            setState(() => _attachments.removeAt(index));
                          },
                        );
                      },
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Add image',
                      onPressed: widget.enabled ? _pickImage : null,
                      icon: const Icon(Icons.image_outlined),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: widget.enabled,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: l10n.send,
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: l10n.send,
                      onPressed: _canSend ? _send : null,
                      icon: const Icon(Icons.send_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuotePreview extends StatelessWidget {
  const _QuotePreview({
    required this.quote,
    required this.onCancel,
  });

  final ChatQuoteDraft quote;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = quote.ref?.textPreview ?? quote.preview;
    return Container(
      key: const Key('composer-quote'),
      margin: const EdgeInsets.fromLTRB(4, 2, 4, 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          if (quote.ref?.imageAttachment != null) ...[
            _QuoteImage(
              key: const Key('composer-quote-image'),
              attachment: quote.ref!.imageAttachment!,
            ),
            const SizedBox(width: 8),
          ] else ...[
            Icon(
              Icons.format_quote_outlined,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _roleLabel(quote.ref?.role),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (preview.trim().isNotEmpty)
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel reply',
            visualDensity: VisualDensity.compact,
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _QuoteImage extends StatelessWidget {
  const _QuoteImage({
    super.key,
    required this.attachment,
  });

  final AttachmentRef attachment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Image.file(
          File(attachment.localPath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined, size: 18),
          ),
        ),
      ),
    );
  }
}

String _roleLabel(ChatRole? role) {
  return switch (role) {
    ChatRole.user => 'User',
    ChatRole.assistant => 'Assistant',
    ChatRole.system => 'System',
    null => 'Reply',
  };
}
