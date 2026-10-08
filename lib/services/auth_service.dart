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
          // The default PocketBase `users` collection exposes the display
          // name as `name`.
          'name': username.trim(),
          'password': password,
          'passwordConfirm': passwordConfirm,
        },
      );
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_readError(e, 'Ошибка регистрации'));
    }
  }

  /// Checks whether [value] is already taken by an `email` or a `name`.
  ///
  /// Relies on the collection List/Search API rule:
  /// `@request.query.k = 'pb_av_1' && (email = @request.query.q || name = @request.query.q)`
  ///
  /// Returns `true` when the value is occupied. Throws when the server
  /// rejects the request (for example when the rule is not configured yet).
  Future<bool> isValueTaken(String value) async {
    final query = value.trim();
    if (query.isEmpty) return false;

    try {
      final response = await _api.dio.get(
        '/api/collections/${AppConfig.usersCollection}/records',
        queryParameters: <String, dynamic>{
          AppConfig.availabilityKey: AppConfig.availabilityKey,
          AppConfig.availabilityQuery: query,
          'perPage': 1,
        },
      );
      final data = response.data;
      final total = data is Map ? (data['totalItems'] as num?)?.toInt() : null;
      return (total ?? 0) > 0;
    } on DioException catch (e) {
      throw Exception(_readError(e, 'Не удалось проверить доступность'));
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
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'Нет связи с сервером. Проверьте интернет-соединение.';
      case DioExceptionType.cancel:
        return 'Запрос был отменён.';
      default:
        break;
    }

    final data = e.response?.data;
    if (data is Map) {
      final rawMessage =
          (data['message'] ?? data['error'])?.toString().trim() ?? '';
      final details = _describeDetails(data['data']);
      final message = _localizeMessage(rawMessage);

      if (details.isNotEmpty && message.isNotEmpty) return '$message $details';
      if (details.isNotEmpty) return details;
      if (message.isNotEmpty) return message;
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();

    final localized = _localizeMessage(e.message?.trim() ?? '');
    if (localized.isEmpty ||
        localized.toLowerCase().contains('http status error')) {
      return fallback;
    }
    return localized;
  }

  /// PocketBase reports failures in English; the app speaks Russian.
  String _localizeMessage(String raw) {
    if (raw.isEmpty) return '';
    final m = raw.toLowerCase();
    if (m.contains('failed to authenticate')) {
      return 'Неверный email или пароль.';
    }
    if (m.contains('failed to create record')) {
      return 'Не удалось создать аккаунт.';
    }
    if (m.contains('failed to update')) {
      return 'Не удалось обновить данные.';
    }
    if (m.contains("wasn't found") || m.contains('not found')) {
      return 'Запись не найдена.';
    }
    if (m.contains('too many requests')) {
      return 'Слишком много попыток. Повторите позже.';
    }
    if (m.contains('something went wrong')) {
      return 'Сервер вернул ошибку. Повторите позже.';
    }
    if (m.contains('token') && m.contains('expired')) {
      return 'Сессия истекла. Войдите заново.';
    }
    return raw;
  }

  /// Turns the `data` map of a validation error into readable lines.
  String _describeDetails(dynamic data) {
    if (data is! Map || data.isEmpty) return '';
    final parts = <String>[];
    data.forEach((dynamic key, dynamic value) {
      final String text;
      if (value is Map) {
        text = (value['message'] ?? value.values.join(', ')).toString();
      } else {
        text = value.toString();
      }
      parts.add('$key: ${_localizeField(text)}');
    });
    return parts.join('\n');
  }

  /// Translates the individual field messages PocketBase returns.
  String _localizeField(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('already exists') || m.contains('must be unique')) {
      return 'занято';
    }
    if (m.contains('valid email')) return 'некорректный email';
    if (m.contains('8 or more')) return 'минимум 8 символов';
    if (m.contains('do not match') || m.contains('should match')) {
      return 'значения не совпадают';
    }
    if (m.contains('required')) return 'обязательное поле';
    if (m.contains('too short')) return 'слишком короткое значение';
    if (m.contains('invalid')) return 'недопустимое значение';
    return raw;
  }
}
