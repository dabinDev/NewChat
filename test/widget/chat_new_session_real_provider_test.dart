import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/chat/application/chat_controller.dart';
import 'package:newchat/features/chat/data/session_repository.dart';
import 'package:newchat/features/chat/domain/chat_models.dart';
import 'package:newchat/features/chat/domain/chat_provider.dart';
import 'package:newchat/features/chat/presentation/chat_screen.dart';
import 'package:newchat/features/providers/application/provider_controller.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('new chat initializes app bar from saved provider',
      (tester) async {
    final sessionRepository = InMemorySessionRepository();
    final chatProvider = _RecordingChatProvider();
    final providerRepository = InMemoryProviderRepository(
      providers: [
        _provider(
          id: 'real-provider',
          defaultModelId: 'real-model',
        ),
      ],
      models: const [
        ModelConfig(
          id: 'real-model',
          displayName: 'Real Model',
          protocol: ProviderProtocol.openai,
          supportsStreaming: true,
          supportsImages: true,
        ),
      ],
    );
    final controller = ChatController(
      repository: sessionRepository,
      chatProvider: chatProvider,
      providerRepository: providerRepository,
    );
    await controller.createSession(
      providerId: 'old-provider',
      modelId: 'old-model',
      title: 'Old session',
    );
    final oldSessionId = controller.currentDocument!.id;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(sessionRepository),
          providerRepositoryProvider.overrideWithValue(providerRepository),
          chatControllerProvider.overrideWithValue(controller),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(sessionId: 'new'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('real-provider / real-model'), findsOneWidget);
    expect(controller.currentDocument!.id, oldSessionId);
  });

  testWidgets('new chat is disabled when no provider exists', (tester) async {
    final controller = ChatController(
      repository: InMemorySessionRepository(),
      chatProvider: _RecordingChatProvider(),
      providerRepository: InMemoryProviderRepository(
        providers: const [],
        models: const [],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerRepositoryProvider.overrideWithValue(
            InMemoryProviderRepository(
              providers: const [],
              models: const [],
            ),
          ),
          chatControllerProvider.overrideWithValue(controller),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(sessionId: 'new'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('provider', findRichText: true), findsWidgets);
    expect(
      tester.widget<TextField>(find.byType(TextField)).enabled,
      isFalse,
    );
  });

  testWidgets('new chat keeps sending in first created provider session',
      (tester) async {
    final sessionRepository = InMemorySessionRepository();
    final chatProvider = _RecordingChatProvider();
    final providerRepository = InMemoryProviderRepository(
      providers: [
        _provider(
          id: 'real-provider',
          defaultModelId: 'real-model',
        ),
      ],
      models: const [
        ModelConfig(
          id: 'real-model',
          displayName: 'Real Model',
          protocol: ProviderProtocol.openai,
          supportsStreaming: true,
          supportsImages: true,
        ),
      ],
    );
    final controller = ChatController(
      repository: sessionRepository,
      chatProvider: chatProvider,
      providerRepository: providerRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(sessionRepository),
          providerRepositoryProvider.overrideWithValue(providerRepository),
          chatControllerProvider.overrideWithValue(controller),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(sessionId: 'new'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _sendText(tester, 'First message');
    await _sendText(tester, 'Second message');

    final sessions = await sessionRepository.listMetas();
    expect(sessions, hasLength(1));

    final document =
        (await sessionRepository.loadDocument(sessions.single.id))!;
    final userMessages = document.messages
        .where((message) => message.role == ChatRole.user)
        .map((message) => message.fullText)
        .toList();
    expect(userMessages, ['First message', 'Second message']);

    expect(chatProvider.requests, hasLength(2));
    expect(_userTexts(chatProvider.requests.first), ['First message']);
    expect(
      _userTexts(chatProvider.requests.last),
      ['First message', 'Second message'],
    );
  });

  testWidgets('sent message appears before streaming response finishes',
      (tester) async {
    final sessionRepository = InMemorySessionRepository();
    final chatProvider = _ControlledChatProvider();
    final providerRepository = InMemoryProviderRepository(
      providers: [
        _provider(
          id: 'real-provider',
          defaultModelId: 'real-model',
        ),
      ],
      models: const [
        ModelConfig(
          id: 'real-model',
          displayName: 'Real Model',
          protocol: ProviderProtocol.openai,
          supportsStreaming: true,
          supportsImages: true,
        ),
      ],
    );
    final controller = ChatController(
      repository: sessionRepository,
      chatProvider: chatProvider,
      providerRepository: providerRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(sessionRepository),
          providerRepositoryProvider.overrideWithValue(providerRepository),
          chatControllerProvider.overrideWithValue(controller),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(sessionId: 'new'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Visible immediately');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();

    expect(find.text('Visible immediately'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    chatProvider.events
      ..add(const ChatStreamDelta('streamed'))
      ..add(const ChatStreamDelta(' answer'))
      ..add(const ChatStreamDone());
    await tester.pumpAndSettle();

    expect(find.text('streamed answer'), findsOneWidget);
  });

  testWidgets('switch model sheet uses real models and persists selection',
      (tester) async {
    final sessionRepository = InMemorySessionRepository();
    final chatProvider = _RecordingChatProvider();
    final providerRepository = InMemoryProviderRepository(
      providers: [
        _provider(
          id: 'real-provider',
          defaultModelId: 'text-only',
        ),
      ],
      models: const [
        ModelConfig(
          id: 'text-only',
          displayName: 'Text Only',
          protocol: ProviderProtocol.openai,
          supportsStreaming: true,
          supportsImages: false,
        ),
        ModelConfig(
          id: 'vision-model',
          displayName: 'Vision Model',
          protocol: ProviderProtocol.openai,
          supportsStreaming: true,
          supportsImages: true,
        ),
      ],
    );
    final controller = ChatController(
      repository: sessionRepository,
      chatProvider: chatProvider,
      providerRepository: providerRepository,
    );
    await controller.createSession(
      providerId: 'real-provider',
      modelId: 'text-only',
      title: 'Existing session',
    );
    final sessionId = controller.currentDocument!.id;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(sessionRepository),
          providerRepositoryProvider.overrideWithValue(providerRepository),
          chatControllerProvider.overrideWithValue(controller),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(sessionId: sessionId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch model'));
    await tester.pumpAndSettle();

    expect(find.text('GPT-4o mini'), findsNothing);
    expect(find.text('Vision Model'), findsOneWidget);

    await tester.tap(find.text('Vision Model'));
    await tester.pumpAndSettle();

    expect(find.text('real-provider / vision-model'), findsOneWidget);
    expect(controller.currentDocument!.modelId, 'vision-model');
    expect(
      (await sessionRepository.loadDocument(sessionId))!.modelId,
      'vision-model',
    );
  });
}

Future<void> _sendText(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_outlined));
  await tester.pumpAndSettle();
}

List<String> _userTexts(ChatRequest request) => request.messages
    .where((message) => message.role == ChatRole.user)
    .map((message) => message.fullText)
    .toList();

class _RecordingChatProvider implements ChatProvider {
  final requests = <ChatRequest>[];

  @override
  Stream<ChatStreamEvent> sendStream(ChatRequest request) async* {
    requests.add(request);
    yield const ChatStreamDone();
  }

  @override
  Future<ConnectionTestResult> testConnection(
    ConnectionTestRequest request,
  ) async {
    return const ConnectionTestResult.success();
  }
}

class _ControlledChatProvider implements ChatProvider {
  final events = StreamController<ChatStreamEvent>();

  @override
  Stream<ChatStreamEvent> sendStream(ChatRequest request) => events.stream;

  @override
  Future<ConnectionTestResult> testConnection(
    ConnectionTestRequest request,
  ) async {
    return const ConnectionTestResult.success();
  }
}

ProviderConfig _provider({
  required String id,
  required String defaultModelId,
}) {
  final now = DateTime.utc(2026, 5, 30);
  return ProviderConfig(
    id: id,
    name: 'Real Provider',
    protocol: ProviderProtocol.openai,
    baseUrl: 'https://api.openai.com',
    defaultModelId: defaultModelId,
    createdAt: now,
    updatedAt: now,
  );
}
