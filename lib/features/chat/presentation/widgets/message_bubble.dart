import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onReply,
    this.onEdit,
  });

  final ChatMessage message;
  final ValueChanged<ChatMessage>? onReply;
  final ValueChanged<ChatMessage>? onEdit;

  bool get _isUser => message.role == ChatRole.user;
  bool get _canReply =>
      message.state == MessageState.completed &&
      (message.role == ChatRole.user || message.role == ChatRole.assistant) &&
      onReply != null;
  bool get _canEdit =>
      message.state == MessageState.completed &&
      message.role == ChatRole.user &&
      onEdit != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor =
        _isUser ? colorScheme.primaryContainer : colorScheme.surfaceContainer;
    final foreground =
        _isUser ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final parts = _mergedAdjacentTextParts(message.parts);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final maxBubbleWidth = (availableWidth * 0.86).clamp(0.0, 720.0);
        final shouldFillAssistantWidth = !_isUser && parts.isNotEmpty;

        return Align(
          alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: _canReply || _canEdit
                  ? () => _showMessageActions(context)
                  : null,
              child: Container(
                width: shouldFillAssistantWidth ? maxBubbleWidth : null,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(8),
                  border: _isUser
                      ? null
                      : Border.all(color: colorScheme.outlineVariant),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: foreground),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((message.replyPreview != null &&
                              message.replyPreview!.trim().isNotEmpty) ||
                          message.replyRef != null)
                        _BubbleQuotePreview(
                          ref: message.replyRef,
                          preview: message.replyPreview?.trim() ?? '',
                          foreground: foreground,
                        ),
                      for (final part in parts) _MessagePartView(part: part),
                      if (message.state == MessageState.streaming &&
                          parts.isEmpty)
                        _TypingIndicator(color: colorScheme.primary),
                      if (message.editedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Edited',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: foreground.withValues(alpha: 0.72),
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMessageActions(BuildContext context) async {
    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canReply)
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('Reply'),
                onTap: () => Navigator.of(context).pop(_MessageAction.reply),
              ),
            if (_canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.of(context).pop(_MessageAction.edit),
              ),
          ],
        ),
      ),
    );

    switch (action) {
      case _MessageAction.reply:
        onReply?.call(message);
      case _MessageAction.edit:
        onEdit?.call(message);
      case null:
        break;
    }
  }
}

enum _MessageAction { reply, edit }

List<MessagePart> _mergedAdjacentTextParts(List<MessagePart> parts) {
  final merged = <MessagePart>[];
  for (final part in parts) {
    if (part.type == MessagePartType.text &&
        merged.isNotEmpty &&
        merged.last.type == MessagePartType.text) {
      final previous = merged.removeLast();
      merged.add(MessagePart.text('${previous.text ?? ''}${part.text ?? ''}'));
      continue;
    }
    merged.add(part);
  }
  return merged;
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Thinking',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _BubbleQuotePreview extends StatelessWidget {
  const _BubbleQuotePreview({
    required this.ref,
    required this.preview,
    required this.foreground,
  });

  final MessageReplyRef? ref;
  final String preview;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('message-reply-block'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: foreground.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          if (ref?.imageAttachment != null) ...[
            _ReplyImage(
              key: const Key('message-reply-image'),
              attachment: ref!.imageAttachment!,
              foreground: foreground,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _roleLabel(ref?.role),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: foreground.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (preview.isNotEmpty)
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: foreground.withValues(alpha: 0.82),
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyImage extends StatelessWidget {
  const _ReplyImage({
    super.key,
    required this.attachment,
    required this.foreground,
  });

  final AttachmentRef attachment;
  final Color foreground;

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
            color: foreground.withValues(alpha: 0.12),
            child: Icon(
              Icons.broken_image_outlined,
              size: 18,
              color: foreground.withValues(alpha: 0.75),
            ),
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

class _MessagePartView extends StatelessWidget {
  const _MessagePartView({required this.part});

  final MessagePart part;

  @override
  Widget build(BuildContext context) {
    switch (part.type) {
      case MessagePartType.text:
        return _MarkdownWithMath(data: part.text ?? '');
      case MessagePartType.image:
        return _ImageThumbnail(attachment: part.attachment!);
      case MessagePartType.error:
        return _InlineError(text: part.text ?? '');
      case MessagePartType.info:
      case MessagePartType.reasoning:
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            part.text ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
    }
  }
}

class _MarkdownWithMath extends StatelessWidget {
  const _MarkdownWithMath({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mathMatch = RegExp(r'^\$\$(.+)\$\$$', dotAll: true).firstMatch(data);
    if (mathMatch != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: SelectableText(
          mathMatch.group(1)!.trim(),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
      );
    }

    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
      ),
      builders: {
        'code': _CodeElementBuilder(),
      },
    );
  }
}

class _CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(element, TextStyle? preferredStyle) {
    final className = element.attributes['class'] ?? '';
    final language = className.replaceFirst('language-', '');
    final code = element.textContent;
    if (code.trim().isEmpty) {
      return Text(code, style: preferredStyle);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: language.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      )
                    : HighlightView(
                        code,
                        language: language,
                        theme: githubTheme,
                        padding: const EdgeInsets.all(12),
                        textStyle: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({required this.attachment});

  final AttachmentRef attachment;

  @override
  Widget build(BuildContext context) {
    final file = File(attachment.localPath);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 160,
          height: 120,
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.broken_image_outlined)),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
