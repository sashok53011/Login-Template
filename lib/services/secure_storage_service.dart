import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const String _tokenKey = 'token';
  static const String _userIdKey = 'userId';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';

  // Auth
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> saveUserData({
    required String userId,
    String? username,
    String? email,
  }) async {
    await _storage.write(key: _userIdKey, value: userId);
    if (username != null) {
      await _storage.write(key: _usernameKey, value: username);
    }
    if (email != null) {
      await _storage.write(key: _emailKey, value: email);
    }
  }

  Future<Map<String, String?>> getUserData() async {
    final userId = await _storage.read(key: _userIdKey);
    final username = await _storage.read(key: _usernameKey);
    final email = await _storage.read(key: _emailKey);
    return <String, String?>{
      'userId': userId,
      'username': username,
      'email': email,
    };
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _emailKey);
  }

  // API keys for AI providers
  Future<String?> readApiKey({
    required String userId,
    required String providerId,
  }) async {
    final key = _key(userId: userId, providerId: providerId);
    return _storage.read(key: key);
  }

  Future<void> writeApiKey({
    required String userId,
    required String providerId,
    required String apiKey,
  }) async {
    final key = _key(userId: userId, providerId: providerId);
    await _storage.write(key: key, value: apiKey);
  }

  Future<void> deleteApiKey({
    required String userId,
    required String providerId,
  }) async {
    final key = _key(userId: userId, providerId: providerId);
    await _storage.delete(key: key);
  }

  Future<void> deleteAllForUser(String userId) async {
    final keys = await _storage.readAll();
    for (final entry in keys.entries) {
      if (entry.key.contains('ai_provider_${userId}_')) {
        await _storage.delete(key: entry.key);
      }
    }
  }

  String _key({required String userId, required String providerId}) {
    return 'ai_provider_${userId}_$providerId';
  }
}
