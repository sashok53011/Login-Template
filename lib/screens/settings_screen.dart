import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../providers/settings_provider.dart';

/// Lets the user pick the UI language and one of the ten colour themes.
/// Both choices apply immediately (and are persisted by [SettingsNotifier]).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const List<String> _languages = <String>['ru', 'en', 'de'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final language = settings.language;

    return Scaffold(
      appBar: AppBar(title: Text(translate('settings.title', language))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              translate('settings.languageTitle', language),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            RadioGroup<String>(
              groupValue: language,
              onChanged: (String? value) {
                if (value != null) notifier.setLanguage(value);
              },
              child: Column(
                children: _languages
                    .map(
                      (String code) => RadioListTile<String>(
                        value: code,
                        title: Text(translate('language.$code', language)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(height: 32),
            Text(
              translate('settings.themeTitle', language),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.4,
              ),
              itemCount: AppThemeVariant.values.length,
              itemBuilder: (BuildContext context, int index) {
                final variant = AppThemeVariant.values[index];
                return _ThemeTile(
                  variant: variant,
                  label: variant.label(language),
                  selected: variant == settings.theme,
                  onTap: () => notifier.setTheme(variant),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One theme choice: a colour preview, its localised name and a check mark
/// while it is the active one.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.variant,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppThemeVariant variant;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The actual look of the variant, so the preview matches the app.
    final preview = themeFor(variant).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: preview.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: scheme.primary, size: 18),
          ],
        ),
      ),
    );
  }
}
