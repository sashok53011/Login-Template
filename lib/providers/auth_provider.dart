import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});

/// Immutable auth state.
class AuthState {
  const AuthState({
    this.user,
    this.isLoading = true,
    this.isLoggedIn = false,
    this.error,
    this.displayName = '',
  });

  final User? user;
  final bool isLoading;
  final bool isLoggedIn;
  final String? error;
  final String displayName;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isLoggedIn,
    String? error,
    String? displayName,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      error: error,
      displayName: displayName ?? this.displayName,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._service) : super(const AuthState()) {
    checkAuth();
  }

  final AuthService _service;

  /// Restores the session on app start (auto login).
  Future<void> checkAuth() async {
    try {
      final token = await _service.restoreSession();
      if (token == null) {
        state = state.copyWith(
          isLoading: false,
          isLoggedIn: false,
          displayName: '',
        );
        return;
      }
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        displayName: await _service.getDisplayName(),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: false,
        displayName: '',
      );
    }
  }

  Future<User> register({
    required String email,
    required String username,
    required String password,
    required String passwordConfirm,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _service.register(
        email: email,
        username: username,
        password: password,
        passwordConfirm: passwordConfirm,
      );
      state = state.copyWith(isLoading: false);
      return user;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<User> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _service.login(email: email, password: password);
      state = state.copyWith(
        user: user,
        isLoading: false,
        isLoggedIn: true,
        displayName: user.displayName,
      );
      return user;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    await _service.logout();
    state = const AuthState(
      isLoading: false,
      isLoggedIn: false,
      displayName: '',
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authServiceProvider)),
);
