import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/core/storage/app_database.dart';
import 'package:newchat/features/providers/application/provider_controller.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockDatabase extends Mock implements Database {}

void main() {
  test('persistent repository reloads providers and custom models', () async {
    final appDatabase = _MockAppDatabase();
    final database = _MockDatabase();
    final kv = <String, String>{};
    when(appDatabase.open).thenAnswer((_) async => database);
    when(
      () => database.query(
        'app_kv',
        columns: any(named: 'columns'),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      final key = (invocation.namedArguments[#whereArgs] as List<Object?>)
          .single as String;
      final value = kv[key];
      return value == null
          ? <Map<String, Object?>>[]
          : <Map<String, Object?>>[
              {'value': value},
            ];
    });
    when(
      () => database.insert(
        'app_kv',
        any(),
        conflictAlgorithm: any(named: 'conflictAlgorithm'),
      ),
    ).thenAnswer((invocation) async {
      final values = invocation.positionalArguments[1] as Map<String, Object?>;
      kv[values['key']! as String] = values['value']! as String;
      return 1;
    });

    final firstRepository = PersistentProviderRepository(appDatabase);
    final provider = ProviderConfig(
      id: 'local-openai',
      name: 'Local OpenAI',
      protocol: ProviderProtocol.openai,
      baseUrl: 'https://gateway.example/v1',
      defaultModelId: 'local-model',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    const customModel = ModelConfig(
      id: 'local-model',
      displayName: 'Local Model',
      protocol: ProviderProtocol.openai,
      supportsStreaming: false,
      supportsImages: false,
      contextLength: 4096,
    );

    await firstRepository.saveProvider(provider);
    await firstRepository.saveModel(customModel);

    final secondRepository = PersistentProviderRepository(appDatabase);

    final providers = await secondRepository.listProviders();
    final models = await secondRepository.listModels();

    expect(providers, hasLength(1));
    expect(providers.single.id, provider.id);
    expect(providers.single.name, provider.name);
    expect(providers.single.baseUrl, provider.baseUrl);
    expect(
      models.any(
        (model) =>
            model.id == customModel.id &&
            model.displayName == customModel.displayName &&
            model.contextLength == customModel.contextLength,
      ),
      isTrue,
    );
    expect(
      models.where((model) => model.id == customModel.id),
      hasLength(1),
    );
  });

  test('production provider repository is persistent', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(providerRepositoryProvider),
      isA<PersistentProviderRepository>(),
    );
  });

  test('seed models match the default provider contract', () {
    final models = seedModelConfigs();

    expect(models, hasLength(4));
    expect(
      models.map((model) => model.id),
      [
        'gpt-4o-mini',
        'gpt-4o',
        'claude-3-5-sonnet-latest',
        'claude-3-5-haiku-latest',
      ],
    );

    final expectedModels = [
      (
        displayName: 'GPT-4o mini',
        protocol: ProviderProtocol.openai,
      ),
      (
        displayName: 'GPT-4o',
        protocol: ProviderProtocol.openai,
      ),
      (
        displayName: 'Claude 3.5 Sonnet',
        protocol: ProviderProtocol.claude,
      ),
      (
        displayName: 'Claude 3.5 Haiku',
        protocol: ProviderProtocol.claude,
      ),
    ];

    for (final (index, expectedModel) in expectedModels.indexed) {
      final model = models[index];

      expect(model.displayName, expectedModel.displayName);
      expect(model.protocol, expectedModel.protocol);
      expect(model.supportsStreaming, isTrue);
      expect(model.supportsImages, isTrue);
    }
  });
}
