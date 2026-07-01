import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiKeyStore {
  static const _key = 'openrouter_api_key';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String value) =>
      _storage.write(key: _key, value: value.trim());

  Future<void> clear() => _storage.delete(key: _key);
}
