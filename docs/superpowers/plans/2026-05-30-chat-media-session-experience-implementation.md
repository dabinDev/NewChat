# Chat Media Session Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add rich quoted replies, image viewing/saving/edit-regeneration, unfinished conversation restore, and session list pin/delete/unread controls.

**Architecture:** Extend chat/session domain metadata first, then wire repository/controller behavior, then layer UI affordances on top. Keep provider payloads text-based for quote context; image thumbnails are UI metadata only.

**Tech Stack:** Flutter, Dart, Riverpod, sqflite, existing chat/provider/session architecture, Flutter unit and widget tests.

---

## File Structure

- Modify `lib/features/chat/domain/chat_models.dart`
  - Add `MessageReplyRef`.
  - Add `replyRef` to `ChatMessage` while preserving `replyToMessageId` and `replyPreview`.
  - Add `isPinned`, `pinnedAt`, `isUnread` to `ChatSessionMeta` and `ChatSessionDocument`.
- Modify `lib/features/chat/data/session_repository.dart`
  - Persist and sort pin/unread metadata.
  - Add soft-delete/pin/unread update helpers or implement them via document saves.
- Modify `lib/core/storage/app_database.dart`
  - Add idempotent migration columns for `session_metas`.
- Modify `lib/features/chat/application/chat_controller.dart`
  - Build rich reply refs.
  - Mark loaded streaming assistants interrupted.
  - Retry failed/interrupted/cancelled trailing assistants.
  - Send image edit prompts.
- Modify `lib/features/chat/application/session_list_controller.dart`
  - Add pin/unpin, mark read/unread, soft delete methods.
- Modify `lib/features/chat/presentation/widgets/chat_input_bar.dart`
  - Show text/image/mixed quote previews.
- Modify `lib/features/chat/presentation/widgets/message_bubble.dart`
  - Show rich quote ref blocks.
  - Make images tappable.
  - Add image actions.
- Create `lib/features/chat/presentation/image_viewer_screen.dart`
  - Full-screen `InteractiveViewer` image viewer with save/edit actions.
- Modify `lib/features/chat/presentation/chat_screen.dart`
  - Wire rich reply refs, image viewer, image edit, retry/continue.
- Modify `lib/features/chat/presentation/session_list_screen.dart`
  - Add per-session menu for pin/delete/unread/read.
- Tests:
  - `test/features/chat/chat_models_test.dart`
  - `test/features/chat/session_repository_test.dart`
  - `test/features/chat/chat_controller_test.dart`
  - `test/widget/chat_reply_edit_test.dart`
  - `test/widget/message_bubble_layout_test.dart`
  - `test/widget/session_list_sessions_test.dart`
  - New `test/widget/image_viewer_test.dart`

## Task 1: Domain Metadata

**Files:**
- Modify: `lib/features/chat/domain/chat_models.dart`
- Test: `test/features/chat/chat_models_test.dart`

- [ ] **Step 1: Write failing tests**

Add tests:

```dart
test('message reply ref round trips text and image preview metadata', () {
  final now = DateTime.utc(2026, 5, 30);
  final ref = MessageReplyRef(
    messageId: 'm1',
    role: ChatRole.assistant,
    textPreview: 'look at this',
    imageAttachment: const AttachmentRef(
      id: 'image-1',
      localPath: '/tmp/image.png',
      mimeType: 'image/png',
    ),
    createdAt: now,
  );
  final message = ChatMessage(
    id: 'm2',
    role: ChatRole.user,
    state: MessageState.completed,
    parts: const [MessagePart.text('reply')],
    replyRef: ref,
    createdAt: now,
    updatedAt: now,
  );

  final copy = ChatMessage.fromJson(message.toJson());

  expect(copy.replyRef!.messageId, 'm1');
  expect(copy.replyRef!.role, ChatRole.assistant);
  expect(copy.replyRef!.textPreview, 'look at this');
  expect(copy.replyRef!.imageAttachment!.id, 'image-1');
  expect(copy.replyToMessageId, 'm1');
  expect(copy.replyPreview, 'look at this');
});

test('old reply fields hydrate text-only reply ref', () {
  final copy = ChatMessage.fromJson({
    'id': 'm2',
    'role': 'user',
    'state': 'completed',
    'parts': [
      {'type': 'text', 'text': 'reply'},
    ],
    'createdAt': '2026-05-30T00:00:00.000Z',
    'updatedAt': '2026-05-30T00:00:00.000Z',
    'replyToMessageId': 'm1',
    'replyPreview': 'legacy preview',
  });

  expect(copy.replyRef!.messageId, 'm1');
  expect(copy.replyRef!.textPreview, 'legacy preview');
  expect(copy.replyRef!.imageAttachment, isNull);
});

test('session pin and unread metadata round trips with old defaults', () {
  final now = DateTime.utc(2026, 5, 30);
  final document = ChatSessionDocument(
    id: 's1',
    title: 'Pinned',
    providerId: 'p1',
    modelId: 'm1',
    systemPrompt: '',
    messages: const [],
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
    isPinned: true,
    pinnedAt: now,
    isUnread: true,
  );

  final copy = ChatSessionDocument.fromJson(document.toJson());
  expect(copy.isPinned, isTrue);
  expect(copy.pinnedAt, now);
  expect(copy.isUnread, isTrue);
  expect(copy.meta.isPinned, isTrue);
  expect(copy.meta.isUnread, isTrue);

  final old = ChatSessionDocument.fromJson({
    'id': 's2',
    'title': 'Old',
    'providerId': 'p1',
    'modelId': 'm1',
    'systemPrompt': '',
    'messages': <Object?>[],
    'createdAt': '2026-05-30T00:00:00.000Z',
    'updatedAt': '2026-05-30T00:00:00.000Z',
    'schemaVersion': 1,
  });
  expect(old.isPinned, isFalse);
  expect(old.pinnedAt, isNull);
  expect(old.isUnread, isFalse);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/features/chat/chat_models_test.dart`

Expected: FAIL because `MessageReplyRef` and session flags do not exist.

- [ ] **Step 3: Implement model changes**

Add `MessageReplyRef` with JSON serialization. Add optional `replyRef` to `ChatMessage`. Keep `replyToMessageId` and `replyPreview` getters or fields populated from `replyRef` for compatibility. Add session fields to `ChatSessionMeta` and `ChatSessionDocument`, defaulting to false/null.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test/features/chat/chat_models_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/domain/chat_models.dart test/features/chat/chat_models_test.dart
git commit -m "feat: add rich reply and session flags"
```

## Task 2: Repository Session Flags

**Files:**
- Modify: `lib/core/storage/app_database.dart`
- Modify: `lib/features/chat/data/session_repository.dart`
- Test: `test/features/chat/session_repository_test.dart`

- [ ] **Step 1: Write failing tests**

Add tests for:

```dart
test('listMetas orders pinned sessions before recent unpinned sessions', () async { ... });
test('persistent repository round trips pinned and unread metadata', () async { ... });
test('persistent repository hides soft deleted sessions', () async { ... });
```

Use two pinned sessions with different `pinnedAt` and one unpinned newer session. Expected order: pinned newer pinnedAt, pinned older pinnedAt, unpinned by updatedAt.

- [ ] **Step 2: Run RED**

Run: `flutter test test/features/chat/session_repository_test.dart test/core/storage/app_database_test.dart`

Expected: FAIL for missing fields/columns/order.

- [ ] **Step 3: Implement persistence**

Update `session_metas` migration to add `is_pinned`, `pinned_at`, `is_unread` idempotently. Update row mapping and `orderBy`:

```sql
is_pinned DESC,
pinned_at DESC,
updated_at DESC
```

Implement soft delete by saving `is_deleted = 1` in meta while keeping payload, or add a repository method if the existing interface is extended. Preserve old hard-delete if tests depend on it, but UI can use soft delete through controller.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test/features/chat/session_repository_test.dart test/core/storage/app_database_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/storage/app_database.dart lib/features/chat/data/session_repository.dart test/features/chat/session_repository_test.dart test/core/storage/app_database_test.dart
git commit -m "feat: persist session list flags"
```

## Task 3: Controller Reply Refs And Restore

**Files:**
- Modify: `lib/features/chat/application/chat_controller.dart`
- Modify: `lib/features/chat/application/session_list_controller.dart`
- Test: `test/features/chat/chat_controller_test.dart`

- [ ] **Step 1: Write failing tests**

Add tests:

```dart
test('sendMessage stores rich reply ref for quoted image message', () async { ... });
test('loadSession converts trailing streaming assistant to interrupted', () async { ... });
test('retryLastFailed retries interrupted and cancelled trailing assistants', () async { ... });
test('edit image prompt sends new user message without overwriting image', () async { ... });
test('session list controller pins marks unread and soft deletes sessions', () async { ... });
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/features/chat/chat_controller_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement controller behavior**

Add `sendMessage` support for `MessageReplyRef? replyRef`. Add helper to build ref from a message, including first image attachment and compact text. On load, if last assistant is streaming, replace with interrupted and save. Extend retry to failed/cancelled/interrupted trailing assistant. Add `sendImageEditPrompt({required ChatMessage imageMessage, required String prompt})` or equivalent public method that appends a new user prompt and generates without mutating old image.

Update `SessionListController` methods:

- `pinSession`
- `unpinSession`
- `markUnread`
- `markRead`
- `softDeleteSession`

- [ ] **Step 4: Run GREEN**

Run: `flutter test test/features/chat/chat_controller_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/application/chat_controller.dart lib/features/chat/application/session_list_controller.dart test/features/chat/chat_controller_test.dart
git commit -m "feat: manage rich replies and session state"
```

## Task 4: Rich Quote UI

**Files:**
- Modify: `lib/features/chat/presentation/widgets/chat_input_bar.dart`
- Modify: `lib/features/chat/presentation/widgets/message_bubble.dart`
- Modify: `lib/features/chat/presentation/chat_screen.dart`
- Test: `test/widget/chat_reply_edit_test.dart`
- Test: `test/widget/message_bubble_layout_test.dart`

- [ ] **Step 1: Write failing widget tests**

Add tests:

```dart
testWidgets('composer quote shows text and image thumbnail', (tester) async { ... });
testWidgets('sent bubble quote shows role text and image thumbnail', (tester) async { ... });
testWidgets('composer quote clears after sending while sent bubble keeps ref', (tester) async { ... });
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/widget/chat_reply_edit_test.dart test/widget/message_bubble_layout_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement UI**

Extend `ChatQuoteDraft` to hold `MessageReplyRef`. Render thumbnails with stable `48x48` sizing. In `ChatScreen._setReplyQuote`, build ref from message and pass it to controller on send. In `MessageBubble`, render role label, thumbnail, and text preview.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test/widget/chat_reply_edit_test.dart test/widget/message_bubble_layout_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/presentation/widgets/chat_input_bar.dart lib/features/chat/presentation/widgets/message_bubble.dart lib/features/chat/presentation/chat_screen.dart test/widget/chat_reply_edit_test.dart test/widget/message_bubble_layout_test.dart
git commit -m "feat: show rich quoted replies"
```

## Task 5: Image Viewer Save And Edit

**Files:**
- Create: `lib/features/chat/presentation/image_viewer_screen.dart`
- Modify: `lib/features/chat/presentation/widgets/message_bubble.dart`
- Modify: `lib/features/chat/presentation/chat_screen.dart`
- Test: `test/widget/image_viewer_test.dart`
- Test: `test/widget/message_bubble_layout_test.dart`

- [ ] **Step 1: Write failing tests**

Add tests:

```dart
testWidgets('tapping image opens full screen viewer', (tester) async { ... });
testWidgets('image viewer save copies image and shows snackbar', (tester) async { ... });
testWidgets('image viewer edit returns edited prompt to chat screen', (tester) async { ... });
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/widget/image_viewer_test.dart test/widget/message_bubble_layout_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement image viewer**

Create an `ImageViewerScreen` or modal route using `InteractiveViewer`. Add back, save, edit icon buttons. Save copies to app documents `saved-images`. Edit opens prompt dialog seeded from nearest prompt and calls controller image edit method.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test/widget/image_viewer_test.dart test/widget/message_bubble_layout_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/presentation/image_viewer_screen.dart lib/features/chat/presentation/widgets/message_bubble.dart lib/features/chat/presentation/chat_screen.dart test/widget/image_viewer_test.dart test/widget/message_bubble_layout_test.dart
git commit -m "feat: add image viewer and edit prompt"
```

## Task 6: Session List Actions

**Files:**
- Modify: `lib/features/chat/presentation/session_list_screen.dart`
- Test: `test/widget/session_list_sessions_test.dart`

- [ ] **Step 1: Write failing widget tests**

Add tests:

```dart
testWidgets('session list shows pinned sessions first with pin icon', (tester) async { ... });
testWidgets('session menu toggles pin unread and delete', (tester) async { ... });
testWidgets('opening unread session marks it read', (tester) async { ... });
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/widget/session_list_sessions_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement list actions**

Add trailing overflow menu with pin/unpin, mark unread/read, delete. Add unread indicator and stronger title style. Refresh provider after actions.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test/widget/session_list_sessions_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/presentation/session_list_screen.dart test/widget/session_list_sessions_test.dart
git commit -m "feat: add session list controls"
```

## Task 7: Full Verification And APK

**Files:**
- No planned source edits.

- [ ] **Step 1: Format**

Run: `dart format lib test`

- [ ] **Step 2: Analyze**

Run: `flutter analyze`

Expected: no issues.

- [ ] **Step 3: Full tests**

Run: `flutter test`

Expected: all tests pass.

- [ ] **Step 4: Build APK**

Run: `flutter build apk --debug`

Expected: `build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 5: Copy and install**

Run:

```powershell
Copy-Item -LiteralPath build\app\outputs\flutter-apk\app-debug.apk -Destination E:\windows\Desktop\NewChat-debug.apk -Force
adb -s emulator-5554 install -r E:\windows\Desktop\NewChat-debug.apk
adb -s emulator-5554 shell monkey -p cn.cylonai.newchat 1
adb -s emulator-5554 logcat -d -t 300 | Select-String -Pattern "FATAL EXCEPTION|AndroidRuntime|flutter|NewChat|newchat"
```

Expected: install succeeds and no fatal exception appears.

- [ ] **Step 6: Push**

Run: `git push origin feature/newchat-implementation`

## Self-Review

- Spec coverage: all requested features are mapped to tasks.
- Placeholder scan: no placeholders remain; tests are behavior-specific.
- Scope check: route A is broad, but tasks are separable and each produces testable behavior.
- Type consistency: `MessageReplyRef`, session flags, and image viewer actions are consistently named.
