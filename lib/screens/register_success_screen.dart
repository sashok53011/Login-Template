import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown after a successful registration.
class RegisterSuccessScreen extends StatelessWidget {
  const RegisterSuccessScreen({super.key, this.email, this.username});

  final String? email;
  final String? username;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = (username?.trim().isNotEmpty ?? false)
        ? username!.trim()
        : (email?.trim() ?? '');

    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              const Spacer(),
              Icon(
                Icons.check_circle_outline,
                size: 96,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Регистрация прошла успешно',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Аккаунт создан. Теперь войдите, чтобы продолжить.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              if (identity.isNotEmpty || (email?.isNotEmpty ?? false)) ...<Widget>[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: <Widget>[
                        if (username?.trim().isNotEmpty ?? false)
                          _Row(label: 'Username', value: username!.trim()),
                        if (email?.trim().isNotEmpty ?? false)
                          _Row(label: 'Email', value: email!.trim()),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Перейти к входу'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('Зарегистрировать ещё один аккаунт'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
