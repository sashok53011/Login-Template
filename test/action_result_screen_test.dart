import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:login_app/models/action_result.dart';
import 'package:login_app/providers/action_result_provider.dart';
import 'package:login_app/screens/action_result_screen.dart';

/// Builds a router whose plain routes render their own path so that the
/// current location can be asserted with `find.text`.
GoRouter buildRouter() {
  Widget plain(String path) => Text(path);

  return GoRouter(
    initialLocation: '/register-result',
    routes: <RouteBase>[
      GoRoute(path: '/login', builder: (_, _) => plain('/login')),
      GoRoute(path: '/register', builder: (_, _) => plain('/register')),
      GoRoute(path: '/home', builder: (_, _) => plain('/home')),
      GoRoute(
        path: '/register-result',
        builder: (_, _) => const ActionResultScreen(),
      ),
      GoRoute(
        path: '/login-result',
        builder: (_, _) => const ActionResultScreen(),
      ),
    ],
  );
}

Future<GoRouter> pumpScreen(WidgetTester tester, ActionResult? result) async {
  final container = ProviderContainer();
  final router = buildRouter();
  addTearDown(container.dispose);
  addTearDown(router.dispose);

  if (result != null) {
    container.read(actionResultProvider.notifier).state = result;
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('registration success offers a way to the login form',
      (WidgetTester tester) async {
    await pumpScreen(
      tester,
      const ActionResult(
        success: true,
        kind: ActionKind.register,
        message: 'Регистрация прошла успешно',
        description: 'Аккаунт создан.',
        rows: <ResultRow>[ResultRow(label: 'Email', value: 'a@b.co')],
      ),
    );

    expect(find.text('Регистрация прошла успешно'), findsOneWidget);
    expect(find.text('Аккаунт создан.'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('a@b.co'), findsOneWidget);
    expect(find.text('Перейти к входу'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('registration failure describes the error and offers login',
      (WidgetTester tester) async {
    await pumpScreen(
      tester,
      const ActionResult(
        success: false,
        kind: ActionKind.register,
        message: 'Регистрация не выполнена',
        description: 'Email или username уже заняты.',
        rows: <ResultRow>[ResultRow(label: 'Email', value: 'a@b.co')],
      ),
    );

    expect(find.text('Регистрация не выполнена'), findsOneWidget);
    expect(find.text('Email или username уже заняты.'), findsOneWidget);
    expect(find.text('Попробовать снова'), findsOneWidget);
    expect(find.text('Перейти к входу'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('login success shows the confirmation',
      (WidgetTester tester) async {
    await pumpScreen(
      tester,
      const ActionResult(
        success: true,
        kind: ActionKind.login,
        message: 'Вход выполнен',
        description: 'Добро пожаловать!',
        rows: <ResultRow>[
          ResultRow(label: 'Username', value: 'sashok'),
          ResultRow(label: 'Id', value: 'abc123'),
        ],
      ),
    );

    expect(find.text('Вход выполнен'), findsOneWidget);
    expect(find.text('Добро пожаловать!'), findsOneWidget);
    expect(find.text('sashok'), findsOneWidget);
    expect(find.text('abc123'), findsOneWidget);
    expect(find.text('Перейти в профиль'), findsOneWidget);
    // Registration-specific action must not leak into the login screen.
    expect(find.text('Перейти к входу'), findsNothing);
  });

  testWidgets('login failure describes the error and can retry',
      (WidgetTester tester) async {
    await pumpScreen(
      tester,
      const ActionResult(
        success: false,
        kind: ActionKind.login,
        message: 'Вход не выполнен',
        description: 'Неверный email или пароль.',
      ),
    );

    expect(find.text('Вход не выполнен'), findsOneWidget);
    expect(find.text('Неверный email или пароль.'), findsOneWidget);
    expect(find.text('Попробовать снова'), findsOneWidget);
    expect(find.text('Создать аккаунт'), findsOneWidget);

    await tester.tap(find.text('Попробовать снова'));
    await tester.pumpAndSettle();
    expect(find.text('/login'), findsOneWidget);
  });

  testWidgets('falls back to the login form when there is no result',
      (WidgetTester tester) async {
    await pumpScreen(tester, null);

    expect(find.text('Нет данных о результате'), findsOneWidget);
    expect(find.text('Перейти ко входу'), findsOneWidget);

    await tester.tap(find.text('Перейти ко входу'));
    await tester.pumpAndSettle();
    expect(find.text('/login'), findsOneWidget);
  });
}
