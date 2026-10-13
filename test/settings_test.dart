import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/core/app_theme.dart';
import 'package:login_app/main.dart';
import 'package:login_app/providers/auth_provider.dart';
import 'package:login_app/providers/settings_provider.dart';
import 'package:login_app/screens/settings_screen.dart';
import 'package:login_app/services/secure_storage_service.dart';

/// In-memory replacement for flutter_secure_storage.
class _MemStorage extends SecureStorageService {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Map<String, String?>> getUserData() async => <String, String?>{};

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

void _pinRussian(WidgetTester tester) {
  tester.platformDispatcher.localeTestValue = const Locale('ru');
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('ru')];
}

void main() {
  group('translate', () {
    test('the English and German maps contain every Russian key', () {
      final ru = kTranslations['ru']!;
      for (final String language in <String>['en', 'de']) {
        final table = kTranslations[language]!;
        for (final String key in ru.keys) {
          expect(
            table.containsKey(key),
            isTrue,
            reason: '$language is missing the key "$key"',
          );
        }
      }
    });

    test('an unknown key comes back unchanged', () {
      expect(translate('this is plain text', 'en'), 'this is plain text');
      expect(translate('err.doesNotExist', 'de'), 'err.doesNotExist');
      expect(translate('просто текст', 'ru'), 'просто текст');
    });

    test('args replace the {name} placeholders', () {
      expect(
        translate('home.loggedInAs', 'ru', args: <String, String>{'name': 'sashok'}),
        'Вы зашли как sashok',
      );
      expect(
        translate('home.loggedInAs', 'en', args: <String, String>{'name': 'sashok'}),
        'Signed in as sashok',
      );
    });

    test('a composite message of keys is translated token by token', () {
      expect(
        translate('err.createFailed email: err.taken', 'ru'),
        'Не удалось создать аккаунт. email: занято',
      );
    });
  });

  group('themes', () {
    test('day variants are light, night variants are dark', () {
      for (final AppThemeVariant variant in AppThemeVariant.values) {
        final theme = themeFor(variant);
        expect(theme.useMaterial3, isTrue);
        expect(
          theme.colorScheme.brightness,
          variant.isDark ? Brightness.dark : Brightness.light,
          reason: '${variant.name} has the wrong brightness',
        );
      }
    });

    test('every variant has its seed colour', () {
      expect(AppThemeVariant.day.seedColor, Colors.indigo);
      expect(AppThemeVariant.dayYellow.seedColor, Colors.amber);
      expect(AppThemeVariant.dayRed.seedColor, Colors.red);
      expect(AppThemeVariant.dayGreen.seedColor, Colors.green);
      expect(AppThemeVariant.dayOrange.seedColor, Colors.deepOrange);
      expect(AppThemeVariant.nightRed.seedColor, Colors.red);
      expect(AppThemeVariant.nightBlue.seedColor, Colors.blue);
      expect(AppThemeVariant.nightYellow.seedColor, Colors.amber);
      expect(AppThemeVariant.nightGreen.seedColor, Colors.green);
      expect(AppThemeVariant.nightOrange.seedColor, Colors.deepOrange);
    });
  });

  testWidgets('switching the language changes the login button',
      (WidgetTester tester) async {
    _pinRussian(tester);
    final container = ProviderContainer(
      overrides: <Override>[
        secureStorageProvider.overrideWithValue(_MemStorage()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LoginApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);

    await container.read(settingsProvider.notifier).setLanguage('en');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

    await container.read(settingsProvider.notifier).setLanguage('de');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Anmelden'), findsOneWidget);

    await container.read(settingsProvider.notifier).setLanguage('ru');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
  });

  testWidgets('switching the theme changes Theme.of(context).brightness',
      (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: <Override>[
        secureStorageProvider.overrideWithValue(_MemStorage()),
      ],
    );
    addTearDown(container.dispose);

    Brightness? captured;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final variant = ref.watch(settingsProvider).theme;
            return MaterialApp(
              theme: themeFor(variant),
              home: Builder(
                builder: (BuildContext context) {
                  captured = Theme.of(context).brightness;
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).theme, AppThemeVariant.day);
    expect(captured, Brightness.light);

    await container
        .read(settingsProvider.notifier)
        .setTheme(AppThemeVariant.nightBlue);
    await tester.pumpAndSettle();
    expect(captured, Brightness.dark);

    await container
        .read(settingsProvider.notifier)
        .setTheme(AppThemeVariant.dayRed);
    await tester.pumpAndSettle();
    expect(captured, Brightness.light);
  });

  testWidgets('the settings screen lists the languages, all ten themes and '
      'applies a language change', (WidgetTester tester) async {
    _pinRussian(tester);
    final container = ProviderContainer(
      overrides: <Override>[
        secureStorageProvider.overrideWithValue(_MemStorage()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    for (final AppThemeVariant variant in AppThemeVariant.values) {
      expect(
        find.text(variant.label('ru')),
        findsOneWidget,
        reason: 'the theme ${variant.name} is missing from the list',
      );
    }

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).language, 'en');
    // The screen itself follows the new language.
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('the choices are persisted through the storage service',
      (WidgetTester tester) async {
    _pinRussian(tester);
    final storage = _MemStorage();
    final container = ProviderContainer(
      overrides: <Override>[
        secureStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).setLanguage('de');
    await container
        .read(settingsProvider.notifier)
        .setTheme(AppThemeVariant.nightGreen);

    expect(storage.values[SettingsNotifier.languageKey], 'de');
    expect(storage.values[SettingsNotifier.themeKey], 'nightGreen');
  });
}
