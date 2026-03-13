import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/errors/app_exception.dart';

void main() {
  group('AppException.from', () {
    test('returns same AppException if already AppException', () {
      final ex = const AppException('already friendly');
      expect(AppException.from(ex).message, 'already friendly');
    });

    test('wraps generic Dart exception with non-empty message', () {
      final result = AppException.from(Exception('some internal error'));
      expect(result.message, isNotEmpty);
    });

    test('from with AppException is idempotent', () {
      const ex = AppException('test message');
      final result = AppException.from(ex);
      expect(result.message, 'test message');
    });
  });

  group('AppException.fromFirebase', () {
    test('maps permission-denied to friendly message', () {
      final fe = FirebaseException(
          plugin: 'cloud_firestore', code: 'permission-denied',);
      expect(
        AppException.from(fe).message,
        "You don't have permission to do that.",
      );
    });

    test('maps not-found to friendly message', () {
      final fe =
          FirebaseException(plugin: 'cloud_firestore', code: 'not-found');
      expect(
        AppException.from(fe).message,
        'The requested data was not found.',
      );
    });

    test('maps unavailable to friendly message', () {
      final fe =
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      expect(
        AppException.from(fe).message,
        'Service temporarily unavailable. Please try again.',
      );
    });

    test('maps deadline-exceeded to friendly message', () {
      final fe = FirebaseException(
          plugin: 'cloud_firestore', code: 'deadline-exceeded',);
      expect(
        AppException.from(fe).message,
        'Request timed out. Check your connection.',
      );
    });

    test('maps resource-exhausted to friendly message', () {
      final fe = FirebaseException(
          plugin: 'cloud_firestore', code: 'resource-exhausted',);
      expect(
        AppException.from(fe).message,
        'Too many requests. Please wait a moment.',
      );
    });

    test('maps unauthenticated to friendly message', () {
      final fe =
          FirebaseException(plugin: 'firebase_auth', code: 'unauthenticated');
      expect(
        AppException.from(fe).message,
        'Please sign in to continue.',
      );
    });

    test('maps network-request-failed to friendly message', () {
      final fe = FirebaseException(
          plugin: 'firebase_auth', code: 'network-request-failed',);
      expect(
        AppException.from(fe).message,
        'Network error. Check your connection.',
      );
    });

    test('maps already-exists to friendly message', () {
      final fe =
          FirebaseException(plugin: 'cloud_firestore', code: 'already-exists');
      expect(
        AppException.from(fe).message,
        'This record already exists.',
      );
    });

    test('maps cancelled to friendly message', () {
      final fe =
          FirebaseException(plugin: 'cloud_firestore', code: 'cancelled');
      expect(
        AppException.from(fe).message,
        'Operation was cancelled.',
      );
    });

    test('maps unknown code to raw message when present', () {
      final fe = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unknown-code',
        message: 'some internal message',
      );
      expect(AppException.from(fe).message, 'some internal message');
    });

    test('maps unknown code with no message to fallback string', () {
      final fe =
          FirebaseException(plugin: 'cloud_firestore', code: 'unknown-code');
      expect(
          AppException.from(fe).message, 'Something went wrong. Please try again.',);
    });

    test('fromFirebase preserves the error code', () {
      final fe = FirebaseException(
          plugin: 'cloud_firestore', code: 'permission-denied',);
      expect(AppException.from(fe).code, 'permission-denied');
    });
  });
}
