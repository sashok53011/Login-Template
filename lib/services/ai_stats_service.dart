import 'package:dio/dio.dart';

import '../models/ai_stats.dart';
import 'api_client.dart';

/// Reads and writes the provider test statistics kept by the server.
///
///   GET  /api/ai-stats   -> every provider that has data
///   POST /api/ai-stats   -> records one test result
///
/// The server refuses a report for a provider the administrator marked as
/// `dead`, so a blocked provider cannot be tested by accident either.
class AiStatsService {
  AiStatsService(this._api);

  final ApiClient _api;

  static const String _path = '/api/ai-stats';

  Future<Map<String, ProviderStats>> fetchAll() async {
    try {
      final response = await _api.dio.get<dynamic>(_path);
      return _parse(response.data);
    } on DioException catch (e) {
      throw Exception(_readError(e, 'err.statsLoad'));
    }
  }

  Future<ProviderStats> report({
    required String providerId,
    required String model,
    required bool ok,
    String? error,
  }) async {
    try {
      final response = await _api.dio.post<dynamic>(
        _path,
        data: <String, dynamic>{
          'providerId': providerId,
          'model': model,
          'ok': ok,
          if (error != null && error.isNotEmpty) 'error': error,
        },
      );
      final data = response.data;
      if (data is Map) {
        return ProviderStats.fromJson(
          providerId,
          data.cast<String, dynamic>(),
        );
      }
      return ProviderStats(providerId: providerId);
    } on DioException catch (e) {
      throw Exception(_readError(e, 'err.statsSave'));
    }
  }

  Map<String, ProviderStats> _parse(dynamic data) {
    final result = <String, ProviderStats>{};
    if (data is Map) {
      data.forEach((dynamic key, dynamic value) {
        if (value is Map) {
          result[key.toString()] =
              ProviderStats.fromJson(key.toString(), value.cast<String, dynamic>());
        }
      });
    }
    return result;
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

    final status = e.response?.statusCode;
    if (status == 401) {
      return 'err.sessionExpired';
    }

    final data = e.response?.data;
    if (data is Map) {
      final message = (data['message'] ?? data['error'])?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    return fallback;
  }
}
