// lib/core/data/ghana_catalog_adapter.dart
//
// Bridges the domain-facing CostCatalogPort to the concrete GhanaCostCatalog.

import 'cost_catalog.dart' as cat;
import '../services/estimate_service.dart';

class GhanaCatalogAdapter implements CostCatalogPort {
  const GhanaCatalogAdapter();

  @override
  double baseCostPerSqm({required String region, required String city}) {
    // If you later want region/city-specific baselines, thread them in here.
    return cat.GhanaCostCatalog.baseCostPerSqm(
      buildType: cat.BuildType.residential,
      quality: cat.Quality.standard,
      site: cat.SiteComplexity.normal,
    );
  }

  @override
  Map<String, double> phaseWeightsForRegion(String region) {
    return cat.GhanaCostCatalog.phaseWeightsForRegion(region);
  }

  @override
  double additionalSubstructurePerSqmForExtraFloor({
    required int floorIndex,
    required double heightM,
  }) {
    return cat.GhanaCostCatalog.additionalSubstructurePerSqmForExtraFloor(
      floorIndex: floorIndex,
      heightM: heightM,
    );
  }

  @override
  double stairsCostPerFlight({required double riseM}) {
    return cat.GhanaCostCatalog.stairsCostPerFlight(riseM: riseM);
  }
}
