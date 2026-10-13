import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final language = ref.watch(settingsProvider).language;
    final name = auth.displayName.trim().isNotEmpty
        ? auth.displayName
        : translate('common.user', language);

    return Scaffold(
      appBar: AppBar(
        title: Text(translate('home.title', language)),
        actions: <Widget>[
          IconButton(
            tooltip: translate('home.settings', language),
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            tooltip: translate('common.logout', language),
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.account_circle, size: 96),
                const SizedBox(height: 24),
                Text(
                  translate(
                    'home.loggedInAs',
                    language,
                    args: <String, String>{'name': name},
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (auth.user?.email != null &&
                    auth.user!.email.isNotEmpty &&
                    auth.user!.email != name)
                  Text(
                    auth.user!.email,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 32),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.list_alt),
                  label: Text(translate('home.aiProviders', language)),
                  onPressed: () => context.push('/ai-providers'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.settings),
                  label: Text(translate('home.settings', language)),
                  onPressed: () => context.push('/settings'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.logout),
                  label: Text(translate('common.logout', language)),
                  onPressed: () => _logout(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final language = ref.read(settingsProvider).language;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(translate('home.logoutTitle', language)),
        content: Text(translate('home.logoutConfirm', language)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(translate('common.cancel', language)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(translate('common.logout', language)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authProvider.notifier).logout();
  }
}
