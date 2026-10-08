/// Form field validators.
class Validators {
  Validators._();

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Введите email';
    final emailReg = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');
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
    if (v.length < 6) return 'Минимум 6 символов';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final v = value ?? '';
    if (v.isEmpty) return 'Повторите пароль';
    if (v != password) return 'Пароли не совпадают';
    return null;
  }
}
