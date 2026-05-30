# Image Reference And Visual Refresh Design

Date: 2026-05-30

## Goal

Fix image-reply behavior so a quoted image is sent to the model as a real visual reference, then refresh the native Flutter interface under the `newchatbox` name with clearer chat layout, bilingual copy, provider persistence, and a new launcher icon.

This design supersedes the earlier `Chat Media And Session Experience Design` statement that image quote thumbnails are UI metadata only.

## Scope

This feature covers:

- Quoted image references becoming model-visible image inputs.
- Image-edit prompts using the referenced image instead of only the prompt text.
- OpenAI and Claude request payload tests for quoted images.
- Safer behavior for OpenAI image-generation models when a reference image is present.
- A focused visual refresh for session list, chat, message bubbles, composer, provider editor, model manager, settings, and image viewer.
- Chinese and English localization cleanup.
- Provider editor remembering saved base URL and showing saved API-key state on reopen.
- App display name changed to `newchatbox`.
- New Android launcher icon assets.

Out of scope:

- Pixel-level bitmap editing tools such as crop, brush, mask, or erase.
- Cloud sync.
- iOS packaging.
- Public Android gallery export beyond the existing save behavior unless already supported.
- Replacing OpenAI/Claude protocol support with a different API contract.

## Root Cause

The current quote flow preserves image quote metadata in `MessageReplyRef.imageAttachment`, and the UI can show the thumbnail. However, `ChatContextBuilder` only converts that reference into text like `[Image] product screenshot`. It does not add the referenced attachment as a `MessagePart.image` in the provider request. OpenAI and Claude payload builders only encode images that exist as image parts, so the model never sees the quoted file.

For image-generation models, the OpenAI route currently posts only a prompt to `/v1/images/generations`. When a user quotes an image and asks for an edit, this behaves like fresh generation from text, not image-conditioned editing.

## Product Behavior

### Quoted Image Replies

When the user replies to an image message, the composer keeps showing a compact quote preview with:

- A thumbnail for the referenced image.
- Up to two lines of text preview when available.
- A clear role label.

After sending, the composer quote preview is cleared. The sent user message keeps the reference block in history, including the thumbnail and text preview.

The provider request for the latest user turn must include:

- A text preface explaining that the user is replying to an earlier image message.
- The user's typed text.
- The referenced image as an image part.
- Any new images the user explicitly attached in the composer.

This applies to both OpenAI and Claude chat-style payloads.

### Image Editing From Viewer Or Quote

When the user taps edit on an image or replies to an image with an edit prompt, the referenced image must be part of the request. The model should receive the original image as visual context so instructions like "keep the person the same and change the background" are grounded in the actual image.

If the selected model is a chat/vision model, send the referenced image as a normal multimodal chat message.

If the selected model is an OpenAI image-generation model, first attempt an image-edit/reference-capable path when supported by the gateway. If the gateway rejects reference-image generation with a 400, show a specific message explaining that the selected gateway/model does not support image editing from a reference image, instead of silently falling back to unrelated fresh generation.

### Context Compression

Automatic context compression may summarize old text messages, but it must not remove the referenced image from the latest user turn. Only the latest user message preserves image parts. Older image attachments remain summarized or omitted unless they are explicitly referenced by the current user message.

### Provider Validation

The image-support guard must treat quoted images the same as directly attached images. If a user replies to an image while the selected model is marked text-only, the app should block send and show the localized "model does not support images" message before making a network request.

## UI Refresh

Use the approved visual direction from the brainstorm mockup:

- Native, work-focused chat tool rather than a marketing screen.
- Warm paper surfaces for light mode.
- Deep teal navigation and structural accents.
- Brass/gold primary action accent.
- Compact layouts with stable message, thumbnail, toolbar, and input dimensions.
- Cards only for repeated list items or bounded tools; no nested cards.
- 8px corner radius for core UI elements unless Android system components require otherwise.

### Session List

The first screen remains the actual conversation list. It should show:

- `newchatbox` as the app title.
- Search-like scan area or compact header affordance if simple to implement.
- Pinned/unread state clearly, without crowding trailing actions.
- A direct settings icon and new chat action.

### Chat Screen

The chat page should feel closer to a modern mobile messenger:

- Back button must remain visible at the top.
- Title and provider/model subtitle must fit on small screens.
- User messages align right; assistant messages align left.
- Streaming state should show a compact loading indicator that does not distort the bubble width.
- Keyboard appearance should keep the latest messages visible through normal `adjustResize`, `SafeArea`, and bottom padding behavior.
- The model switcher remains reachable from the top actions and must reflect the current selection after switching.

### Composer

The composer should keep:

- Image attach button.
- Text input.
- Send button.
- Quote preview above the input row.
- Direct image thumbnails for selected attachments instead of generic chips when practical.

Text must fit in Chinese and English. Tooltips and labels should be localized.

### Provider Editor

The provider editor should:

- Load saved provider name, protocol, base URL, and default model on reopen.
- Show saved API-key state without exposing the raw secret by default.
- Preserve the existing saved key when the field is left unchanged.
- Allow replacing or clearing the key explicitly.
- Keep "Fetch models", "Test connection", and "Save" visible and understandable.

For new provider creation, defaults may still use official OpenAI/Claude URLs, but once the user saves `https://token.cylonai.cn`, reopening that provider must show that saved value.

## Localization

Fix the damaged Chinese ARB content and move hardcoded user-facing text into localization resources where it appears in primary flows:

- Session list actions.
- Chat top actions.
- Message actions.
- Composer labels and errors.
- Provider editor.
- Model manager and settings.
- Image viewer labels and errors.

English remains the fallback locale. Chinese text should be concise Simplified Chinese. Generated localization files must be refreshed through the normal Flutter localization flow.

## App Identity

The app display name becomes `newchatbox`.

Android changes:

- Update the launcher label.
- Keep package name `cn.cylonai.newchat`.
- Replace launcher icons in the existing mipmap density folders.

Icon direction:

- A simple native app icon with a deep teal base.
- A compact chat mark or rounded "N" motif.
- Brass/gold highlight.
- Legible at small launcher sizes.

## Data Flow

1. User long-presses or opens an image message and starts a reply/edit.
2. UI creates `MessageReplyRef` with `imageAttachment`.
3. `ChatController.sendMessage` stores the user message with the reply ref.
4. `ChatContextBuilder` builds provider messages.
5. If the latest user message has `replyRef.imageAttachment`, the builder adds that attachment as an image part on the latest user provider message.
6. Controller validation counts direct attachments plus quoted image attachments.
7. OpenAI/Claude payload builders encode the image bytes exactly as they already do for direct image attachments.
8. Provider response is streamed or stored as today.

## Error Handling

- Missing referenced local image file: show a clear localized error in the assistant failure bubble and do not crash.
- Text-only model with direct or quoted image: block before request with localized unsupported-image message.
- Provider 400 for reference-image generation: show a specific safe message that the selected gateway/model cannot edit from a reference image.
- Provider/network failures: continue using safe provider error formatting without leaking API keys.

## Testing

Add or update tests for:

- `ChatContextBuilder` includes quoted image attachment in the latest user provider message.
- `ChatContextBuilder` keeps direct attachments and quoted image attachments together.
- Context compression does not drop the latest quoted image.
- Controller validation blocks quoted images for text-only models.
- `sendImageEditPrompt` sends the image message's attachment as a quote/reference.
- OpenAI chat payload encodes quoted images as `image_url` data URLs.
- Claude payload encodes quoted images as base64 image sources.
- OpenAI image-generation reference failure produces a specific user-facing error.
- Provider editor reopens with saved base URL and saved-key state.
- Empty API-key field preserves the existing saved key unless clear is selected.
- Chinese and English app localizations load without garbled text.
- Message bubble/composer quote thumbnails remain stable after the visual refresh.
- Basic widget smoke tests for session list, chat, provider editor, settings, model manager, and image viewer.

## Verification

Run:

- `dart format lib test`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`

Then copy the debug APK to `E:\windows\Desktop\NewChat-debug.apk`, install it on the running emulator, and inspect app logs for startup or chat-flow failures.

## Risks

- OpenAI-compatible gateways vary in whether `/v1/images/edits` or reference-image generation is supported. The app should be explicit when the gateway cannot do reference edits.
- Provider editor key UX must balance remembering state with not exposing secrets.
- The UI refresh touches many screens, so visual changes should be incremental and covered by widget smoke tests.
- Localization changes may require generated files to update cleanly in the current Flutter setup.

## Self-Review

- No placeholders remain.
- The spec explicitly reverses the old UI-only image quote behavior.
- The design keeps scope focused on OpenAI/Claude and native Flutter.
- Provider secret handling avoids displaying raw saved keys by default.
- Verification includes automated tests, APK build, emulator install, and log inspection.
