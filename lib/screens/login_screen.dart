import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/action_result.dart';
import '../providers/action_result_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/validators.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Captured before the first await: the auth redirect may dispose this
    // screen as soon as the login succeeds.
    final router = GoRouter.of(context);
    final notifier = ref.read(authProvider.notifier);
    final setResult = ref.read(actionResultProvider.notifier);
    final email = _emailCtrl.text.trim();

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final user = await notifier.login(email: email, password: _passCtrl.text);
      setResult.state = ActionResult(
        success: true,
        kind: ActionKind.login,
        message: 'Вход выполнен',
        description: 'Добро пожаловать! Вы вошли в аккаунт.',
        rows: <ResultRow>[
          if (user.username.isNotEmpty)
            ResultRow(label: 'Username', value: user.username),
          if (user.email.isNotEmpty)
            ResultRow(label: 'Email', value: user.email),
          if (user.id.isNotEmpty) ResultRow(label: 'Id', value: user.id),
        ],
      );
      router.go('/login-result');
    } catch (e) {
      setResult.state = ActionResult(
        success: false,
        kind: ActionKind.login,
        message: 'Вход не выполнен',
        description: _clean(e),
        rows: <ResultRow>[
          if (email.isNotEmpty) ResultRow(label: 'Email', value: email),
        ],
      );
      router.push('/login-result');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 32),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  autofillHints: const <String>[AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: Validators.password,
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
                      : const Text('Войти'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : () => context.go('/register'),
                  child: const Text('Ещё нет аккаунта? Зарегистрироваться'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _clean(Object e) {
  final s = e.toString();
  const prefix = 'Exception: ';
  return s.startsWith(prefix) ? s.substring(prefix.length) : s;
}
