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
