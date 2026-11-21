/// Form validators shared by the login and registration screens.
/// Each returns an error message, or null when the value is valid.
class Validators {
  Validators._();

  static final RegExp _emailPattern =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email.';
    if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  /// Sign-in only checks presence; the policy is enforced at registration.
  static String? requiredPassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    return null;
  }

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Choose a password.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  static String? name(String? value, {required String label}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your $label.';
    if (v.length > 50) return '$label must be 50 characters or fewer.';
    return null;
  }
}
