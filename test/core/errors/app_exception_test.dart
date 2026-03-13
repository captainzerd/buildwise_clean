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
}
