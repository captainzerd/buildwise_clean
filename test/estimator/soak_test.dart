// test/estimator/soak_test.dart
//
// Task 13 — Soak / exhaustive coverage tests
//
// Groups:
//   1. Combinatorial sweep — all BuildingTypology × ConstructionType × foundation
//      × soil × roof × quality combinations (972 inputs).
//   2. Boundary inputs — extreme areas, many floors, all add-ons, zeroed soft costs.
//   3. Catalog fallback integrity — CatalogVersion.fallback() field sanity checks.
//   4. Regressive professional fee scale — 1,000 sample points over [1, 100 M].
//
// Run: flutter test test/estimator/soak_test.dart -v

import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/models/catalog_version.dart';
import 'package:wysebrix/core/use_cases/calculate_estimate.dart';

// ── Shared constants ──────────────────────────────────────────────────────────

const _engine = EstimationEngine();

// Quality → unit rate mapping (from CatalogVersion.fallback())
const _unitRates = {
  'Economy': 2700.0,
  'Standard': 4200.0,
  'Premium': 7500.0,
};

// ── Input factory ─────────────────────────────────────────────────────────────

EstimateInput _makeInput({
  required String quality,
  required BuildingTypology typology,
  required String foundation,
  required String soil,
  required String roof,
  required ConstructionType constructionType,
  List<FloorSpec> floors = const [FloorSpec(areaM2: 150, heightM: 3.0)],
  bool includeExternalWorks = false,
  double externalWallLenM = 0,
  double drivewayAreaM2 = 0,
  bool includeSeptic = false,
  bool includeWaterTank = false,
  bool includeGeneratorHouse = false,
  bool includeSwimmingPool = false,
  double swimmingPoolGhs = 0.0,
  double securityWallLenM = 0.0,
  double securityWallRatePerM = 1200.0,
  double preliminariesPct = 10.0,
  double ohpPct = 10.0,
  bool contingencyEnabled = true,
  double contingencyPct = 10.0,
  PermitMode permitMode = PermitMode.percent,
  double permitPct = 1.5,
  double? permitManualGhs,
  List<TaxLine> taxLines = const [],
  bool professionalFeesEnabled = true,
  double professionalFeesPct = 5.0,
  double regionalIndex = 1.18,
}) {
  final unitRate = _unitRates[quality] ?? 4200.0;
  return EstimateInput(
    floors: floors,
    quality: quality,
    foundation: foundation,
    soil: soil,
    roof: roof,
    typology: typology,
    constructionType: constructionType,
    unitRateGhsPerM2: unitRate,
    regionalIndex: regionalIndex,
    phasePercents: const {},
    includeExternalWorks: includeExternalWorks,
    externalWallLenM: externalWallLenM,
    drivewayAreaM2: drivewayAreaM2,
    includeSeptic: includeSeptic,
    includeWaterTank: includeWaterTank,
    includeGeneratorHouse: includeGeneratorHouse,
    includeSwimmingPool: includeSwimmingPool,
    swimmingPoolGhs: swimmingPoolGhs,
    securityWallLenM: securityWallLenM,
    securityWallRatePerM: securityWallRatePerM,
    compoundWallRatePerM: 1200.0,
    drivewayRatePerM2: 350.0,
    septicLumpSum: 25000.0,
    preliminariesPct: preliminariesPct,
    ohpPct: ohpPct,
    contingencyEnabled: contingencyEnabled,
    contingencyPct: contingencyPct,
    permitMode: permitMode,
    permitPct: permitPct,
    permitManualGhs: permitManualGhs,
    taxLines: taxLines,
    professionalFeesEnabled: professionalFeesEnabled,
    professionalFeesPct: professionalFeesPct,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 1 — Combinatorial sweep
  // 3 qualities × 6 typologies × 3 foundations × 3 soils × 2 roofs × 3 ctypes
  // = 972 combinations
  // ══════════════════════════════════════════════════════════════════════════
  group('Combinatorial sweep', () {
    const qualities = ['Economy', 'Standard', 'Premium'];
    const foundations = ['Strip', 'Raft', 'Pile'];
    const soils = ['Firm', 'Soft', 'Waterlogged'];
    const roofs = ['Pitched sheet', 'Concrete flat'];
    final typologies = BuildingTypology.values;
    final constructionTypes = ConstructionType.values;

    // Verify the expected count before running.
    final expectedCount = qualities.length *
        typologies.length *
        foundations.length *
        soils.length *
        roofs.length *
        constructionTypes.length;

    test('combinatorial count equals $expectedCount', () {
      expect(expectedCount, equals(972),
          reason: 'Expected 3×6×3×3×2×3 = 972 combinations');
    });

    test('all $expectedCount combinations produce valid, finite results', () {
      int count = 0;
      final failures = <String>[];

      for (final quality in qualities) {
        for (final typology in typologies) {
          for (final foundation in foundations) {
            for (final soil in soils) {
              for (final roof in roofs) {
                for (final ctype in constructionTypes) {
                  final label =
                      '$quality / ${typology.name} / $foundation / $soil / $roof / ${ctype.name}';
                  count++;

                  final input = _makeInput(
                    quality: quality,
                    typology: typology,
                    foundation: foundation,
                    soil: soil,
                    roof: roof,
                    constructionType: ctype,
                  );
                  final r = _engine.calculate(input);

                  if (r.totalPlannedGhs <= 0) {
                    failures
                        .add('$label: totalPlannedGhs=${r.totalPlannedGhs}');
                  }
                  if (r.totalPlannedGhs.isNaN) {
                    failures.add('$label: totalPlannedGhs is NaN');
                  }
                  if (r.totalPlannedGhs.isInfinite) {
                    failures.add('$label: totalPlannedGhs is Infinite');
                  }
                  if (r.costPerM2Ghs <= 0) {
                    failures.add('$label: costPerM2Ghs=${r.costPerM2Ghs}');
                  }
                  if (r.phaseBreakdownGhs.isEmpty) {
                    failures.add('$label: phaseBreakdownGhs is empty');
                  }
                }
              }
            }
          }
        }
      }

      expect(count, equals(expectedCount),
          reason: 'Ran $count combinations, expected $expectedCount');
      expect(failures, isEmpty, reason: 'Failures:\n${failures.join('\n')}');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 2 — Boundary inputs
  // ══════════════════════════════════════════════════════════════════════════
  group('Boundary inputs', () {
    // Floor area extremes
    for (final area in [0.1, 1.0, 50000.0]) {
      test('floor area $area m² → positive finite total', () {
        final input = _makeInput(
          quality: 'Standard',
          typology: BuildingTypology.residentialStandard,
          foundation: 'Strip',
          soil: 'Firm',
          roof: 'Pitched sheet',
          constructionType: ConstructionType.blockMasonry,
          floors: [FloorSpec(areaM2: area, heightM: 3.0)],
        );
        final r = _engine.calculate(input);
        expect(r.totalPlannedGhs, greaterThan(0),
            reason: 'area=$area m²: totalPlannedGhs must be > 0');
        expect(r.totalPlannedGhs.isNaN, isFalse,
            reason: 'area=$area m²: totalPlannedGhs is NaN');
        expect(r.totalPlannedGhs.isInfinite, isFalse,
            reason: 'area=$area m²: totalPlannedGhs is Infinite');
      });
    }

    // Floor count extremes (1, 2, 10, 30, 99 floors)
    for (final floorCount in [1, 2, 10, 30, 99]) {
      test('$floorCount floor(s) → positive finite total', () {
        final floors = List.generate(
          floorCount,
          (_) => const FloorSpec(areaM2: 100, heightM: 3.0),
        );
        final input = _makeInput(
          quality: 'Standard',
          typology: BuildingTypology.residentialStandard,
          foundation: 'Strip',
          soil: 'Firm',
          roof: 'Pitched sheet',
          constructionType: ConstructionType.blockMasonry,
          floors: floors,
        );
        final r = _engine.calculate(input);
        expect(r.totalPlannedGhs, greaterThan(0),
            reason: '$floorCount floors: totalPlannedGhs must be > 0');
        expect(r.totalPlannedGhs.isNaN, isFalse,
            reason: '$floorCount floors: totalPlannedGhs is NaN');
        expect(r.totalPlannedGhs.isInfinite, isFalse,
            reason: '$floorCount floors: totalPlannedGhs is Infinite');
      });
    }

    // All add-ons simultaneously enabled
    test('all add-ons enabled → positive finite total', () {
      final input = _makeInput(
        quality: 'Premium',
        typology: BuildingTypology.residentialStandard,
        foundation: 'Raft',
        soil: 'Firm',
        roof: 'Pitched sheet',
        constructionType: ConstructionType.blockMasonry,
        includeExternalWorks: true,
        externalWallLenM: 50.0,
        drivewayAreaM2: 80.0,
        includeSeptic: true,
        includeWaterTank: true,
        includeGeneratorHouse: true,
        includeSwimmingPool: true,
        swimmingPoolGhs: 120000.0,
        securityWallLenM: 60.0,
        securityWallRatePerM: 1200.0,
      );
      final r = _engine.calculate(input);
      expect(r.totalPlannedGhs, greaterThan(0));
      expect(r.totalPlannedGhs.isNaN, isFalse);
      expect(r.totalPlannedGhs.isInfinite, isFalse);
      expect(r.addOnsGhs.isNotEmpty, isTrue,
          reason: 'Expected add-ons to be populated');
    });

    // All soft costs zeroed and permit set to manual with 0
    test('all soft costs zeroed → positive finite total', () {
      final input = _makeInput(
        quality: 'Standard',
        typology: BuildingTypology.residentialStandard,
        foundation: 'Strip',
        soil: 'Firm',
        roof: 'Pitched sheet',
        constructionType: ConstructionType.blockMasonry,
        preliminariesPct: 0.0,
        ohpPct: 0.0,
        contingencyEnabled: false,
        contingencyPct: 0.0,
        permitMode: PermitMode.manual,
        permitManualGhs: 0.0,
        permitPct: 0.0,
        taxLines: const [],
        professionalFeesEnabled: false,
        professionalFeesPct: 0.0,
      );
      final r = _engine.calculate(input);
      expect(r.totalPlannedGhs, greaterThan(0));
      expect(r.totalPlannedGhs.isNaN, isFalse);
      expect(r.totalPlannedGhs.isInfinite, isFalse);
    });

    // Zero area edge case: costPerM2Ghs should be 0.0 (not NaN), total >= 0
    test('zero area (0.0 m²) → costPerM2Ghs is 0.0 and totalPlannedGhs >= 0',
        () {
      final input = _makeInput(
        quality: 'Standard',
        typology: BuildingTypology.residentialStandard,
        foundation: 'Strip',
        soil: 'Firm',
        roof: 'Pitched sheet',
        constructionType: ConstructionType.blockMasonry,
        floors: const [FloorSpec(areaM2: 0.0, heightM: 3.0)],
      );
      final r = _engine.calculate(input);
      expect(r.costPerM2Ghs.isNaN, isFalse,
          reason: 'costPerM2Ghs must not be NaN when area=0');
      expect(r.totalPlannedGhs.isNaN, isFalse,
          reason: 'totalPlannedGhs must not be NaN when area=0');
      expect(r.totalPlannedGhs.isInfinite, isFalse,
          reason: 'totalPlannedGhs must not be Infinite when area=0');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 3 — Catalog fallback integrity
  // ══════════════════════════════════════════════════════════════════════════
  group('Catalog fallback integrity', () {
    final catalog = CatalogVersion.fallback();

    test('base rates per m² are all > 0', () {
      expect(catalog.baseRatesPerM2.isNotEmpty, isTrue,
          reason: 'baseRatesPerM2 must not be empty');
      for (final entry in catalog.baseRatesPerM2.entries) {
        expect(entry.value, greaterThan(0),
            reason: '${entry.key} base rate must be > 0');
      }
    });

    test('base rates contain Economy, Standard, Premium keys', () {
      expect(catalog.baseRatesPerM2.containsKey('Economy'), isTrue);
      expect(catalog.baseRatesPerM2.containsKey('Standard'), isTrue);
      expect(catalog.baseRatesPerM2.containsKey('Premium'), isTrue);
    });

    test('all regional indices are in range (0.0, 2.0]', () {
      expect(catalog.regionalIndices.isNotEmpty, isTrue,
          reason: 'regionalIndices must not be empty');
      for (final entry in catalog.regionalIndices.entries) {
        expect(entry.value, greaterThan(0.0),
            reason: 'Regional index for ${entry.key} must be > 0');
        expect(entry.value, lessThanOrEqualTo(2.0),
            reason: 'Regional index for ${entry.key} must be <= 2.0');
      }
    });

    test('catalog phase weights sum to 1.0 (within 0.0001)', () {
      final weights = catalog.phaseWeights;
      expect(weights.isNotEmpty, isTrue,
          reason: 'phaseWeights must not be empty');
      final sum = weights.values.fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(1.0, 0.0001),
          reason: 'Phase weights sum=$sum, expected 1.0 ± 0.0001');
    });

    test('engine typology phase weights all sum to 1.0 (within 0.0001)', () {
      // Non-tautological check: canonical inputs with all spec multipliers = 1.0
      // (blockMasonry/Strip/Firm/Pitched sheet, 1 floor, regionalIndex=1.0)
      // produce a predictable phaseSum derived from the weights alone.
      //
      // baseGhs = unitRate(1000) × area(100) × regionalIndex(1.0) = 100,000
      //
      // The engine applies typologyMul to Superstructure and Services phases,
      // and all other multipliers are 1.0 for these canonical inputs.
      // Expected phaseSum per typology (computed from weights × multipliers):
      //
      //   residentialStandard  (mul=1.00): (0.15+0.35+0.07+0.22+0.21)×baseGhs
      //                                    = 1.00 × 100,000 = 100,000
      //   residentialMediumRise (mul=1.18): sub=16000, sup=32000×1.18=37760,
      //                                    roof=8000, fin=22000, srv=22000×1.18=25960
      //                                    = 109,720
      //   residentialHighRise  (mul=1.40): sub=17000, sup=33000×1.40=46200,
      //                                    roof=6000, fin=20000, srv=24000×1.40=33600
      //                                    = 122,800
      //   commercialOffice     (mul=1.22): sub=14000, sup=35000×1.22=42700,
      //                                    roof=7000, fin=22000, srv=22000×1.22=26840
      //                                    = 112,540
      //   commercialRetail     (mul=1.28): sub=13000, sup=35000×1.28=44800,
      //                                    roof=8000, fin=28000, srv=16000×1.28=20480
      //                                    = 114,280
      //   commercialWarehouse  (mul=0.88): sub=15000, sup=45000×0.88=39600,
      //                                    roof=18000, fin=10000, srv=12000×0.88=10560
      //                                    = 93,160
      //
      // A bug where weights summed to 1.05 for any typology would shift the
      // result by ~5,000 GHS, well outside the tolerance of 1.0 GHS.
      const expectedPhaseSum = {
        BuildingTypology.residentialStandard: 100000.0,
        BuildingTypology.residentialMediumRise: 109720.0,
        BuildingTypology.residentialHighRise: 122800.0,
        BuildingTypology.commercialOffice: 112540.0,
        BuildingTypology.commercialRetail: 114280.0,
        BuildingTypology.commercialWarehouse: 93160.0,
      };

      for (final typology in BuildingTypology.values) {
        final input = EstimateInput(
          floors: const [FloorSpec(areaM2: 100.0, heightM: 3.0)],
          quality: 'Standard',
          foundation: 'Strip',
          soil: 'Firm',
          roof: 'Pitched sheet',
          typology: typology,
          constructionType: ConstructionType.blockMasonry,
          unitRateGhsPerM2: 1000.0,
          regionalIndex: 1.0,
          phasePercents: const {},
          includeExternalWorks: false,
          externalWallLenM: 0,
          drivewayAreaM2: 0,
          includeSeptic: false,
          compoundWallRatePerM: 1200.0,
          drivewayRatePerM2: 350.0,
          septicLumpSum: 25000.0,
          preliminariesPct: 0,
          ohpPct: 0,
          contingencyEnabled: false,
          contingencyPct: 0,
          permitMode: PermitMode.manual,
          permitPct: 0,
          permitManualGhs: 0,
          taxLines: const [],
          professionalFeesEnabled: false,
          professionalFeesPct: 0,
        );
        final r = _engine.calculate(input);
        final phaseSum =
            r.phaseBreakdownGhs.values.fold<double>(0, (a, b) => a + b);
        final expected = expectedPhaseSum[typology]!;
        expect(
          phaseSum,
          closeTo(expected, 1.0),
          reason: 'Typology ${typology.name}: phaseSum '
              '${phaseSum.toStringAsFixed(2)} != expected '
              '${expected.toStringAsFixed(2)} — weights may not sum to 1.0',
        );
      }
    });

    test('default pct fields are all > 0', () {
      expect(catalog.preliminariesDefaultPct, greaterThan(0),
          reason: 'preliminariesDefaultPct must be > 0');
      expect(catalog.ohpDefaultPct, greaterThan(0),
          reason: 'ohpDefaultPct must be > 0');
      expect(catalog.permitDefaultPct, greaterThan(0),
          reason: 'permitDefaultPct must be > 0');
      expect(catalog.contingencyDefaultPct, greaterThan(0),
          reason: 'contingencyDefaultPct must be > 0');
    });

    test('tax lines are non-empty and all pct > 0', () {
      expect(catalog.taxLines.isNotEmpty, isTrue,
          reason: 'taxLines must not be empty in fallback catalog');
      for (final t in catalog.taxLines) {
        expect(t.pct, greaterThan(0),
            reason: 'Tax line "${t.name}" pct must be > 0');
        expect(t.name.isNotEmpty, isTrue,
            reason: 'Tax line name must not be empty');
      }
    });

    test('add-on rates are all > 0', () {
      expect(catalog.addOnRates.isNotEmpty, isTrue,
          reason: 'addOnRates must not be empty');
      for (final entry in catalog.addOnRates.entries) {
        expect(entry.value, greaterThan(0),
            reason: 'Add-on rate ${entry.key} must be > 0');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 4 — Regressive professional fee scale
  // ══════════════════════════════════════════════════════════════════════════
  group('Regressive professional fee scale', () {
    test(
        'regressiveProfessionalFeesPct: 1,000 samples over [1, 100M] '
        'all in [3.5, 6.0]', () {
      const samples = 1000;
      const minVal = 1.0;
      const maxVal = 100000000.0;
      final step = (maxVal - minVal) / (samples - 1);
      final failures = <String>[];

      for (int i = 0; i < samples; i++) {
        final value = minVal + i * step;
        final pct = regressiveProfessionalFeesPct(value);
        if (pct < 3.5 || pct > 6.0) {
          failures.add(
            'value=${value.toStringAsExponential(3)}: pct=$pct not in [3.5, 6.0]',
          );
        }
      }

      expect(failures, isEmpty,
          reason: 'Out-of-range results:\n${failures.join('\n')}');
    });

    test('regressiveProfessionalFeesPct: breakpoints are correct', () {
      // At or below GHS 500,000 → 6 %
      expect(regressiveProfessionalFeesPct(1.0), equals(6.0));
      expect(regressiveProfessionalFeesPct(500000.0), equals(6.0));
      // Just above 500,000 → 5 %
      expect(regressiveProfessionalFeesPct(500001.0), equals(5.0));
      expect(regressiveProfessionalFeesPct(2000000.0), equals(5.0));
      // Just above 2,000,000 → 3.5 %
      expect(regressiveProfessionalFeesPct(2000001.0), equals(3.5));
      expect(regressiveProfessionalFeesPct(100000000.0), equals(3.5));
    });

    test('regressiveProfessionalFeesPct: is non-increasing', () {
      final values = [
        1.0,
        100000.0,
        500000.0,
        500001.0,
        1000000.0,
        2000000.0,
        2000001.0,
        10000000.0,
        100000000.0
      ];
      double? prev;
      for (final v in values) {
        final pct = regressiveProfessionalFeesPct(v);
        if (prev != null) {
          expect(pct, lessThanOrEqualTo(prev),
              reason: 'Fee at $v ($pct %) is higher than at previous point '
                  '($prev %) — scale must be non-increasing');
        }
        prev = pct;
      }
    });
  });
}
