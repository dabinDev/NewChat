import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/core/routing/app_routes.dart';
import 'package:newchat/features/providers/application/provider_controller.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';
import 'package:newchat/features/providers/presentation/model_manager_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('model manager saves and deletes through repository',
      (tester) async {
    final repository = _RecordingProviderRepository(
      models: const [
        ModelConfig(
          id: 'existing-model',
          displayName: 'Existing Model',
          protocol: ProviderProtocol.openai,
          supportsStreaming: true,
          supportsImages: false,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ModelManagerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Existing Model'), findsOneWidget);

    await tester.tap(find.text('Add model'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Display name'),
      'Saved Model',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Model ID'),
      'saved-model',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedModels.map((model) => model.id), ['saved-model']);
    expect(find.text('Saved Model'), findsOneWidget);

    await tester.tap(find.byTooltip('Model actions').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(repository.deletedModelIds, ['saved-model']);
  });

  testWidgets('custom model protocol can be selected', (tester) async {
    final repository = _RecordingProviderRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ModelManagerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add model'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claude'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Display name'),
      'Claude Local',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Model ID'),
      'claude-local',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedModels.single.protocol, ProviderProtocol.claude);
  });

  testWidgets('seed models do not expose delete action', (tester) async {
    final repository = _RecordingProviderRepository(
      models: seedModelConfigs(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ModelManagerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Model actions').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('back button falls back to settings when opened directly',
      (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.models,
      routes: [
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Settings target')),
          ),
        ),
        GoRoute(
          path: AppRoutes.models,
          builder: (context, state) => const ModelManagerScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerRepositoryProvider.overrideWithValue(
            _RecordingProviderRepository(),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Settings target'), findsOneWidget);
  });
}

class _RecordingProviderRepository implements ProviderRepository {
  _RecordingProviderRepository({List<ModelConfig> models = const []})
      : _models = {
          for (final model in models) model.id: model,
        };

  final Map<String, ModelConfig> _models;
  final savedModels = <ModelConfig>[];
  final deletedModelIds = <String>[];

  @override
  Future<void> deleteModel(String modelId) async {
    deletedModelIds.add(modelId);
    _models.remove(modelId);
  }

  @override
  Future<void> deleteProvider(String providerId) async {}

  @override
  Future<List<ModelConfig>> listModels() async {
    return _models.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  @override
  Future<List<ProviderConfig>> listProviders() async => const [];

  @override
  Future<void> saveModel(ModelConfig model) async {
    savedModels.add(model);
    _models[model.id] = model;
  }

  @override
  Future<void> saveProvider(ProviderConfig provider) async {}
}
