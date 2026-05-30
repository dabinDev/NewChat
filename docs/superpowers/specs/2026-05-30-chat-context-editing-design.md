# Chat Context Editing Design

Date: 2026-05-30

## Goal

Improve conversation continuity in NewChat by adding message editing, quoted replies, and automatic context compression. The app should keep a clear local conversation record while sending a smaller, more relevant model context.

## Scope

This feature covers:

- Editing completed user messages.
- Regenerating assistant output after an edit.
- Quoting a previous message while sending a new prompt.
- Compressing older context into a session summary.
- Avoiding repeated old image payloads during normal follow-up turns.

Out of scope for this feature:

- Cloud sync.
- Cross-session memory.
- User profile memory.
- Branch/fork UI for edited conversations.
- Editing assistant messages.

## Product Behavior

### Message Editing

Users can long-press a completed user message and choose **Edit**. The edit dialog opens with the original user text. Saving the edit updates the message text, sets `editedAt`, and records the previous text in `editHistory`.

When a user message is edited, all messages after that user message are removed before regeneration. This keeps the visible transcript consistent with the new prompt. The app then sends the edited message with the remaining earlier context and generates a new assistant reply.

Only completed user messages are editable. Assistant, failed, streaming, cancelled, and interrupted messages are not editable.

### Quoted Replies

Users can long-press any completed user or assistant message and choose **Reply**. The composer shows a compact quote preview above the input. Sending a new message stores:

- `replyToMessageId`
- `replyPreview`

The provider payload includes a short text preface for that turn:

```text
The user is replying to this earlier message:
"<reply preview>"

User message:
<current text>
```

The visual quote preview appears in the sent user bubble and can be cancelled before sending.

### Context Compression

The app uses a `ContextBuilder` between `ChatController` and protocol providers. It constructs a provider-ready message list from:

- session system prompt
- `contextSummary`
- recent completed messages
- the current user message and its current-turn images

The first version uses deterministic local compression, not a model call. When the number of completed user/assistant messages exceeds a threshold, older text-only content is summarized into `contextSummary` as compact bullet text. The recent window remains verbatim.

Initial thresholds:

- Keep the most recent 12 completed user/assistant messages verbatim.
- Compress earlier completed text into `contextSummary`.
- Do not include old image bytes in compressed history.
- Include only images attached to the latest user message in the provider payload.

`contextSummary` is stored in `ChatSessionDocument` with `contextSummaryUpdatedAt`.

## Data Model

`ChatMessage` gains optional fields:

- `replyToMessageId`
- `replyPreview`
- `editedAt`
- `editHistory`

`editHistory` is a list of previous text values with timestamps.

`ChatSessionDocument` gains optional fields:

- `contextSummary`
- `contextSummaryUpdatedAt`

JSON parsing must be backward compatible. Missing new fields default to null or empty list.

## Request Context

Provider classes should still receive `ChatRequest`, but the request messages should come from the new context builder instead of directly from `document.messages`.

The context builder filters history as follows:

- Include completed user and assistant messages only.
- Exclude failed/cancelled/interrupted/streaming assistant messages.
- Convert `contextSummary` to a system/info-style text message near the top of context.
- Include quote preface only on the current user turn.
- Strip image parts from all older messages.
- Preserve current user message images.

This makes follow-up turns more stable and avoids repeatedly uploading old screenshots or images.

## UI

Long-pressing a bubble opens actions:

- User completed message: Reply, Edit, Copy.
- Assistant completed message: Reply, Copy.
- Failed assistant message: Copy, Retry from existing retry control when available.

The composer shows a quoted reply preview with a close button. The preview uses restrained styling and does not take over the input area.

Edited messages display a small `Edited` marker.

## Testing

Add tests for:

- Message JSON backward compatibility for new fields.
- Editing user messages records edit history and removes later messages.
- Regeneration after editing sends the edited text.
- Reply sends quote metadata and quote preface in provider context.
- Context builder keeps recent messages, summarizes older text, and strips old images.
- Provider payload includes current images but not old images.
- Widget tests for long-press actions, edit dialog, and quote preview.

## Implementation Notes

Prefer focused units:

- Keep domain model changes in `chat_models.dart`.
- Add context construction to a new application/domain helper instead of growing provider classes.
- Keep `ChatController` responsible for mutation workflows.
- Keep `ChatInputBar` responsible for composer state and callbacks.

Do not add remote summarization in this phase. Deterministic local summaries are enough to stabilize context without increasing cost or adding failure modes.
