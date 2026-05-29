import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/errors/chat_error.dart';
import 'package:newchat/features/chat/application/chat_controller.dart';
import 'package:newchat/features/chat/application/session_list_controller.dart';
import 'package:newchat/features/chat/data/session_repository.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/domain/chat_provider.dart';

void main() {
  test('sendMessage appends user message and streamed assistant text',
      () async {
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

  test('failed stream marks assistant failed and stores error part', () async {
    final repository = InMemorySessionRepository();
    final fakeProvider = FakeChatProvider([
      const ChatStreamDelta('partial'),
      const ChatStreamFailed(
        ChatError(type: ChatErrorType.network, message: 'network failed'),
      ),
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

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.state, MessageState.failed);
    expect(assistant.fullText, 'partial');
    expect(assistant.parts.last.type, MessagePartType.error);
    expect(assistant.parts.last.text, 'network failed');
  });

  test('loadSession loads existing session', () async {
    final repository = InMemorySessionRepository();
    final document = _document(id: 'session-1', title: 'Existing Chat');
    await repository.saveDocument(document);
    final controller = ChatController(
      repository: repository,
      chatProvider: FakeChatProvider(const []),
    );

    await controller.loadSession('session-1');

    expect(controller.currentDocument!.id, 'session-1');
    expect(controller.currentDocument!.title, 'Existing Chat');
  });

  test('loadSession throws StateError when session is missing', () async {
    final controller = ChatController(
      repository: InMemorySessionRepository(),
      chatProvider: FakeChatProvider(const []),
    );

    expect(
      () => controller.loadSession('missing'),
      throwsA(isA<StateError>()),
    );
  });

  test('stopGeneration marks current streaming assistant cancelled', () async {
    final repository = InMemorySessionRepository();
    final events = StreamController<ChatStreamEvent>();
    final controller = ChatController(
      repository: repository,
      chatProvider: ControlledChatProvider(events.stream),
    );

    await controller.createSession(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      title: 'New Chat',
    );
    final sendFuture =
        controller.sendMessage(text: 'hi', attachments: const []);
    await pumpEventQueue();

    await controller.stopGeneration();
    await sendFuture;

    final assistant = controller.currentDocument!.messages.last;
    expect(assistant.state, MessageState.cancelled);
    await events.close();
  });

  group('SessionListController', () {
    test('load reads repository metas', () async {
      final repository = InMemorySessionRepository();
      await repository.saveDocument(_document(id: 'session-1'));
      final controller = SessionListController(repository: repository);

      await controller.load();

      expect(controller.sessions.single.id, 'session-1');
    });

    test('renameSession updates the document title and reloads metas',
        () async {
      final repository = InMemorySessionRepository();
      await repository.saveDocument(_document(id: 'session-1', title: 'Old'));
      final controller = SessionListController(repository: repository);

      await controller.renameSession('session-1', 'New');

      expect((await repository.loadDocument('session-1'))!.title, 'New');
      expect(controller.sessions.single.title, 'New');
    });

    test('deleteSession removes the session and reloads metas', () async {
      final repository = InMemorySessionRepository();
      await repository.saveDocument(_document(id: 'session-1'));
      final controller = SessionListController(repository: repository);

      await controller.deleteSession('session-1');

      expect(await repository.loadDocument('session-1'), isNull);
      expect(controller.sessions, isEmpty);
    });
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
  Future<ConnectionTestResult> testConnection(
    ConnectionTestRequest request,
  ) async {
    return const ConnectionTestResult.success();
  }
}

class ControlledChatProvider implements ChatProvider {
  const ControlledChatProvider(this.events);

  final Stream<ChatStreamEvent> events;

  @override
  Stream<ChatStreamEvent> sendStream(ChatRequest request) => events;

  @override
  Future<ConnectionTestResult> testConnection(
    ConnectionTestRequest request,
  ) async {
    return const ConnectionTestResult.success();
  }
}

ChatSessionDocument _document({
  required String id,
  String title = 'Title',
}) {
  final now = DateTime.utc(2026, 5, 30);
  return ChatSessionDocument(
    id: id,
    title: title,
    providerId: 'provider-1',
    modelId: 'gpt-4o-mini',
    systemPrompt: '',
    messages: [
      ChatMessage(
        id: 'message-1',
        role: ChatRole.user,
        state: MessageState.completed,
        parts: const [MessagePart.text('hello')],
        createdAt: now,
        updatedAt: now,
      ),
    ],
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  );
}
