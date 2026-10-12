import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:login_app/providers/auth_provider.dart';
import 'package:login_app/screens/home_screen.dart';
import 'package:login_app/screens/ai_providers_list_screen.dart';

class _FakeAuth extends StateNotifier<AuthState> {
  _FakeAuth() : super(const AuthState(isLoggedIn: true, isLoading: false));
}

void main() {
  testWidgets('Home screen has navigation to AI providers', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuth()),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
              GoRoute(
                path: '/ai-providers',
                builder: (context, state) => const AiProvidersListScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI-провайдеры'), findsOneWidget);
    await tester.tap(find.text('AI-провайдеры'));
    await tester.pumpAndSettle();
  });
}
