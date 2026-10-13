import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/secure_storage_service.dart';
import 'auth_provider.dart' show secureStorageProvider;

export '../l10n/strings.dart' show translate, kTranslations;

/// The ten colour variants offered on the settings screen.
///
/// The `day*` entries are light, the `night*` entries are dark (see
/// [isDark]).
enum AppThemeVariant {
  day,
  dayYellow,
  dayRed,
  dayGreen,
  dayOrange,
  nightRed,
  nightBlue,
  nightYellow,
  nightGreen,
  nightOrange;

  /// True for every `night*` variant.
  bool get isDark => name.startsWith('night');

  /// Seed colour passed to `ColorScheme.fromSeed`.
  Color get seedColor {
    switch (this) {
      case AppThemeVariant.day:
        return Colors.indigo;
      case AppThemeVariant.dayYellow:
      case AppThemeVariant.nightYellow:
        return Colors.amber;
      case AppThemeVariant.dayRed:
      case AppThemeVariant.nightRed:
        return Colors.red;
      case AppThemeVariant.dayGreen:
      case AppThemeVariant.nightGreen:
        return Colors.green;
      case AppThemeVariant.dayOrange:
      case AppThemeVariant.nightOrange:
        return Colors.deepOrange;
      case AppThemeVariant.nightBlue:
        return Colors.blue;
    }
  }

  /// Localised label, e.g. «Ночная — голубая».
  String label(String language) => translate('theme.$name', language);
}

/// Persisted UI preferences.
class SettingsState {
  const SettingsState({required this.language, required this.theme});

  final String language;
  final AppThemeVariant theme;

  SettingsState copyWith({String? language, AppThemeVariant? theme}) {
    return SettingsState(
      language: language ?? this.language,
      theme: theme ?? this.theme,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SettingsState &&
      other.language == language &&
      other.theme == theme;

  @override
  int get hashCode => Object.hash(language, theme);
}

/// Holds the language and theme, and stores them through
/// [SecureStorageService].
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._storage) : super(_defaults());

  /// Secure-storage keys.
  static const String languageKey = 'ui_language';
  static const String themeKey = 'ui_theme';

  final SecureStorageService _storage;

  /// The starting point: the device language when it is `en`/`de`/`ru`,
  /// otherwise Russian; `day` unless the platform runs in dark mode.
  static SettingsState _defaults() {
    return SettingsState(
      language: _deviceLanguage(),
      theme: _deviceTheme(),
    );
  }

  static String _deviceLanguage() {
    try {
      final code = WidgetsBinding
          .instance.platformDispatcher.locale.languageCode
          .toLowerCase();
      if (code == 'en' || code == 'de' || code == 'ru') return code;
    } catch (_) {
      // No binding (unit test): fall through to the default.
    }
    return 'ru';
  }

  static AppThemeVariant _deviceTheme() {
    try {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      if (brightness == Brightness.dark) return AppThemeVariant.nightBlue;
    } catch (_) {
      // No binding (unit test): fall through to the default.
    }
    return AppThemeVariant.day;
  }

  /// Restores the stored choices; a failure or an empty store keeps the
  /// defaults. Called once on startup.
  Future<void> load() async {
    try {
      final language = await _storage.readValue(languageKey);
      final theme = await _storage.readValue(themeKey);
      state = SettingsState(
        language: _validLanguage(language) ?? state.language,
        theme: _validTheme(theme) ?? state.theme,
      );
    } catch (_) {
      // Best effort: the defaults stay in place.
    }
  }

  Future<void> setLanguage(String language) async {
    if (_validLanguage(language) == null || language == state.language) return;
    state = state.copyWith(language: language);
    await _store(languageKey, language);
  }

  Future<void> setTheme(AppThemeVariant theme) async {
    if (theme == state.theme) return;
    state = state.copyWith(theme: theme);
    await _store(themeKey, theme.name);
  }

  Future<void> _store(String key, String value) async {
    try {
      await _storage.writeValue(key, value);
    } catch (_) {
      // Best effort: the in-memory choice still applies.
    }
  }

  static String? _validLanguage(String? value) {
    if (value == 'ru' || value == 'en' || value == 'de') return value;
    return null;
  }

  static AppThemeVariant? _validTheme(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final variant in AppThemeVariant.values) {
      if (variant.name == value) return variant;
    }
    return null;
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    final notifier = SettingsNotifier(ref.watch(secureStorageProvider));
    // Kick off the best-effort restore of the stored choices.
    notifier.load();
    return notifier;
  },
);

/// Widget-side accessor: reads the current language (and rebuilds the caller
/// when it changes).
String tr(WidgetRef ref, String key, {Map<String, String>? args}) {
  return translate(key, ref.watch(settingsProvider).language, args: args);
}
