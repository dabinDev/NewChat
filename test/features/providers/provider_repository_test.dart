import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';

void main() {
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
