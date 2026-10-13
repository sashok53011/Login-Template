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
      throw Exception(_readError(e, 'err.registerFailed'));
    }
  }

  /// Checks whether [value] is already taken by an `email` or a `name`.
  ///
  /// Relies on the collection List/Search API rule:
  /// `@request.query.k = 'pb_av_1' && (email = @request.query.q || name = @request.query.q)`
  ///
  /// Returns `true` when the value is occupied. Throws when the server
  /// rejects the request (for example when the rule is not configured yet).
  ///
  /// Transient transport failures are retried once: the check runs on every
  /// keystroke pause and a single tunnel hiccup must not read as "unknown".
  Future<bool> isValueTaken(String value) async {
    final query = value.trim();
    if (query.isEmpty) return false;

    const url = '/api/collections/${AppConfig.usersCollection}/records';
    final params = <String, dynamic>{
      AppConfig.availabilityParam: AppConfig.availabilitySecret,
      AppConfig.availabilityQuery: query,
      'perPage': 1,
    };

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _api.dio.get(url, queryParameters: params);
        final data = response.data;
        final total =
            data is Map ? (data['totalItems'] as num?)?.toInt() : null;
        return (total ?? 0) > 0;
      } on DioException catch (e) {
        final message = _readError(e, 'err.availabilityCheck');
        if (attempt == 0 && _isTransportError(e)) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          continue;
        }
        throw Exception(message);
      }
    }
    return false;
  }

  /// True for failures that are worth repeating (no HTTP answer at all).
  bool _isTransportError(DioException e) {
    return e.response == null ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
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
        throw Exception('err.noToken');
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
      throw Exception(_readError(e, 'err.loginFailed'));
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

  /// Rebuilds the signed-in user from what was stored at login time.
  ///
  /// The token alone is not enough: without the id the per-user screens (AI
  /// providers, statistics) cannot address anything, which is why an auto
  /// login used to come back with an empty provider list.
  Future<User?> restoreUser() async {
    final data = await _storage.getUserData();
    final id = data['userId']?.trim() ?? '';
    if (id.isEmpty) return null;
    return User(
      id: id,
      email: data['email']?.trim() ?? '',
      username: data['username']?.trim() ?? '',
    );
  }

  /// Best effort display name: username > email > id > none.
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
    // Left empty on purpose: the home screen substitutes a translated
    // placeholder, so no Russian literal lives in the service layer.
    return '';
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
    throw UnimplementedError('Google OAuth is not connected yet');
  }

  String _readError(DioException e, String fallback) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'err.noConnection';
      case DioExceptionType.cancel:
        return 'err.cancelled';
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

  /// Maps the English PocketBase/transport messages onto `err.*` keys; the
  /// screens translate them for the user. An unknown message is passed
  /// through unchanged.
  String _localizeMessage(String raw) {
    if (raw.isEmpty) return '';
    final m = raw.toLowerCase();
    if (m.contains('failed to authenticate')) {
      return 'err.authFailed';
    }
    if (m.contains('failed to create record')) {
      return 'err.createFailed';
    }
    if (m.contains('failed to update')) {
      return 'err.updateFailed';
    }
    if (m.contains("wasn't found") || m.contains('not found')) {
      return 'err.notFound';
    }
    if (m.contains('too many requests')) {
      return 'err.tooMany';
    }
    if (m.contains('something went wrong')) {
      return 'err.serverError';
    }
    if (m.contains('token') && m.contains('expired')) {
      return 'err.sessionExpired';
    }
    return raw;
  }

  /// Turns the `data` map of a validation error into readable lines built
  /// from `err.*` keys.
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

  /// Maps the individual PocketBase field messages onto `err.*` keys.
  String _localizeField(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('already exists') || m.contains('must be unique')) {
      return 'err.taken';
    }
    if (m.contains('valid email')) return 'err.invalidEmail';
    if (m.contains('8 or more')) return 'err.min8';
    if (m.contains('do not match') || m.contains('should match')) {
      return 'err.mismatch';
    }
    if (m.contains('required')) return 'err.requiredField';
    if (m.contains('too short')) return 'err.tooShort';
    if (m.contains('invalid')) return 'err.invalidValue';
    return raw;
  }
}
