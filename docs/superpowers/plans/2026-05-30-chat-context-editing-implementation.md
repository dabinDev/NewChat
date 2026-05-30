# Chat Context Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add editable user messages, quoted replies, and deterministic context compression so one conversation keeps useful continuity without repeatedly sending stale image payloads.

**Architecture:** Extend the existing chat domain model with backward-compatible metadata, add a focused `ChatContextBuilder` between `ChatController` and providers, and keep UI state for reply/edit actions in chat presentation widgets. Providers continue to consume `ChatRequest`; the controller is responsible for mutating stored documents and passing compact provider-ready messages.

**Tech Stack:** Flutter, Dart, Riverpod `ChangeNotifier`, existing session repository, existing OpenAI/Claude provider payload builders, Flutter unit and widget tests.

---

## File Structure

- Modify `lib/features/chat/domain/chat_models.dart`: add `MessageEditEntry`; add `replyToMessageId`, `replyPreview`, `editedAt`, `editHistory`; add `contextSummary`, `contextSummaryUpdatedAt`.
- Create `lib/features/chat/application/chat_context_builder.dart`: build compact provider context; keep latest 12 completed user/assistant messages; summarize older text; strip old images; preserve latest user images; add quote preface.
- Modify `lib/features/chat/application/chat_controller.dart`: accept reply metadata, add edit-and-regenerate workflow, use context builder in `_requestFor`, persist context summaries.
- Modify `lib/features/chat/presentation/chat_screen.dart`: hold quote draft, show edit dialog, wire bubble actions.
- Modify `lib/features/chat/presentation/widgets/chat_input_bar.dart`: expose `ChatSendPayload`, show quote preview, cancel quote, pass reply metadata on send.
- Modify `lib/features/chat/presentation/widgets/message_bubble.dart`: long-press actions, quote preview rendering, edited marker.
- Tests: `test/features/chat/chat_models_test.dart`, new `test/features/chat/chat_context_builder_test.dart`, `test/features/chat/chat_controller_test.dart`, provider tests, and widget tests.

## Task 1: Domain Model Metadata

**Files:**
- Modify: `lib/features/chat/domain/chat_models.dart`
- Test: `test/features/chat/chat_models_test.dart`

- [ ] **Step 1: Write failing JSON tests**

Add tests proving new fields round-trip and old JSON still loads:

```dart
test('chat message reply and edit metadata round trips', () {
  final createdAt = DateTime.utc(2026, 5, 30, 1);
  final editedAt = DateTime.utc(2026, 5, 30, 2);
  final message = ChatMessage(
    id: 'message-1',
    role: ChatRole.user,
    state: MessageState.completed,
    parts: const [MessagePart.text('new text')],
    replyToMessageId: 'message-0',
    replyPreview: 'previous answer',
    editedAt: editedAt,
    editHistory: [MessageEditEntry(text: 'old text', editedAt: editedAt)],
    createdAt: createdAt,
    updatedAt: editedAt,
  );

  final copy = ChatMessage.fromJson(message.toJson());

  expect(copy.replyToMessageId, 'message-0');
  expect(copy.replyPreview, 'previous answer');
  expect(copy.editedAt, editedAt);
  expect(copy.editHistory.single.text, 'old text');
  expect(copy.editHistory.single.editedAt, editedAt);
});

test('chat message JSON remains backward compatible', () {
  final copy = ChatMessage.fromJson({
    'id': 'message-1',
    'role': 'user',
    'state': 'completed',
    'parts': [
      {'type': 'text', 'text': 'hello'},
    ],
    'createdAt': '2026-05-30T00:00:00.000Z',
    'updatedAt': '2026-05-30T00:00:00.000Z',
  });

  expect(copy.replyToMessageId, isNull);
  expect(copy.replyPreview, isNull);
  expect(copy.editedAt, isNull);
  expect(copy.editHistory, isEmpty);
});

test('chat session context summary round trips and old JSON defaults', () {
  final now = DateTime.utc(2026, 5, 30);
  final document = ChatSessionDocument(
    id: 'session-1',
    title: 'Title',
    providerId: 'provider-1',
    modelId: 'model-1',
    systemPrompt: '',
    messages: const [],
    contextSummary: '- user: older request',
    contextSummaryUpdatedAt: now,
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  );

  final copy = ChatSessionDocument.fromJson(document.toJson());
  expect(copy.contextSummary, '- user: older request');
  expect(copy.contextSummaryUpdatedAt, now);

  final oldCopy = ChatSessionDocument.fromJson({
    'id': 'session-old',
    'title': 'Old',
    'providerId': 'provider-1',
    'modelId': 'model-1',
    'systemPrompt': '',
    'messages': <Object?>[],
    'createdAt': '2026-05-30T00:00:00.000Z',
    'updatedAt': '2026-05-30T00:00:00.000Z',
    'schemaVersion': 1,
  });
  expect(oldCopy.contextSummary, isNull);
  expect(oldCopy.contextSummaryUpdatedAt, isNull);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/chat/chat_models_test.dart`

Expected: FAIL because `MessageEditEntry` and the new constructor fields do not exist.

- [ ] **Step 3: Implement minimal domain changes**

Add `MessageEditEntry` with `text`, `editedAt`, `toJson`, and `fromJson`. Add optional metadata fields to `ChatMessage`, defensively copy `editHistory`, include JSON keys, and parse missing `editHistory` as `const []`. Add nullable `contextSummary` and `contextSummaryUpdatedAt` to `ChatSessionDocument`, include them in JSON, and parse missing keys as null.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/chat/chat_models_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/domain/chat_models.dart test/features/chat/chat_models_test.dart
git commit -m "feat: add chat message metadata"
```

## Task 2: Context Builder

**Files:**
- Create: `lib/features/chat/application/chat_context_builder.dart`
- Test: `test/features/chat/chat_context_builder_test.dart`

- [ ] **Step 1: Write failing context tests**

Create tests for:

```dart
test('keeps latest 12 completed messages and summarizes older text', () { ... });
test('strips old images and preserves latest user images only', () { ... });
test('adds quote preface only to current replied user turn', () { ... });
test('excludes streaming failed cancelled and interrupted messages', () { ... });
```

Use real `ChatSessionDocument`, `ChatMessage`, `MessagePart`, and `AttachmentRef`. Assert the result begins with a `ChatRole.system` summary message when older text exists; assert only recent message ids remain; assert old image `AttachmentRef` ids are absent; assert latest user image id remains; assert quote-prefixed text contains:

```text
The user is replying to this earlier message:
"Paris"

User message:
why?
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/chat/chat_context_builder_test.dart`

Expected: FAIL because `ChatContextBuilder` does not exist.

- [ ] **Step 3: Implement builder**

Create:

```dart
class ChatContextBuildResult {
  const ChatContextBuildResult({
    required this.messages,
    required this.summary,
    required this.summaryUpdatedAt,
  });

  final List<ChatMessage> messages;
  final String? summary;
  final DateTime? summaryUpdatedAt;
}

class ChatContextBuilder {
  const ChatContextBuilder({this.recentMessageLimit = 12});
  final int recentMessageLimit;

  ChatContextBuildResult build(ChatSessionDocument document) { ... }
}
```

Implementation details:
- Filter to completed user/assistant messages.
- Split older/recent at `completed.length - recentMessageLimit`.
- Summary lines are deterministic: existing summary first, then `- user: <compact text>` or `- assistant: <compact text>` for older messages with non-empty text.
- Add summary as a `ChatRole.system` message with `MessagePart.text('Earlier conversation summary:\n$summary')`.
- Copy recent messages for provider payload.
- Preserve image parts only on the latest completed user message; strip images elsewhere.
- If a user message has `replyPreview`, replace its text part with the quote preface plus original text.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/chat/chat_context_builder_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/application/chat_context_builder.dart test/features/chat/chat_context_builder_test.dart
git commit -m "feat: build compact chat context"
```

## Task 3: Controller Editing And Reply Workflow

**Files:**
- Modify: `lib/features/chat/application/chat_controller.dart`
- Test: `test/features/chat/chat_controller_test.dart`

- [ ] **Step 1: Write failing controller tests**

Add tests for:

```dart
test('sendMessage stores reply metadata and sends quote preface', () async { ... });
test('editUserMessageAndRegenerate records history and removes later messages', () async { ... });
test('editUserMessageAndRegenerate rejects assistant messages', () async { ... });
test('requestFor persists generated context summary', () async { ... });
```

Use existing `FakeChatProvider`, `SequentialChatProvider`, and `InMemorySessionRepository`. Verify edited message text is sent to the provider, previous assistant messages after the edited user message are removed before regeneration, `editHistory.single.text` is the old prompt, and provider requests contain compact context messages.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/chat/chat_controller_test.dart`

Expected: FAIL because `sendMessage` has no reply parameters and `editUserMessageAndRegenerate` does not exist.

- [ ] **Step 3: Implement controller changes**

Update constructor to accept `ChatContextBuilder contextBuilder = const ChatContextBuilder()` and store `_contextBuilder`.

Update `sendMessage`:

```dart
Future<void> sendMessage({
  required String text,
  required List<AttachmentRef> attachments,
  String? replyToMessageId,
  String? replyPreview,
})
```

Pass reply fields into the created user message.

Add:

```dart
Future<void> editUserMessageAndRegenerate({
  required String messageId,
  required String text,
}) async { ... }
```

Rules:
- Throw if generation is active.
- Locate message by id.
- Allow only completed user messages.
- Trim new text and reject empty.
- Preserve original image parts.
- Replace text, set `editedAt`, append `MessageEditEntry(text: original.fullText, editedAt: now)`.
- Truncate all messages after the edited user message.
- Save document, then call `_streamAssistantResponse`.

Update `_requestFor`:
- Build context from `_currentDocument!` with `_contextBuilder`.
- If summary changed, save a copied document with `contextSummary` and `contextSummaryUpdatedAt`.
- Pass `context.messages` into `ChatRequest` instead of `document.messages`.

Update `_copyDocument` and `_copyMessage` to carry all new fields.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/chat/chat_controller_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/application/chat_controller.dart test/features/chat/chat_controller_test.dart
git commit -m "feat: edit and quote chat messages"
```

## Task 4: Provider Compact Context Coverage

**Files:**
- Modify: `test/features/providers/openai_provider_test.dart`
- Modify: `test/features/providers/claude_provider_test.dart`

- [ ] **Step 1: Add provider regression tests**

Add one OpenAI test and one Claude test that pass context-builder-style messages:
- A `ChatRole.system` summary message containing `Earlier conversation summary`.
- A latest user message with text and current image.
- No old image message.

Assert JSON includes the summary text and current data URL, and does not include an old local image path such as `C:\images\old.png`.

- [ ] **Step 2: Run provider tests**

Run: `flutter test test/features/providers/openai_provider_test.dart test/features/providers/claude_provider_test.dart`

Expected: PASS if providers already trust compact context; otherwise make the minimal provider filtering change required by the tests.

- [ ] **Step 3: Commit**

```bash
git add test/features/providers/openai_provider_test.dart test/features/providers/claude_provider_test.dart lib/features/providers
git commit -m "test: cover compact provider context"
```

## Task 5: Chat UI Reply And Edit Actions

**Files:**
- Modify: `lib/features/chat/presentation/chat_screen.dart`
- Modify: `lib/features/chat/presentation/widgets/chat_input_bar.dart`
- Modify: `lib/features/chat/presentation/widgets/message_bubble.dart`
- Test: `test/widget/message_bubble_layout_test.dart`
- Test: `test/widget/chat_reply_edit_test.dart`

- [ ] **Step 1: Write failing widget tests**

Create `test/widget/chat_reply_edit_test.dart` with:

```dart
testWidgets('input bar displays quote preview and sends reply metadata', (tester) async { ... });
testWidgets('message bubble exposes reply and edit actions for completed user messages', (tester) async { ... });
testWidgets('assistant bubble exposes reply but not edit', (tester) async { ... });
testWidgets('message bubble renders quote preview and edited marker', (tester) async { ... });
```

Assertions:
- `ChatInputBar` displays quote preview text and close icon.
- Send callback receives a `ChatSendPayload` with text, attachments, `replyToMessageId`, and `replyPreview`.
- Long-press completed user bubble shows `Reply` and `Edit`.
- Long-press completed assistant bubble shows `Reply` but not `Edit`.
- A message with `replyPreview` displays that preview.
- A message with `editedAt` displays `Edited`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/message_bubble_layout_test.dart test/widget/chat_reply_edit_test.dart`

Expected: FAIL because the UI APIs do not exist.

- [ ] **Step 3: Implement `ChatInputBar` quote payload**

Add:

```dart
class ChatQuoteDraft {
  const ChatQuoteDraft({required this.messageId, required this.preview});
  final String messageId;
  final String preview;
}

class ChatSendPayload {
  const ChatSendPayload({
    required this.text,
    required this.attachments,
    this.replyToMessageId,
    this.replyPreview,
  });
  final String text;
  final List<AttachmentRef> attachments;
  final String? replyToMessageId;
  final String? replyPreview;
}

typedef ChatSendCallback = void Function(ChatSendPayload payload);
```

Add `quote` and `onCancelQuote` fields, render a compact quote row above attachments, and send a `ChatSendPayload`.

- [ ] **Step 4: Implement `MessageBubble` actions and rendering**

Add optional `ValueChanged<ChatMessage> onReply` and `onEdit` callbacks. Wrap the bubble in a long-press handler that shows a bottom sheet. User completed messages get Reply/Edit; assistant completed messages get Reply only. Render `replyPreview` above the content and `Edited` below the content when `editedAt != null`.

- [ ] **Step 5: Wire `ChatScreen`**

Maintain `ChatQuoteDraft? _quote`. On reply, set `_quote` from message id and a compact preview from `message.fullText`. On send, clear `_quote` and pass reply metadata into `controller.sendMessage`. On edit, open an `AlertDialog` seeded with `message.fullText` and call `controller.editUserMessageAndRegenerate`.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/widget/message_bubble_layout_test.dart test/widget/chat_reply_edit_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/chat/presentation test/widget/message_bubble_layout_test.dart test/widget/chat_reply_edit_test.dart
git commit -m "feat: add chat reply and edit UI"
```

## Task 6: Full Verification, APK, Emulator Install

**Files:**
- No planned source edits; fix only defects found by verification.

- [ ] **Step 1: Format**

Run: `dart format lib test`

Expected: formatting succeeds.

- [ ] **Step 2: Analyze**

Run: `flutter analyze`

Expected: no issues.

- [ ] **Step 3: Full tests**

Run: `flutter test`

Expected: all tests pass.

- [ ] **Step 4: Build debug APK**

Run: `flutter build apk --debug`

Expected: `build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 5: Copy APK to desktop**

Run: `Copy-Item -LiteralPath build\app\outputs\flutter-apk\app-debug.apk -Destination E:\windows\Desktop\NewChat-debug.apk -Force`

Expected: `E:\windows\Desktop\NewChat-debug.apk` exists.

- [ ] **Step 6: Install on emulator**

Run: `adb -s emulator-5554 install -r E:\windows\Desktop\NewChat-debug.apk`

Expected: install succeeds.

- [ ] **Step 7: Launch and inspect logs**

Run: `adb -s emulator-5554 shell monkey -p cn.cylonai.newchat 1`

Run: `adb -s emulator-5554 logcat -d -t 300 | Select-String -Pattern "FATAL EXCEPTION|flutter|NewChat"`

Expected: no fatal exception during launch. Verify long-press actions, quote preview, edit dialog, and normal chat send on emulator.

- [ ] **Step 8: Push**

Run:

```bash
git status --short
git push origin feature/newchat-implementation
```

Expected: all feature commits are pushed. If verification fixes created changes, commit them before pushing.

## Self-Review

- Spec coverage: Task 1 covers data model and compatibility. Task 2 covers local compression, recent window, summary storage input, quote preface, filtering, and image stripping. Task 3 covers editing, truncation, regeneration, reply metadata, and request context. Task 4 guards provider payload behavior. Task 5 covers long-press UI, quote preview, edit dialog, and edited marker. Task 6 covers format, analysis, tests, APK, emulator install, launch, logs, and push.
- Placeholder scan: no task contains TODO/TBD/fill-in work; each behavior has named files, commands, and expected outcomes.
- Type consistency: `MessageEditEntry`, `ChatContextBuilder`, `ChatQuoteDraft`, `ChatSendPayload`, `editUserMessageAndRegenerate`, `replyToMessageId`, and `replyPreview` are consistently named across tasks.
