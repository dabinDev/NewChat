import 'dart:io';

import 'package:flutter/material.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();
typedef ViewerImageBuilder = Widget Function(BuildContext context, File file);

class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({
    super.key,
    required this.attachment,
    this.initialPrompt,
    this.onEditPrompt,
    this.documentsDirectoryProvider,
    this.imageBuilder,
  });

  final AttachmentRef attachment;
  final String? initialPrompt;
  final ValueChanged<String>? onEditPrompt;
  final DocumentsDirectoryProvider? documentsDirectoryProvider;
  final ViewerImageBuilder? imageBuilder;

  bool get _fileExists => File(attachment.localPath).existsSync();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exists = _fileExists;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: l10n.back,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(l10n.image),
        actions: [
          IconButton(
            tooltip: l10n.saveImage,
            onPressed: exists ? () => _save(context) : null,
            icon: const Icon(Icons.save_alt_outlined),
          ),
          IconButton(
            tooltip: l10n.editImagePrompt,
            onPressed:
                onEditPrompt == null ? null : () => _showEditDialog(context),
            icon: const Icon(Icons.auto_fix_high_outlined),
          ),
        ],
      ),
      body: Center(
        child: exists
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: _buildImage(context, File(attachment.localPath)),
              )
            : const _MissingImageState(),
      ),
    );
  }

  Widget _buildImage(BuildContext context, File file) {
    final builder = imageBuilder;
    if (builder != null) {
      return builder(context, file);
    }
    return Image.file(
      file,
      errorBuilder: (context, error, stackTrace) => const _MissingImageState(),
    );
  }

  Future<void> _save(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      final documentsDirectory = documentsDirectoryProvider == null
          ? await getApplicationDocumentsDirectory()
          : await documentsDirectoryProvider!();
      final file = await saveViewerImage(
        attachment: attachment,
        documentsDirectory: documentsDirectory,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.savedTo(file.path))),
      );
    } on Object {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unableToSaveImage)),
      );
    }
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final prompt = await showDialog<String>(
      context: context,
      builder: (context) => _EditPromptDialog(initialPrompt: initialPrompt),
    );

    if (prompt == null || prompt.isEmpty) {
      return;
    }
    onEditPrompt?.call(prompt);
    if (context.mounted) {
      Navigator.of(context).maybePop();
    }
  }
}

Future<File> saveViewerImage({
  required AttachmentRef attachment,
  required Directory documentsDirectory,
}) async {
  final directory = Directory(p.join(documentsDirectory.path, 'saved-images'));
  await directory.create(recursive: true);
  final extension = _extensionForMimeType(attachment.mimeType);
  final file = File(p.join(directory.path, '${attachment.id}$extension'));
  return File(attachment.localPath).copy(file.path);
}

class _EditPromptDialog extends StatefulWidget {
  const _EditPromptDialog({required this.initialPrompt});

  final String? initialPrompt;

  @override
  State<_EditPromptDialog> createState() => _EditPromptDialogState();
}

class _EditPromptDialogState extends State<_EditPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPrompt ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editImagePrompt),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 8,
        decoration: InputDecoration(
          labelText: l10n.prompt,
          alignLabelWithHint: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.generate),
        ),
      ],
    );
  }
}

class _MissingImageState extends StatelessWidget {
  const _MissingImageState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.broken_image_outlined,
          size: 48,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.imageFileMissing,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

String _extensionForMimeType(String mimeType) {
  return switch (mimeType.toLowerCase()) {
    'image/jpeg' || 'image/jpg' => '.jpg',
    'image/webp' => '.webp',
    'image/gif' => '.gif',
    _ => '.png',
  };
}
