import 'package:dio/dio.dart';

import '../models/ai_config.dart';
import '../models/ai_provider.dart';
import 'api_client.dart';

/// Reads and writes the shared provider catalogue kept by the server.
///
///   GET /api/ai-config   -> the catalogue (plus this user's flags)
///   PUT /api/ai-config   -> stores the flags, and for a regular user creates
///                           the entries that are new as their own proposals
///
/// The same data backs the web page at
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
      case DioExceptionType.badCertificate:
        return 'Проблема с сертификатом сервера.';
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
