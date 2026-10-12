import 'package:dio/dio.dart';

import '../models/ai_config.dart';
import '../models/ai_provider.dart';
import 'api_client.dart';

/// Talks to the PocketBase hook that keeps one JSON config file per user.
///
///   GET /api/ai-config   -> AiConfig
///   PUT /api/ai-config   -> AiConfig (what the server stored)
///
/// The same file backs the web page at
/// https://app.devhorizon.online/ai-providers/, so both sides see one list.
/// API keys are never part of the payload.
class AiConfigSyncService {
  AiConfigSyncService(this._api);

  final ApiClient _api;

  static const String _path = '/api/ai-config';

  Future<AiConfig> fetch() async {
    try {
      final response = await _api.dio.get<dynamic>(_path);
      final data = response.data;
      if (data is Map) {
        return AiConfig.fromJson(data.cast<String, dynamic>());
      }
      return const AiConfig();
    } on DioException catch (e) {
      throw Exception(_readError(e, 'Не удалось получить конфиг с сервера'));
    }
  }

  Future<AiConfig> push(List<AiProvider> providers) async {
    try {
      final response = await _api.dio.put<dynamic>(
        _path,
        data: AiConfig(providers: providers).toJson(),
      );
      final data = response.data;
      if (data is Map) {
        return AiConfig.fromJson(data.cast<String, dynamic>());
      }
      return AiConfig(providers: providers);
    } on DioException catch (e) {
      throw Exception(_readError(e, 'Не удалось сохранить конфиг на сервере'));
    }
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

    final status = e.response?.statusCode;
    if (status == 401) {
      return 'Сессия истекла. Войдите заново.';
    }

    final data = e.response?.data;
    if (data is Map) {
      final message = (data['message'] ?? data['error'])?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return fallback;
  }
}
