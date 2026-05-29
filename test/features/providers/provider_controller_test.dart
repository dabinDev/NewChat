import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/errors/chat_error.dart';
import 'package:newchat/core/storage/secure_key_store.dart';
import 'package:newchat/features/chat/domain/chat_provider.dart';
import 'package:newchat/features/providers/application/provider_controller.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';
import 'package:newchat/core/constants/app_constants.dart';

void main() {
  test('testConnection routes OpenAI and Claude protocols separately',
      () async {
    final repository = InMemoryProviderRepository(
      providers: [
        _provider(
          id: 'openai-provider',
          protocol: ProviderProtocol.openai,
          modelId: 'gpt-4o-mini',
        ),
        _provider(
          id: 'claude-provider',
          protocol: ProviderProtocol.claude,
          modelId: 'claude-3-5-sonnet-latest',
        ),
      ],
      models: [
        _model('gpt-4o-mini', ProviderProtocol.openai),
        _model('claude-3-5-sonnet-latest', ProviderProtocol.claude),
      ],
    );
    final keyStore = FakeProviderKeyStore({
      'openai-provider': 'sk-openai-secret',
      'claude-provider': 'sk-claude-secret',
    });
    final openAiProvider = RecordingChatProvider();
    final claudeProvider = RecordingChatProvider();
    final controller = ProviderController(
      repository: repository,
      keyStore: keyStore,
      dio: Dio(),
      openAiProviderFactory: (_, __) => openAiProvider,
      claudeProviderFactory: (_, __) => claudeProvider,
    );

    await controller.testConnection(
      providerId: 'openai-provider',
      modelId: 'gpt-4o-mini',
      apiKeyInput: '',
    );
    await controller.testConnection(
      providerId: 'claude-provider',
      modelId: 'claude-3-5-sonnet-latest',
      apiKeyInput: '',
    );

    expect(openAiProvider.testedRequests.single.provider.id, 'openai-provider');
    expect(claudeProvider.testedRequests.single.provider.id, 'claude-provider');
  });

  test('saveProvider preserves existing API key when input is blank', () async {
    final repository = InMemoryProviderRepository(
      providers: [_provider(id: 'provider-1')],
      models: [_model('gpt-4o-mini', ProviderProtocol.openai)],
    );
    final keyStore = FakeProviderKeyStore({'provider-1': 'sk-existing-secret'});
    final controller = ProviderController(
      repository: repository,
      keyStore: keyStore,
      dio: Dio(),
    );

    await controller.saveProvider(
      ProviderConfig(
        id: 'provider-1',
        name: 'Updated',
        protocol: ProviderProtocol.openai,
        baseUrl: 'https://api.openai.com',
        defaultModelId: 'gpt-4o-mini',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
      apiKeyInput: '   ',
    );

    expect(await keyStore.readProviderKey('provider-1'), 'sk-existing-secret');
    expect(keyStore.deletedProviderIds, isEmpty);
  });

  test('saveProvider clears API key only through explicit clear path',
      () async {
    final repository = InMemoryProviderRepository(
      providers: [_provider(id: 'provider-1')],
      models: [_model('gpt-4o-mini', ProviderProtocol.openai)],
    );
    final keyStore = FakeProviderKeyStore({'provider-1': 'sk-existing-secret'});
    final controller = ProviderController(
      repository: repository,
      keyStore: keyStore,
      dio: Dio(),
    );

    await controller.saveProvider(
      _provider(id: 'provider-1'),
      apiKeyInput: '',
      clearApiKey: true,
    );

    expect(await keyStore.readProviderKey('provider-1'), isNull);
    expect(keyStore.deletedProviderIds, ['provider-1']);
  });

  test('testConnection rejects diagnostics that expose API key input',
      () async {
    final repository = InMemoryProviderRepository(
      providers: [_provider(id: 'provider-1')],
      models: [_model('gpt-4o-mini', ProviderProtocol.openai)],
    );
    final keyStore = FakeProviderKeyStore();
    final controller = ProviderController(
      repository: repository,
      keyStore: keyStore,
      dio: Dio(),
    );

    final result = await controller.testConnection(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      apiKeyInput: 'sk-live-secret-value',
    );

    expect(result.message, isNot(contains('sk-live-secret-value')));
  });

  test('testConnection masks API key leaked in provider error message',
      () async {
    const rawKey = 'sk-live-provider-error-secret';
    final repository = InMemoryProviderRepository(
      providers: [_provider(id: 'provider-1')],
      models: [_model('gpt-4o-mini', ProviderProtocol.openai)],
    );
    final keyStore = FakeProviderKeyStore();
    final provider = RecordingChatProvider(
      error: const ChatError(
        type: ChatErrorType.authentication,
        message: 'Authentication failed for sk-live-provider-error-secret',
        statusCode: 401,
      ),
    );
    final controller = ProviderController(
      repository: repository,
      keyStore: keyStore,
      dio: Dio(),
      openAiProviderFactory: (_, __) => provider,
    );

    final result = await controller.testConnection(
      providerId: 'provider-1',
      modelId: 'gpt-4o-mini',
      apiKeyInput: rawKey,
    );

    expect(result.isSuccess, isFalse);
    expect(result.message, isNot(contains(rawKey)));
    expect(result.message, contains('[masked]'));
    expect(result.message, contains('(401)'));
  });
}

class RecordingChatProvider implements ChatProvider {
  RecordingChatProvider({this.error});

  final ChatError? error;
  final testedRequests = <ConnectionTestRequest>[];

  @override
  Stream<ChatStreamEvent> sendStream(ChatRequest request) async* {}

  @override
  Future<ConnectionTestResult> testConnection(
    ConnectionTestRequest request,
  ) async {
    testedRequests.add(request);
    final error = this.error;
    if (error != null) {
      return ConnectionTestResult.failure(error);
    }
    return const ConnectionTestResult.success();
  }
}

class FakeProviderKeyStore implements ProviderKeyStore {
  FakeProviderKeyStore([Map<String, String>? keys]) : _keys = keys ?? {};

  final Map<String, String> _keys;
  final deletedProviderIds = <String>[];

  @override
  Future<void> deleteProviderKey(String providerId) async {
    deletedProviderIds.add(providerId);
    _keys.remove(providerId);
  }

  @override
  Future<String?> readProviderKey(String providerId) async => _keys[providerId];

  @override
  Future<void> writeProviderKey(String providerId, String apiKey) async {
    _keys[providerId] = apiKey;
  }
}

ProviderConfig _provider({
  required String id,
  ProviderProtocol protocol = ProviderProtocol.openai,
  String modelId = 'gpt-4o-mini',
}) {
  final now = DateTime.utc(2026);
  return ProviderConfig(
    id: id,
    name: id,
    protocol: protocol,
    baseUrl: 'https://api.example.com',
    defaultModelId: modelId,
    createdAt: now,
    updatedAt: now,
  );
}

ModelConfig _model(String id, ProviderProtocol protocol) => ModelConfig(
      id: id,
      displayName: id,
      protocol: protocol,
      supportsStreaming: true,
      supportsImages: true,
    );
