# Flutter ChatBox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter Android APK chat client for user-configured sub2api/newapi gateways with OpenAI and Claude protocol support, streaming responses, image understanding, local multi-session history, and Chinese/English UI.

**Architecture:** Create a Flutter app from the empty repository, then implement the app as focused feature modules under `lib/features`. Domain models are provider-neutral, storage uses SQLite-backed session documents plus secure API-key storage, and protocol adapters convert OpenAI/Claude requests and SSE streams into unified app events.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, sqflite, flutter_secure_storage, dio, image_picker, flutter_markdown, flutter_highlight, flutter_math_fork, flutter_localizations, intl.

---

## Scope Notes

This plan implements the first-release scope from `docs/superpowers/specs/2026-05-30-flutter-chatbox-design.md`.

The implementation deliberately leaves these second-release features out:

- Cloud sync.
- Account login.
- Prompt marketplace or full role preset library.
- Image generation.
- Plugin/tool calling.
- Import/export.
- iOS release validation.

## Target File Structure

Create or modify these files:

- `pubspec.yaml`: app metadata, dependencies, assets, localization config.
- `analysis_options.yaml`: lint rules.
- `lib/main.dart`: app bootstrap.
- `lib/app.dart`: Material app, router, localization, theme.
- `lib/core/constants/app_constants.dart`: app constants and supported protocols.
- `lib/core/errors/chat_error.dart`: normalized error model.
- `lib/core/security/secret_masker.dart`: API-key masking helper.
- `lib/core/network/sse_parser.dart`: generic SSE line parser.
- `lib/core/network/http_client_provider.dart`: Dio client provider.
- `lib/core/storage/app_database.dart`: SQLite schema and helpers.
- `lib/core/storage/secure_key_store.dart`: secure API-key wrapper.
- `lib/core/storage/session_file_store.dart`: image file storage and cleanup.
- `lib/core/l10n/app_localizations.dart`: generated localization access.
- `lib/l10n/app_en.arb`: English strings.
- `lib/l10n/app_zh.arb`: Chinese strings.
- `lib/features/chat/domain/chat_models.dart`: session, message, content part, attachment models.
- `lib/features/chat/domain/chat_provider.dart`: provider-neutral streaming interface.
- `lib/features/chat/data/session_repository.dart`: session document persistence.
- `lib/features/chat/application/chat_controller.dart`: active chat send/stream/stop logic.
- `lib/features/chat/application/session_list_controller.dart`: session list state.
- `lib/features/chat/presentation/session_list_screen.dart`: mobile session list.
- `lib/features/chat/presentation/chat_screen.dart`: mobile chat page.
- `lib/features/chat/presentation/widgets/message_bubble.dart`: Markdown/LaTeX/code message rendering.
- `lib/features/chat/presentation/widgets/chat_input_bar.dart`: text and image input.
- `lib/features/providers/domain/provider_models.dart`: provider and model config models.
- `lib/features/providers/data/provider_repository.dart`: provider/model persistence and seed data.
- `lib/features/providers/data/openai_provider.dart`: OpenAI Chat Completions protocol.
- `lib/features/providers/data/claude_provider.dart`: Claude Messages protocol.
- `lib/features/providers/application/provider_controller.dart`: provider/model settings state.
- `lib/features/providers/presentation/settings_screen.dart`: settings shell.
- `lib/features/providers/presentation/provider_editor_screen.dart`: provider editor and connection test.
- `lib/features/providers/presentation/model_manager_screen.dart`: model management.
- `lib/features/system_prompt/presentation/system_prompt_screen.dart`: per-session system prompt editor.
- `test/core/network/sse_parser_test.dart`: SSE parsing tests.
- `test/core/security/secret_masker_test.dart`: secret masking tests.
- `test/features/providers/openai_provider_test.dart`: OpenAI request and stream parsing tests.
- `test/features/providers/claude_provider_test.dart`: Claude request and stream parsing tests.
- `test/features/chat/session_repository_test.dart`: session document persistence tests.
- `test/features/chat/chat_controller_test.dart`: send/stream/failure state tests.
- `test/widget/chat_empty_provider_test.dart`: empty provider routing test.
- `test/widget/chat_image_model_guard_test.dart`: image unsupported guard test.

## Task 1: Generate Flutter Android Project

**Files:**
- Create: Flutter project files under current repository.
- Modify: `README.md`
- Modify: `pubspec.yaml`
- Modify: `analysis_options.yaml`

- [ ] **Step 1: Verify repository is clean**

Run:

```powershell
git status --short --branch
```

Expected:

```text
## main...origin/main
```

- [ ] **Step 2: Generate Flutter project in place**

Run:

```powershell
flutter create --platforms android --project-name newchat .
```

Expected:

```text
All done!
```

- [ ] **Step 3: Replace README with project-specific content**

Modify `README.md` to:

```markdown
# NewChat

NewChat is a Flutter Android chat client for user-configured OpenAI-compatible and Claude-compatible gateways.

## First Release Scope

- OpenAI Chat Completions protocol
- Claude Messages protocol
- Streaming responses
- Text chat and image understanding
- Local multi-session history
- Per-session system prompt
- Chinese and English UI

## Development

```powershell
flutter pub get
flutter test
flutter run
```
```

- [ ] **Step 4: Add dependencies**

Modify `pubspec.yaml` so the dependency sections contain:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  cupertino_icons: ^1.0.8
  dio: ^5.8.0+1
  flutter_highlight: ^0.7.0
  flutter_markdown: ^0.7.6+2
  flutter_math_fork: ^0.7.3
  flutter_riverpod: ^2.6.1
  flutter_secure_storage: ^9.2.4
  go_router: ^14.8.1
  image_picker: ^1.1.2
  intl: ^0.19.0
  path: ^1.9.0
  path_provider: ^2.1.5
  sqflite: ^2.4.1
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  mocktail: ^1.0.4
```

Also add:

```yaml
flutter:
  generate: true
  uses-material-design: true
```

- [ ] **Step 5: Configure lints**

Create or replace `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    avoid_print: true
    prefer_final_locals: true
    require_trailing_commas: true
```

- [ ] **Step 6: Fetch packages**

Run:

```powershell
flutter pub get
```

Expected:

```text
Got dependencies!
```

- [ ] **Step 7: Run generated tests**

Run:

```powershell
flutter test
```

Expected: all generated tests pass.

- [ ] **Step 8: Commit scaffold**

Run:

```powershell
git add .
git commit -m "chore: scaffold flutter android app"
```

## Task 2: Add Core Domain Models

**Files:**
- Create: `lib/core/constants/app_constants.dart`
- Create: `lib/core/errors/chat_error.dart`
- Create: `lib/features/chat/domain/chat_models.dart`
- Create: `lib/features/chat/domain/chat_provider.dart`
- Create: `lib/features/providers/domain/provider_models.dart`
- Test: `test/features/chat/chat_models_test.dart`

- [ ] **Step 1: Write model serialization test**

Create `test/features/chat/chat_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';

void main() {
  test('session document round trips message parts and attachments', () {
    final document = ChatSessionDocument(
      id: 'session-1',
      title: 'Vision test',
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      systemPrompt: 'Be concise.',
      messages: [
        ChatMessage(
          id: 'message-1',
          role: ChatRole.user,
          state: MessageState.completed,
          parts: [
            const MessagePart.text('what is in this image?'),
            MessagePart.image(
              AttachmentRef(
                id: 'attachment-1',
                localPath: '/private/image.jpg',
                mimeType: 'image/jpeg',
                width: 1280,
                height: 720,
                fileSize: 2048,
              ),
            ),
          ],
          createdAt: DateTime.utc(2026, 5, 30),
          updatedAt: DateTime.utc(2026, 5, 30),
        ),
      ],
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
      schemaVersion: 1,
    );

    final copy = ChatSessionDocument.fromJson(document.toJson());

    expect(copy.id, 'session-1');
    expect(copy.messages.single.parts.length, 2);
    expect(copy.messages.single.parts.last.type, MessagePartType.image);
    expect(copy.systemPrompt, 'Be concise.');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/features/chat/chat_models_test.dart
```

Expected: FAIL because `ChatSessionDocument` and related classes are not defined.

- [ ] **Step 3: Add constants and errors**

Create `lib/core/constants/app_constants.dart`:

```dart
enum ProviderProtocol {
  openai,
  claude,
}

class AppConstants {
  const AppConstants._();

  static const appName = 'NewChat';
  static const schemaVersion = 1;
  static const streamFlushIntervalMs = 500;
}
```

Create `lib/core/errors/chat_error.dart`:

```dart
enum ChatErrorType {
  authentication,
  permission,
  notFound,
  badRequest,
  timeout,
  network,
  parsing,
  cancelled,
  unknown,
}

class ChatError implements Exception {
  const ChatError({
    required this.type,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final ChatErrorType type;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'ChatError($type, $statusCode, $message)';
}
```

- [ ] **Step 4: Add provider config models**

Create `lib/features/providers/domain/provider_models.dart`:

```dart
import 'package:newchat/core/constants/app_constants.dart';

class ProviderConfig {
  const ProviderConfig({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    required this.defaultModelId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final ProviderProtocol protocol;
  final String baseUrl;
  final String defaultModelId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'baseUrl': baseUrl,
        'defaultModelId': defaultModelId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ProviderConfig.fromJson(Map<String, Object?> json) => ProviderConfig(
        id: json['id']! as String,
        name: json['name']! as String,
        protocol: ProviderProtocol.values.byName(json['protocol']! as String),
        baseUrl: json['baseUrl']! as String,
        defaultModelId: json['defaultModelId']! as String,
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
      );
}

class ModelConfig {
  const ModelConfig({
    required this.id,
    required this.displayName,
    required this.protocol,
    required this.supportsStreaming,
    required this.supportsImages,
    this.contextLength,
  });

  final String id;
  final String displayName;
  final ProviderProtocol protocol;
  final bool supportsStreaming;
  final bool supportsImages;
  final int? contextLength;

  Map<String, Object?> toJson() => {
        'id': id,
        'displayName': displayName,
        'protocol': protocol.name,
        'supportsStreaming': supportsStreaming,
        'supportsImages': supportsImages,
        'contextLength': contextLength,
      };

  factory ModelConfig.fromJson(Map<String, Object?> json) => ModelConfig(
        id: json['id']! as String,
        displayName: json['displayName']! as String,
        protocol: ProviderProtocol.values.byName(json['protocol']! as String),
        supportsStreaming: json['supportsStreaming']! as bool,
        supportsImages: json['supportsImages']! as bool,
        contextLength: json['contextLength'] as int?,
      );
}
```

- [ ] **Step 5: Add chat domain models**

Create `lib/features/chat/domain/chat_models.dart` with enums, immutable classes, and `toJson` / `fromJson` methods for `ChatSessionMeta`, `ChatSessionDocument`, `ChatMessage`, `MessagePart`, and `AttachmentRef`. The implementation must use these exact enum names:

```dart
enum ChatRole { user, assistant, system }
enum MessageState { completed, streaming, failed, cancelled, interrupted }
enum MessagePartType { text, image, reasoning, info, error }
```

The `MessagePart` class must expose these constructors:

```dart
const MessagePart.text(String text);
const MessagePart.error(String text);
MessagePart.image(AttachmentRef attachment);
```

The JSON format must store enum values with `.name` and dates with ISO-8601 strings.

- [ ] **Step 6: Add provider-neutral stream interface**

Create `lib/features/chat/domain/chat_provider.dart`:

```dart
import 'package:newchat/core/errors/chat_error.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';

sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatStreamDelta extends ChatStreamEvent {
  const ChatStreamDelta(this.text);
  final String text;
}

class ChatStreamDone extends ChatStreamEvent {
  const ChatStreamDone();
}

class ChatStreamFailed extends ChatStreamEvent {
  const ChatStreamFailed(this.error);
  final ChatError error;
}

class ChatRequest {
  const ChatRequest({
    required this.provider,
    required this.model,
    required this.systemPrompt,
    required this.messages,
    required this.stream,
  });

  final ProviderConfig provider;
  final ModelConfig model;
  final String systemPrompt;
  final List<ChatMessage> messages;
  final bool stream;
}

class ConnectionTestRequest {
  const ConnectionTestRequest({
    required this.provider,
    required this.model,
  });

  final ProviderConfig provider;
  final ModelConfig model;
}

class ConnectionTestResult {
  const ConnectionTestResult.success() : error = null;
  const ConnectionTestResult.failure(this.error);

  final ChatError? error;
  bool get isSuccess => error == null;
}

abstract interface class ChatProvider {
  Stream<ChatStreamEvent> sendStream(ChatRequest request);
  Future<ConnectionTestResult> testConnection(ConnectionTestRequest request);
}
```

- [ ] **Step 7: Run model tests**

Run:

```powershell
flutter test test/features/chat/chat_models_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit domain models**

Run:

```powershell
git add lib/core lib/features test/features/chat/chat_models_test.dart
git commit -m "feat: add chat domain models"
```

## Task 3: Add Secret Masking And SSE Parser

**Files:**
- Create: `lib/core/security/secret_masker.dart`
- Create: `lib/core/network/sse_parser.dart`
- Test: `test/core/security/secret_masker_test.dart`
- Test: `test/core/network/sse_parser_test.dart`

- [ ] **Step 1: Write secret masking tests**

Create `test/core/security/secret_masker_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/security/secret_masker.dart';

void main() {
  test('masks long API keys', () {
    expect(maskSecret('sk-abcdefghijklmnopqrstuvwxyz'), 'sk-a...wxyz');
  });

  test('masks short secrets completely', () {
    expect(maskSecret('abc123'), '******');
  });

  test('masks empty secrets', () {
    expect(maskSecret(''), '');
  });
}
```

- [ ] **Step 2: Write SSE parser tests**

Create `test/core/network/sse_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/network/sse_parser.dart';

void main() {
  test('parses SSE event with data', () {
    final events = parseSseChunk('event: content_block_delta\ndata: {"x":1}\n\n');

    expect(events, hasLength(1));
    expect(events.single.event, 'content_block_delta');
    expect(events.single.data, '{"x":1}');
  });

  test('parses OpenAI data-only event', () {
    final events = parseSseChunk('data: {"choices":[]}\n\n');

    expect(events.single.event, isNull);
    expect(events.single.data, '{"choices":[]}');
  });

  test('ignores comments and blank chunks', () {
    final events = parseSseChunk(': keepalive\n\n');

    expect(events, isEmpty);
  });
}
```

- [ ] **Step 3: Run tests to verify failure**

Run:

```powershell
flutter test test/core/security/secret_masker_test.dart test/core/network/sse_parser_test.dart
```

Expected: FAIL because helper files are missing.

- [ ] **Step 4: Implement secret masker**

Create `lib/core/security/secret_masker.dart`:

```dart
String maskSecret(String value) {
  if (value.isEmpty) {
    return '';
  }
  if (value.length < 12) {
    return '******';
  }
  return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
}
```

- [ ] **Step 5: Implement SSE parser**

Create `lib/core/network/sse_parser.dart`:

```dart
class SseEvent {
  const SseEvent({
    required this.data,
    this.event,
  });

  final String? event;
  final String data;
}

List<SseEvent> parseSseChunk(String chunk) {
  final normalized = chunk.replaceAll('\r\n', '\n');
  final blocks = normalized.split('\n\n');
  final events = <SseEvent>[];

  for (final block in blocks) {
    String? event;
    final dataLines = <String>[];

    for (final rawLine in block.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty || line.startsWith(':')) {
        continue;
      }
      if (line.startsWith('event:')) {
        event = line.substring('event:'.length).trimLeft();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring('data:'.length).trimLeft());
      }
    }

    if (dataLines.isNotEmpty) {
      events.add(SseEvent(event: event, data: dataLines.join('\n')));
    }
  }

  return events;
}
```

- [ ] **Step 6: Run helper tests**

Run:

```powershell
flutter test test/core/security/secret_masker_test.dart test/core/network/sse_parser_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit helpers**

Run:

```powershell
git add lib/core/security lib/core/network test/core
git commit -m "feat: add secret masking and sse parser"
```

## Task 4: Add SQLite Document Storage And Secure Key Store

**Files:**
- Create: `lib/core/storage/app_database.dart`
- Create: `lib/core/storage/secure_key_store.dart`
- Create: `lib/core/storage/session_file_store.dart`
- Create: `lib/features/chat/data/session_repository.dart`
- Test: `test/features/chat/session_repository_test.dart`

- [ ] **Step 1: Write session repository test**

Create `test/features/chat/session_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/features/chat/data/session_repository.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';

void main() {
  test('in-memory repository saves and lists session documents', () async {
    final repository = InMemorySessionRepository();
    final createdAt = DateTime.utc(2026, 5, 30);
    final document = ChatSessionDocument(
      id: 'session-1',
      title: 'Hello',
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      systemPrompt: '',
      messages: [
        ChatMessage(
          id: 'message-1',
          role: ChatRole.user,
          state: MessageState.completed,
          parts: const [MessagePart.text('hello')],
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      ],
      createdAt: createdAt,
      updatedAt: createdAt,
      schemaVersion: 1,
    );

    await repository.saveDocument(document);

    final loaded = await repository.loadDocument('session-1');
    final metas = await repository.listMetas();

    expect(loaded!.title, 'Hello');
    expect(metas.single.lastMessagePreview, 'hello');
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```powershell
flutter test test/features/chat/session_repository_test.dart
```

Expected: FAIL because repository does not exist.

- [ ] **Step 3: Implement session repository interface and in-memory test repository**

Create `lib/features/chat/data/session_repository.dart` with:

```dart
import 'package:newchat/features/chat/domain/chat_models.dart';

abstract interface class SessionRepository {
  Future<List<ChatSessionMeta>> listMetas();
  Future<ChatSessionDocument?> loadDocument(String id);
  Future<void> saveDocument(ChatSessionDocument document);
  Future<void> deleteSession(String id);
}

class InMemorySessionRepository implements SessionRepository {
  final Map<String, ChatSessionDocument> _documents = {};

  @override
  Future<void> deleteSession(String id) async {
    _documents.remove(id);
  }

  @override
  Future<ChatSessionDocument?> loadDocument(String id) async => _documents[id];

  @override
  Future<List<ChatSessionMeta>> listMetas() async {
    final metas = _documents.values.map(_toMeta).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return metas;
  }

  @override
  Future<void> saveDocument(ChatSessionDocument document) async {
    _documents[document.id] = document;
  }

  ChatSessionMeta _toMeta(ChatSessionDocument document) {
    final preview = document.messages.reversed
        .expand((message) => message.parts)
        .where((part) => part.type == MessagePartType.text)
        .map((part) => part.text ?? '')
        .firstWhere((text) => text.isNotEmpty, orElse: () => '');
    return ChatSessionMeta(
      id: document.id,
      title: document.title,
      lastMessagePreview: preview,
      providerId: document.providerId,
      modelId: document.modelId,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
      isDeleted: false,
    );
  }
}
```

- [ ] **Step 4: Add SQLite schema**

Create `lib/core/storage/app_database.dart` with an `AppDatabase` class that opens sqflite database `newchat.db` and creates:

```sql
CREATE TABLE IF NOT EXISTS app_kv (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS session_metas (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  last_message_preview TEXT NOT NULL,
  provider_id TEXT NOT NULL,
  model_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  payload_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

Expose methods:

```dart
Future<Database> open();
Future<void> close();
```

- [ ] **Step 5: Add secure key store**

Create `lib/core/storage/secure_key_store.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyStore {
  SecureKeyStore(this._storage);

  final FlutterSecureStorage _storage;

  String _keyForProvider(String providerId) => 'provider_api_key_$providerId';

  Future<void> writeProviderKey(String providerId, String apiKey) {
    return _storage.write(key: _keyForProvider(providerId), value: apiKey);
  }

  Future<String?> readProviderKey(String providerId) {
    return _storage.read(key: _keyForProvider(providerId));
  }

  Future<void> deleteProviderKey(String providerId) {
    return _storage.delete(key: _keyForProvider(providerId));
  }
}
```

- [ ] **Step 6: Add session file store**

Create `lib/core/storage/session_file_store.dart` with methods:

```dart
Future<Directory> attachmentsDirectory(String sessionId);
Future<File> copyAttachmentIntoSession({
  required String sessionId,
  required File source,
  required String attachmentId,
});
Future<void> deleteSessionAttachments(String sessionId);
```

The implementation must use `path_provider.getApplicationDocumentsDirectory()` and store files under `attachments/<sessionId>/`.

- [ ] **Step 7: Run storage test**

Run:

```powershell
flutter test test/features/chat/session_repository_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit storage foundation**

Run:

```powershell
git add lib/core/storage lib/features/chat/data test/features/chat/session_repository_test.dart
git commit -m "feat: add local storage foundation"
```

## Task 5: Add Provider And Model Repository

**Files:**
- Create: `lib/features/providers/data/provider_repository.dart`
- Create: `test/features/providers/provider_repository_test.dart`

- [ ] **Step 1: Write seed model test**

Create `test/features/providers/provider_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';

void main() {
  test('seed models include openai and claude vision-capable models', () {
    final models = seedModelConfigs();

    expect(
      models.any((model) =>
          model.protocol == ProviderProtocol.openai && model.supportsImages),
      isTrue,
    );
    expect(
      models.any((model) =>
          model.protocol == ProviderProtocol.claude && model.supportsImages),
      isTrue,
    );
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```powershell
flutter test test/features/providers/provider_repository_test.dart
```

Expected: FAIL because repository does not exist.

- [ ] **Step 3: Implement seed models**

Create `lib/features/providers/data/provider_repository.dart` with:

```dart
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';

List<ModelConfig> seedModelConfigs() => const [
      ModelConfig(
        id: 'gpt-4o-mini',
        displayName: 'GPT-4o mini',
        protocol: ProviderProtocol.openai,
        supportsStreaming: true,
        supportsImages: true,
      ),
      ModelConfig(
        id: 'gpt-4o',
        displayName: 'GPT-4o',
        protocol: ProviderProtocol.openai,
        supportsStreaming: true,
        supportsImages: true,
      ),
      ModelConfig(
        id: 'claude-3-5-sonnet-latest',
        displayName: 'Claude 3.5 Sonnet',
        protocol: ProviderProtocol.claude,
        supportsStreaming: true,
        supportsImages: true,
      ),
      ModelConfig(
        id: 'claude-3-5-haiku-latest',
        displayName: 'Claude 3.5 Haiku',
        protocol: ProviderProtocol.claude,
        supportsStreaming: true,
        supportsImages: true,
      ),
    ];

abstract interface class ProviderRepository {
  Future<List<ProviderConfig>> listProviders();
  Future<List<ModelConfig>> listModels();
  Future<void> saveProvider(ProviderConfig provider);
  Future<void> deleteProvider(String providerId);
  Future<void> saveModel(ModelConfig model);
  Future<void> deleteModel(String modelId);
}
```

- [ ] **Step 4: Run repository test**

Run:

```powershell
flutter test test/features/providers/provider_repository_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit provider repository foundation**

Run:

```powershell
git add lib/features/providers test/features/providers/provider_repository_test.dart
git commit -m "feat: add provider model seeds"
```

## Task 6: Implement OpenAI Protocol Adapter

**Files:**
- Create: `lib/features/providers/data/openai_provider.dart`
- Test: `test/features/providers/openai_provider_test.dart`

- [ ] **Step 1: Write OpenAI payload and stream tests**

Create `test/features/providers/openai_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/providers/data/openai_provider.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';

void main() {
  test('builds OpenAI request with system prompt and text message', () {
    final provider = ProviderConfig(
      id: 'p1',
      name: 'Gateway',
      protocol: ProviderProtocol.openai,
      baseUrl: 'https://token.cylonai.cn',
      defaultModelId: 'gpt-4o-mini',
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
    );
    const model = ModelConfig(
      id: 'gpt-4o-mini',
      displayName: 'GPT-4o mini',
      protocol: ProviderProtocol.openai,
      supportsStreaming: true,
      supportsImages: true,
    );

    final payload = buildOpenAiPayload(
      provider: provider,
      model: model,
      systemPrompt: 'Be concise.',
      messages: [
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          state: MessageState.completed,
          parts: const [MessagePart.text('hello')],
          createdAt: DateTime.utc(2026, 5, 30),
          updatedAt: DateTime.utc(2026, 5, 30),
        ),
      ],
      stream: true,
    );

    expect(payload['model'], 'gpt-4o-mini');
    expect(payload['stream'], isTrue);
    expect((payload['messages']! as List).first['role'], 'system');
  });

  test('parses OpenAI text delta', () {
    final events = parseOpenAiSse(
      'data: {"choices":[{"delta":{"content":"hi"}}]}\n\n',
    );

    expect(events.single, 'hi');
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```powershell
flutter test test/features/providers/openai_provider_test.dart
```

Expected: FAIL because OpenAI adapter is missing.

- [ ] **Step 3: Implement OpenAI payload builder and parser**

Create `lib/features/providers/data/openai_provider.dart` with exported functions:

```dart
Map<String, Object?> buildOpenAiPayload({
  required ProviderConfig provider,
  required ModelConfig model,
  required String systemPrompt,
  required List<ChatMessage> messages,
  required bool stream,
});

List<String> parseOpenAiSse(String chunk);
```

Rules:

- Include a `system` message only when `systemPrompt.trim().isNotEmpty`.
- Convert `ChatRole.user` to `user`, `ChatRole.assistant` to `assistant`.
- Text-only messages can use a string `content`.
- Messages with images must use OpenAI content array with `{"type":"text"}` and `{"type":"image_url"}` parts.
- `parseOpenAiSse` must ignore `[DONE]`.
- `parseOpenAiSse` must return text from `choices[].delta.content`.

- [ ] **Step 4: Implement `OpenAIProvider` class**

In the same file, implement:

```dart
class OpenAIProvider implements ChatProvider {
  OpenAIProvider({
    required Dio dio,
    required Future<String?> Function(String providerId) readApiKey,
  });
}
```

Behavior:

- POST to `${provider.baseUrl}/v1/chat/completions`.
- Use `Authorization: Bearer <key>`.
- Use `Accept: text/event-stream` for streaming requests.
- Emit `ChatStreamDelta` for parsed deltas.
- Emit `ChatStreamDone` on `[DONE]`.
- Convert Dio errors to `ChatStreamFailed(ChatError(...))`.

- [ ] **Step 5: Run OpenAI tests**

Run:

```powershell
flutter test test/features/providers/openai_provider_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit OpenAI adapter**

Run:

```powershell
git add lib/features/providers/data/openai_provider.dart test/features/providers/openai_provider_test.dart
git commit -m "feat: add openai protocol adapter"
```

## Task 7: Implement Claude Protocol Adapter

**Files:**
- Create: `lib/features/providers/data/claude_provider.dart`
- Test: `test/features/providers/claude_provider_test.dart`

- [ ] **Step 1: Write Claude payload and stream tests**

Create `test/features/providers/claude_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/providers/data/claude_provider.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';

void main() {
  test('builds Claude request with system prompt and text message', () {
    final provider = ProviderConfig(
      id: 'p1',
      name: 'Claude Gateway',
      protocol: ProviderProtocol.claude,
      baseUrl: 'https://token.cylonai.cn',
      defaultModelId: 'claude-3-5-sonnet-latest',
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
    );
    const model = ModelConfig(
      id: 'claude-3-5-sonnet-latest',
      displayName: 'Claude 3.5 Sonnet',
      protocol: ProviderProtocol.claude,
      supportsStreaming: true,
      supportsImages: true,
    );

    final payload = buildClaudePayload(
      provider: provider,
      model: model,
      systemPrompt: 'Be concise.',
      messages: [
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          state: MessageState.completed,
          parts: const [MessagePart.text('hello')],
          createdAt: DateTime.utc(2026, 5, 30),
          updatedAt: DateTime.utc(2026, 5, 30),
        ),
      ],
      stream: true,
    );

    expect(payload['model'], 'claude-3-5-sonnet-latest');
    expect(payload['system'], 'Be concise.');
    expect(payload['stream'], isTrue);
  });

  test('parses Claude content block delta', () {
    final events = parseClaudeSse(
      'event: content_block_delta\ndata: {"delta":{"type":"text_delta","text":"hi"}}\n\n',
    );

    expect(events.single, 'hi');
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```powershell
flutter test test/features/providers/claude_provider_test.dart
```

Expected: FAIL because Claude adapter is missing.

- [ ] **Step 3: Implement Claude payload builder and parser**

Create `lib/features/providers/data/claude_provider.dart` with exported functions:

```dart
Map<String, Object?> buildClaudePayload({
  required ProviderConfig provider,
  required ModelConfig model,
  required String systemPrompt,
  required List<ChatMessage> messages,
  required bool stream,
});

List<String> parseClaudeSse(String chunk);
```

Rules:

- Put system prompt in top-level `system`.
- Convert only user and assistant messages into `messages`.
- Convert text content to Claude content blocks `{ "type": "text", "text": "..." }`.
- Convert image content to `{ "type": "image", "source": { "type": "base64", "media_type": mimeType, "data": base64 } }`.
- `parseClaudeSse` must return text from `content_block_delta` events where `delta.type == text_delta`.

- [ ] **Step 4: Implement `ClaudeProvider` class**

In the same file, implement:

```dart
class ClaudeProvider implements ChatProvider {
  ClaudeProvider({
    required Dio dio,
    required Future<String?> Function(String providerId) readApiKey,
  });
}
```

Behavior:

- POST to `${provider.baseUrl}/v1/messages`.
- Use `x-api-key: <key>`.
- Use `anthropic-version: 2023-06-01`.
- Use `Accept: text/event-stream` for streaming requests.
- Emit `ChatStreamDelta` for parsed deltas.
- Emit `ChatStreamDone` when Claude stream stops.
- Convert Dio errors to `ChatStreamFailed(ChatError(...))`.

- [ ] **Step 5: Run Claude tests**

Run:

```powershell
flutter test test/features/providers/claude_provider_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Claude adapter**

Run:

```powershell
git add lib/features/providers/data/claude_provider.dart test/features/providers/claude_provider_test.dart
git commit -m "feat: add claude protocol adapter"
```

## Task 8: Add Chat Controller Streaming Workflow

**Files:**
- Create: `lib/features/chat/application/chat_controller.dart`
- Create: `lib/features/chat/application/session_list_controller.dart`
- Test: `test/features/chat/chat_controller_test.dart`

- [ ] **Step 1: Write chat controller test**

Create `test/features/chat/chat_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/errors/chat_error.dart';
import 'package:newchat/features/chat/application/chat_controller.dart';
import 'package:newchat/features/chat/data/session_repository.dart';
import 'package:newchat/features/chat/domain/chat_provider.dart';

void main() {
  test('sendMessage appends user message and streamed assistant text', () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider([
      const ChatStreamDelta('hello'),
      const ChatStreamDelta(' world'),
      const ChatStreamDone(),
    ]);
    final controller = ChatController(
      repository: repository,
      chatProvider: fakeProvider,
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    await controller.sendMessage(text: 'hi', attachments: const []);

    final document = controller.currentDocument!;
    expect(document.messages.length, 2);
    expect(document.messages.last.fullText, 'hello world');
  });
}

class FakeChatProvider implements ChatProvider {
  FakeChatProvider(this.events);

  final List<ChatStreamEvent> events;

  @override
  Stream<ChatStreamEvent> sendStream(ChatRequest request) async* {
    for (final event in events) {
      yield event;
    }
  }

  @override
  Future<ConnectionTestResult> testConnection(ConnectionTestRequest request) async {
    return const ConnectionTestResult.success();
  }
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```powershell
flutter test test/features/chat/chat_controller_test.dart
```

Expected: FAIL because controller is missing.

- [ ] **Step 3: Implement chat controller**

Create `lib/features/chat/application/chat_controller.dart` with:

```dart
class ChatController {
  ChatController({
    required SessionRepository repository,
    required ChatProvider chatProvider,
  });

  ChatSessionDocument? get currentDocument;
  Future<void> createSession({
    required String providerId,
    required String modelId,
    required String title,
  });
  Future<void> loadSession(String sessionId);
  Future<void> sendMessage({
    required String text,
    required List<AttachmentRef> attachments,
  });
  Future<void> stopGeneration();
  Future<void> retryLastFailed();
}
```

Implementation details:

- Use `uuid` for message ids.
- Add a completed user message before streaming.
- Add a streaming assistant message before consuming provider events.
- Append `ChatStreamDelta.text` into the assistant message.
- Mark assistant as `completed` on `ChatStreamDone`.
- Mark assistant as `failed` and add `MessagePart.error(...)` on `ChatStreamFailed`.
- Save the document after user message, after assistant creation, and after stream completion.

- [ ] **Step 4: Implement session list controller**

Create `lib/features/chat/application/session_list_controller.dart` exposing methods:

```dart
Future<void> load();
Future<void> renameSession(String sessionId, String title);
Future<void> deleteSession(String sessionId);
```

The controller must read and update `SessionRepository`.

- [ ] **Step 5: Run controller tests**

Run:

```powershell
flutter test test/features/chat/chat_controller_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit chat workflow**

Run:

```powershell
git add lib/features/chat/application test/features/chat/chat_controller_test.dart
git commit -m "feat: add chat streaming workflow"
```

## Task 9: Add Localization, App Shell, Routing, Theme, And Route Screens

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/app.dart`
- Create: `lib/features/chat/presentation/session_list_screen.dart`
- Create: `lib/features/chat/presentation/chat_screen.dart`
- Create: `lib/features/providers/presentation/settings_screen.dart`
- Create: `lib/features/providers/presentation/provider_editor_screen.dart`
- Create: `lib/features/providers/presentation/model_manager_screen.dart`
- Create: `lib/features/system_prompt/presentation/system_prompt_screen.dart`
- Create: `lib/l10n/app_en.arb`
- Create: `lib/l10n/app_zh.arb`
- Create: `l10n.yaml`
- Test: `test/widget/app_smoke_test.dart`

- [ ] **Step 1: Add localization files**

Create `l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
```

Create `lib/l10n/app_en.arb`:

```json
{
  "appTitle": "NewChat",
  "newChat": "New chat",
  "settings": "Settings",
  "send": "Send",
  "stop": "Stop",
  "providerRequired": "Add a provider before chatting.",
  "imageUnsupported": "The selected model does not support images.",
  "testConnection": "Test connection",
  "connectionSucceeded": "Connection succeeded.",
  "connectionFailed": "Connection failed."
}
```

Create `lib/l10n/app_zh.arb`:

```json
{
  "appTitle": "NewChat",
  "newChat": "新会话",
  "settings": "设置",
  "send": "发送",
  "stop": "停止",
  "providerRequired": "请先添加服务商配置。",
  "imageUnsupported": "当前模型不支持图片。",
  "testConnection": "测试连接",
  "connectionSucceeded": "连接成功。",
  "connectionFailed": "连接失败。"
}
```

- [ ] **Step 2: Replace app bootstrap**

Modify `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:newchat/app.dart';

void main() {
  runApp(const ProviderScope(child: NewChatApp()));
}
```

- [ ] **Step 3: Create app shell**

Create `lib/app.dart` with a `MaterialApp.router` using `GoRouter`, generated `AppLocalizations`, Chinese and English supported locales, Material 3 theme, and routes:

- `/` -> `SessionListScreen`
- `/chat/:sessionId` -> `ChatScreen`
- `/settings` -> `SettingsScreen`
- `/settings/provider/new` -> `ProviderEditorScreen`
- `/settings/models` -> `ModelManagerScreen`
- `/chat/:sessionId/system-prompt` -> `SystemPromptScreen`

- [ ] **Step 4: Create route target screen skeletons**

Create `lib/features/chat/presentation/session_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:newchat/l10n/app_localizations.dart';

class SessionListScreen extends StatelessWidget {
  const SessionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.settings,
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Center(child: Text(l10n.providerRequired)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: Text(l10n.newChat),
      ),
    );
  }
}
```

Create `lib/features/chat/presentation/chat_screen.dart`:

```dart
import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    required this.sessionId,
    super.key,
  });

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(sessionId)),
      body: const Center(child: Text('Chat')),
    );
  }
}
```

Create `lib/features/providers/presentation/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:newchat/l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Providers'),
            onTap: () => context.go('/settings/provider/new'),
          ),
          ListTile(
            title: const Text('Models'),
            onTap: () => context.go('/settings/models'),
          ),
        ],
      ),
    );
  }
}
```

Create `lib/features/providers/presentation/provider_editor_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:newchat/l10n/app_localizations.dart';

class ProviderEditorScreen extends StatelessWidget {
  const ProviderEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.testConnection)),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: 'Name')),
            TextField(decoration: InputDecoration(labelText: 'Base URL')),
            TextField(decoration: InputDecoration(labelText: 'API Key')),
          ],
        ),
      ),
    );
  }
}
```

Create `lib/features/providers/presentation/model_manager_screen.dart`:

```dart
import 'package:flutter/material.dart';

class ModelManagerScreen extends StatelessWidget {
  const ModelManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Models')),
      body: const Center(child: Text('Models')),
    );
  }
}
```

Create `lib/features/system_prompt/presentation/system_prompt_screen.dart`:

```dart
import 'package:flutter/material.dart';

class SystemPromptScreen extends StatelessWidget {
  const SystemPromptScreen({
    required this.sessionId,
    super.key,
  });

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Prompt')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: TextField(
          maxLines: null,
          decoration: InputDecoration(labelText: 'System Prompt'),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Write smoke test**

Create `test/widget/app_smoke_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/app.dart';

void main() {
  testWidgets('app starts and shows title', (tester) async {
    await tester.pumpWidget(const NewChatApp());
    await tester.pumpAndSettle();

    expect(find.text('NewChat'), findsWidgets);
  });
}
```

- [ ] **Step 6: Run code generation and test**

Run:

```powershell
flutter gen-l10n
flutter test test/widget/app_smoke_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit app shell**

Run:

```powershell
git add lib/main.dart lib/app.dart lib/features lib/l10n l10n.yaml test/widget/app_smoke_test.dart
git commit -m "feat: add app shell and localization"
```

## Task 10: Add Chat And Settings Screens

**Files:**
- Modify: `lib/features/chat/presentation/session_list_screen.dart`
- Modify: `lib/features/chat/presentation/chat_screen.dart`
- Create: `lib/features/chat/presentation/widgets/message_bubble.dart`
- Create: `lib/features/chat/presentation/widgets/chat_input_bar.dart`
- Modify: `lib/features/providers/presentation/settings_screen.dart`
- Modify: `lib/features/providers/presentation/provider_editor_screen.dart`
- Modify: `lib/features/providers/presentation/model_manager_screen.dart`
- Modify: `lib/features/system_prompt/presentation/system_prompt_screen.dart`
- Test: `test/widget/chat_empty_provider_test.dart`
- Test: `test/widget/chat_image_model_guard_test.dart`

- [ ] **Step 1: Write empty provider widget test**

Create `test/widget/chat_empty_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/app.dart';

void main() {
  testWidgets('empty provider state shows settings guidance', (tester) async {
    await tester.pumpWidget(const NewChatApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('provider', findRichText: true), findsWidgets);
  });
}
```

- [ ] **Step 2: Create session list screen**

Create `lib/features/chat/presentation/session_list_screen.dart` with:

- `Scaffold`
- app bar title `NewChat`
- settings icon button routed to `/settings`
- list of session cards
- floating action button for new chat
- empty state that links to settings when no provider exists

- [ ] **Step 3: Create chat screen**

Create `lib/features/chat/presentation/chat_screen.dart` with:

- app bar title from session title
- provider/model subtitle
- popup actions: rename, system prompt, switch model, delete
- message list
- `ChatInputBar`
- stop button while streaming

- [ ] **Step 4: Create message bubble**

Create `lib/features/chat/presentation/widgets/message_bubble.dart` using:

- `flutter_markdown` for Markdown.
- `flutter_highlight` for fenced code blocks.
- `flutter_math_fork` for LaTeX spans or blocks.
- image thumbnails for `MessagePartType.image`.
- inline error display for `MessagePartType.error`.

- [ ] **Step 5: Create input bar**

Create `lib/features/chat/presentation/widgets/chat_input_bar.dart` with:

- multiline text field.
- image picker button using `image_picker`.
- send icon button.
- disabled send state when text and attachments are empty.
- localized error when selected model does not support images.

- [ ] **Step 6: Create settings screens**

Create settings screens with these controls:

- Provider list.
- Add/edit provider form.
- Protocol segmented choice: OpenAI / Claude.
- Base URL field.
- API key field with masked display.
- Default model dropdown.
- Test connection button.
- Model manager with add/edit/delete and `supportsImages` checkbox.
- Language choice: system, Chinese, English.

- [ ] **Step 7: Create system prompt screen**

Create `lib/features/system_prompt/presentation/system_prompt_screen.dart` with:

- multiline text field.
- save button.
- clear button.
- back navigation after save.

- [ ] **Step 8: Run widget tests**

Run:

```powershell
flutter test test/widget/chat_empty_provider_test.dart test/widget/chat_image_model_guard_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit UI screens**

Run:

```powershell
git add lib/features test/widget
git commit -m "feat: add mobile chat ui"
```

## Task 11: Wire Real Providers, Persistence, And Connection Tests

**Files:**
- Create: `lib/core/network/http_client_provider.dart`
- Modify: `lib/features/providers/application/provider_controller.dart`
- Modify: `lib/features/providers/presentation/provider_editor_screen.dart`
- Modify: `lib/features/chat/application/chat_controller.dart`
- Modify: `lib/features/chat/presentation/chat_screen.dart`

- [ ] **Step 1: Create Dio provider**

Create `lib/core/network/http_client_provider.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
});
```

- [ ] **Step 2: Add provider controller**

Create `lib/features/providers/application/provider_controller.dart` exposing Riverpod providers for:

- provider list.
- model list.
- selected language.
- save provider.
- delete provider.
- save model.
- delete model.
- test connection.

The controller must construct `OpenAIProvider` for `ProviderProtocol.openai` and `ClaudeProvider` for `ProviderProtocol.claude`.

- [ ] **Step 3: Wire settings form to repository**

Modify `provider_editor_screen.dart` so save stores:

- provider config in `ProviderRepository`.
- API key in `SecureKeyStore`.

The API key text field must not persist empty input over an existing key unless the user explicitly clears it.

- [ ] **Step 4: Wire test connection button**

Modify `provider_editor_screen.dart` so tapping test:

- validates Base URL, protocol, model, and API key fields.
- runs provider-specific non-streaming test.
- displays success or mapped failure message.
- masks the key in every visible diagnostic.

- [ ] **Step 5: Wire chat screen to selected provider**

Modify `chat_screen.dart` and `chat_controller.dart` so sending a message:

- loads the session's provider and model.
- verifies provider protocol matches model protocol.
- blocks images when model `supportsImages == false`.
- sends through `OpenAIProvider` or `ClaudeProvider`.

- [ ] **Step 6: Run focused tests**

Run:

```powershell
flutter test test/features/providers test/features/chat
```

Expected: PASS.

- [ ] **Step 7: Commit provider wiring**

Run:

```powershell
git add lib/core/network lib/features
git commit -m "feat: wire providers and connection tests"
```

## Task 12: Android Permissions, Manual QA, And Release APK

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `README.md`

- [ ] **Step 1: Add Android permissions**

Modify `android/app/src/main/AndroidManifest.xml` to include:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

For Android versions below 13, also include:

```xml
<uses-permission
    android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

- [ ] **Step 2: Run full analyzer and tests**

Run:

```powershell
flutter analyze
flutter test
```

Expected:

```text
No issues found!
All tests passed!
```

- [ ] **Step 3: Build debug APK**

Run:

```powershell
flutter build apk --debug
```

Expected output includes:

```text
Built build\app\outputs\flutter-apk\app-debug.apk
```

- [ ] **Step 4: Manual acceptance on Android**

Install and verify:

```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

Manual checks:

- Add OpenAI provider with gateway Base URL and a user-entered key.
- Add Claude provider with the same gateway Base URL and a different user-entered key.
- Test OpenAI connection.
- Test Claude connection.
- Send OpenAI text message and verify streaming.
- Send Claude text message and verify streaming.
- Send OpenAI image message with a vision-capable model.
- Send Claude image message with a vision-capable model.
- Stop generation and verify partial response is preserved.
- Restart app and verify local history returns.
- Rename and delete a session.
- Switch language between Chinese and English.

- [ ] **Step 5: Update README with APK path**

Add:

```markdown
## Debug APK

After a successful build, the debug APK is available at:

`build/app/outputs/flutter-apk/app-debug.apk`
```

- [ ] **Step 6: Commit release prep**

Run:

```powershell
git add android/app/src/main/AndroidManifest.xml README.md
git commit -m "chore: prepare android debug build"
```

- [ ] **Step 7: Push all commits**

Run:

```powershell
git push
```

Expected:

```text
main -> main
```

## Self-Review

- Spec coverage: The tasks cover Flutter scaffold, OpenAI and Claude protocols, streaming, image content, local session documents, secure key storage, multi-session UI, system prompt, Markdown/code/LaTeX rendering, Chinese/English localization, provider/model testing, Android APK build, and manual gateway acceptance.
- Placeholder scan: The plan contains no `TBD` markers. UI tasks specify required widgets and behaviors, while protocol and domain tasks define exact class names, methods, and tests.
- Type consistency: The plan uses the same protocol enum, chat model names, provider interface, stream event names, and repository names across tasks.
- Scope check: Second-release features remain excluded and are not scheduled.
