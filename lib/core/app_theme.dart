import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';

/// Builds the [ThemeData] for one of the ten [AppThemeVariant] values.
///
/// The app keeps its existing visual language: a Material 3 scheme derived
/// from a single seed colour, no extra fonts or components.
ThemeData themeFor(AppThemeVariant variant) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: variant.seedColor,
      brightness: variant.isDark ? Brightness.dark : Brightness.light,
    ),
    useMaterial3: true,
  );
}
