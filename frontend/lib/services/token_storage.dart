import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the JWT in platform-encrypted storage (Keystore on Android, Keychain
/// on iOS) rather than plain preferences, since the token is a credential.
class TokenStorage {
  static const _tokenKey = 'auth_token';

  const TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _tokenKey);

  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clear() => _storage.delete(key: _tokenKey);
}
