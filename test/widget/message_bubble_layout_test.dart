import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/presentation/widgets/message_bubble.dart';

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
}
