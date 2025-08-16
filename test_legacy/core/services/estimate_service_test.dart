import 'package:flutter_test/flutter_test.dart';
// Prefer package import if your package name is "app". Otherwise use relative:
// import '../../lib/core/services/estimate_service.dart';
import 'package:buildwise/core/services/estimate_service.dart';

void main() {
  late EstimateService svc;

  setUp(() {
    svc = const EstimateService();
  });

  test('computes total and breakdown for typical sqft', () {
    final e = svc.generateEstimate(
      projectName: 'Villa',
      squareFootage: 250.0,
      filePaths: const [],
      region: 'Greater Accra',
      city: 'Accra',
    );

    expect(e.projectName, 'Villa');
    expect(e.squareFootage, 250);
    // Guard: totals consistent with breakdown
    final sum = e.breakdown.values.fold<double>(0, (a, b) => a + b);
    expect(e.totalCost, closeTo(sum, 0.01));
  });

  test('rounding: total matches sum of rounded breakdowns', () {
    final e = svc.generateEstimate(
      projectName: 'Rounding',
      squareFootage: 1234.56,
      filePaths: const [],
      region: 'Ashanti',
      city: 'Kumasi',
    );

    final sum = e.breakdown.values
        .map((v) => double.parse(v.toStringAsFixed(2)))
        .fold<double>(0, (a, b) => a + b);

    expect(double.parse(e.totalCost.toStringAsFixed(2)), closeTo(sum, 0.01));
  });

  test('zero sqft yields zero costs', () {
    final e = svc.generateEstimate(
      projectName: 'Zero',
      squareFootage: 0,
      filePaths: const [],
      region: 'Western',
      city: 'Takoradi',
    );
    expect(e.totalCost, 0);
    expect(e.breakdown.values.every((v) => v == 0), isTrue);
  });

  test('negative sqft throws', () {
    expect(
      () => svc.generateEstimate(
        projectName: 'Bad',
        squareFootage: -10,
        filePaths: const [],
        region: 'Greater Accra',
        city: 'Accra',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('very large sqft does not overflow', () {
    final e = svc.generateEstimate(
      projectName: 'Mega',
      squareFootage: 1e7, // 10 million sqft
      filePaths: const [],
      region: 'Greater Accra',
      city: 'Accra',
    );
    expect(e.totalCost.isFinite, isTrue);
    expect(e.totalCost, greaterThan(0));
  });
}
