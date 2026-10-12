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

  @override
  Future<void> saveToken(String value) async {
    token = value;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> saveUserData({
    String? userId,
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
}

/// PocketBase double. Behaviour is controlled by [knownEmail] /
/// [knownName] (availability), [loginOk] and [createOk].
class FakeBackend implements HttpClientAdapter {
  FakeBackend({
    this.knownEmail,
    this.knownName,
    this.loginOk = true,
    this.createOk = true,
  });

  final String? knownEmail;
  final String? knownName;
  final bool loginOk;
  final bool createOk;

  final List<String> calls = <String>[];

  static ResponseBody _json(int status, Map<String, dynamic> body) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  static Future<Map<String, dynamic>> _readBody(
    Stream<Uint8List>? stream,
  ) async {
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

    if (method == 'GET') {
      final q = options.uri.queryParameters['q'] ?? '';
      final taken = q.isNotEmpty && (q == knownEmail || q == knownName);
      return _json(200, <String, dynamic>{
        'items': taken ? <dynamic>[<String, dynamic>{}] : <dynamic>[],
        'page': 1,
        'perPage': 1,
        'totalItems': taken ? 1 : 0,
        'totalPages': taken ? 1 : 0,
      });
    }

    if (path.endsWith('/auth-with-password')) {
      if (loginOk && body['password'] == 'correct-horse') {
        return _json(200, <String, dynamic>{
          'token': 'test-token',
          'record': <String, dynamic>{
            'id': 'id1234567890123',
            'name': 'sashok',
            'email': body['identity'],
            'verified': false,
          },
        });
      }
      return _json(400, <String, dynamic>{
        'data': <String, dynamic>{},
        'message': 'Failed to authenticate.',
        'status': 400,
      });
    }

    if (path.endsWith('/records')) {
      if (!createOk) {
        return _json(400, <String, dynamic>{
          'data': <String, dynamic>{
            'email': <String, dynamic>{
              'message': 'value already exists',
              'code': 'validation_exists',
            },
          },
          'message': 'Failed to create record.',
          'status': 400,
        });
      }
      return _json(200, <String, dynamic>{
        'id': 'id9876543210987',
        'name': body['name'],
        'email': '',
        'verified': false,
      });
    }

    return _json(404, <String, dynamic>{'message': 'not found'});
  }

  @override
  void close({bool force = false}) {}
}

Future<void> pumpApp(
  WidgetTester tester,
  FakeBackend backend,
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
}

Future<void> enterTexts(
  WidgetTester tester,
  List<int> indexes,
  List<String> values,
) async {
  final fields = find.byType(TextFormField);
  for (var i = 0; i < indexes.length; i++) {
    await tester.enterText(fields.at(indexes[i]), values[i]);
  }
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login succeeds, shows the result, then opens home',
      (WidgetTester tester) async {
    final backend = FakeBackend();
    await pumpApp(tester, backend, FakeStorage());

    expect(find.text('Вход'), findsOneWidget);

    await enterTexts(
      tester,
      <int>[0, 1],
      <String>['user@example.com', 'correct-horse'],
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Вход выполнен'), findsOneWidget);
    expect(find.text('sashok'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('id1234567890123'), findsOneWidget);
    expect(find.text('Перейти в профиль'), findsOneWidget);

    await tester.tap(find.text('Перейти в профиль'));
    await tester.pumpAndSettle();

    expect(find.text('Вы зашли как sashok'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
  });

  testWidgets('login failure lands on the result screen with the reason',
      (WidgetTester tester) async {
    final backend = FakeBackend();
    await pumpApp(tester, backend, FakeStorage());

    await enterTexts(
      tester,
      <int>[0, 1],
      <String>['user@example.com', 'wrong-password'],
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Вход не выполнен'), findsOneWidget);
    expect(find.text('Неверный email или пароль.'), findsOneWidget);
    expect(find.text('Попробовать снова'), findsOneWidget);

    await tester.tap(find.text('Попробовать снова'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
  });

  testWidgets('registration succeeds and offers the way to the login form',
      (WidgetTester tester) async {
    final backend = FakeBackend();
    await pumpApp(tester, backend, FakeStorage());

    await tester.tap(
      find.widgetWithText(TextButton, 'Ещё нет аккаунта? Зарегистрироваться'),
    );
    await tester.pumpAndSettle();

    await enterTexts(
      tester,
      <int>[0, 1, 2, 3],
      <String>['new@example.com', 'newuser', 'correct-horse', 'correct-horse'],
    );

    expect(find.text('Свободен'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilledButton, 'Зарегистрироваться'));
    await tester.pumpAndSettle();

    expect(find.text('Регистрация прошла успешно'), findsOneWidget);
    expect(find.text('new@example.com'), findsOneWidget);
    expect(find.text('newuser'), findsOneWidget);
    expect(find.text('Перейти к входу'), findsOneWidget);

    await tester.tap(find.text('Перейти к входу'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
  });

  testWidgets('taken email blocks registration before the request is sent',
      (WidgetTester tester) async {
    final backend = FakeBackend(knownEmail: 'taken@example.com');
    await pumpApp(tester, backend, FakeStorage());

    await tester.tap(
      find.widgetWithText(TextButton, 'Ещё нет аккаунта? Зарегистрироваться'),
    );
    await tester.pumpAndSettle();

    await enterTexts(
      tester,
      <int>[0, 1, 2, 3],
      <String>['taken@example.com', 'newuser', 'correct-horse', 'correct-horse'],
    );

    expect(find.text('Занят'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Зарегистрироваться'));
    await tester.pumpAndSettle();

    expect(find.text('Регистрация не выполнена'), findsOneWidget);
    expect(
      find.text(
        'Email или username уже заняты. Если это ваш аккаунт — войдите с помощью него.',
      ),
      findsOneWidget,
    );
    // Pre-submit guard: no create request must have been made.
    expect(backend.calls.where((String c) => c.startsWith('POST')), isEmpty);

    await tester.tap(find.text('Перейти к входу'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
  });

  testWidgets('server rejection is reported in Russian on the result screen',
      (WidgetTester tester) async {
    // Availability says "free" but PocketBase rejects the create anyway.
    final backend = FakeBackend(createOk: false);
    await pumpApp(tester, backend, FakeStorage());

    await tester.tap(
      find.widgetWithText(TextButton, 'Ещё нет аккаунта? Зарегистрироваться'),
    );
    await tester.pumpAndSettle();

    await enterTexts(
      tester,
      <int>[0, 1, 2, 3],
      <String>['new@example.com', 'newuser', 'correct-horse', 'correct-horse'],
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Зарегистрироваться'));
    await tester.pumpAndSettle();

    expect(find.text('Регистрация не выполнена'), findsOneWidget);
    expect(find.textContaining('Не удалось создать аккаунт.'), findsOneWidget);
    expect(find.textContaining('email: занято'), findsOneWidget);
    expect(find.text('Перейти к входу'), findsOneWidget);
  });

  testWidgets('logout returns to the login form', (WidgetTester tester) async {
    final storage = FakeStorage();
    await pumpApp(tester, FakeBackend(), storage);

    await enterTexts(
      tester,
      <int>[0, 1],
      <String>['user@example.com', 'correct-horse'],
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перейти в профиль'));
    await tester.pumpAndSettle();

    expect(find.text('Вы зашли как sashok'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Выйти').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Выйти').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
    expect(storage.token, isNull);
  });
}
