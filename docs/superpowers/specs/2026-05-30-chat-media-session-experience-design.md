# Chat Media And Session Experience Design

Date: 2026-05-30

## Goal

Improve NewChat's day-to-day chat experience by making quoted replies visible and useful, making generated and uploaded images inspectable, adding prompt-based image editing/regeneration, preserving unfinished conversations across app restarts, and adding session-list management actions.

## Scope

This feature covers:

- Rich quoted replies for text and image messages.
- Quote previews in the composer and in sent message bubbles.
- Full-screen image viewing with zoom and save.
- Prompt-based image editing/regeneration.
- Session-list pin, delete, unread, and read actions.
- Restoring unfinished chat state when reopening a session.

Out of scope:

- Pixel-level image editing such as crop, draw, erase, or annotations.
- Cloud sync.
- Cross-device unread state.
- Branching conversation trees.
- Saving images to the Android public gallery through platform channels. The first version saves a copy inside app-controlled storage and exposes the saved path through user feedback.

## Product Behavior

### Rich Quoted Replies

Users can long-press any completed user or assistant message and choose **Reply**.

The composer quote preview must show:

- A text icon and up to two lines of compact text when the referenced message has text.
- A thumbnail and a short label when the referenced message contains an image.
- Both thumbnail and compact text when the referenced message contains both.

After sending, the composer quote preview is cleared immediately. The sent user bubble still displays the quote reference so the chat record remains understandable after reopening the session.

Sent message bubbles display a compact reference block above message content. The reference block includes:

- The referenced message role label, such as `User` or `Assistant`.
- Text preview when available.
- Image thumbnail when available.

If a quoted image file is missing locally, the reference block shows a broken-image placeholder instead of failing layout.

### Quote Data Model

`ChatMessage` currently stores only `replyToMessageId` and `replyPreview`. That is not enough for image quotes. Add a richer optional `replyRef` while continuing to read old messages that only have `replyPreview`.

`MessageReplyRef` stores:

- `messageId`
- `role`
- `textPreview`
- `imageAttachment`
- `createdAt`

The old fields remain backward-compatible:

- On read, if `replyRef` is missing but `replyToMessageId` or `replyPreview` exists, create an equivalent text-only reference in memory.
- On write, keep `replyToMessageId` and `replyPreview` populated so older app versions degrade gracefully.

### Provider Context For Replies

Provider payloads keep using short text quote context only. Image quote thumbnails are UI metadata, not resent as provider image payloads. If a user replies to an image, the text preface should say that the user is replying to an earlier image message and include any available text preview.

Example:

```text
The user is replying to this earlier message:
"[Image] product screenshot"

User message:
What should I change?
```

### Image Viewer

Tapping any image thumbnail in a message opens a full-screen viewer.

The viewer provides:

- Back button.
- Pinch-to-zoom and pan.
- Save button.
- Edit button.

The image should be shown from its existing local file path. If the file is missing, the viewer shows a clear broken-image state and disables save/edit.

### Image Save

The save action copies the image into an app-controlled saved-images directory under application documents. It shows a snackbar with the saved path. This avoids platform-channel gallery complexity while still giving a durable saved copy.

If the copy fails, show a short safe error message. Do not expose stack traces.

### Prompt-Based Image Editing

Image editing means editing the prompt and regenerating a new image, not drawing on the bitmap.

Users can start image editing from:

- Long-pressing an image message and choosing **Edit Image**.
- Opening the full-screen viewer and tapping **Edit**.

The edit dialog is seeded from the nearest useful prompt:

1. If the image message has a preceding user message in the same turn, use that user's text.
2. Otherwise use the image message text if present.
3. Otherwise start with an empty prompt.

Saving the edited prompt sends a new user message and generates a new assistant image response. It does not overwrite the old image. This keeps the conversation history understandable.

The edit request should preserve the current session's selected provider and model. If the selected model is not an OpenAI image generation model, the app should still send normally; the provider may return text or an image depending on model capability. A later phase can add stricter model routing if needed.

### Unfinished Conversation Restore

When reopening a session, the app must show the stored messages exactly as saved. It must not discard streaming, failed, cancelled, or interrupted assistant messages.

If the last assistant message is:

- `streaming`: show it as `interrupted` after load, because the old network stream no longer exists.
- `failed`: keep failure text and show retry control.
- `cancelled` or `interrupted`: show retry/continue control.

The retry control reuses the existing `retryLastFailed` style, but should also work for interrupted/cancelled trailing assistant messages by removing that assistant and sending the previous user message again.

### Session List Management

The session list supports:

- Pin / unpin.
- Delete.
- Mark unread / mark read.

Pinned sessions appear first, ordered by `pinnedAt DESC`. Unpinned sessions follow, ordered by `updatedAt DESC`.

Unread sessions show a small unread indicator and use a stronger title style. Opening a session marks it read. Users can manually mark a session unread from the list.

Delete is a soft delete in metadata and hides the session from the list. Existing full delete behavior can remain as an internal repository operation, but the UI action should use soft delete so accidental deletion can be recovered later if needed.

### Session Data Model

`ChatSessionMeta` gains:

- `isPinned`
- `pinnedAt`
- `isUnread`

`ChatSessionDocument` gains:

- `isPinned`
- `pinnedAt`
- `isUnread`

The document remains the source of truth for in-memory and file/JSON compatibility. The persistent repository mirrors these fields into `session_metas`.

Existing saved sessions default to:

- `isPinned: false`
- `pinnedAt: null`
- `isUnread: false`

### Database Migration

The persistent SQLite `session_metas` table gains nullable columns:

- `is_pinned INTEGER NOT NULL DEFAULT 0`
- `pinned_at TEXT NULL`
- `is_unread INTEGER NOT NULL DEFAULT 0`

The migration must be idempotent for development databases.

### UI Notes

- Keep chat UI compact and close to current style.
- Do not add nested cards.
- Use icon buttons and bottom sheets for actions.
- Image thumbnails should have stable dimensions to avoid layout jumps.
- Quote previews should use one small thumbnail and short text, not large embedded previews.
- The full-screen image viewer can use `InteractiveViewer` and standard Flutter widgets.

## Testing

Add tests for:

- JSON backward compatibility for `MessageReplyRef` and session meta flags.
- Composer quote preview with text-only, image-only, and mixed references.
- Sent message bubble reference block with text and image thumbnails.
- Composer quote clears after send while sent bubble keeps reference.
- Image thumbnail tap opens viewer.
- Viewer save copies file and reports success.
- Image edit sends a new prompt without overwriting the old image.
- Reopening a session with streaming assistant marks it interrupted.
- Retry works for failed, cancelled, and interrupted trailing assistant messages.
- Session list pin ordering.
- Session list delete hides sessions.
- Session list unread/read state.
- Persistent repository migrates and round-trips new meta fields.

## Implementation Order

1. Data model and repository support.
2. Rich quote references and UI previews.
3. Image viewer with zoom and save.
4. Prompt-based image edit/regeneration.
5. Unfinished conversation restore and retry.
6. Session list management.
7. Full verification, APK build, emulator install, and log inspection.

## Risks

- Session metadata touches both JSON documents and SQLite meta rows, so tests must cover old data.
- Prompt-based image edit depends on current model behavior; if the selected model is not an image generation model, output may be text.
- Android gallery saving is not implemented in this phase; saved copies remain app-controlled.

## Self-Review

- No placeholders remain.
- The design explicitly separates UI image quote metadata from provider payloads.
- The image edit behavior is prompt regeneration, matching the user's selected option.
- The session list scope is included in this spec, matching route A.
- Backward compatibility defaults are explicit for both messages and sessions.
