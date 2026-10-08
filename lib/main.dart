import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/action_result_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';

/// Routes an anonymous user is allowed to visit.
const Set<String> kAuthRoutes = <String>{
  '/login',
  '/register',
};

/// Routes that always render the outcome of the last action and are never
/// intercepted by the auth redirect: an anonymous user must be able to read a
/// login failure, and a logged-in user must be able to read the confirmation.
const Set<String> kResultRoutes = <String>{
  '/register-result',
  '/login-result',
};

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LoginApp()));
}

class LoginApp extends ConsumerStatefulWidget {
  const LoginApp({super.key});

  @override
  ConsumerState<LoginApp> createState() => _LoginAppState();
}

class _LoginAppState extends ConsumerState<LoginApp> {
  final ValueNotifier<int> _refresh = ValueNotifier<int>(0);
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: _refresh,
      redirect: (context, state) {
        final auth = ref.read(authProvider);
        final location = state.matchedLocation;

        // Still restoring the session -> splash.
        if (auth.isLoading) {
          return location == '/splash' ? null : '/splash';
        }

        final onAuthPage = kAuthRoutes.contains(location);

        // Result screens are exempt: they must render both for an anonymous
        // visitor (login/register failed) and for an authenticated one
        // (login succeeded).
        if (kResultRoutes.contains(location)) return null;

        if (!auth.isLoggedIn && !onAuthPage) return '/login';
        if (auth.isLoggedIn && onAuthPage) return '/home';
        if (auth.isLoggedIn && location == '/splash') return '/home';
        return null;
      },
      routes: <GoRoute>[
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/register-result',
          builder: (context, state) => const ActionResultScreen(),
        ),
        GoRoute(
          path: '/login-result',
          builder: (context, state) => const ActionResultScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _refresh.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-run route redirects whenever the auth state changes.
    ref.listen(authProvider, (previous, next) => _refresh.value++);

    return MaterialApp.router(
      title: 'DevHorizon Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
