import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/providers/application/provider_controller.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';
import 'package:newchat/features/providers/presentation/model_manager_screen.dart';

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
        child: const MaterialApp(home: ModelManagerScreen()),
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
