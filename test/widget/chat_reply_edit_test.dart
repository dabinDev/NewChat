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

  testWidgets('composer quote shows text and image thumbnail', (tester) async {
    ChatSendPayload? sentPayload;
    final replyRef = MessageReplyRef(
      messageId: 'assistant-image',
      role: ChatRole.assistant,
      textPreview: 'Earlier image answer',
      imageAttachment: AttachmentRef(
        id: 'image-1',
        localPath: '/missing/composer-quote.png',
        mimeType: 'image/png',
      ),
      createdAt: DateTime.utc(2026, 5, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatInputBar(
            supportsImages: true,
            quote: ChatQuoteDraft(ref: replyRef),
            onCancelQuote: () {},
            onSend: (payload) => sentPayload = payload,
          ),
        ),
      ),
    );

    expect(find.text('Assistant'), findsOneWidget);
    expect(find.text('Earlier image answer'), findsOneWidget);
    expect(find.byKey(const Key('composer-quote-image')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'What should change?');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();

    expect(sentPayload!.replyRef!.messageId, 'assistant-image');
    expect(sentPayload!.replyRef!.imageAttachment!.id, 'image-1');
    expect(sentPayload!.replyToMessageId, 'assistant-image');
    expect(sentPayload!.replyPreview, 'Earlier image answer');
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

  testWidgets('image message exposes edit image action', (tester) async {
    final message = ChatMessage(
      id: 'assistant-image',
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
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
    );
    ChatMessage? imageEdited;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: message,
            onImageEdit: (message) => imageEdited = message,
          ),
        ),
      ),
    );

    await _longPressBubble(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Image'));
    await tester.pumpAndSettle();

    expect(imageEdited, same(message));
  });

  testWidgets('sent bubble quote shows role text and image thumbnail',
      (tester) async {
    final message = _message(
      id: 'reply-message',
      role: ChatRole.user,
      text: 'What should I change?',
      replyRef: MessageReplyRef(
        messageId: 'assistant-image',
        role: ChatRole.assistant,
        textPreview: 'Earlier image answer',
        imageAttachment: AttachmentRef(
          id: 'image-1',
          localPath: '/missing/bubble-quote.png',
          mimeType: 'image/png',
        ),
        createdAt: DateTime.utc(2026, 5, 30),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(message: message),
        ),
      ),
    );

    expect(find.text('Assistant'), findsOneWidget);
    expect(find.text('Earlier image answer'), findsOneWidget);
    expect(find.byKey(const Key('message-reply-image')), findsOneWidget);
    expect(find.text('What should I change?'), findsOneWidget);
  });

  testWidgets('composer quote clears after sending while sent bubble keeps ref',
      (tester) async {
    final replyRef = MessageReplyRef(
      messageId: 'assistant-1',
      role: ChatRole.assistant,
      textPreview: 'Earlier assistant answer',
      createdAt: DateTime.utc(2026, 5, 30),
    );
    ChatMessage? sentMessage;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _ComposerHarness(
          replyRef: replyRef,
          onSent: (message) => sentMessage = message,
        ),
      ),
    );

    expect(find.byKey(const Key('composer-quote')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Why?');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();

    expect(sentMessage!.replyRef!.messageId, 'assistant-1');
    expect(find.byKey(const Key('composer-quote')), findsNothing);
    expect(find.byKey(const Key('message-reply-block')), findsOneWidget);
    expect(find.text('Earlier assistant answer'), findsOneWidget);
  });
}

ChatMessage _message({
  required String id,
  required ChatRole role,
  required String text,
  MessageState state = MessageState.completed,
  String? replyPreview,
  MessageReplyRef? replyRef,
  DateTime? editedAt,
}) {
  final now = DateTime.utc(2026, 5, 30);
  return ChatMessage(
    id: id,
    role: role,
    state: state,
    parts: [MessagePart.text(text)],
    replyPreview: replyPreview,
    replyRef: replyRef,
    editedAt: editedAt,
    createdAt: now,
    updatedAt: now,
  );
}

class _ComposerHarness extends StatefulWidget {
  const _ComposerHarness({
    required this.replyRef,
    required this.onSent,
  });

  final MessageReplyRef replyRef;
  final ValueChanged<ChatMessage> onSent;

  @override
  State<_ComposerHarness> createState() => _ComposerHarnessState();
}

class _ComposerHarnessState extends State<_ComposerHarness> {
  ChatQuoteDraft? _quote;
  ChatMessage? _message;

  @override
  void initState() {
    super.initState();
    _quote = ChatQuoteDraft(ref: widget.replyRef);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_message != null) MessageBubble(message: _message!),
          ChatInputBar(
            supportsImages: true,
            quote: _quote,
            onCancelQuote: () => setState(() => _quote = null),
            onSend: (payload) {
              final now = DateTime.utc(2026, 5, 30, 1);
              final message = ChatMessage(
                id: 'sent',
                role: ChatRole.user,
                state: MessageState.completed,
                parts: [MessagePart.text(payload.text)],
                replyRef: payload.replyRef,
                createdAt: now,
                updatedAt: now,
              );
              widget.onSent(message);
              setState(() {
                _message = message;
                _quote = null;
              });
            },
          ),
        ],
      ),
    );
  }
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
