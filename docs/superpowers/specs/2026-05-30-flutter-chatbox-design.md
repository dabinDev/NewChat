# Flutter ChatBox Design

Date: 2026-05-30

## Goal

Build a Flutter Android app that works like a mobile ChatBox/NextChat-style client for a user-provided sub2api/newapi gateway. The first release targets Android APK only. Users configure their own Base URL, API keys, providers, and models inside the app.

The app supports:

- OpenAI Chat Completions protocol.
- Claude Anthropic Messages protocol.
- Streaming text responses.
- Text chat and image understanding.
- Local multi-session chat history.
- Per-session system prompt.
- Markdown, code highlighting, and LaTeX rendering.
- Chinese and English UI.
- Provider/model connection testing.

Out of scope for the first release:

- Cloud sync.
- Account system.
- Prompt/role preset library.
- Image generation.
- Plugin/tool calling.
- Import/export.
- iOS release validation.

## Product Boundaries

The first version is a complete local mobile chat client, not a web wrapper. Flutter is acceptable because it builds a native mobile APK and does not rely on WebView.

The app must not embed shared production API keys. Users enter Base URL and API keys in settings. The same Base URL can be used by both OpenAI and Claude providers, but each provider has its own independent API key.

Example provider setup:

- OpenAI provider: `https://token.cylonai.cn` + OpenAI-compatible key entered by the user.
- Claude provider: `https://token.cylonai.cn` + Claude-compatible key entered by the user.

Real API keys are never written to source code, logs, docs, exported data, or SQLite.

## Architecture

The app is divided into five layers.

### Presentation

Flutter screens and widgets:

- Session list.
- Chat screen.
- Settings.
- Provider editor.
- Model manager.
- System prompt editor.

This layer renders state and dispatches user actions. It does not build protocol-specific HTTP payloads.

### Application State

Use Riverpod for shared state and async workflows:

- Current provider and model.
- Session list.
- Active session document.
- Message send and streaming lifecycle.
- Connection test state.
- Language and theme preferences.

### Domain

Core models:

- `ProviderConfig`
- `ModelConfig`
- `ChatSessionMeta`
- `ChatSessionDocument`
- `ChatMessage`
- `MessagePart`
- `AttachmentRef`
- `ChatStreamEvent`
- `ChatError`

Provider interface:

```dart
abstract interface class ChatProvider {
  Stream<ChatStreamEvent> sendStream(ChatRequest request);
  Future<ConnectionTestResult> testConnection(ConnectionTestRequest request);
}
```

### Data

Use SQLite as the durable local store, but model chat sessions as JSON documents, similar to Chatbox's design. API keys use `flutter_secure_storage`.

Images are stored in the app private file directory. Chat data stores attachment references, not inline image bytes.

### Provider / Protocol

Implement two first-release providers:

- `OpenAIProvider`: calls `/v1/chat/completions`.
- `ClaudeProvider`: calls `/v1/messages`.

Both providers convert protocol-specific SSE chunks into the unified `ChatStreamEvent` stream consumed by the app.

## Local Storage

The first release uses a hybrid document storage model:

- `app_kv`: settings, migration version, current provider id, language, theme.
- `session_metas`: lightweight session list rows for fast startup.
- `sessions`: one row per full session document, with `payload_json`.

API keys are stored separately in secure storage by provider id.

### Session Meta

`session_metas` stores:

- `id`
- `title`
- `last_message_preview`
- `provider_id`
- `model_id`
- `created_at`
- `updated_at`
- `archived_or_deleted`

### Session Document

Each session document stores:

- Session identity and title.
- Provider id and model id.
- Per-session system prompt.
- Messages array.
- Optional future fields such as summary, forks, and migration version.

### Message Structure

Messages use content parts instead of a single text field:

- `text`
- `image`
- `reasoning`
- `info`
- `error`

The first release actively supports `text`, `image`, and `error`. The extra part types are reserved so future reasoning or tool-call content does not require a schema rewrite.

Message states:

- `completed`
- `streaming`
- `failed`
- `cancelled`
- `interrupted`

If the app restarts and finds a `streaming` message, it changes that message to `interrupted`.

## Chat Flow

1. User enters text and optionally selects images.
2. App saves a completed `user` message to the current session document.
3. App creates an empty `assistant` message with `streaming` state.
4. Application state selects the provider from the session's provider id.
5. Provider converts the unified message model into protocol-specific payload.
6. Provider sends an SSE request.
7. Provider parses protocol-specific events and emits unified `ChatStreamEvent` values.
8. UI appends deltas to the assistant message in memory.
9. Storage writes are throttled, roughly every 300-800 ms during streaming.
10. On completion, the assistant message becomes `completed`.
11. On failure, the assistant message becomes `failed` and preserves any partial content and error details.

Stopping generation cancels the HTTP request and keeps the partial assistant content with a `cancelled` state.

## Protocol Details

### OpenAI

Endpoint:

- `POST {baseUrl}/v1/chat/completions`

Supported first-release features:

- `messages`
- `model`
- `stream: true`
- system prompt
- text content
- image content through `image_url` with data URL where supported by the gateway

Streaming parser:

- Parse SSE `data:` lines.
- Extract `choices[].delta.content`.
- Treat `[DONE]` as stream completion.

### Claude

Endpoint:

- `POST {baseUrl}/v1/messages`

Supported first-release features:

- `model`
- `messages`
- `system`
- `stream: true`
- text content blocks
- image content blocks using base64 source format

Streaming parser:

- Parse Anthropic SSE event names.
- Handle `content_block_delta` for text deltas.
- Handle message completion events.
- Convert API errors into `ChatError`.

## Provider And Model Settings

Users can create multiple providers.

Provider fields:

- Display name.
- Protocol: `openai` or `claude`.
- Base URL.
- API key.
- Default model.

Base URL is not unique. This permits OpenAI and Claude providers to share one gateway URL while using different keys.

Model fields:

- Model id.
- Display name.
- Protocol.
- Supports streaming.
- Supports images.
- Optional context length.

The app ships with common model seeds and lets users manually add, edit, and delete custom models. The first release does not depend on `/v1/models`, because gateway behavior varies.

## Connection Testing

Provider/model settings include a test action.

OpenAI test:

- Send a short non-streaming request to `/v1/chat/completions`.

Claude test:

- Send a short non-streaming request to `/v1/messages`.

Diagnostic mapping:

- `401` / `403`: API key or permission problem.
- `404`: Base URL, route, or protocol mismatch.
- `400`: model name, protocol, or request format problem.
- timeout: network or gateway availability problem.
- TLS/network exception: device network or certificate problem.

Errors must mask secrets.

## Screens

### Session List

Shows:

- Session title.
- Last message preview.
- Updated time.
- Current model.

Actions:

- New session.
- Open session.
- Search sessions.
- Rename session.
- Delete session.
- Open settings.

### Chat Screen

Shows:

- Current session title.
- Provider/model indicator.
- Markdown messages.
- Code blocks with highlighting.
- LaTeX rendering.
- Image thumbnails.
- Streaming assistant text.

Actions:

- Send text.
- Attach one or more images.
- Stop generation.
- Retry failed message.
- Rename session.
- Edit system prompt.
- Switch provider/model.
- Delete session.

If no provider exists, the chat screen guides the user to settings.

If the selected model does not support images, image sending is blocked with a clear localized message.

### Settings

Includes:

- Provider management.
- Model management.
- Language switch.
- Theme preference.
- Cache cleanup.
- About page.

### System Prompt Editor

Each session has one editable system prompt. The first release does not include a full prompt or role preset library.

## Localization

The first release supports Chinese and English. The app uses system language by default when possible and falls back to Chinese.

All user-facing strings, including network diagnostics and empty states, must be localized.

## Privacy And Security

- API keys are stored only in secure storage.
- API keys are masked in UI.
- API keys are not included in logs, database rows, exported data, or error messages.
- Images are stored in the app private directory.
- Deleting a session removes its messages and associated image files.
- Since this is a shared-account client, user access control and quota limits belong in the newapi/sub2api backend, not the first-release mobile app.

## Testing Strategy

### Unit Tests

Cover:

- OpenAI request construction for text, images, system prompt, and stream flag.
- Claude request construction for text, images, system prompt, and stream flag.
- OpenAI SSE parsing for deltas, completion, malformed JSON, and error payloads.
- Claude SSE parsing for content deltas, completion, malformed JSON, and error payloads.
- Session document serialization and migration.
- API key masking helpers.

### Widget Tests

Cover:

- Empty provider state routes user to settings.
- Sending a message creates user and streaming assistant messages.
- Failed messages show error and retry action.
- Model without image support blocks image sending.

### Manual Acceptance

On Android emulator or device:

- Configure OpenAI provider with gateway Base URL and user-entered key.
- Configure Claude provider with the same gateway Base URL and a separate user-entered key.
- Test OpenAI text chat.
- Test OpenAI image chat.
- Test Claude text chat.
- Test Claude image chat.
- Verify streaming output.
- Verify stop generation.
- Verify local history after app restart.
- Verify language switch.
- Verify session rename and delete.
- Verify connection test diagnostics.

## Implementation Notes

Recommended Flutter packages:

- `flutter_riverpod` for state.
- `dio` or `http` for network streaming.
- `sqlite3` or `sqflite` for local SQLite.
- `flutter_secure_storage` for API keys.
- `path_provider` for app-private files.
- `image_picker` for image selection.
- Markdown/code/LaTeX rendering packages selected during implementation planning.

The exact package choices can be finalized in the implementation plan.

