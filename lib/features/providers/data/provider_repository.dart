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
