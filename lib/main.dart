import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';

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

        final onAuthPage =
            location == '/login' || location == '/register';

        if (!auth.isLoggedIn && !onAuthPage) return '/login';
        if (auth.isLoggedIn && (onAuthPage || location == '/splash')) {
          return '/home';
        }
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
