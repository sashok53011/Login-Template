import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/action_result_screen.dart';
import 'screens/ai_providers_list_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/settings_screen.dart';
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
        GoRoute(
          path: '/ai-providers',
          builder: (context, state) => const AiProvidersListScreen(),
        ),
        // Authenticated route on purpose: it is not in [kAuthRoutes], so the
        // redirect sends an anonymous visitor back to /login.
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
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

    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'DevHorizon Login',
      debugShowCheckedModeBanner: false,
      locale: Locale(settings.language),
      supportedLocales: const <Locale>[
        Locale('ru'),
        Locale('en'),
        Locale('de'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // A single scheme is used for both slots; the variant itself decides
      // whether the app is light or dark via [themeMode].
      theme: themeFor(settings.theme),
      darkTheme: themeFor(settings.theme),
      themeMode: settings.theme.isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
    );
  }
}
