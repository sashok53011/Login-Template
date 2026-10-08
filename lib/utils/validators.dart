/// Form field validators.
class Validators {
  Validators._();

  /// Minimum password length required by the PocketBase `users` collection.
  static const int passwordMinLength = 8;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Введите email';
    final emailReg = RegExp(r'^[\w\-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailReg.hasMatch(v)) return 'Некорректный email';
    return null;
  }

  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Введите username';
    if (v.length < 3) return 'Минимум 3 символа';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Введите пароль';
    if (v.length < passwordMinLength) {
      return 'Минимум $passwordMinLength символов';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final v = value ?? '';
    if (v.isEmpty) return 'Повторите пароль';
    if (v != password) return 'Пароли не совпадают';
    return null;
  }
}

/// A single live password rule shown in the registration form checklist.
class PasswordRule {
  const PasswordRule(this.label, this.ok);

  final String label;
  final bool ok;
}

/// Requirements evaluated on every keystroke: `[password, passwordMatch]`.
List<PasswordRule> passwordRules(String password, String confirmation) {
  return <PasswordRule>[
    PasswordRule(
      'Минимум ${Validators.passwordMinLength} символов',
      password.length >= Validators.passwordMinLength,
    ),
    PasswordRule(
      'Пароли совпадают',
      confirmation.isNotEmpty && confirmation == password,
    ),
  ];
}
