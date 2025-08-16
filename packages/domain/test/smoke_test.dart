import 'package:buildwise_domain/buildwise_domain.dart';
import 'package:test/test.dart';

void main() {
  test('variance computes', () {
    expect(variance([1000]), 0); // single value -> 0
    expect(variance([1, 1, 1, 1]), 0); // all same -> 0
    expect(variance([1, 2, 3]), closeTo(2 / 3, 1e-9)); // population variance
  });
}
