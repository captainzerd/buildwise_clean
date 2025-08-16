import 'package:flutter_test/flutter_test.dart';
import 'package:buildwise/core/services/variance_service.dart';

void main() {
  test('variance calculations', () {
    const v = Variance(1000, 1200);
    expect(v.delta, 200);
    expect(v.pct, closeTo(0.2, 1e-9)); // 20%
  });

  test('zero budget -> pct = 0 (avoid div by zero)', () {
    const v = Variance(0, 500);
    expect(v.delta, 500);
    expect(v.pct, 0);
  });

  test('underrun negative delta', () {
    const v = Variance(1000, 800);
    expect(v.delta, -200);
    expect(v.pct, closeTo(-0.2, 1e-9));
  });
}
