import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyStore {
  SecureKeyStore(this._storage);

  final FlutterSecureStorage _storage;

  String _keyForProvider(String providerId) => 'provider_api_key_$providerId';

  Future<void> writeProviderKey(String providerId, String apiKey) {
    return _storage.write(key: _keyForProvider(providerId), value: apiKey);
  }

  Future<String?> readProviderKey(String providerId) {
    return _storage.read(key: _keyForProvider(providerId));
  }

  Future<void> deleteProviderKey(String providerId) {
    return _storage.delete(key: _keyForProvider(providerId));
  }
}
