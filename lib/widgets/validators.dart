class Validators {
  static String? requiredText(String? v, {String name = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$name is required';
    return null;
  }

  static String? positiveNumber(String? v, {String name = 'Value'}) {
    if (v == null || v.trim().isEmpty) return '$name is required';
    final n = double.tryParse(v);
    if (n == null || n <= 0) return '$name must be greater than 0';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final re = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (!re.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? displayName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    if (v.trim().length < 2) return 'Name must be at least 2 characters';
    if (v.trim().length > 80) return 'Name must be 80 characters or fewer';
    return null;
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? rangeDouble(
    String? v, {
    required double min,
    required double max,
    String name = 'Value',
  }) {
    if (v == null || v.trim().isEmpty) return '$name is required';
    final n = double.tryParse(v);
    if (n == null) return '$name must be a number';
    if (n < min || n > max) return '$name must be between $min and $max';
    return null;
  }
}
