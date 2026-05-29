import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';

void main() {
  test('seed models include openai and claude vision-capable models', () {
    final models = seedModelConfigs();

    expect(
      models.any((model) =>
          model.protocol == ProviderProtocol.openai && model.supportsImages),
      isTrue,
    );
    expect(
      models.any((model) =>
          model.protocol == ProviderProtocol.claude && model.supportsImages),
      isTrue,
    );
  });
}
