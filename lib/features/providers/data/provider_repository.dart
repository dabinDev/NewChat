import 'dart:convert';

import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/core/storage/app_database.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';
import 'package:sqflite/sqflite.dart';

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

bool isSeedModel(String modelId) {
  return seedModelConfigs().any((model) => model.id == modelId);
}

abstract interface class ProviderRepository {
  Future<List<ProviderConfig>> listProviders();
  Future<List<ModelConfig>> listModels();
  Future<void> saveProvider(ProviderConfig provider);
  Future<void> deleteProvider(String providerId);
  Future<void> saveModel(ModelConfig model);
  Future<void> deleteModel(String modelId);
}

class InMemoryProviderRepository implements ProviderRepository {
  InMemoryProviderRepository({
    List<ProviderConfig> providers = const [],
    List<ModelConfig>? models,
  })  : _providers = {
          for (final provider in providers) provider.id: provider,
        },
        _models = {
          for (final model in models ?? seedModelConfigs()) model.id: model,
        };

  final Map<String, ProviderConfig> _providers;
  final Map<String, ModelConfig> _models;

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
    _models[model.id] = model;
  }

  @override
  Future<void> saveProvider(ProviderConfig provider) async {
    _providers[provider.id] = provider;
  }
}

class PersistentProviderRepository implements ProviderRepository {
  PersistentProviderRepository(this._appDatabase);

  static const _providerConfigsKey = 'provider_configs';
  static const _modelConfigsKey = 'model_configs';

  final AppDatabase _appDatabase;

  @override
  Future<void> deleteModel(String modelId) async {
    final models = {
      for (final model in await _readSavedModels()) model.id: model,
    };
    models.remove(modelId);
    await _writeModels(models.values.toList());
  }

  @override
  Future<void> deleteProvider(String providerId) async {
    final providers = {
      for (final provider in await listProviders()) provider.id: provider,
    };
    providers.remove(providerId);
    await _writeProviders(providers.values.toList());
  }

  @override
  Future<List<ModelConfig>> listModels() async {
    final models = {
      for (final model in seedModelConfigs()) model.id: model,
      for (final model in await _readSavedModels()) model.id: model,
    }.values.toList();
    return models..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  @override
  Future<List<ProviderConfig>> listProviders() async {
    final providers = (await _readProviders()).toList();
    return providers..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> saveModel(ModelConfig model) async {
    final models = {
      for (final model in await _readSavedModels()) model.id: model,
    };
    models[model.id] = model;
    await _writeModels(models.values.toList());
  }

  @override
  Future<void> saveProvider(ProviderConfig provider) async {
    final providers = {
      for (final provider in await listProviders()) provider.id: provider,
    };
    providers[provider.id] = provider;
    await _writeProviders(providers.values.toList());
  }

  Future<List<ProviderConfig>> _readProviders() async {
    final value = await _readKv(_providerConfigsKey);
    if (value == null) {
      return const [];
    }
    final decoded = jsonDecode(value) as List<Object?>;
    return decoded
        .cast<Map<String, Object?>>()
        .map(ProviderConfig.fromJson)
        .toList();
  }

  Future<List<ModelConfig>> _readSavedModels() async {
    final value = await _readKv(_modelConfigsKey);
    if (value == null) {
      return const [];
    }
    final decoded = jsonDecode(value) as List<Object?>;
    return decoded
        .cast<Map<String, Object?>>()
        .map(ModelConfig.fromJson)
        .toList();
  }

  Future<String?> _readKv(String key) async {
    final database = await _appDatabase.open();
    final rows = await database.query(
      'app_kv',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.single['value']! as String;
  }

  Future<void> _writeProviders(List<ProviderConfig> providers) async {
    await _writeKv(
      _providerConfigsKey,
      jsonEncode(providers.map((provider) => provider.toJson()).toList()),
    );
  }

  Future<void> _writeModels(List<ModelConfig> models) async {
    await _writeKv(
      _modelConfigsKey,
      jsonEncode(models.map((model) => model.toJson()).toList()),
    );
  }

  Future<void> _writeKv(String key, String value) async {
    final database = await _appDatabase.open();
    await database.insert(
      'app_kv',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
