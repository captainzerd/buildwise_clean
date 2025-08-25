// lib/core/data/ghana_catalog_adapter.dart
//
// Thin adapter that delegates to GhanaCostCatalog.
// NOTE: Do not "implements CostCatalogPort" unless you actually have it exported.
// This version avoids the implements_non_class error.

import 'cost_catalog.dart';

class GhanaCatalogAdapter {
  const GhanaCatalogAdapter();

  double baseCostPerSqm({required String region, required String city}) {
    // If you later vary by region/city, thread values here.
    return GhanaCostCatalog.baseCostPerSqm(
      buildType: BuildType.residential,
      quality: Quality.standard,
      site: SiteComplexity.normal,
    );
  }

  Map<String, double> phaseWeightsForRegion(String region) {
    return GhanaCostCatalog.phaseWeightsForRegion(region);
  }

  double additionalSubstructurePerSqmForExtraFloor({
    required int floorIndex,
    required double heightM,
  }) {
    return GhanaCostCatalog.additionalSubstructurePerSqmForExtraFloor(
      floorIndex: floorIndex,
      heightM: heightM,
    );
  }

  double stairsCostPerFlight({required double riseM}) {
    return GhanaCostCatalog.stairsCostPerFlight(riseM: riseM);
  }
}
