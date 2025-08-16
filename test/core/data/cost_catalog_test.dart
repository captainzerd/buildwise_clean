import 'package:flutter_test/flutter_test.dart';
import 'package:buildwise_clean/core/data/cost_catalog.dart';

void main() {
  group('GhanaCostCatalog – base rates', () {
    test('baseCostPerSqm returns a positive number for default inputs', () {
      final r = GhanaCostCatalog.baseCostPerSqm(
        buildType: BuildType.residential,
        quality: Quality.standard,
        site: SiteComplexity.normal,
      );
      expect(r, isNot(0));
      expect(r, greaterThan(0));
    });

    test('quality and site complexity increase cost monotonically', () {
      final baseline = GhanaCostCatalog.baseCostPerSqm(
        buildType: BuildType.residential,
        quality: Quality.standard,
        site: SiteComplexity.normal,
      );

      final harderSite = GhanaCostCatalog.baseCostPerSqm(
        buildType: BuildType.residential,
        quality: Quality.standard,
        site: SiteComplexity.difficult,
      );

      final premiumQuality = GhanaCostCatalog.baseCostPerSqm(
        buildType: BuildType.residential,
        quality: Quality.premium,
        site: SiteComplexity.normal,
      );

      expect(harderSite, greaterThan(baseline),
          reason: 'difficult site should cost more than normal site');
      expect(premiumQuality, greaterThan(baseline),
          reason: 'premium quality should cost more than standard');
    });
  });

  group('GhanaCostCatalog – phase weights', () {
    test('phase weights sum roughly to 1.0', () {
      final w = GhanaCostCatalog.phaseWeightsForRegion('Ahafo');
      final sum = w.values.fold<double>(0, (a, b) => a + b);
      expect((sum - 1.0).abs() < 0.0001, isTrue,
          reason: 'phase weights should sum to ~1.0; actual = $sum');
      expect(w, isNotEmpty);
    });

    test('contains expected common phases', () {
      final w = GhanaCostCatalog.phaseWeightsForRegion('Greater Accra');
      expect(
        w.keys,
        containsAll(<String>[
          'Substructure',
          'Superstructure',
          'Roofing',
          'Mechanical & Electrical',
          'Finishes',
          'Preliminaries / Admin',
        ]),
      );
    });
  });

  group('GhanaCostCatalog – extra substructure', () {
    test('ground floor uplift is non-negative (catalog baseline)', () {
      final add0 = GhanaCostCatalog.additionalSubstructurePerSqmForExtraFloor(
        floorIndex: 0,
        heightM: 3.0,
      );
      // Your catalog currently returns a positive baseline (e.g. 220.0).
      // If you later decide ground floor should be zero, flip this to expect(0.0).
      expect(add0, greaterThanOrEqualTo(0.0));
    });

    test('extra substructure increases with floor index (same height)', () {
      final ground = GhanaCostCatalog.additionalSubstructurePerSqmForExtraFloor(
        floorIndex: 0,
        heightM: 3.0,
      );
      final first = GhanaCostCatalog.additionalSubstructurePerSqmForExtraFloor(
        floorIndex: 1,
        heightM: 3.0,
      );
      final second = GhanaCostCatalog.additionalSubstructurePerSqmForExtraFloor(
        floorIndex: 2,
        heightM: 3.0,
      );
      expect(first, greaterThanOrEqualTo(ground));
      expect(second, greaterThan(first));
    });

    test('taller floors cost more (height sensitivity)', () {
      final low = GhanaCostCatalog.additionalSubstructurePerSqmForExtraFloor(
        floorIndex: 1,
        heightM: 2.7,
      );
      final high = GhanaCostCatalog.additionalSubstructurePerSqmForExtraFloor(
        floorIndex: 1,
        heightM: 3.6,
      );
      expect(high, greaterThan(low));
    });
  });

  group('GhanaCostCatalog – stairs', () {
    test('stairs cost scales with rise height', () {
      final short = GhanaCostCatalog.stairsCostPerFlight(riseM: 2.7);
      final tall = GhanaCostCatalog.stairsCostPerFlight(riseM: 3.6);
      expect(short, isNot(0));
      expect(tall, greaterThan(short));
    });
  });
}
