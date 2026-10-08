import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/action_result.dart';
import '../providers/action_result_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/validators.dart';

/// Availability of a value that is being checked against the backend.
enum Avail { idle, checking, free, taken, unknown }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const Duration _debounce = Duration(milliseconds: 700);

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  Timer? _emailTimer;
  Timer? _nameTimer;
  Avail _emailAvail = Avail.idle;
  Avail _nameAvail = Avail.idle;

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onEmailChanged);
    _usernameCtrl.addListener(_onUsernameChanged);
    _passCtrl.addListener(_onPasswordChanged);
    _confirmCtrl.addListener(_onPasswordChanged);
  }

  void _onEmailChanged() {
    setState(() {});
    _emailTimer?.cancel();
    final value = _emailCtrl.text.trim();
    if (Validators.email(value) != null) {
      if (_emailAvail != Avail.idle) {
        setState(() => _emailAvail = Avail.idle);
      }
      return;
    }
    _emailTimer = Timer(_debounce, () => _runEmailCheck(value));
  }

  void _onUsernameChanged() {
    setState(() {});
    _nameTimer?.cancel();
    final value = _usernameCtrl.text.trim();
    if (Validators.username(value) != null) {
      if (_nameAvail != Avail.idle) {
        setState(() => _nameAvail = Avail.idle);
      }
      return;
    }
    _nameTimer = Timer(_debounce, () => _runNameCheck(value));
  }

  void _onPasswordChanged() => setState(() {});

  Future<void> _runEmailCheck(String value) async {
    setState(() => _emailAvail = Avail.checking);
    try {
      final taken =
          await ref.read(authServiceProvider).isValueTaken(value);
      if (!mounted || _emailCtrl.text.trim() != value) return;
      setState(() => _emailAvail = taken ? Avail.taken : Avail.free);
    } catch (_) {
      if (!mounted || _emailCtrl.text.trim() != value) return;
      setState(() => _emailAvail = Avail.unknown);
    }
  }

  Future<void> _runNameCheck(String value) async {
    setState(() => _nameAvail = Avail.checking);
    try {
      final taken =
          await ref.read(authServiceProvider).isValueTaken(value);
      if (!mounted || _usernameCtrl.text.trim() != value) return;
      setState(() => _nameAvail = taken ? Avail.taken : Avail.free);
    } catch (_) {
      if (!mounted || _usernameCtrl.text.trim() != value) return;
      setState(() => _nameAvail = Avail.unknown);
    }
  }

  @override
  void dispose() {
    _emailTimer?.cancel();
    _nameTimer?.cancel();
    _emailCtrl.removeListener(_onEmailChanged);
    _usernameCtrl.removeListener(_onUsernameChanged);
    _passCtrl.removeListener(_onPasswordChanged);
    _confirmCtrl.removeListener(_onPasswordChanged);
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Everything the async part needs is captured up front: go_router may
    // move this form off-screen (redirect) while the request is in flight,
    // and a disposed ConsumerState must not be touched afterwards.
    final router = GoRouter.of(context);
    final notifier = ref.read(authProvider.notifier);
    final setResult = ref.read(actionResultProvider.notifier);
    final email = _emailCtrl.text.trim();
    final username = _usernameCtrl.text.trim();

    List<ResultRow> rows() => <ResultRow>[
          if (username.isNotEmpty)
            ResultRow(label: 'Username', value: username),
          if (email.isNotEmpty) ResultRow(label: 'Email', value: email),
        ];

    if (_emailAvail == Avail.taken || _nameAvail == Avail.taken) {
      setResult.state = ActionResult(
        success: false,
        kind: ActionKind.register,
        message: 'Регистрация не выполнена',
        description: 'Email или username уже заняты. '
            'Если это ваш аккаунт — войдите с помощью него.',
        rows: rows(),
      );
      router.push('/register-result');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await notifier.register(
        email: email,
        username: username,
        password: _passCtrl.text,
        passwordConfirm: _confirmCtrl.text,
      );
      setResult.state = ActionResult(
        success: true,
        kind: ActionKind.register,
        message: 'Регистрация прошла успешно',
        description: 'Аккаунт создан. Теперь войдите, чтобы продолжить.',
        rows: rows(),
      );
      router.go('/register-result');
    } catch (e) {
      setResult.state = ActionResult(
        success: false,
        kind: ActionKind.register,
        message: 'Регистрация не выполнена',
        description: _clean(e),
        rows: rows(),
      );
      router.push('/register-result');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = passwordRules(_passCtrl.text, _confirmCtrl.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const <String>[AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: 6),
                AvailBadge(status: _emailAvail),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _usernameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    helperText: 'Показывается на главном экране',
                    border: OutlineInputBorder(),
                  ),
                  validator: Validators.username,
                ),
                const SizedBox(height: 6),
                AvailBadge(status: _nameAvail),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure1,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure1 ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 8),
                RequirementsList(rules: rules),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure2,
                  decoration: InputDecoration(
                    labelText: 'Повторите пароль',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure2 ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                  validator: (v) =>
                      Validators.confirmPassword(v, _passCtrl.text),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Зарегистрироваться'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : () => context.go('/login'),
                  child: const Text('Уже есть аккаунт? Войти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows whether the value in the field is free to use.
class AvailBadge extends StatelessWidget {
  const AvailBadge({super.key, required this.status});

  final Avail status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (status) {
      case Avail.idle:
        return const SizedBox.shrink();
      case Avail.checking:
        return Row(
          children: <Widget>[
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text('Проверяем…', style: theme.textTheme.bodySmall),
          ],
        );
      case Avail.free:
        return _line(
          context,
          Icons.check_circle,
          'Свободен',
          Colors.green,
        );
      case Avail.taken:
        return _line(context, Icons.cancel, 'Занят', theme.colorScheme.error);
      case Avail.unknown:
        return _line(
          context,
          Icons.help_outline,
          'Не удалось проверить доступность',
          theme.colorScheme.outline,
        );
    }
  }

  Widget _line(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
  ) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Live password requirements checklist.
class RequirementsList extends StatelessWidget {
  const RequirementsList({super.key, required this.rules});

  final List<PasswordRule> rules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rules
          .map(
            (PasswordRule rule) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: <Widget>[
                  Icon(
                    rule.ok ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 16,
                    color: rule.ok ? Colors.green : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rule.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            rule.ok ? Colors.green : theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

String _clean(Object e) {
  final s = e.toString();
  const prefix = 'Exception: ';
  return s.startsWith(prefix) ? s.substring(prefix.length) : s;
}
