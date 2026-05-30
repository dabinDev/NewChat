import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/presentation/image_viewer_screen.dart';
import 'package:newchat/features/chat/presentation/widgets/message_bubble.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('tapping image opens full screen viewer', (tester) async {
    final image = AttachmentRef(
      id: 'image-1',
      localPath: '/missing/image.png',
      mimeType: 'image/png',
    );
    AttachmentRef? opened;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageBubble(
            message: _imageMessage(image),
            onImageTap: (attachment) => opened = attachment,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('message-image-thumbnail')));
    await tester.pump();

    expect(opened, same(image));
  });

  test('image viewer save copies image into saved images directory', () async {
    final sourceDir = await Directory.systemTemp.createTemp('newchat-src-');
    final docsDir = await Directory.systemTemp.createTemp('newchat-docs-');
    addTearDown(() async {
      await sourceDir.delete(recursive: true);
      await docsDir.delete(recursive: true);
    });
    final source = File('${sourceDir.path}${Platform.pathSeparator}image.png');
    await source.writeAsBytes(_transparentPngBytes, flush: true);

    final savedFile = await saveViewerImage(
      attachment: AttachmentRef(
        id: 'image-1',
        localPath: source.path,
        mimeType: 'image/png',
      ),
      documentsDirectory: docsDir,
    );

    expect(savedFile.path, contains('saved-images'));
    expect(await savedFile.readAsBytes(), _transparentPngBytes);
  });

  testWidgets('image viewer edit returns edited prompt to chat screen',
      (tester) async {
    String? editedPrompt;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImageViewerScreen(
          attachment: const AttachmentRef(
            id: 'image-1',
            localPath: '/missing/image.png',
            mimeType: 'image/png',
          ),
          initialPrompt: 'draw a red kite',
          onEditPrompt: (prompt) => editedPrompt = prompt,
          documentsDirectoryProvider: () async => Directory.systemTemp,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Edit image prompt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'make it blue');
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    expect(editedPrompt, 'make it blue');
  });

  testWidgets('image viewer disables edit when no edit callback exists',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImageViewerScreen(
          attachment: const AttachmentRef(
            id: 'image-1',
            localPath: '/missing/image.png',
            mimeType: 'image/png',
          ),
          documentsDirectoryProvider: () async => Directory.systemTemp,
          imageBuilder: (context, file) => const SizedBox.shrink(),
        ),
      ),
    );

    final editButton = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Edit image prompt',
      ),
    );
    expect(editButton.onPressed, isNull);
  });
}

const _transparentPngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

ChatMessage _imageMessage(AttachmentRef attachment) {
  final now = DateTime.utc(2026, 5, 30);
  return ChatMessage(
    id: 'assistant-image',
    role: ChatRole.assistant,
    state: MessageState.completed,
    parts: [MessagePart.image(attachment)],
    createdAt: now,
    updatedAt: now,
  );
}
