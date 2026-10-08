import 'package:dio/dio.dart';

import '../core/config.dart';

/// Thin Dio wrapper around the PocketBase REST API.
class ApiClient {
  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

  final Dio dio;

  /// Attaches the PocketBase auth token to every request.
  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = token;
  }

  void clearAuthToken() {
    dio.options.headers.remove('Authorization');
  }
}
