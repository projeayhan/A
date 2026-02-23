/// Password and input validators for admin panel
class PasswordValidator {
  static const int minLength = 8;

  /// Validate password complexity
  static String? validate(String? password) {
    if (password == null || password.isEmpty) return 'Şifre gerekli';
    if (password.length < minLength) return 'Şifre en az $minLength karakter olmalı';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'En az bir büyük harf olmalı';
    if (!password.contains(RegExp(r'[a-z]'))) return 'En az bir küçük harf olmalı';
    if (!password.contains(RegExp(r'[0-9]'))) return 'En az bir rakam olmalı';
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]'))) {
      return 'En az bir özel karakter olmalı';
    }
    return null;
  }

  /// Get password strength as 0.0 - 1.0
  static double getStrength(String password) {
    if (password.isEmpty) return 0;
    double strength = 0;
    if (password.length >= minLength) strength += 0.2;
    if (password.length >= 12) strength += 0.1;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.15;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.15;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]'))) strength += 0.2;
    return strength.clamp(0.0, 1.0);
  }

  /// Email validator
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) return 'E-posta gerekli';
    if (!RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(email)) {
      return 'Geçerli bir e-posta girin';
    }
    return null;
  }
}
