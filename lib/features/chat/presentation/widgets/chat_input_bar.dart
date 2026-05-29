import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

typedef ChatSendCallback = void Function(
  String text,
  List<AttachmentRef> attachments,
);

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.supportsImages,
    required this.onSend,
    this.enabled = true,
    ImagePicker? imagePicker,
  }) : _imagePicker = imagePicker;

  final bool supportsImages;
  final bool enabled;
  final ChatSendCallback onSend;
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

    widget.onSend(_controller.text.trim(), List.unmodifiable(_attachments));
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
