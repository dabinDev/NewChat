import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/chat/application/chat_controller.dart';
import 'package:newchat/features/chat/data/session_repository.dart';
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
}

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
