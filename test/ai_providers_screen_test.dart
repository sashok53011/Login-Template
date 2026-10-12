import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/providers/ai_providers_provider.dart';
import 'package:login_app/providers/auth_provider.dart';
import 'package:login_app/screens/ai_providers_list_screen.dart';

class _FakeAuth extends AuthNotifier {
  _FakeAuth(Ref ref) : super(ref);
  @override
  AuthState build() => const AuthState(isLoggedIn: true, isLoading: false);
}

class _FakeAiProviders extends AiProvidersNotifier {
  _FakeAiProviders(Ref ref) : super(ref);
  @override
  Future<void> load() async {}
}

void main() {
  testWidgets('AiProvidersListScreen renders basic UI', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuth(ref)),
          aiProvidersProvider.overrideWith((ref) => _FakeAiProviders(ref)),
        ],
        child: const MaterialApp(
          home: AiProvidersListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI-провайдеры'), findsOneWidget);
    expect(find.text('Добавить провайдера'), findsOneWidget);
  });
}
