import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/action_result.dart';
import '../providers/action_result_provider.dart';

/// Shown right after a register or login attempt.
///
/// Always displays the outcome of the action:
///  * a confirmation that everything went fine, or
///  * a description of what went wrong.
///
/// For registration the screen also offers to go to the login form.
class ActionResultScreen extends ConsumerWidget {
  const ActionResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = ref.watch(actionResultProvider);

    // Deep link or process death: nothing to report.
    if (result == null) {
      return _fallback(context);
    }

    final color = result.success ? scheme.primary : scheme.error;
    final primary = _primaryFor(context, result);
    final secondary = _secondaryFor(context, result);
    final description = result.description?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(result.kind == ActionKind.register ? 'Регистрация' : 'Вход'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.vertical -
                  kToolbarHeight -
                  48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  result.success
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 96,
                  color: color,
                ),
                const SizedBox(height: 24),
                Text(
                  result.message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                if (description.isNotEmpty && result.success) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (description.isNotEmpty && !result.success) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.info_outline,
                          color: scheme.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            description,
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (result.rows.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: result.rows
                            .map((ResultRow row) => _Row(
                                  label: row.label,
                                  value: row.value,
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: primary.onTap,
                  child: Text(primary.label),
                ),
                if (secondary != null) ...<Widget>[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: secondary.onTap,
                    child: Text(secondary.label),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Результат')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),
              Icon(
                Icons.help_outline,
                size: 96,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 24),
              Text(
                'Нет данных о результате',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Попробуйте выполнить действие ещё раз.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => GoRouter.of(context).go('/login'),
                child: const Text('Перейти ко входу'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Main button: continue after success, retry after a failure.
  _Action _primaryFor(BuildContext context, ActionResult result) {
    final router = GoRouter.of(context);

    if (result.kind == ActionKind.register) {
      if (result.success) {
        return _Action('Перейти к входу', () => router.go('/login'));
      }
      return _Action(
        'Попробовать снова',
        () => router.canPop() ? router.pop() : router.go('/register'),
      );
    }

    if (result.success) {
      return _Action('Перейти в профиль', () => router.go('/home'));
    }
    return _Action(
      'Попробовать снова',
      () => router.canPop() ? router.pop() : router.go('/login'),
    );
  }

  /// Secondary action: registration always offers to go to the login form.
  _Action? _secondaryFor(BuildContext context, ActionResult result) {
    final router = GoRouter.of(context);

    if (result.kind == ActionKind.register) {
      return result.success
          ? _Action('Создать ещё один аккаунт', () => router.go('/register'))
          : _Action('Перейти к входу', () => router.go('/login'));
    }

    return result.success
        ? null
        : _Action('Создать аккаунт', () => router.go('/register'));
  }
}

/// Label/value pair from [ActionResult.rows].
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// A button on the result screen.
class _Action {
  const _Action(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
}
