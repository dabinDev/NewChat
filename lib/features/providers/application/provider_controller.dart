import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:newchat/core/constants/app_constants.dart';
import 'package:newchat/core/errors/chat_error.dart';
import 'package:newchat/core/network/http_client_provider.dart';
import 'package:newchat/core/security/secret_masker.dart';
import 'package:newchat/core/storage/app_database.dart';
import 'package:newchat/core/storage/secure_key_store.dart';
import 'package:newchat/features/chat/domain/chat_provider.dart';
import 'package:newchat/features/providers/data/claude_provider.dart';
import 'package:newchat/features/providers/data/openai_provider.dart';
import 'package:newchat/features/providers/data/provider_repository.dart';
import 'package:newchat/features/providers/domain/provider_models.dart';

typedef ChatProviderFactory = ChatProvider Function(
  Dio dio,
  Future<String?> Function(String providerId) readApiKey,
);

final providerRepositoryProvider = Provider<ProviderRepository>((ref) {
  return PersistentProviderRepository(ref.watch(appDatabaseProvider));
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final secureKeyStoreProvider = Provider<ProviderKeyStore>((ref) {
  return SecureKeyStore(const FlutterSecureStorage());
});

final providerControllerProvider = Provider<ProviderController>((ref) {
  return ProviderController(
    repository: ref.watch(providerRepositoryProvider),
    keyStore: ref.watch(secureKeyStoreProvider),
    dio: ref.watch(dioProvider),
  );
});

final chatProviderProvider = Provider<ChatProvider>((ref) {
  final dio = ref.watch(dioProvider);
  final keyStore = ref.watch(secureKeyStoreProvider);
  return ResolvingChatProvider(
    dio: dio,
    readApiKey: keyStore.readProviderKey,
  );
});

final providerListProvider = FutureProvider<List<ProviderConfig>>((ref) {
  return ref.watch(providerControllerProvider).listProviders();
});

final modelListProvider = FutureProvider<List<ModelConfig>>((ref) {
  return ref.watch(providerControllerProvider).listModels();
});

final selectedLanguageProvider = StateProvider<String>((ref) => 'system');

class ProviderController {
  ProviderController({
    required ProviderRepository repository,
    required ProviderKeyStore keyStore,
    required Dio dio,
    ChatProviderFactory? openAiProviderFactory,
    ChatProviderFactory? claudeProviderFactory,
  })  : _repository = repository,
        _keyStore = keyStore,
        _dio = dio,
        _openAiProviderFactory = openAiProviderFactory ??
            ((dio, readApiKey) => OpenAIProvider(
                  dio: dio,
                  readApiKey: readApiKey,
                )),
        _claudeProviderFactory = claudeProviderFactory ??
            ((dio, readApiKey) => ClaudeProvider(
                  dio: dio,
                  readApiKey: readApiKey,
                ));

  final ProviderRepository _repository;
  final ProviderKeyStore _keyStore;
  final Dio _dio;
  final ChatProviderFactory _openAiProviderFactory;
  final ChatProviderFactory _claudeProviderFactory;

  Future<List<ProviderConfig>> listProviders() => _repository.listProviders();
  Future<List<ModelConfig>> listModels() => _repository.listModels();

  Future<void> saveProvider(
    ProviderConfig provider, {
    required String apiKeyInput,
    bool clearApiKey = false,
  }) async {
    await _repository.saveProvider(provider);
    if (clearApiKey) {
      await _keyStore.deleteProviderKey(provider.id);
      return;
    }

    final trimmedApiKey = apiKeyInput.trim();
    if (trimmedApiKey.isNotEmpty) {
      await _keyStore.writeProviderKey(provider.id, trimmedApiKey);
    }
  }

  Future<void> deleteProvider(String providerId) async {
    await _repository.deleteProvider(providerId);
    await _keyStore.deleteProviderKey(providerId);
  }

  Future<void> saveModel(ModelConfig model) => _repository.saveModel(model);
  Future<void> deleteModel(String modelId) => _repository.deleteModel(modelId);

  Future<ProviderConnectionTestResult> testConnection({
    required String providerId,
    required String modelId,
    required String apiKeyInput,
  }) async {
    try {
      final provider = await _findProvider(providerId);
      final model = await _findModel(modelId);
      final validationError = await _validateConnectionFields(
        provider: provider,
        model: model,
        apiKeyInput: apiKeyInput,
      );
      if (validationError != null) {
        return ProviderConnectionTestResult.failure(validationError);
      }

      final trimmedApiKey = apiKeyInput.trim();
      final readApiKey = (String id) async {
        if (id == provider.id && trimmedApiKey.isNotEmpty) {
          return trimmedApiKey;
        }
        return _keyStore.readProviderKey(id);
      };
      final result = await _chatProviderFor(
        provider.protocol,
        readApiKey,
      ).testConnection(
        ConnectionTestRequest(provider: provider, model: model),
      );

      if (result.isSuccess) {
        return const ProviderConnectionTestResult.success(
          'Connection succeeded.',
        );
      }
      return ProviderConnectionTestResult.failure(
        _safeErrorMessage(result.error!, apiKeyInput),
      );
    } on Object catch (error) {
      return ProviderConnectionTestResult.failure(
        _safeDiagnostic('Connection failed.', apiKeyInput, error),
      );
    }
  }

  Future<ProviderConfig> _findProvider(String providerId) async {
    final providers = await _repository.listProviders();
    return providers.firstWhere(
      (provider) => provider.id == providerId,
      orElse: () => throw StateError('Provider not found.'),
    );
  }

  Future<ModelConfig> _findModel(String modelId) async {
    final models = await _repository.listModels();
    return models.firstWhere(
      (model) => model.id == modelId,
      orElse: () => throw StateError('Model not found.'),
    );
  }

  Future<String?> _validateConnectionFields({
    required ProviderConfig provider,
    required ModelConfig model,
    required String apiKeyInput,
  }) async {
    final baseUrl = Uri.tryParse(provider.baseUrl.trim());
    if (baseUrl == null || !baseUrl.hasScheme || baseUrl.host.isEmpty) {
      return 'Base URL must be a valid absolute URL.';
    }
    if (provider.protocol != model.protocol) {
      return 'Provider and model protocols differ.';
    }
    final key = apiKeyInput.trim().isNotEmpty
        ? apiKeyInput.trim()
        : await _keyStore.readProviderKey(provider.id);
    if (key == null || key.trim().isEmpty) {
      return 'API key is missing.';
    }
    return null;
  }

  ChatProvider _chatProviderFor(
    ProviderProtocol protocol,
    Future<String?> Function(String providerId) readApiKey,
  ) {
    return switch (protocol) {
      ProviderProtocol.openai => _openAiProviderFactory(_dio, readApiKey),
      ProviderProtocol.claude => _claudeProviderFactory(_dio, readApiKey),
    };
  }

  String _safeErrorMessage(ChatError error, String apiKeyInput) {
    final message = _maskKey(error.message, apiKeyInput);
    return error.statusCode == null
        ? message
        : '$message (${error.statusCode})';
  }

  String _safeDiagnostic(String message, String apiKeyInput, Object error) {
    final trimmed = apiKeyInput.trim();
    if (trimmed.isEmpty) {
      return message;
    }
    return '$message API key: ${maskSecret(trimmed)}.';
  }

  String _maskKey(String message, String apiKeyInput) {
    final trimmed = apiKeyInput.trim();
    if (trimmed.isEmpty) {
      return message;
    }
    return message.replaceAll(trimmed, '[masked]');
  }
}

class ProviderConnectionTestResult {
  const ProviderConnectionTestResult.success(this.message) : isSuccess = true;
  const ProviderConnectionTestResult.failure(this.message) : isSuccess = false;

  final bool isSuccess;
  final String message;
}

class ResolvingChatProvider implements ChatProvider {
  ResolvingChatProvider({
    required Dio dio,
    required Future<String?> Function(String providerId) readApiKey,
  })  : _openAiProvider = OpenAIProvider(dio: dio, readApiKey: readApiKey),
        _claudeProvider = ClaudeProvider(dio: dio, readApiKey: readApiKey);

  final ChatProvider _openAiProvider;
  final ChatProvider _claudeProvider;

  @override
  Stream<ChatStreamEvent> sendStream(ChatRequest request) {
    return _providerFor(request.provider.protocol).sendStream(request);
  }

  @override
  Future<ConnectionTestResult> testConnection(ConnectionTestRequest request) {
    return _providerFor(request.provider.protocol).testConnection(request);
  }

  ChatProvider _providerFor(ProviderProtocol protocol) {
    return switch (protocol) {
      ProviderProtocol.openai => _openAiProvider,
      ProviderProtocol.claude => _claudeProvider,
    };
  }
}
