import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/use_cases/calculate_estimate.dart';

const _engine = EstimationEngine();

EstimateInput _baseInput() => const EstimateInput(
      floors: [FloorSpec(areaM2: 150, heightM: 3.0)],
      quality: 'Standard',
      foundation: 'Strip',
      soil: 'Firm',
      roof: 'Pitched sheet',
      typology: BuildingTypology.residentialStandard,
      constructionType: ConstructionType.blockMasonry,
      unitRateGhsPerM2: 4200.0,
      regionalIndex: 1.18,
      phasePercents: {},
      includeExternalWorks: false,
      externalWallLenM: 0,
      drivewayAreaM2: 0,
      includeSeptic: false,
      compoundWallRatePerM: 1200.0,
      drivewayRatePerM2: 350.0,
      septicLumpSum: 25000.0,
      preliminariesPct: 10.0,
      ohpPct: 10.0,
      contingencyEnabled: true,
      contingencyPct: 10.0,
      permitMode: PermitMode.percent,
      permitPct: 1.5,
      permitManualGhs: null,
      taxLines: [],
      professionalFeesEnabled: true,
      professionalFeesPct: 5.0,
    );

void main() {
  group('Performance — throughput', () {
    test('10,000 calculations complete with average < 1 ms and p99 < 5 ms', () {
      const iterations = 10000;
      final input = _baseInput();
      final latencies = <int>[];

      for (int i = 0; i < iterations; i++) {
        final sw = Stopwatch()..start();
        _engine.calculate(input);
        sw.stop();
        latencies.add(sw.elapsedMicroseconds);
      }

      latencies.sort();
      final totalUs = latencies.fold<int>(0, (a, b) => a + b);
      final avgMs = totalUs / iterations / 1000;
      final p99Ms = latencies[(iterations * 0.99).floor()] / 1000;

      expect(avgMs, lessThan(1.0),
          reason: 'Average latency $avgMs ms exceeds 1 ms target',);
      expect(p99Ms, lessThan(5.0),
          reason: 'p99 latency $p99Ms ms exceeds 5 ms target',);
    });
  });

  group('Performance — determinism', () {
    test('same input produces bit-identical results on repeated calls', () {
      final input = _baseInput();
      final r1 = _engine.calculate(input);
      final r2 = _engine.calculate(input);

      expect(r1.totalPlannedGhs,     equals(r2.totalPlannedGhs));
      expect(r1.costPerM2Ghs,        equals(r2.costPerM2Ghs));
      expect(r1.contingencyGhs,      equals(r2.contingencyGhs));
      expect(r1.professionalFeesGhs, equals(r2.professionalFeesGhs));
      expect(r1.phaseBreakdownGhs,   equals(r2.phaseBreakdownGhs));
    });
  });

  group('Performance — monotonic scaling with area', () {
    test('doubling floor area roughly doubles total cost (within 1.95–2.05)', () {
      const input150 = EstimateInput(
        floors: [FloorSpec(areaM2: 150, heightM: 3.0)],
        quality: 'Standard',
        foundation: 'Strip',
        soil: 'Firm',
        roof: 'Pitched sheet',
        typology: BuildingTypology.residentialStandard,
        constructionType: ConstructionType.blockMasonry,
        unitRateGhsPerM2: 4200.0,
        regionalIndex: 1.18,
        phasePercents: {},
        includeExternalWorks: false,
        externalWallLenM: 0,
        drivewayAreaM2: 0,
        includeSeptic: false,
        compoundWallRatePerM: 1200.0,
        drivewayRatePerM2: 350.0,
        septicLumpSum: 25000.0,
        preliminariesPct: 10.0,
        ohpPct: 10.0,
        contingencyEnabled: true,
        contingencyPct: 10.0,
        permitMode: PermitMode.percent,
        permitPct: 1.5,
        permitManualGhs: null,
        taxLines: [],
        professionalFeesEnabled: false,
        professionalFeesPct: 5.0,
      );

      const input300 = EstimateInput(
        floors: [FloorSpec(areaM2: 300, heightM: 3.0)],
        quality: 'Standard',
        foundation: 'Strip',
        soil: 'Firm',
        roof: 'Pitched sheet',
        typology: BuildingTypology.residentialStandard,
        constructionType: ConstructionType.blockMasonry,
        unitRateGhsPerM2: 4200.0,
        regionalIndex: 1.18,
        phasePercents: {},
        includeExternalWorks: false,
        externalWallLenM: 0,
        drivewayAreaM2: 0,
        includeSeptic: false,
        compoundWallRatePerM: 1200.0,
        drivewayRatePerM2: 350.0,
        septicLumpSum: 25000.0,
        preliminariesPct: 10.0,
        ohpPct: 10.0,
        contingencyEnabled: true,
        contingencyPct: 10.0,
        permitMode: PermitMode.percent,
        permitPct: 1.5,
        permitManualGhs: null,
        taxLines: [],
        professionalFeesEnabled: false,
        professionalFeesPct: 5.0,
      );

      final r150 = _engine.calculate(input150);
      final r300 = _engine.calculate(input300);
      final ratio = r300.totalPlannedGhs / r150.totalPlannedGhs;

      expect(ratio, greaterThan(1.95),
          reason: 'Ratio $ratio below 1.95 — cost does not scale linearly',);
      expect(ratio, lessThan(2.05),
          reason: 'Ratio $ratio above 2.05 — cost scales super-linearly',);
    });
  });
}
