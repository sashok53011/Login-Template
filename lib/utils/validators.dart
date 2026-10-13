import '../l10n/strings.dart';

/// Form field validators.
///
/// Every message is produced through [translate], so it follows the UI
/// language that the caller passes in. The default keeps the previous Russian
/// wording for callers that only test validity (without a language).
class Validators {
  Validators._();

  /// Minimum password length required by the PocketBase `users` collection.
  static const int passwordMinLength = 8;

  static String? email(String? value, [String language = 'ru']) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return translate('valid.emailRequired', language);
    final emailReg = RegExp(r'^[\w\-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailReg.hasMatch(v)) {
      return translate('valid.emailInvalid', language);
    }
    return null;
  }

  static String? username(String? value, [String language = 'ru']) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return translate('valid.usernameRequired', language);
    if (v.length < 3) return translate('valid.usernameMin', language);
    return null;
  }

  static String? password(String? value, [String language = 'ru']) {
    final v = value ?? '';
    if (v.isEmpty) return translate('valid.passwordRequired', language);
    if (v.length < passwordMinLength) {
      return translate(
        'valid.passwordMin',
        language,
        args: <String, String>{'n': '$passwordMinLength'},
      );
    }
    return null;
  }

  static String? confirmPassword(
    String? value,
    String password, [
    String language = 'ru',
  ]) {
    final v = value ?? '';
    if (v.isEmpty) return translate('valid.confirmRequired', language);
    if (v != password) return translate('valid.passwordMismatch', language);
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
List<PasswordRule> passwordRules(
  String password,
  String confirmation, [
  String language = 'ru',
]) {
  return <PasswordRule>[
    PasswordRule(
      translate(
        'valid.passwordMin',
        language,
        args: <String, String>{'n': '${Validators.passwordMinLength}'},
      ),
      password.length >= Validators.passwordMinLength,
    ),
    PasswordRule(
      translate('valid.passwordsMatch', language),
      confirmation.isNotEmpty && confirmation == password,
    ),
  ];
}
