// test/estimate_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:buildwise/core/services/estimate_service.dart';

void main() {
  test('creates estimate and totals planned', () {
    final svc = EstimateService();
    final est = svc.create(
      projectName: 'P1',
      phasePlanned: {'A': 100, 'B': 50},
    );
    expect(est.totalPlanned, 150);
    expect(svc.list().length, 1);
  });
}
