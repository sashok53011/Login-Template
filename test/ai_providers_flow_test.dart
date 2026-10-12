import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/main.dart';
import 'package:login_app/providers/auth_provider.dart';
import 'package:login_app/services/api_client.dart';
import 'package:login_app/services/secure_storage_service.dart';

/// In-memory replacement for flutter_secure_storage (no platform channel
/// exists inside a test).
class FakeStorage extends SecureStorageService {
  String? token;
  Map<String, String?> data = <String, String?>{};
  final Map<String, String> apiKeys = <String, String>{};

  @override
  Future<void> saveToken(String value) async => token = value;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> saveUserData({
    required String userId,
    String? username,
    String? email,
  }) async {
    data = <String, String?>{
      'userId': userId,
      'username': username,
      'email': email,
    };
  }

  @override
  Future<Map<String, String?>> getUserData() async => data;

  @override
  Future<void> clearAll() async {
    token = null;
    data = <String, String?>{};
  }

  @override
  Future<String?> readApiKey({
    required String userId,
    required String providerId,
  }) async =>
      apiKeys['$userId/$providerId'];

  @override
  Future<void> writeApiKey({
    required String userId,
    required String providerId,
    required String apiKey,
  }) async {
    apiKeys['$userId/$providerId'] = apiKey;
  }

  @override
  Future<void> deleteApiKey({
    required String userId,
    required String providerId,
  }) async {
    apiKeys.remove('$userId/$providerId');
  }
}

/// PocketBase double covering login plus the `ai_providers` collection.
class FakeAiBackend implements HttpClientAdapter {
  FakeAiBackend(List<Map<String, dynamic>> seed) {
    for (final item in seed) {
      store[item['id'] as String] = Map<String, dynamic>.from(item);
    }
  }

  static const String userId = 'id1234567890123';
  static const String collection = 'ai_providers';

  final Map<String, Map<String, dynamic>> store = <String, Map<String, dynamic>>{};
  final List<String> calls = <String>[];

  static ResponseBody _json(int status, Object? body) {
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  static Future<Map<String, dynamic>> _readBody(Stream<Uint8List>? stream) async {
    if (stream == null) return <String, dynamic>{};
    final chunks = await stream.toList();
    final bytes = chunks.expand((Uint8List e) => e).toList();
    if (bytes.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final method = options.method.toUpperCase();
    final path = options.uri.path;
    final body = await _readBody(requestStream);
    calls.add('$method $path');

    if (path.endsWith('/auth-with-password')) {
      return _json(200, <String, dynamic>{
        'token': 'test-token',
        'record': <String, dynamic>{
          'id': userId,
          'name': 'sashok',
          'email': body['identity'],
          'verified': false,
        },
      });
    }

    if (!path.contains('/collections/$collection/')) {
      return _json(404, <String, dynamic>{'message': 'not found'});
    }

    if (method == 'GET') {
      final items = store.values.toList();
      return _json(200, <String, dynamic>{
        'items': items,
        'page': 1,
        'perPage': 200,
        'totalItems': items.length,
        'totalPages': 1,
      });
    }

    if (method == 'POST') {
      final id = 'new${store.length + 1}';
      final record = <String, dynamic>{...body, 'id': id};
      if (body.containsKey('api_key')) {
        // The field is not part of the schema; it must never reach the server.
        return _json(400, <String, dynamic>{'message': 'unknown field api_key'});
      }
      store[id] = record;
      return _json(200, record);
    }

    final id = path.split('/').last;

    if (method == 'PATCH') {
      if (body.containsKey('userId')) {
        return _json(400, <String, dynamic>{'message': 'unknown field userId'});
      }
      final record = <String, dynamic>{...?store[id], ...body, 'id': id};
      store[id] = record;
      return _json(200, record);
    }

    if (method == 'DELETE') {
      store.remove(id);
      return _json(204, null);
    }

    return _json(404, <String, dynamic>{'message': 'not found'});
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _provider(
  String id,
  String name,
  int priority, {
  bool enabled = false,
}) {
  return <String, dynamic>{
    'id': id,
    'user': FakeAiBackend.userId,
    'name': name,
    'enabled': enabled,
    'url': 'https://api.$id.example/v1',
    'model': '$id-model',
    'fallbackPriority': priority,
    'loginUrl': 'https://$id.example/login',
    'getApiKeyUrl': 'https://$id.example/keys',
    'isPredefined': false,
  };
}

/// Logs in through the real UI and opens the AI providers screen.
Future<void> openProviders(
  WidgetTester tester,
  FakeAiBackend backend,
  FakeStorage storage,
) async {
  final api = ApiClient()..dio.httpClientAdapter = backend;
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        apiClientProvider.overrideWithValue(api),
        secureStorageProvider.overrideWithValue(storage),
      ],
      child: const LoginApp(),
    ),
  );
  await tester.pumpAndSettle();

  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'user@example.com');
  await tester.enterText(fields.at(1), 'correct-horse');
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Перейти в профиль'));
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(FilledButton, 'AI-провайдеры'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home links to the AI providers list', (WidgetTester tester) async {
    final backend = FakeAiBackend(<Map<String, dynamic>>[
      _provider('p1', 'OpenAI', 1, enabled: true),
      _provider('p2', 'Groq', 2),
    ]);

    await openProviders(tester, backend, FakeStorage());

    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Groq'), findsOneWidget);
  });

  testWidgets('providers render with a switch, links and actions',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(<Map<String, dynamic>>[
      _provider('p1', 'OpenAI', 1, enabled: true),
      _provider('p2', 'Groq', 2),
    ]);

    await openProviders(tester, backend, FakeStorage());

    // Sorted by fallbackPriority.
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.byType(Switch), findsNWidgets(2));
    expect(find.text('Приоритет: 1'), findsOneWidget);
    expect(find.text('Добавить провайдера'), findsOneWidget);
    expect(find.text('Редактировать'), findsNWidgets(2));
    expect(find.text('Страница логина'), findsNWidgets(2));
    expect(find.text('Получить API-ключ'), findsNWidgets(2));
    // The API key is never printed, the card only shows a mask.
    expect(find.text('••••••••'), findsNothing);
    expect(find.text('(не задан)'), findsNWidgets(2));
  });

  testWidgets('toggling the switch patches the record',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(<Map<String, dynamic>>[
      _provider('p1', 'OpenAI', 1),
    ]);

    await openProviders(tester, backend, FakeStorage());

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(
      backend.calls,
      contains('PATCH /api/collections/ai_providers/records/p1'),
    );
    expect(backend.store['p1']!['enabled'], true);
  });

  testWidgets('deleting asks for confirmation and removes the provider',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(<Map<String, dynamic>>[
      _provider('p1', 'OpenAI', 1),
      _provider('p2', 'Groq', 2),
    ]);

    await openProviders(tester, backend, FakeStorage());

    await tester.tap(find.widgetWithText(TextButton, 'Удалить').first);
    await tester.pumpAndSettle();

    expect(find.text('Удалить провайдера?'), findsOneWidget);
    expect(find.text('Будет удалён: OpenAI'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();

    expect(
      backend.calls,
      contains('DELETE /api/collections/ai_providers/records/p1'),
    );
    expect(find.text('OpenAI'), findsNothing);
    expect(find.text('Groq'), findsOneWidget);
  });

  testWidgets('adding a provider sends it without the API key',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(<Map<String, dynamic>>[
      _provider('p1', 'OpenAI', 1),
    ]);
    final storage = FakeStorage();

    await openProviders(tester, backend, storage);

    await tester.tap(find.text('Добавить провайдера'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Мой провайдер');
    await tester.enterText(fields.at(1), 'https://mine.example/v1');
    await tester.enterText(fields.at(2), 'mine-model');
    await tester.enterText(fields.at(3), 'super-secret');
    await tester.enterText(fields.at(4), '3');
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Сохранить');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      backend.calls,
      contains('POST /api/collections/ai_providers/records'),
    );
    expect(find.text('Мой провайдер'), findsOneWidget);

    // The secret stays on the device, never in PocketBase.
    expect(
      backend.store.values.any((Map<String, dynamic> r) =>
          r.containsKey('api_key') || r.containsKey('apiKey')),
      isFalse,
    );
    expect(storage.apiKeys.values, contains('super-secret'));
  });

  testWidgets('editing keeps the stored API key masked',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(<Map<String, dynamic>>[
      _provider('p1', 'OpenAI', 1),
    ]);
    final storage = FakeStorage()
      ..apiKeys['${FakeAiBackend.userId}/p1'] = 'stored-key';

    await openProviders(tester, backend, storage);

    await tester.tap(find.widgetWithText(TextButton, 'Редактировать').first);
    await tester.pumpAndSettle();

    expect(find.text('Редактировать провайдера'), findsOneWidget);

    final save = find.widgetWithText(FilledButton, 'Сохранить');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      backend.calls,
      contains('PATCH /api/collections/ai_providers/records/p1'),
    );
    // Saving without touching the key must not send it to the server.
    expect(backend.store['p1']!.containsKey('api_key'), isFalse);
    expect(storage.apiKeys['${FakeAiBackend.userId}/p1'], 'stored-key');
  });
}
