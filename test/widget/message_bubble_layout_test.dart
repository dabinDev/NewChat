import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/presentation/widgets/message_bubble.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('long code block renders inside horizontal scroll container',
      (tester) async {
    final message = ChatMessage(
      id: 'code-message',
      role: ChatRole.assistant,
      state: MessageState.completed,
      parts: const [
        MessagePart.text(
          '```dart\nfinal value = "this-is-a-very-long-line-that-should-scroll-horizontally-instead-of-overflowing-the-bubble";\n```',
        ),
      ],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    await tester.binding.setSurfaceSize(const Size(260, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageBubble(message: message),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'unlabeled long code block renders inside horizontal scroll container',
      (tester) async {
    final message = ChatMessage(
      id: 'unlabeled-code-message',
      role: ChatRole.assistant,
      state: MessageState.completed,
      parts: const [
        MessagePart.text(
          '```\nfinal value = "this-is-a-very-long-line-that-should-scroll-horizontally-instead-of-overflowing-the-bubble";\n```',
        ),
      ],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    await tester.binding.setSurfaceSize(const Size(260, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageBubble(message: message),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsOneWidget,
    );
  });

  testWidgets('assistant text bubble keeps readable width on narrow screens',
      (tester) async {
    final message = ChatMessage(
      id: 'assistant-message',
      role: ChatRole.assistant,
      state: MessageState.completed,
      parts: const [
        MessagePart.text(
          'Today is **Saturday, May 30, 2026**.',
        ),
      ],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageBubble(message: message),
        ),
      ),
    );

    final bubbleWidth = tester
        .getSize(
          find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.margin ==
                    const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ) &&
                widget.padding == const EdgeInsets.all(12),
          ),
        )
        .width;

    expect(tester.takeException(), isNull);
    expect(bubbleWidth, greaterThanOrEqualTo(240));
    expect(bubbleWidth, lessThanOrEqualTo(296));
  });

  testWidgets('adjacent text parts render as a single markdown block',
      (tester) async {
    final message = ChatMessage(
      id: 'split-message',
      role: ChatRole.assistant,
      state: MessageState.completed,
      parts: const [
        MessagePart.text('Could '),
        MessagePart.text('you '),
        MessagePart.text('clarify?'),
      ],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageBubble(message: message),
        ),
      ),
    );

    expect(find.text('Could you clarify?'), findsOneWidget);
    expect(find.text('Could '), findsNothing);
    expect(find.text('you '), findsNothing);
  });

  testWidgets('empty streaming assistant bubble is compact', (tester) async {
    final message = ChatMessage(
      id: 'typing-message',
      role: ChatRole.assistant,
      state: MessageState.streaming,
      parts: const [],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageBubble(message: message),
        ),
      ),
    );

    final bubbleWidth = tester
        .getSize(
          find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.margin ==
                    const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ) &&
                widget.padding == const EdgeInsets.all(12),
          ),
        )
        .width;

    expect(find.text('Thinking'), findsOneWidget);
    expect(bubbleWidth, lessThan(180));
  });

  testWidgets('image thumbnail has stable dimensions', (tester) async {
    final message = ChatMessage(
      id: 'image-message',
      role: ChatRole.assistant,
      state: MessageState.completed,
      parts: [
        MessagePart.image(
          const AttachmentRef(
            id: 'image-1',
            localPath: '/missing/image.png',
            mimeType: 'image/png',
          ),
        ),
      ],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageBubble(message: message),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(const Key('message-image-box')));
    expect(size, const Size(160, 120));
  });
}
