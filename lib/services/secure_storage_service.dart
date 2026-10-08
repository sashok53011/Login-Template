import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants.dart';

/// Persists the session (token + user data) in platform secure storage.
class SecureStorageService {
  SecureStorageService();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveToken(String token) =>
      _storage.write(key: AppConstants.authTokenKey, value: token);

  Future<String?> getToken() =>
      _storage.read(key: AppConstants.authTokenKey);

  Future<void> saveUserData({
    required String userId,
    required String username,
    required String email,
  }) async {
    await _storage.write(key: AppConstants.userIdKey, value: userId);
    await _storage.write(key: AppConstants.usernameKey, value: username);
    await _storage.write(key: AppConstants.emailKey, value: email);
  }

  Future<Map<String, String?>> getUserData() async {
    return <String, String?>{
      'userId': await _storage.read(key: AppConstants.userIdKey),
      'username': await _storage.read(key: AppConstants.usernameKey),
      'email': await _storage.read(key: AppConstants.emailKey),
    };
  }

  Future<void> clearAll() => _storage.deleteAll();
}
