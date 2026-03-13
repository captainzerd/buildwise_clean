// lib/core/utils/validators.dart
//
// Pure functions for TextFormField.validator.
// Returns null if valid, or a user-friendly error string if invalid.

abstract class Validators {
  /// Required field — rejects null, empty, and whitespace-only.
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  /// Optional phone — must be E.164 format if provided (+CountryCodeNumber).
  /// Returns null for null/empty (field is optional).
  static String? phone(String? value) {
    if (value == null || value.isEmpty) return null;
    final e164 = RegExp(r'^\+[1-9]\d{6,14}$');
    if (!e164.hasMatch(value)) {
      return 'Enter phone in international format, e.g. +233201234567';
    }
    return null;
  }

  /// Optional email — must be valid format if provided.
  static String? email(String? value) {
    if (value == null || value.isEmpty) return null;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}
