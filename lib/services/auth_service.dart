import 'package:dio/dio.dart';

import '../core/config.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

/// Authentication logic: register, login, logout.
///
/// The class exposes a single extension point (`_oauthProviders`) so that
/// Google OAuth / other social providers can be added later without
/// touching the screens.
class AuthService {
  AuthService(this._api, this._storage);

  final ApiClient _api;
  final SecureStorageService _storage;

  /// Register a new user (email + username + password).
  Future<User> register({
    required String email,
    required String username,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      final response = await _api.dio.post(
        '/api/collections/${AppConfig.usersCollection}/records',
        data: <String, dynamic>{
          'email': email.trim(),
          'username': username.trim(),
          'password': password,
          'passwordConfirm': passwordConfirm,
        },
      );
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_readError(e, 'Ошибка регистрации'));
    }
  }

  /// Login with email + password, then persist the session.
  Future<User> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _api.dio.post(
        '/api/collections/${AppConfig.usersCollection}/auth-with-password',
        data: <String, dynamic>{
          'identity': email.trim(),
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['token']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('Сервер не вернул токен авторизации');
      }

      final user = User.fromJson(data['record'] as Map<String, dynamic>);

      await _storage.saveToken(token);
      await _storage.saveUserData(
        userId: user.id,
        username: user.username,
        email: user.email,
      );
      _api.setAuthToken(token);

      return user;
    } on DioException catch (e) {
      throw Exception(_readError(e, 'Ошибка входа'));
    }
  }

  /// Drop the local session.
  Future<void> logout() async {
    _api.clearAuthToken();
    await _storage.clearAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    return token != null && token.isNotEmpty;
  }

  /// Restore the stored token (used on app start for auto login).
  Future<String?> restoreSession() async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) return null;
    _api.setAuthToken(token);
    return token;
  }

  /// Best effort display name: username > email > id > fallback.
  Future<String> getDisplayName() async {
    final data = await _storage.getUserData();
    for (final value in <String?>[
      data['username'],
      data['email'],
      data['userId'],
    ]) {
      final v = value?.trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return 'пользователь';
  }

  // ---------------------------------------------------------------------------
  // Future providers (Google OAuth, Apple, VK, ...).
  //
  // Add new entries here and expose them through [signInWithProvider]; the
  // UI will keep working unchanged.
  // ---------------------------------------------------------------------------
  static const List<String> availableProviders = <String>['password'];

  Future<void> signInWithGoogle() async {
    // TODO: enable Google OAuth in PocketBase Settings > Auth providers,
    // then exchange the provider code for a session here.
    throw UnimplementedError('Google OAuth пока не подключён');
  }

  String _readError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message != null && message.toString().trim().isNotEmpty) {
        final inner = data['data'];
        if (inner is Map && inner.isNotEmpty) {
          return '$message: ${inner.values.join(', ')}';
        }
        return message.toString();
      }
    }
    if (data is String && data.trim().isNotEmpty) return data;
    return e.message ?? fallback;
  }
}
