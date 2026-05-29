import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ProviderKeyStore {
  Future<void> writeProviderKey(String providerId, String apiKey);
  Future<String?> readProviderKey(String providerId);
  Future<void> deleteProviderKey(String providerId);
}

class SecureKeyStore implements ProviderKeyStore {
  SecureKeyStore(this._storage);

  final FlutterSecureStorage _storage;

  String _keyForProvider(String providerId) => 'provider_api_key_$providerId';

  @override
  Future<void> writeProviderKey(String providerId, String apiKey) {
    return _storage.write(key: _keyForProvider(providerId), value: apiKey);
  }

  @override
  Future<String?> readProviderKey(String providerId) {
    return _storage.read(key: _keyForProvider(providerId));
  }

  @override
  Future<void> deleteProviderKey(String providerId) {
    return _storage.delete(key: _keyForProvider(providerId));
  }
}
