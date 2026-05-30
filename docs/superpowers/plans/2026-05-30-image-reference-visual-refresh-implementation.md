# Image Reference And Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make quoted images real model inputs, improve image-edit behavior, refresh the native Flutter UI, fix bilingual text, rename the app to `newchatbox`, and build/install a debug APK.

**Architecture:** Keep the existing domain model. Treat `MessageReplyRef.imageAttachment` as an input-image source only when building the latest user provider message. Provider payload builders continue to encode `MessagePart.image`; controller validation and image-edit entry points become aware of quoted images. UI refresh stays in the current Flutter screens and widgets without introducing a new design framework.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Dio, sqflite, flutter_test, Android launcher mipmap assets.

---

### Task 1: Quoted Images Enter Provider Context

**Files:**
- Modify: `lib/features/chat/application/chat_context_builder.dart`
- Test: `test/features/chat/chat_context_builder_test.dart`

- [ ] **Step 1: Write failing context-builder tests**

Add these tests near the existing quote/context tests in `test/features/chat/chat_context_builder_test.dart`:

```dart
  test('adds quoted image attachment to latest user provider message', () {
    final quotedImage = _attachment('quoted-image');
    final result = ChatContextBuilder(recentMessageLimit: 4).build(
      _document(
        messages: [
          _message(
            id: 'assistant-image',
            role: ChatRole.assistant,
            text: 'product screenshot',
            parts: [
              const MessagePart.text('product screenshot'),
              MessagePart.image(quotedImage),
            ],
          ),
          _message(
            id: 'current-reply',
            role: ChatRole.user,
            text: 'make the background darker',
            replyRef: MessageReplyRef(
              messageId: 'assistant-image',
              role: ChatRole.assistant,
              textPreview: 'product screenshot',
              imageAttachment: quotedImage,
              createdAt: DateTime.utc(2026, 5, 30),
            ),
          ),
        ],
      ),
    );

    final providerUser = result.messages.singleWhere(
      (message) => message.id == 'current-reply',
    );

    expect(providerUser.fullText, '''
The user is replying to this earlier image message:
"[Image] product screenshot"

User message:
make the background darker''');
    expect(
      providerUser.parts
          .where((part) => part.type == MessagePartType.image)
          .map((part) => part.attachment!.id),
      ['quoted-image'],
    );
  });

  test('keeps direct and quoted images on latest user provider message', () {
    final quotedImage = _attachment('quoted-image');
    final directImage = _attachment('direct-image');
    final result = ChatContextBuilder(recentMessageLimit: 4).build(
      _document(
        messages: [
          _message(
            id: 'current-reply',
            role: ChatRole.user,
            text: 'compare these',
            parts: [
              const MessagePart.text('compare these'),
              MessagePart.image(directImage),
            ],
            replyRef: MessageReplyRef(
              messageId: 'assistant-image',
              role: ChatRole.assistant,
              textPreview: '',
              imageAttachment: quotedImage,
              createdAt: DateTime.utc(2026, 5, 30),
            ),
          ),
        ],
      ),
    );

    final providerUser = result.messages.single;

    expect(
      providerUser.parts
          .where((part) => part.type == MessagePartType.image)
          .map((part) => part.attachment!.id),
      ['quoted-image', 'direct-image'],
    );
  });
```

Update the `_message` helper to accept `MessageReplyRef? replyRef` and pass it into `ChatMessage`.

- [ ] **Step 2: Run context-builder tests and verify RED**

Run:

```powershell
flutter test test/features/chat/chat_context_builder_test.dart
```

Expected: the new tests fail because `quoted-image` is missing from provider message parts.

- [ ] **Step 3: Implement minimal context-builder change**

In `ChatContextBuilder._providerMessage`, insert the quoted image before direct preserved images when `addQuotePreface` is true:

```dart
      if (addQuotePreface && message.replyRef?.imageAttachment != null)
        MessagePart.image(message.replyRef!.imageAttachment!),
      if (preserveImages)
        ...message.parts.where((part) => part.type == MessagePartType.image),
```

Keep the existing text preface unchanged.

- [ ] **Step 4: Run context-builder tests and verify GREEN**

Run:

```powershell
flutter test test/features/chat/chat_context_builder_test.dart
```

Expected: all tests in the file pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/chat/application/chat_context_builder.dart test/features/chat/chat_context_builder_test.dart
git commit -m "fix: include quoted images in chat context"
```

---

### Task 2: Controller Validation And Image Edit References

**Files:**
- Modify: `lib/features/chat/application/chat_controller.dart`
- Test: `test/features/chat/chat_controller_test.dart`

- [ ] **Step 1: Write failing controller tests**

Add these tests in `test/features/chat/chat_controller_test.dart` near the rich reply and image edit tests:

```dart
  test('quoted image is validated as image input before provider call',
      () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider(const [ChatStreamDone()]);
    final quotedImage = const AttachmentRef(
      id: 'quoted-image',
      localPath: '/tmp/quoted.png',
      mimeType: 'image/png',
    );
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
      providerRepository: InMemoryProviderRepository(
        providers: [
          _provider(
            id: 'provider-1',
            protocol: ProviderProtocol.openai,
            defaultModelId: 'text-only',
          ),
        ],
        models: [
          _model(
            'text-only',
            ProviderProtocol.openai,
            supportsImages: false,
          ),
        ],
      ),
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'text-only',
      title: 'New Chat',
    );
    await controller.sendMessage(
      text: 'edit this image',
      attachments: const [],
      replyRef: MessageReplyRef(
        messageId: 'assistant-image',
        role: ChatRole.assistant,
        textPreview: 'original image',
        imageAttachment: quotedImage,
        createdAt: DateTime.utc(2026, 5, 30, 8),
      ),
    );

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.role, ChatRole.assistant);
    expect(assistant.state, MessageState.failed);
    expect(
      assistant.parts.single.text,
      'The selected model does not support images.',
    );
    expect(fakeProvider.requests, isEmpty);
  });

  test('sendImageEditPrompt sends referenced image in provider request',
      () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider(const [ChatStreamDone()]);
    final image = const AttachmentRef(
      id: 'image-old',
      localPath: '/tmp/old.png',
      mimeType: 'image/png',
    );
    final imageMessage = ChatMessage(
      id: 'assistant-image',
      role: ChatRole.assistant,
      state: MessageState.completed,
      parts: [
        const MessagePart.text('original product shot'),
        MessagePart.image(image),
      ],
      createdAt: DateTime.utc(2026, 5, 30, 8, 1),
      updatedAt: DateTime.utc(2026, 5, 30, 8, 1),
    );
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
    );
    await repository.saveDocument(
      _document(
        id: 'session-1',
        messages: [
          ChatMessage(
            id: 'user-original',
            role: ChatRole.user,
            state: MessageState.completed,
            parts: const [MessagePart.text('draw product')],
            createdAt: DateTime.utc(2026, 5, 30, 8),
            updatedAt: DateTime.utc(2026, 5, 30, 8),
          ),
          imageMessage,
        ],
      ),
    );

    await controller.loadSession('session-1');
    await controller.sendImageEditPrompt(
      imageMessage: imageMessage,
      prompt: 'change the background to night',
    );

    final providerUser = fakeProvider.requests.single.messages.lastWhere(
      (message) => message.role == ChatRole.user,
    );
    expect(providerUser.replyRef!.messageId, 'assistant-image');
    expect(providerUser.replyRef!.imageAttachment!.id, 'image-old');
    expect(
      providerUser.parts
          .where((part) => part.type == MessagePartType.image)
          .map((part) => part.attachment!.id),
      ['image-old'],
    );
  });
```

- [ ] **Step 2: Run controller tests and verify RED**

Run:

```powershell
flutter test test/features/chat/chat_controller_test.dart
```

Expected: the quoted-image validation test calls the provider instead of blocking, and image edit prompt lacks the reply reference.

- [ ] **Step 3: Implement quoted-image validation**

In `sendMessage`, pass `attachments.isNotEmpty || _hasReplyImage(replyRef)` to `_streamAssistantResponse`.

Add:

```dart
bool _hasReplyImage(MessageReplyRef? replyRef) => replyRef?.imageAttachment != null;
```

In `retryLastFailed`, pass `_hasImageAttachments(previous) || _hasReplyImage(previous.replyRef)`.

- [ ] **Step 4: Implement image edit reference**

Change `sendImageEditPrompt` to find the first image on `imageMessage` and send a reply ref:

```dart
    final imageAttachment = _firstImageAttachment(imageMessage);
    await sendMessage(
      text: trimmedPrompt,
      attachments: const [],
      replyRef: imageAttachment == null
          ? null
          : MessageReplyRef(
              messageId: imageMessage.id,
              role: imageMessage.role,
              textPreview: _compactPreview(imageMessage.fullText),
              imageAttachment: imageAttachment,
              createdAt: imageMessage.createdAt,
            ),
    );
```

Add private helpers:

```dart
AttachmentRef? _firstImageAttachment(ChatMessage message) {
  for (final part in message.parts) {
    if (part.type == MessagePartType.image && part.attachment != null) {
      return part.attachment;
    }
  }
  return null;
}

String _compactPreview(String text) {
  final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= 120) {
    return normalized;
  }
  return '${normalized.substring(0, 117)}...';
}
```

- [ ] **Step 5: Run controller tests and verify GREEN**

Run:

```powershell
flutter test test/features/chat/chat_controller_test.dart
```

Expected: all tests in the file pass.

- [ ] **Step 6: Commit**

```powershell
git add lib/features/chat/application/chat_controller.dart test/features/chat/chat_controller_test.dart
git commit -m "fix: preserve image references in edit prompts"
```

---

### Task 3: Provider Payloads And Image-Generation Reference Errors

**Files:**
- Modify: `lib/features/providers/data/openai_provider.dart`
- Modify: `lib/features/providers/data/claude_provider.dart`
- Test: `test/features/providers/openai_provider_test.dart`
- Test: `test/features/providers/claude_provider_test.dart`

- [ ] **Step 1: Add provider payload tests for quoted image context**

Add OpenAI and Claude tests that build payloads from a `ChatMessage` containing the text preface and `MessagePart.image`. Use existing image encoding helpers and assert the encoded image appears in payload. These tests should pass after Task 1, but they document the cross-provider contract.

- [ ] **Step 2: Add failing OpenAI image-generation reference rejection test**

In `test/features/providers/openai_provider_test.dart`, add a test that sends `gpt-image-2` with a latest user message containing an image part and configures `_FakeHttpClientAdapter` to throw a 400 DioException. Assert returned error text is specific:

```dart
expect(
  failed.error.message,
  contains('does not support image editing from a reference image'),
);
```

- [ ] **Step 3: Run provider tests and verify RED**

Run:

```powershell
flutter test test/features/providers/openai_provider_test.dart test/features/providers/claude_provider_test.dart
```

Expected: the new OpenAI 400 reference-image generation test fails with the generic invalid request message.

- [ ] **Step 4: Implement specific OpenAI reference-image error**

In the `gpt-image` branch of `OpenAIProvider.sendStream`, compute whether request messages include image parts. If a `DioException` from image generation has status 400 and the request had image parts, yield:

```dart
const ChatStreamFailed(
  ChatError(
    type: ChatErrorType.badRequest,
    message:
        'The selected gateway/model does not support image editing from a reference image.',
    statusCode: 400,
  ),
)
```

Then return. Leave other Dio errors using existing `_chatErrorFromDio`.

- [ ] **Step 5: Run provider tests and verify GREEN**

Run:

```powershell
flutter test test/features/providers/openai_provider_test.dart test/features/providers/claude_provider_test.dart
```

Expected: both provider test files pass.

- [ ] **Step 6: Commit**

```powershell
git add lib/features/providers/data/openai_provider.dart lib/features/providers/data/claude_provider.dart test/features/providers/openai_provider_test.dart test/features/providers/claude_provider_test.dart
git commit -m "fix: report unsupported image reference edits"
```

---

### Task 4: Provider Editor Persistence UX

**Files:**
- Modify: `lib/features/providers/presentation/provider_editor_screen.dart`
- Modify: `lib/features/providers/application/provider_controller.dart`
- Test: `test/widget/provider_editor_state_test.dart`
- Test: `test/features/providers/provider_controller_test.dart`

- [ ] **Step 1: Write failing tests for saved base URL and key state**

In `provider_editor_state_test.dart`, add a widget test that seeds a provider with `baseUrl: 'https://token.cylonai.cn'`, opens `ProviderEditorScreen(providerId: ...)`, and expects that text to be present. Add a test that saved-key state is shown as a non-secret label such as `Saved key is stored`.

In `provider_controller_test.dart`, add a test that saving a provider with blank `apiKeyInput` does not delete or overwrite an existing key.

- [ ] **Step 2: Run provider editor/controller tests and verify RED**

Run:

```powershell
flutter test test/widget/provider_editor_state_test.dart test/features/providers/provider_controller_test.dart
```

Expected: saved-key UI state fails until implemented; existing key preservation may already pass and should be kept as a regression test.

- [ ] **Step 3: Implement saved-key state without exposing secrets**

Add a provider-controller method:

```dart
Future<bool> hasSavedApiKey(String providerId) async {
  final key = await _keyStore.readProviderKey(providerId);
  return key != null && key.trim().isNotEmpty;
}
```

In `ProviderEditorScreen._loadProvider`, call it after loading provider and set `_hasSavedApiKey`. Display helper text under the API-key field:

```dart
helperText: _hasSavedApiKey
    ? 'Saved key is stored. Leave blank to keep it.'
    : 'Paste an API key to save it securely.',
```

Keep `_apiKeyController.text` empty on load.

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```powershell
flutter test test/widget/provider_editor_state_test.dart test/features/providers/provider_controller_test.dart
```

Expected: both test files pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/providers/presentation/provider_editor_screen.dart lib/features/providers/application/provider_controller.dart test/widget/provider_editor_state_test.dart test/features/providers/provider_controller_test.dart
git commit -m "feat: show saved provider key state"
```

---

### Task 5: Localization And Visual Refresh

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/features/chat/presentation/session_list_screen.dart`
- Modify: `lib/features/chat/presentation/chat_screen.dart`
- Modify: `lib/features/chat/presentation/widgets/message_bubble.dart`
- Modify: `lib/features/chat/presentation/widgets/chat_input_bar.dart`
- Modify: `lib/features/chat/presentation/image_viewer_screen.dart`
- Modify: `lib/features/providers/presentation/settings_screen.dart`
- Modify: `lib/features/providers/presentation/provider_editor_screen.dart`
- Modify: `lib/features/providers/presentation/model_manager_screen.dart`
- Test: existing widget tests under `test/widget/`

- [ ] **Step 1: Write failing localization/widget checks**

Add tests that verify:

- `AppLocalizations.supportedLocales` can load Chinese and `appTitle == 'newchatbox'`.
- `SessionListScreen` shows `newchatbox`.
- `ChatInputBar` image button tooltip is localized.
- Message action bottom sheet uses localized `Reply`, `Edit`, and `Edit image` labels.

- [ ] **Step 2: Run widget tests and verify RED**

Run:

```powershell
flutter test test/widget
```

Expected: tests fail because `appTitle` is still `NewChat`, Chinese ARB is garbled, and several labels are hardcoded.

- [ ] **Step 3: Update theme**

In `lib/app.dart`, define a Material 3 theme using:

- primary deep teal: `Color(0xFF123C44)`
- secondary brass: `Color(0xFFE0B84D)`
- light surface: `Color(0xFFF7F4EC)`
- rounded components at 8px where configured.

Keep `MaterialApp.router` and routing unchanged.

- [ ] **Step 4: Fix ARB files**

Replace `app_en.arb` and `app_zh.arb` with valid UTF-8 JSON containing all current and newly localized labels. Minimum keys:

```json
{
  "appTitle": "newchatbox",
  "newChat": "New chat",
  "settings": "Settings",
  "send": "Send",
  "stop": "Stop",
  "providerRequired": "Add a provider before chatting.",
  "imageUnsupported": "The selected model does not support images.",
  "testConnection": "Test connection",
  "connectionSucceeded": "Connection succeeded.",
  "connectionFailed": "Connection failed.",
  "reply": "Reply",
  "edit": "Edit",
  "editImage": "Edit image",
  "rename": "Rename",
  "systemPrompt": "System prompt",
  "switchModel": "Switch model",
  "delete": "Delete",
  "continueAction": "Continue",
  "addImage": "Add image",
  "cancelReply": "Cancel reply",
  "thinking": "Thinking",
  "userRole": "User",
  "assistantRole": "Assistant",
  "systemRole": "System",
  "replyRole": "Reply",
  "provider": "Provider",
  "providerName": "Provider name",
  "baseUrl": "Base URL",
  "apiKey": "API key",
  "defaultModel": "Default model",
  "fetchModels": "Fetch models",
  "save": "Save",
  "savedKeyStored": "Saved key is stored. Leave blank to keep it.",
  "pasteKeyToSave": "Paste an API key to save it securely.",
  "clearSavedApiKey": "Clear saved API key"
}
```

Chinese values must be valid Simplified Chinese, for example `appTitle: "newchatbox"`, `newChat: "新对话"`, `settings: "设置"`.

- [ ] **Step 5: Replace primary hardcoded strings**

Use `AppLocalizations.of(context)` in the modified screens/widgets for primary flows listed in the spec. Keep non-primary internal debug strings only if not user-visible.

- [ ] **Step 6: Apply visual refresh**

Update layout styling to match the approved direction:

- Session list: warm background, compact repeated cards at 8px radius, clearer pinned/unread indicators.
- Chat screen: warm background, compact app bar subtitle, stable message list bottom padding.
- Message bubbles: deep teal/brass contrast, fixed thumbnail dimensions, compact streaming indicator.
- Composer: stable rounded input container, thumbnail attachments instead of generic image chips when practical.
- Provider editor/settings/model manager/image viewer: consistent spacing, buttons, and back actions.

- [ ] **Step 7: Generate localization and run widget tests**

Run:

```powershell
flutter gen-l10n
flutter test test/widget
```

Expected: widget tests pass and no ARB encoding errors occur.

- [ ] **Step 8: Commit**

```powershell
git add lib test/widget
git commit -m "style: refresh newchatbox interface"
```

---

### Task 6: App Name And Launcher Icon

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- Modify: `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- Modify: `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- Modify: `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- Modify: `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

- [ ] **Step 1: Update Android label**

Change:

```xml
android:label="newchat"
```

to:

```xml
android:label="newchatbox"
```

Keep package/activity paths unchanged.

- [ ] **Step 2: Generate launcher PNGs**

Use a local script/tool to create square PNGs with:

- deep teal background
- brass rounded chat mark or `N`
- sizes 48, 72, 96, 144, 192 for mdpi through xxxhdpi.

The generated files must replace the existing `ic_launcher.png` files.

- [ ] **Step 3: Verify assets exist**

Run:

```powershell
Get-ChildItem android/app/src/main/res/mipmap-* -Filter ic_launcher.png | Select-Object FullName,Length
```

Expected: five non-empty PNG files.

- [ ] **Step 4: Commit**

```powershell
git add android/app/src/main/AndroidManifest.xml android/app/src/main/res/mipmap-*/ic_launcher.png
git commit -m "brand: rename app and update launcher icon"
```

---

### Task 7: Full Verification, APK, Emulator Install, And Logs

**Files:**
- No source edits expected unless verification exposes a defect.

- [ ] **Step 1: Format**

Run:

```powershell
dart format lib test
```

Expected: formatter completes successfully.

- [ ] **Step 2: Analyze**

Run:

```powershell
flutter analyze
```

Expected: no analyzer errors.

- [ ] **Step 3: Full tests**

Run:

```powershell
flutter test
```

Expected: all tests pass.

- [ ] **Step 4: Build debug APK**

Run:

```powershell
flutter build apk --debug
```

Expected: debug APK exists at `build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 5: Copy APK to desktop**

Run:

```powershell
Copy-Item -LiteralPath build/app/outputs/flutter-apk/app-debug.apk -Destination E:\windows\Desktop\NewChat-debug.apk -Force
```

Expected: `E:\windows\Desktop\NewChat-debug.apk` exists.

- [ ] **Step 6: Install on emulator**

Run:

```powershell
adb devices
adb install -r E:\windows\Desktop\NewChat-debug.apk
```

Expected: target emulator is listed and install reports success.

- [ ] **Step 7: Inspect logs**

Run:

```powershell
adb logcat -d -t 300 | Select-String -Pattern "FATAL EXCEPTION|AndroidRuntime|newchat|newchatbox|flutter"
```

Expected: no fatal startup exceptions for the installed app.

- [ ] **Step 8: Commit verification fixes if any**

If verification required source changes, commit them:

```powershell
git add <changed-files>
git commit -m "fix: address final verification issues"
```

If no files changed, do not create an empty commit.

## Plan Self-Review

- Spec coverage: quoted image context, edit references, provider errors, provider editor persistence, UI refresh, localization, app name/icon, and APK verification all have tasks.
- Placeholder scan: no `TBD`, `TODO`, or "implement later" steps remain.
- Type consistency: all referenced classes and helpers already exist or are introduced in the task that uses them.
- TDD order: behavioral code tasks start with failing tests before implementation.
