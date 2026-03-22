import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/utils/validators.dart';

void main() {
  group('Validators.required', () {
    test('accepts non-empty string', () {
      expect(Validators.required('hello'), isNull);
    });
    test('rejects null', () {
      expect(Validators.required(null), isNotNull);
    });
    test('rejects empty string', () {
      expect(Validators.required(''), isNotNull);
    });
    test('rejects whitespace only', () {
      expect(Validators.required('   '), isNotNull);
    });
  });

  group('Validators.phone', () {
    test('accepts valid E.164 Ghana number', () {
      expect(Validators.phone('+233201234567'), isNull);
    });
    test('accepts valid E.164 other country', () {
      expect(Validators.phone('+447911123456'), isNull);
    });
    test('rejects local format without country code', () {
      expect(Validators.phone('0201234567'), isNotNull);
    });
    test('rejects empty (optional field)', () {
      expect(Validators.phone(''), isNull);
    });
    test('accepts null (optional field)', () {
      expect(Validators.phone(null), isNull);
    });
  });

  group('Validators.email', () {
    test('accepts valid email', () {
      expect(Validators.email('user@example.com'), isNull);
    });
    test('rejects missing @', () {
      expect(Validators.email('notanemail'), isNotNull);
    });
    test('rejects empty (optional field)', () {
      expect(Validators.email(''), isNull);
    });
    test('accepts null (optional field)', () {
      expect(Validators.email(null), isNull);
    });
  });
}
