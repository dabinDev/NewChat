import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/core/network/http_client_provider.dart';
import 'package:newchat/core/storage/secure_key_store.dart';
import 'package:newchat/features/chat/domain/chat_provider.dart';
import 'package:newchat/features/providers/application/provider_controller.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';
import 'package:newchat/features/providers/presentation/provider_editor_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  testWidgets(
      'provider editor preserves typed fields across local state changes',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerRepositoryProvider.overrideWithValue(
            _RecordingProviderRepository(
              models: const [
                ModelConfig(
                  id: 'gpt-4o-mini',
                  displayName: 'GPT-4o mini',
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
              ],
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderEditorScreen(),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Provider name'),
      'Personal gateway',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Base URL'),
      'https://gateway.example/v1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'API key'),
      'sk-live-local',
    );

    await tester.tap(find.byTooltip('Show API key'));
    await tester.pump();

    expect(find.text('Personal gateway'), findsOneWidget);
    expect(find.text('https://gateway.example/v1'), findsOneWidget);
    expect(find.text('sk-live-local'), findsOneWidget);

    await tester.tap(find.text('Claude'));
    await tester.pump();

    expect(find.text('Personal gateway'), findsOneWidget);
    expect(find.text('https://api.anthropic.com'), findsOneWidget);
    expect(find.text('sk-live-local'), findsOneWidget);
  });

  testWidgets('test connection does not persist provider or API key',
      (tester) async {
    final repository = _RecordingProviderRepository(
      models: const [
        ModelConfig(
          id: 'gpt-4o-mini',
          displayName: 'GPT-4o mini',
          protocol: ProviderProtocol.openai,
          supportsStreaming: true,
          supportsImages: true,
        ),
      ],
    );
    final keyStore = _RecordingKeyStore();

    await _pumpEditor(
      tester,
      repository: repository,
      keyStore: keyStore,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Provider name'),
      'Unsaved gateway',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'API key'),
      'sk-test-transient',
    );

    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();

    expect(repository.savedProviders, isEmpty);
    expect(keyStore.writtenKeys, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpEditor(
      tester,
      repository: repository,
      keyStore: keyStore,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Provider name'),
      'Unsaved gateway',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'API key'),
      'sk-test-transient',
    );
    await tester.ensureVisible(find.byIcon(Icons.save_outlined));
    await tester.tap(find.byIcon(Icons.save_outlined), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(repository.savedProviders.single.name, 'Unsaved gateway');
    expect(keyStore.writtenKeys.single.value, 'sk-test-transient');
  });

  testWidgets('loads existing provider for edit and preserves id and createdAt',
      (tester) async {
    final createdAt = DateTime.utc(2026, 1, 2);
    final repository = _RecordingProviderRepository(
      providers: [
        ProviderConfig(
          id: 'provider-existing',
          name: 'Existing gateway',
          protocol: ProviderProtocol.claude,
          baseUrl: 'https://api.anthropic.com',
          defaultModelId: 'claude-3-5-sonnet-latest',
          createdAt: createdAt,
          updatedAt: DateTime.utc(2026, 1, 3),
        ),
      ],
      models: const [
        ModelConfig(
          id: 'claude-3-5-sonnet-latest',
          displayName: 'Claude 3.5 Sonnet',
          protocol: ProviderProtocol.claude,
          supportsStreaming: true,
          supportsImages: true,
        ),
      ],
    );
    final keyStore = _RecordingKeyStore({
      'provider-existing': 'sk-stored-existing',
    });

    await _pumpEditor(
      tester,
      repository: repository,
      keyStore: keyStore,
      providerId: 'provider-existing',
    );
    await tester.pumpAndSettle();

    expect(find.text('Existing gateway'), findsOneWidget);
    expect(find.text('https://api.anthropic.com'), findsOneWidget);
    expect(find.text('sk-stored-existing'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Provider name'),
      'Renamed gateway',
    );
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();

    expect(repository.savedProviders, isEmpty);
    expect(keyStore.readProviderIds, contains('provider-existing'));

    await tester.ensureVisible(find.byIcon(Icons.save_outlined));
    await tester.tap(find.byIcon(Icons.save_outlined), warnIfMissed: false);
    await tester.pumpAndSettle();

    final saved = repository.savedProviders.single;
    expect(saved.id, 'provider-existing');
    expect(saved.createdAt, createdAt);
    expect(saved.name, 'Renamed gateway');
    expect(keyStore.writtenKeys, isEmpty);
  });

  testWidgets('custom model appears in provider default model dropdown',
      (tester) async {
    final repository = _RecordingProviderRepository(
      models: const [
        ModelConfig(
          id: 'gpt-4o-mini',
          displayName: 'GPT-4o mini',
          protocol: ProviderProtocol.openai,
          supportsStreaming: true,
          supportsImages: true,
        ),
        ModelConfig(
          id: 'local-model',
          displayName: 'Local Model',
          protocol: ProviderProtocol.openai,
          supportsStreaming: true,
          supportsImages: false,
        ),
      ],
    );

    await _pumpEditor(
      tester,
      repository: repository,
      keyStore: _RecordingKeyStore(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('local-model'), findsOneWidget);
  });

  testWidgets('fetch models button imports models into repository',
      (tester) async {
    final keyStore = _RecordingKeyStore();
    final repository = _RecordingProviderRepository(
      models: const [
        ModelConfig(
          id: 'gpt-4o-mini',
          displayName: 'GPT-4o mini',
          protocol: ProviderProtocol.openai,
          supportsStreaming: true,
          supportsImages: true,
        ),
      ],
    );

    await _pumpEditor(
      tester,
      repository: repository,
      keyStore: keyStore,
      controllerOverride: (ref) => ProviderController(
        repository: repository,
        keyStore: keyStore,
        dio: ref.watch(dioProvider),
        modelFetcher: (_, __) async => const [
          ModelConfig(
            id: 'gpt-4.1-mini',
            displayName: 'gpt-4.1-mini',
            protocol: ProviderProtocol.openai,
            supportsStreaming: true,
            supportsImages: true,
          ),
        ],
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'API key'),
      'sk-fetch-models',
    );

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.sync_outlined));
    await tester.pumpAndSettle();

    expect(repository.savedModels.map((model) => model.id), [
      'gpt-4.1-mini',
    ]);
    expect(find.text('Fetched 1 models.'), findsOneWidget);
  });

  testWidgets('provider editor exposes a back button', (tester) async {
    await _pumpEditor(
      tester,
      repository: _RecordingProviderRepository(),
      keyStore: _RecordingKeyStore(),
    );

    expect(find.byTooltip('Back'), findsOneWidget);
  });
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required _RecordingProviderRepository repository,
  required _RecordingKeyStore keyStore,
  String? providerId,
  ProviderController Function(Ref ref)? controllerOverride,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        providerRepositoryProvider.overrideWithValue(repository),
        secureKeyStoreProvider.overrideWithValue(keyStore),
        providerControllerProvider.overrideWith(
          controllerOverride ??
              (ref) => ProviderController(
                    repository: repository,
                    keyStore: keyStore,
                    dio: ref.watch(dioProvider),
                    openAiProviderFactory: (_, __) =>
                        _SuccessfulConnectionProvider(),
                    claudeProviderFactory: (_, __) =>
                        _SuccessfulConnectionProvider(),
                  ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProviderEditorScreen(providerId: providerId),
      ),
    ),
  );
}

class _RecordingProviderRepository implements ProviderRepository {
  _RecordingProviderRepository({
    List<ProviderConfig> providers = const [],
    List<ModelConfig> models = const [],
  })  : _providers = {for (final provider in providers) provider.id: provider},
        _models = {for (final model in models) model.id: model};

  final Map<String, ProviderConfig> _providers;
  final Map<String, ModelConfig> _models;
  final savedProviders = <ProviderConfig>[];
  final savedModels = <ModelConfig>[];

  @override
  Future<void> deleteModel(String modelId) async {
    _models.remove(modelId);
  }

  @override
  Future<void> deleteProvider(String providerId) async {
    _providers.remove(providerId);
  }

  @override
  Future<List<ModelConfig>> listModels() async {
    return _models.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  @override
  Future<List<ProviderConfig>> listProviders() async {
    return _providers.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> saveModel(ModelConfig model) async {
    savedModels.add(model);
    _models[model.id] = model;
  }

  @override
  Future<void> saveProvider(ProviderConfig provider) async {
    savedProviders.add(provider);
    _providers[provider.id] = provider;
  }
}

class _RecordingKeyStore implements ProviderKeyStore {
  _RecordingKeyStore([Map<String, String>? keys]) : _keys = keys ?? {};

  final Map<String, String> _keys;
  final writtenKeys = <({String providerId, String value})>[];
  final readProviderIds = <String>[];

  @override
  Future<void> deleteProviderKey(String providerId) async {
    _keys.remove(providerId);
  }

  @override
  Future<String?> readProviderKey(String providerId) async {
    readProviderIds.add(providerId);
    return _keys[providerId];
  }

  @override
  Future<void> writeProviderKey(String providerId, String apiKey) async {
    writtenKeys.add((providerId: providerId, value: apiKey));
    _keys[providerId] = apiKey;
  }
}

class _SuccessfulConnectionProvider implements ChatProvider {
  @override
  Stream<ChatStreamEvent> sendStream(ChatRequest request) async* {}

  @override
  Future<ConnectionTestResult> testConnection(
    ConnectionTestRequest request,
  ) async {
    return const ConnectionTestResult.success();
  }
}
