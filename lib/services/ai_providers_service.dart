import 'package:dio/dio.dart';

import '../models/ai_provider.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

class AiProvidersService {
  AiProvidersService(this._api, [this._secureStorage]);

  final ApiClient _api;
  final SecureStorageService? _secureStorage;
  static const String _collection = 'ai_providers';

  Future<List<AiProvider>> list({required String userId}) async {
    try {
      final response = await _api.dio.get(
        '/api/collections/$_collection/records',
        queryParameters: <String, dynamic>{
          'filter': 'user="$userId"',
          'sort': '+fallbackPriority,+id',
          'perPage': 200,
        },
      );
      final data = response.data;
      final items = data is Map ? data['items'] : null;
      if (items is List) {
        final result = <AiProvider>[];
        for (final e in items.whereType<Map>()) {
          final map = e.cast<String, dynamic>();
          final provider = AiProvider.fromJson(map);
          final apiKey = await _secureStorage?.readApiKey(
            userId: userId,
            providerId: provider.id,
          );
          result.add(provider.copyWith(apiKey: apiKey));
        }
        return result;
      }
      return const <AiProvider>[];
    } on DioException catch (e) {
      throw Exception(_readError(e, 'Не удалось загрузить AI-провайдеры'));
    }
  }

  Future<AiProvider> create(AiProvider provider) async {
    try {
      final apiKey = provider.apiKey;
      final payload = provider.toJsonForPocketBase();
      if (provider.userId != null && !payload.containsKey('user')) {
        payload['user'] = provider.userId;
      }
      final response = await _api.dio.post(
        '/api/collections/$_collection/records',
        data: payload,
      );
      final created = AiProvider.fromJson(response.data as Map<String, dynamic>);
      if (apiKey != null && apiKey.isNotEmpty && provider.userId != null) {
        await _secureStorage?.writeApiKey(
          userId: provider.userId!,
          providerId: created.id,
          apiKey: apiKey,
        );
      }
      return created.copyWith(apiKey: apiKey);
    } on DioException catch (e) {
      throw Exception(_readError(e, 'Не удалось создать провайдера'));
    }
  }

  Future<AiProvider> update(String id, Map<String, dynamic> changes) async {
    try {
      final userId = changes['userId']?.toString() ?? changes['user']?.toString();
      final apiKey = changes.remove('api_key');
      final nonSecretChanges = Map<String, dynamic>.from(changes);
      nonSecretChanges.remove('apiKey');
      final response = await _api.dio.patch(
        '/api/collections/$_collection/records/$id',
        data: nonSecretChanges.isEmpty && apiKey == null ? <String, dynamic>{} : nonSecretChanges,
      );
      final updated = AiProvider.fromJson(response.data as Map<String, dynamic>);
      if (apiKey is String && apiKey.isNotEmpty && userId != null) {
        await _secureStorage?.writeApiKey(
          userId: userId,
          providerId: id,
          apiKey: apiKey,
        );
      }
      return updated.copyWith(apiKey: apiKey is String ? apiKey : null);
    } on DioException catch (e) {
      throw Exception(_readError(e, 'Не удалось обновить провайдера'));
    }
  }

  Future<void> delete(String id, {String? userId}) async {
    try {
      await _api.dio.delete('/api/collections/$_collection/records/$id');
      if (userId != null) {
        await _secureStorage?.deleteApiKey(userId: userId, providerId: id);
      }
    } on DioException catch (e) {
      throw Exception(_readError(e, 'Не удалось удалить провайдера'));
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
    final data = e.response?.data;
    if (data is Map) {
      final rawMessage = (data['message'] ?? data['error'])?.toString().trim() ?? '';
      final details = _describeDetails(data['data']);
      final message = _localizeMessage(rawMessage);
      if (details.isNotEmpty && message.isNotEmpty) return '$message $details';
      if (details.isNotEmpty) return details;
      if (message.isNotEmpty) return message;
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    final localized = _localizeMessage(e.message?.trim() ?? '');
    if (localized.isEmpty || localized.toLowerCase().contains('http status error')) {
      return fallback;
    }
    return localized;
  }

  String _localizeMessage(String raw) {
    if (raw.isEmpty) return '';
    final m = raw.toLowerCase();
    if (m.contains('failed to authenticate')) {
      return 'Неверный email или пароль.';
    }
    if (m.contains('failed to create record')) {
      return 'Не удалось создать запись.';
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

  String _localizeField(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('already exists') || m.contains('must be unique')) {
      return 'занято';
    }
    if (m.contains('valid url') || m.contains('invalid url')) {
      return 'некорректный URL';
    }
    if (m.contains('valid email')) return 'некорректный email';
    if (m.contains('required')) return 'обязательное поле';
    if (m.contains('too short')) return 'слишком короткое значение';
    if (m.contains('invalid')) return 'недопустимое значение';
    return raw;
  }
}
