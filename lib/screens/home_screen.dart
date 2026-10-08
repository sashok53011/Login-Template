import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final name = auth.displayName.trim().isNotEmpty
        ? auth.displayName
        : 'пользователь';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Выйти',
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
                  'Вы зашли как $name',
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
                  icon: const Icon(Icons.logout),
                  label: const Text('Выйти'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти?'),
        content: const Text('Сессия будет завершена, потребуется войти снова.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authProvider.notifier).logout();
  }
}
