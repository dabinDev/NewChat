import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:newchat/features/chat/presentation/widgets/message_bubble.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('input bar displays quote preview and sends reply metadata',
      (tester) async {
    ChatSendPayload? sentPayload;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatInputBar(
            supportsImages: true,
            quote: const ChatQuoteDraft(
              messageId: 'message-1',
              preview: 'Earlier assistant answer',
            ),
            onCancelQuote: () {},
            onSend: (payload) => sentPayload = payload,
          ),
        ),
      ),
    );

    expect(find.text('Earlier assistant answer'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Why is that?');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();

    expect(sentPayload, isNotNull);
    expect(sentPayload!.text, 'Why is that?');
    expect(sentPayload!.attachments, isEmpty);
    expect(sentPayload!.replyToMessageId, 'message-1');
    expect(sentPayload!.replyPreview, 'Earlier assistant answer');
  });

  testWidgets(
      'message bubble exposes reply and edit actions for completed user messages',
      (tester) async {
    final message = _message(
      id: 'user-message',
      role: ChatRole.user,
      text: 'Can I edit this?',
    );
    ChatMessage? replied;
    ChatMessage? edited;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: message,
            onReply: (message) => replied = message,
            onEdit: (message) => edited = message,
          ),
        ),
      ),
    );

    await _longPressBubble(tester);
    await tester.pumpAndSettle();

    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(replied, same(message));

    await _longPressBubble(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(edited, same(message));
  });

  testWidgets('assistant bubble exposes reply but not edit', (tester) async {
    final message = _message(
      id: 'assistant-message',
      role: ChatRole.assistant,
      text: 'Assistant answer',
    );
    ChatMessage? replied;
    ChatMessage? edited;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: message,
            onReply: (message) => replied = message,
            onEdit: (message) => edited = message,
          ),
        ),
      ),
    );

    await _longPressBubble(tester);
    await tester.pumpAndSettle();

    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);

    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(replied, same(message));
    expect(edited, isNull);
  });

  testWidgets('message bubble renders quote preview and edited marker',
      (tester) async {
    final message = _message(
      id: 'edited-message',
      role: ChatRole.user,
      text: 'Updated question',
      replyPreview: 'Earlier assistant answer',
      editedAt: DateTime.utc(2026, 5, 30, 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(message: message),
        ),
      ),
    );

    expect(find.text('Earlier assistant answer'), findsOneWidget);
    expect(find.text('Updated question'), findsOneWidget);
    expect(find.text('Edited'), findsOneWidget);
  });
}

ChatMessage _message({
  required String id,
  required ChatRole role,
  required String text,
  MessageState state = MessageState.completed,
  String? replyPreview,
  DateTime? editedAt,
}) {
  final now = DateTime.utc(2026, 5, 30);
  return ChatMessage(
    id: id,
    role: role,
    state: state,
    parts: [MessagePart.text(text)],
    replyPreview: replyPreview,
    editedAt: editedAt,
    createdAt: now,
    updatedAt: now,
  );
}

Finder _bubbleContainer() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.margin ==
            const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ) &&
        widget.padding == const EdgeInsets.all(12),
  );
}

Future<void> _longPressBubble(WidgetTester tester) async {
  final topLeft = tester.getTopLeft(_bubbleContainer());
  await tester.longPressAt(topLeft + const Offset(6, 6));
  await tester.pumpAndSettle();
}
