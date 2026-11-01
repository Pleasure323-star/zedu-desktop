import 'package:zedu/core/core.dart';

class SecureStorageService {
  SecureStorageService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';

  /// Token kept for this run only, never written to disk.
  String? _sessionToken;

  /// With [persist] false ("Remember me" unticked) the token lives in memory
  /// only, so the next launch starts signed out.
  Future<void> saveAccessToken(String token, {bool persist = true}) async {
    if (persist) {
      _sessionToken = null;
      await _storage.write(key: _accessTokenKey, value: token);
    } else {
      _sessionToken = token;
      await _storage.delete(key: _accessTokenKey);
    }
  }

  Future<String?> getAccessToken() async =>
      _sessionToken ?? await _storage.read(key: _accessTokenKey);

  Future<void> deleteAccessToken() async {
    _sessionToken = null;
    await _storage.delete(key: _accessTokenKey);
  }

  Future<void> writeData(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<String?> readData(String key) => _storage.read(key: key);

  Future<void> deleteValue(String key) => _storage.delete(key: key);

  Future<void> clearAll() async {
    _sessionToken = null;
    await _storage.deleteAll();
  }
}
