import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/main.dart';
import 'package:login_app/providers/ai_providers_provider.dart';
import 'package:login_app/providers/auth_provider.dart';
import 'package:login_app/services/api_client.dart';
import 'package:login_app/services/provider_test_service.dart';
import 'package:login_app/services/secure_storage_service.dart';

/// In-memory replacement for flutter_secure_storage (no platform channel
/// exists inside a test).
class FakeStorage extends SecureStorageService {
  String? token;
  Map<String, String?> data = <String, String?>{};
  final Map<String, String> apiKeys = <String, String>{};
  final Map<String, String> values = <String, String>{};

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

  @override
  Future<String?> readValue(String key) async => values[key];

  @override
  Future<void> writeValue(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> deleteValue(String key) async {
    values.remove(key);
  }
}

/// PocketBase double: login plus the /api/ai-config catalogue endpoint.
///
/// Like the real hook, PUT stores **only** the enabled flags and answers with
/// the merged view, so a test cannot accidentally pass while the app believes
/// it may rewrite provider definitions.
class FakeAiBackend implements HttpClientAdapter {
  FakeAiBackend(this.catalogue);

  static const String userId = 'id1234567890123';

  Map<String, dynamic> catalogue;
  final List<Map<String, dynamic>> putBodies = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> statsPosts = <Map<String, dynamic>>[];
  Map<String, dynamic> statsView = <String, dynamic>{};
  final List<String> calls = <String>[];

  /// Answers the provider's own /models endpoint for the test button.
  String providerModelsBody = '{"data":[{"id":"openai-model"}]}';
  int providerModelsStatus = 200;

  static ResponseBody _json(int status, Object? body) {
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
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

    if (path == '/api/ai-config') {
      if (method == 'GET') {
        return _json(200, catalogue);
      }
      if (method == 'PUT') {
        putBodies.add(body);
        return _json(200, _mergeFlags(body));
      }
    }

    if (path == '/api/ai-stats') {
      if (method == 'GET') {
        return _json(200, statsView);
      }
      if (method == 'POST') {
        statsPosts.add(body);
        final providerId = body['providerId'] as String? ?? '';
        final model = body['model'] as String? ?? '';
        final ok = body['ok'] == true;
        statsView = <String, dynamic>{
          providerId: <String, dynamic>{
            'version': 1,
            'providerId': providerId,
            'updated': '2026-10-12T21:00:00Z',
            'models': <String, dynamic>{
              model: <String, dynamic>{
                'ok': ok ? 1 : 0,
                'fail': ok ? 0 : 1,
                'usersOk': ok ? 1 : 0,
                'usersFail': ok ? 0 : 1,
                'last': '2026-10-12T21:00:00Z',
                'lastStatus': ok ? 'ok' : 'fail',
                'lastError': body['error'] ?? '',
              },
            },
          },
        };
        return _json(200, statsView[providerId]);
      }
    }

    return _json(404, <String, dynamic>{'message': 'not found'});
  }

  /// The server keeps only the flags and returns the catalogue merged with them.
  Map<String, dynamic> _mergeFlags(Map<String, dynamic> body) {
    final flags = <String, bool>{};
    final sent = body['providers'];
    if (sent is List) {
      for (final item in sent) {
        if (item is Map && item['id'] is String) {
          flags[item['id'] as String] = item['enabled'] == true;
        }
      }
    }

    final providers = <dynamic>[];
    final known = <String>{};
    for (final raw in (catalogue['providers'] as List<dynamic>)) {
      final provider = Map<String, dynamic>.from(raw as Map);
      final id = provider['id'] as String;
      known.add(id);
      if (flags.containsKey(id)) {
        provider['enabled'] = flags[id];
      }
      providers.add(provider);
    }

    // Unknown ids become the caller's own proposals, like the real server.
    for (final raw in (body['providers'] as List<dynamic>? ?? <dynamic>[])) {
      final item = Map<String, dynamic>.from(raw as Map);
      final id = item['id'] as String;
      if (known.contains(id)) continue;
      providers.add(<String, dynamic>{
        ...item,
        'origin': 'user',
        'authorName': 'sashok',
        'mine': true,
      });
    }

    catalogue = <String, dynamic>{
      ...catalogue,
      'updated': '2026-10-12T21:00:00Z',
      'providers': providers,
    };
    return catalogue;
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _entry(
  String id,
  String name,
  int priority, {
  bool enabled = false,
  String status = 'active',
  String? url,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'enabled': enabled,
    'url': url ?? 'https://api.$id.example/v1',
    'model': '$id-model',
    'fallbackPriority': priority,
    'loginUrl': 'https://$id.example/login',
    'getApiKeyUrl': 'https://$id.example/keys',
    'logoUrl': '',
    'logoAsset': '',
    'status': status,
  };
}

Map<String, dynamic> _catalogue(List<Map<String, dynamic>> providers) {
  return <String, dynamic>{
    'version': 2,
    'updated': '2026-10-12T20:00:00Z',
    'canEdit': false,
    'providers': providers,
  };
}

/// Answers the provider's own API, i.e. the /models call behind the test
/// button. Keeps the tests off the network.
class FakeProviderAdapter implements HttpClientAdapter {
  FakeProviderAdapter(this.backend);

  final FakeAiBackend backend;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final status = backend.providerModelsStatus;
    final body = status == 200
        ? backend.providerModelsBody
        : jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{'message': 'invalid api key'},
          });

    return ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> pumpApp(
  WidgetTester tester,
  FakeAiBackend backend,
  FakeStorage storage,
) async {
  // The suite asserts the Russian default, so pin the platform locale.
  tester.platformDispatcher.localeTestValue = const Locale('ru');
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('ru')];

  // A taller surface keeps the extended FAB from covering the card buttons,
  // which is what a real phone screen does not do either.
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final api = ApiClient()..dio.httpClientAdapter = backend;
  final providerApi = ProviderTestService(
    dio: Dio()..httpClientAdapter = FakeProviderAdapter(backend),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        apiClientProvider.overrideWithValue(api),
        secureStorageProvider.overrideWithValue(storage),
        providerTestServiceProvider.overrideWithValue(providerApi),
      ],
      child: const LoginApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Logs in through the real UI and opens the AI providers screen.
Future<void> openProviders(
  WidgetTester tester,
  FakeAiBackend backend,
  FakeStorage storage,
) async {
  await pumpApp(tester, backend, storage);

  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'user@example.com');
  await tester.enterText(fields.at(1), 'probe-password');
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Перейти в профиль'));
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(FilledButton, 'AI-провайдеры'));
  await tester.pumpAndSettle();
}

Finder switchOf(String providerName) => find.descendant(
      of: find.widgetWithText(Card, providerName),
      matching: find.byType(Switch),
    );

void main() {
  testWidgets('the catalogue is shown without any admin controls',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[
        _entry('openai', 'OpenAI', 1, enabled: true),
        _entry('groq', 'Groq', 2),
      ]),
    );

    await openProviders(tester, backend, FakeStorage());

    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Groq'), findsOneWidget);
    // The sync switch plus one per provider.
    expect(find.byType(Switch), findsNWidgets(3));
    expect(
      find.text('Каталог провайдеров ведёт администратор'),
      findsOneWidget,
    );

    // A regular user cannot change the administrator's entries...
    expect(find.text('Редактировать'), findsNothing);
    expect(find.text('Удалить'), findsNothing);
    // ...but may propose their own.
    expect(find.text('Добавить провайдера'), findsOneWidget);
  });

  testWidgets('switching a provider on sends the choice to the server',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[
        _entry('openai', 'OpenAI', 1),
        _entry('groq', 'Groq', 2),
      ]),
    );

    await openProviders(tester, backend, FakeStorage());

    final groq = switchOf('Groq');
    await tester.ensureVisible(groq);
    await tester.pumpAndSettle();
    await tester.tap(groq);
    await tester.pumpAndSettle();

    expect(backend.putBodies, isNotEmpty);
    final sent = backend.putBodies.last['providers'] as List<dynamic>;
    final flags = <String, bool>{
      for (final item in sent)
        (item as Map<String, dynamic>)['id'] as String: item['enabled'] == true,
    };
    expect(flags['groq'], isTrue);
    expect(flags['openai'], isFalse);
  });

  testWidgets('the API key stays on the device',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[_entry('openai', 'OpenAI', 1)]),
    );
    final storage = FakeStorage();

    await openProviders(tester, backend, storage);

    final keyButton = find.widgetWithText(TextButton, 'Ввести ключ');
    await tester.ensureVisible(keyButton);
    await tester.pumpAndSettle();
    await tester.tap(keyButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'super-secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();

    expect(
      storage.apiKeys['${FakeAiBackend.userId}/openai'],
      'super-secret',
    );
    // Nothing that was sent to the server may contain the secret.
    expect(jsonEncode(backend.putBodies), isNot(contains('super-secret')));
  });

  testWidgets('a dead provider is dropped while off and kept while on',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[
        _entry('openai', 'OpenAI', 1, enabled: true),
        _entry('ghost', 'Ghost', 2, status: 'dead'),
        _entry('zombie', 'Zombie', 3, enabled: true, status: 'dead'),
      ]),
    );

    await openProviders(tester, backend, FakeStorage());

    expect(find.text('OpenAI'), findsOneWidget);
    // Switched off and dead -> removed.
    expect(find.text('Ghost'), findsNothing);
    // Switched on -> never touched, even when dead, but flagged.
    expect(find.text('Zombie'), findsOneWidget);
    expect(find.text('не работает'), findsOneWidget);
  });

  testWidgets('off providers take the catalogue URL, on providers keep theirs',
      (WidgetTester tester) async {
    final storage = FakeStorage();
    storage.values['ai_providers_snapshot_${FakeAiBackend.userId}'] = jsonEncode(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'openai',
          'name': 'OpenAI',
          'enabled': true,
          'url': 'https://local.example/v1',
          'model': 'local-model',
          'fallbackPriority': 1,
          'status': 'active',
        },
        <String, dynamic>{
          'id': 'groq',
          'name': 'Groq',
          'enabled': false,
          'url': 'https://stale.example/v1',
          'model': 'stale-model',
          'fallbackPriority': 2,
          'status': 'active',
        },
      ],
    );

    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[
        _entry('openai', 'OpenAI', 1, url: 'https://catalogue.example/v2'),
        _entry('groq', 'Groq', 2, url: 'https://catalogue.example/v2'),
      ]),
    );

    await openProviders(tester, backend, storage);

    // Switched on: the local copy wins.
    expect(find.text('https://local.example/v1'), findsOneWidget);
    // Switched off: the administrator's fresh URL is taken.
    expect(find.text('https://catalogue.example/v2'), findsOneWidget);
    expect(find.text('https://stale.example/v1'), findsNothing);
  });

  testWidgets('the last email is remembered and prefilled',
      (WidgetTester tester) async {
    final storage = FakeStorage()
      ..values['last_login_email'] = 'saved@example.com';

    await pumpApp(tester, FakeAiBackend(_catalogue(<Map<String, dynamic>>[])), storage);

    final email = tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(email.controller?.text, 'saved@example.com');
  });

  testWidgets('a successful login stores the email for next time',
      (WidgetTester tester) async {
    final storage = FakeStorage();

    await openProviders(
      tester,
      FakeAiBackend(_catalogue(<Map<String, dynamic>>[])),
      storage,
    );

    expect(storage.values['last_login_email'], 'user@example.com');
  });

  testWidgets('a provider marked dead cannot be tested',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[
        _entry('openai', 'OpenAI', 1, status: 'dead', enabled: true),
      ]),
    );
    final storage = FakeStorage()
      ..apiKeys['${FakeAiBackend.userId}/openai'] = 'sk-test';

    await openProviders(tester, backend, storage);

    expect(
      find.text('Проверка недоступна: провайдер помечен администратором.'),
      findsOneWidget,
    );

    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Проверить и список моделей'),
    );
    expect(button.onPressed, isNull);
    expect(backend.statsPosts, isEmpty);
  });

  testWidgets('testing a provider publishes the result and lists the models',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[_entry('openai', 'OpenAI', 1)]),
    );
    final storage = FakeStorage()
      ..apiKeys['${FakeAiBackend.userId}/openai'] = 'sk-test';

    await openProviders(tester, backend, storage);

    final button = find.widgetWithText(TextButton, 'Проверить и список моделей');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(backend.statsPosts, hasLength(1));
    expect(backend.statsPosts.first['providerId'], 'openai');
    expect(backend.statsPosts.first['model'], 'openai-model');
    expect(backend.statsPosts.first['ok'], true);

    expect(find.text('Модели: OpenAI'), findsOneWidget);
    expect(find.textContaining('Найдено моделей: 1'), findsOneWidget);
  });

  testWidgets('the paste button wakes up only when the field is focused',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[_entry('openai', 'OpenAI', 1)]),
    );

    await openProviders(tester, backend, FakeStorage());

    final keyButton = find.widgetWithText(TextButton, 'Ввести ключ');
    await tester.ensureVisible(keyButton);
    await tester.pumpAndSettle();
    await tester.tap(keyButton);
    await tester.pumpAndSettle();

    final paste = find.widgetWithText(TextButton, 'Вставить из буфера');
    expect(paste, findsOneWidget);
    // Disabled until the user actually touches the field.
    expect(tester.widget<TextButton>(paste).onPressed, isNull);

    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(paste).onPressed, isNotNull);

    // An empty clipboard must not throw.
    await tester.tap(paste);
    await tester.pumpAndSettle();
  });

  testWidgets('a new provider is sent as the user own proposal',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[_entry('openai', 'OpenAI', 1)]),
    );

    await openProviders(tester, backend, FakeStorage());

    await tester.tap(find.text('Добавить провайдера'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'My LLM');
    await tester.enterText(fields.at(1), 'http://192.168.0.5:8080/v1');
    await tester.enterText(fields.at(2), 'my-model');
    await tester.enterText(fields.at(3), '11');
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Сохранить');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    // The definition reaches the server without any secret...
    final sent = backend.putBodies.last['providers'] as List<dynamic>;
    final proposal = sent.firstWhere(
      (dynamic p) => (p as Map<String, dynamic>)['name'] == 'My LLM',
    ) as Map<String, dynamic>;
    expect(proposal['url'], 'http://192.168.0.5:8080/v1');
    expect(proposal['model'], 'my-model');
    expect(proposal['fallbackPriority'], 11);
    expect(jsonEncode(sent), isNot(contains('api_key')));

    // ...and the entry is marked as the user's own.
    expect(find.text('My LLM'), findsOneWidget);
    expect(find.text('ваш'), findsOneWidget);
  });

  testWidgets('an auto login restores the user so the catalogue loads',
      (WidgetTester tester) async {
    // A stored token alone used to be enough to look signed in while the user
    // id stayed empty, which silently disabled the whole sync.
    final storage = FakeStorage()
      ..token = 'test-token'
      ..data = <String, String?>{
        'userId': FakeAiBackend.userId,
        'username': 'sashok',
        'email': 'user@example.com',
      };
    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[_entry('openai', 'OpenAI', 1)]),
    );

    await pumpApp(tester, backend, storage);

    // Went straight to the home screen without a login form.
    expect(find.text('Вы зашли как sashok'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'AI-провайдеры'));
    await tester.pumpAndSettle();

    expect(backend.calls, contains('GET /api/ai-config'));
    expect(find.text('OpenAI'), findsOneWidget);
  });

  testWidgets('a provider switched off for everybody asks the user to turn it off',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[
        _entry(
          'openai',
          'OpenAI',
          1,
          enabled: true,
          status: 'disabled_for_all',
        ),
      ]),
    );

    await openProviders(tester, backend, FakeStorage());

    expect(find.text('отключён админом'), findsOneWidget);
    expect(find.textContaining('Администратор отключил'), findsOneWidget);

    // Such a provider cannot be tested any more.
    final testButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Проверить и список моделей'),
    );
    expect(testButton.onPressed, isNull);

    // Turning it off is offered right there.
    final turnOff = find.widgetWithText(FilledButton, 'Выключить');
    await tester.ensureVisible(turnOff);
    await tester.pumpAndSettle();
    await tester.tap(turnOff);
    await tester.pumpAndSettle();

    final sent = backend.putBodies.last['providers'] as List<dynamic>;
    final openai = sent.firstWhere(
      (dynamic p) => (p as Map<String, dynamic>)['id'] == 'openai',
    ) as Map<String, dynamic>;
    expect(openai['enabled'], false);
  });

  testWidgets('a rejected key is reported as a failure',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[_entry('openai', 'OpenAI', 1)]),
    )..providerModelsStatus = 401;
    final storage = FakeStorage()
      ..apiKeys['${FakeAiBackend.userId}/openai'] = 'sk-bad';

    await openProviders(tester, backend, storage);

    final button = find.widgetWithText(TextButton, 'Проверить и список моделей');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(backend.statsPosts, hasLength(1));
    expect(backend.statsPosts.first['ok'], false);
    expect(
      backend.statsPosts.first['error'].toString(),
      contains('Неверный API-ключ'),
    );
  });

  testWidgets('the model list is fetched even without a key',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[_entry('openai', 'OpenAI', 1)]),
    );

    await openProviders(tester, backend, FakeStorage());

    final button = find.widgetWithText(TextButton, 'Проверить и список моделей');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    // A local server answers without a key, so the list opens and the result
    // is published like any other test.
    expect(find.text('Модели: OpenAI'), findsOneWidget);
    expect(backend.statsPosts, hasLength(1));
    expect(backend.statsPosts.first['ok'], true);
  });

  testWidgets('a provider that demands a key is explained, not published',
      (WidgetTester tester) async {
    final backend = FakeAiBackend(
      _catalogue(<Map<String, dynamic>>[_entry('openai', 'OpenAI', 1)]),
    )..providerModelsStatus = 401;

    await openProviders(tester, backend, FakeStorage());

    final button = find.widgetWithText(TextButton, 'Проверить и список моделей');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    // Nothing was sent, so nothing can be said about the provider and no
    // failure is published for it.
    expect(backend.statsPosts, isEmpty);
    expect(find.textContaining('введите ключ'), findsOneWidget);
  });
}
