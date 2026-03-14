import 'package:firebase_core/firebase_core.dart';

/// Application-level exception with a user-friendly message.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;

  /// Convert a raw Firebase exception to a user-friendly AppException.
  static AppException fromFirebase(FirebaseException e) =>
      AppException(_friendlyFirebaseMessage(e), code: e.code);

  /// Convert any error to an AppException.
  static AppException from(Object e) {
    if (e is AppException) return e;
    if (e is FirebaseException) return fromFirebase(e);
    return AppException(e.toString());
  }

  static String _friendlyFirebaseMessage(FirebaseException e) =>
      switch (e.code) {
        'permission-denied' => "You don't have permission to do that.",
        'not-found' => 'The requested data was not found.',
        'unavailable' =>
          'Service temporarily unavailable. Please try again.',
        'deadline-exceeded' => 'Request timed out. Check your connection.',
        'resource-exhausted' => 'Too many requests. Please wait a moment.',
        'unauthenticated' => 'Please sign in to continue.',
        'network-request-failed' => 'Network error. Check your connection.',
        'already-exists' => 'This record already exists.',
        'cancelled' => 'Operation was cancelled.',
        _ => e.message ?? 'Something went wrong. Please try again.',
      };
}
