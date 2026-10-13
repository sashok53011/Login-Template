import 'package:dio/dio.dart';

import '../models/ai_provider.dart';

/// Outcome of a provider test: the key was accepted and the provider listed
/// its models.
class ProviderTestResult {
  const ProviderTestResult({
    required this.ok,
    this.models = const <String>[],
    this.endpoint = '',
    this.error,
    this.status,
  });

  final bool ok;

  /// Model ids the provider reported.
  final List<String> models;

  /// The URL that was called, shown in the UI on failure.
  final String endpoint;

  /// `err.*` key of the failure, or null when [ok].
  final String? error;

  /// HTTP status behind the failure, when there was an answer.
  final int? status;

  /// Whether the model configured for the provider is among the offered ones.
  bool offersModel(String? model) {
    if (model == null || model.isEmpty || models.isEmpty) return false;
    final wanted = model.toLowerCase();
    for (final candidate in models) {
      if (candidate.toLowerCase() == wanted) return true;
    }
    // Providers often prefix or namespace model ids.
    for (final candidate in models) {
      final lower = candidate.toLowerCase();
      if (lower.endsWith('/$wanted') || lower.endsWith(':$wanted')) {
        return true;
      }
    }
    return false;
  }
}

/// Asks a provider for its model list, which doubles as the API key check.
///
/// Almost every provider on the catalogue speaks the OpenAI compatible
/// `GET <base>/models`; Anthropic has its own path and auth header, so it is
/// special-cased.
class ProviderTestService {
  ProviderTestService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: <String, String>{'Accept': 'application/json'},
              ),
            );

  final Dio _dio;

  Future<ProviderTestResult> fetchModels({
    required AiProvider provider,
    required String apiKey,
  }) async {
    final isAnthropic = provider.url.contains('anthropic.com');
    final endpoint = _endpoint(provider.url, isAnthropic: isAnthropic);

    final headers = <String, String>{};
    if (isAnthropic) {
      headers['x-api-key'] = apiKey;
      headers['anthropic-version'] = '2023-06-01';
    } else {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    try {
      final response = await _dio.get<dynamic>(endpoint, options: Options(headers: headers));
      final models = _extractModels(response.data);

      if (models.isEmpty) {
        return ProviderTestResult(
          ok: false,
          endpoint: endpoint,
          error: 'err.providerEmptyModels',
        );
      }

      return ProviderTestResult(
        ok: true,
        models: models,
        endpoint: endpoint,
      );
    } on DioException catch (e) {
      return ProviderTestResult(
        ok: false,
        endpoint: endpoint,
        error: _readError(e),
        status: e.response?.statusCode,
      );
    }
  }

  String _endpoint(String baseUrl, {required bool isAnthropic}) {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (isAnthropic && !url.contains('/v1')) {
      url = '$url/v1';
    }
    return '$url/models';
  }

  List<String> _extractModels(dynamic data) {
    final result = <String>[];

    void collect(dynamic list, String key) {
      if (list is! List) return;
      for (final item in list) {
        if (item is Map) {
          final id = item[key] ?? item['id'] ?? item['name'];
          if (id != null && id.toString().trim().isNotEmpty) {
            result.add(id.toString());
          }
        } else if (item is String && item.trim().isNotEmpty) {
          result.add(item);
        }
      }
    }

    if (data is Map) {
      collect(data['data'], 'id');
      if (result.isEmpty) collect(data['models'], 'name');
      if (result.isEmpty) collect(data['models'], 'id');
    }

    result.sort();
    return result;
  }

  String _readError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'err.providerTimeout';
      case DioExceptionType.connectionError:
        return 'err.providerNoConnection';
      case DioExceptionType.badCertificate:
        return 'err.providerBadCert';
      case DioExceptionType.cancel:
        return 'err.providerCancelled';
      default:
        break;
    }

    final status = e.response?.statusCode;
    switch (status) {
      case 401:
      case 403:
        return 'err.badApiKey';
      case 404:
        return 'err.noModelsEndpoint';
      case 429:
        return 'err.rateLimited';
      case null:
        return 'err.providerUnreachable';
      default:
        return 'err.providerStatus';
    }
  }
}
