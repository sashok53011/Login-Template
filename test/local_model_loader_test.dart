import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/ai_provider.dart';
import 'package:login_app/services/local_model_loader.dart';

/// A local server in miniature: it answers POST /api/pull the way Ollama does,
/// line by line, and can be told to fail, to hang or to refuse.
class FakePullServer implements HttpClientAdapter {
  FakePullServer(this.lines);

  /// The NDJSON body to answer with, one JSON object per line.
  final String lines;

  /// Set to answer with a plain HTTP failure instead of a stream.
  int status = 200;

  /// Set to keep the stream open forever, so the time limit has to act.
  bool hangs = false;

  final List<String> requestedPaths = <String>[];

  static const Map<String, List<String>> _headers = <String, List<String>>{
    Headers.contentTypeHeader: <String>['application/x-ndjson'],
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add('${options.method} ${options.uri.path}');

    if (status != 200) {
      return ResponseBody.fromString('{"message":"nope"}', status);
    }

    if (hangs) {
      final controller = StreamController<Uint8List>();
      // Dio tells the adapter that the caller gave up.
      cancelFuture?.then((_) => controller.close());
      return ResponseBody(controller.stream, 200, headers: _headers);
    }

    return ResponseBody.fromString(lines, 200, headers: _headers);
  }

  @override
  void close({bool force = false}) {}
}

AiProvider _local({String url = 'http://localhost:11434/v1'}) {
  return AiProvider(
    id: 'ollama',
    name: 'Ollama',
    enabled: true,
    url: url,
    model: 'llama3.2',
  );
}

LocalModelLoader _loaderWith(FakePullServer server) {
  return LocalModelLoader(dio: Dio()..httpClientAdapter = server);
}

void main() {
  group('AiProvider.isLocal', () {
    test('recognises this device and the local network', () {
      expect(_local(url: 'http://localhost:11434/v1').isLocal, isTrue);
      expect(_local(url: 'http://127.0.0.1:1234/v1').isLocal, isTrue);
      expect(_local(url: 'http://192.168.0.10:1234/v1').isLocal, isTrue);
      expect(_local(url: 'http://10.1.2.3:1234/v1').isLocal, isTrue);
      expect(_local(url: 'http://172.16.0.9:1234/v1').isLocal, isTrue);
    });

    test('leaves everything on the internet alone', () {
      expect(_local(url: 'https://api.openai.com/v1').isLocal, isFalse);
      expect(_local(url: 'http://172.32.0.9:1234/v1').isLocal, isFalse);
      expect(_local(url: 'not a url').isLocal, isFalse);
    });
  });

  group('LocalModelLoader.pull', () {
    test('reads the stream and reports how far it got', () async {
      final server = FakePullServer(
        '{"status":"pulling manifest"}\n'
        '{"status":"downloading","total":100,"completed":50}\n'
        '{"status":"downloading","total":100,"completed":100}\n'
        '{"status":"success"}\n',
      );

      final statuses = <String>[];
      final fractions = <double?>[];
      final result = await _loaderWith(server).pull(
        provider: _local(),
        model: 'llama3.2',
        timeout: const Duration(seconds: 10),
        onProgress: (double? fraction, String status) {
          fractions.add(fraction);
          statuses.add(status);
        },
      );

      expect(result.ok, isTrue);
      expect(result.error, isNull);
      expect(statuses.first, 'pulling manifest');
      expect(statuses.last, 'success');
      // Only the lines carrying counts produce a share; "success" does not.
      expect(fractions.whereType<double>(), <double>[0.5, 1.0]);
      // The OpenAI style suffix is taken off: Ollama's API lives at the root.
      expect(server.requestedPaths.single, 'POST /api/pull');
    });

    test('hands the provider’s own message back untouched', () async {
      final server = FakePullServer('{"error":"model not found"}\n');

      final result = await _loaderWith(server).pull(
        provider: _local(),
        model: 'nope',
        timeout: const Duration(seconds: 5),
        onProgress: (double? fraction, String status) {},
      );

      expect(result.ok, isFalse);
      expect(result.error, 'model not found');
    });

    test('explains a server without a pull endpoint', () async {
      final server = FakePullServer('')..status = 404;

      final result = await _loaderWith(server).pull(
        provider: _local(),
        model: 'llama3.2',
        timeout: const Duration(seconds: 5),
        onProgress: (double? fraction, String status) {},
      );

      expect(result.ok, isFalse);
      expect(result.error, 'ai.loadUnsupported');
    });

    test('gives up when the time limit runs out', () async {
      final server = FakePullServer('')..hangs = true;

      final result = await _loaderWith(server).pull(
        provider: _local(),
        model: 'llama3.2',
        timeout: const Duration(milliseconds: 60),
        onProgress: (double? fraction, String status) {},
      );

      expect(result.ok, isFalse);
      expect(result.error, 'ai.loadTimeout');
    });

    test('stops when the user cancels', () async {
      final server = FakePullServer('')..hangs = true;
      final token = CancelToken();

      final pending = _loaderWith(server).pull(
        provider: _local(),
        model: 'llama3.2',
        timeout: const Duration(seconds: 30),
        cancelToken: token,
        onProgress: (double? fraction, String status) {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      token.cancel();

      final result = await pending;
      expect(result.ok, isFalse);
      expect(result.error, 'ai.loadCancelled');
    });
  });
}
