import 'package:test/test.dart';
import 'package:buildwise_domain/buildwise_domain.dart';

void main() {
  test('estimate total = sum of phaseBudget', () {
    final est = Estimate(
      id: 'e1',
      projectName: 'P',
      phaseBudget: {'foundation': 1200, 'roofing': 800},
    );
    expect(est.total, 2000);
  });
}
