import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/ai_provider.dart';

/// Outcome of pulling a model into the memory of a local server.
class ModelLoadResult {
  const ModelLoadResult({required this.ok, this.error});

  final bool ok;

  /// Key to translate (`ai.*` for what the loader itself decided, `err.*` for
  /// the network, or the provider's own message), or null when [ok].
  final String? error;
}

/// Pulls a model into the memory of a local server.
///
/// Ollama answers `POST <base>/api/pull` with a stream of small JSON objects —
/// `{"status":"pulling manifest"}`, then one per downloaded piece with `total`
/// and `completed`, and finally `{"status":"success"}`. A big model takes
/// minutes, so the caller gets progress updates, a cancel token and a time
/// limit; without those the user would be staring at a frozen screen.
class LocalModelLoader {
  LocalModelLoader({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                headers: <String, String>{
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;

  /// Only a local server can load a model by itself — hosted providers get
  /// their models from the vendor and have no such endpoint.
  bool supports(AiProvider provider) => provider.isLocal;

  /// Starts the pull and reports progress until it finishes, is cancelled or
  /// runs out of [timeout].
  ///
  /// [onProgress] receives the share of downloaded bytes (null while the server
  /// has not said anything countable yet) and the server's own status text.
  Future<ModelLoadResult> pull({
    required AiProvider provider,
    required String model,
    required Duration timeout,
    required void Function(double? fraction, String status) onProgress,
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    // Told apart from the user's own cancel by this flag rather than by the
    // reason attached to the token, which Dio does not hand back consistently.
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      if (!token.isCancelled) token.cancel();
    });

    final buffer = <int>[];

    try {
      final response = await _dio.post<ResponseBody>(
        '${_base(provider.url)}/api/pull',
        data: <String, Object?>{'name': model, 'stream': true},
        cancelToken: token,
        options: Options(responseType: ResponseType.stream),
      );

      final body = response.data;
      if (body == null) {
        return const ModelLoadResult(ok: false, error: 'ai.loadFailed');
      }

      await for (final chunk in body.stream) {
        buffer.addAll(chunk);
        var index = buffer.indexOf(0x0a); // newline
        while (index >= 0) {
          final line = utf8.decode(buffer.sublist(0, index));
          buffer.removeRange(0, index + 1);
          final finished = _handleLine(line, onProgress);
          if (finished != null) return finished;
          index = buffer.indexOf(0x0a);
        }
      }

      // The stream ended without "success": either the server stopped early,
      // or the request was cancelled while the lines were still coming.
      if (token.isCancelled) {
        return ModelLoadResult(
          ok: false,
          error: timedOut ? 'ai.loadTimeout' : 'ai.loadCancelled',
        );
      }
      return const ModelLoadResult(ok: false, error: 'ai.loadFailed');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return ModelLoadResult(
          ok: false,
          error: timedOut ? 'ai.loadTimeout' : 'ai.loadCancelled',
        );
      }
      final status = e.response?.statusCode;
      // Local servers that are not Ollama have no such endpoint.
      if (status == 404 || status == 405) {
        return const ModelLoadResult(ok: false, error: 'ai.loadUnsupported');
      }
      return ModelLoadResult(ok: false, error: _readError(e));
    } finally {
      timer.cancel();
      buffer.clear();
    }
  }

  /// Handles one line of the stream; returns a result once the pull is over.
  ModelLoadResult? _handleLine(
    String line,
    void Function(double? fraction, String status) onProgress,
  ) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) return null;
      data = decoded;
    } catch (_) {
      return null; // noise on the stream is not our business
    }

    final status = (data['status'] ?? '').toString();
    final total = data['total'];
    final completed = data['completed'];
    double? fraction;
    if (total is num && completed is num && total > 0) {
      fraction = (completed / total).clamp(0.0, 1.0).toDouble();
    }
    onProgress(fraction, status);

    if (status == 'success') return const ModelLoadResult(ok: true);

    final error = data['error'];
    if (error != null && error.toString().trim().isNotEmpty) {
      return ModelLoadResult(ok: false, error: error.toString().trim());
    }
    return null;
  }

  /// `<base>/api/pull`, with the trailing slash and the OpenAI style `/v1`
  /// taken off, because Ollama's own API lives at the root.
  static String _base(String url) {
    var value = url.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.endsWith('/v1')) {
      value = value.substring(0, value.length - 3);
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
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
      default:
        break;
    }
    if (e.response?.statusCode == null) return 'err.providerUnreachable';
    return 'err.providerStatus';
  }
}
