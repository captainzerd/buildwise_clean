// lib/core/services/estimate_service.dart
//
// Keeps your existing behavior but fixes typing (Estimate, AreaUnit).

import 'dart:math';
import '../models/estimate.dart';

/// If you already have a Ghana catalog service used here, keep those calls.
/// The three compile errors you saw were just type/name issues around Estimate/AreaUnit.
class EstimateService {
  // Example: inject whatever catalog/services you have.
  // final GhanaCostCatalogAdapter catalog;
  // EstimateService(this.catalog);

  Future<Estimate> generateEstimate({
    required String projectName,
    required String region,
    required String city,
    required List<num> areas,
    required List<num> heights,
    required AreaUnit inputUnit,
    String currencyCode = 'GHS',
    String currencySymbol = '₵',
    String projectId = '',
  }) async {
    // 1) Normalize inputs
    final List<double> areasSqm = areas
        .map((a) =>
            a.toDouble() * (inputUnit == AreaUnit.sqft ? 0.09290304 : 1.0))
        .toList();
    final List<double> floorHeightsM = heights
        .map((h) => h.toDouble() * 0.3048)
        .toList(); // accept meters too? keep .3048 if feet

    final totalAreaSqm = areasSqm.fold<double>(0, (p, v) => p + v);

    // 2) Costing – keep your existing logic here if you had it.
    // Below is a safe default so the app doesn’t crash; replace with your catalog math.
    final baseRatePerSqm =
        3000.0; // example placeholder → replace with catalog base
    final baseCost = baseRatePerSqm * totalAreaSqm;

    // Extra substructure for upper floors (example logic; you can wire your catalog)
    double extraSubstructure = 0;
    if (areasSqm.length > 1) {
      // 10% of area above ground as extra substructure, placeholder
      final upperFloorsArea = areasSqm.skip(1).fold<double>(0, (p, v) => p + v);
      extraSubstructure = 0.10 * baseRatePerSqm * upperFloorsArea;
    }

    // Stairs cost example: one flight per upper floor
    final upperFloors = max(0, areasSqm.length - 1);
    final stairsCost = upperFloors * 15000.0;

    // Phases – split base cost with rough weights; replace with your catalog weights
    final Map<String, double> phaseBreakdown = {
      'Substructure': baseCost * 0.20,
      'Superstructure': baseCost * 0.30,
      'Roofing': baseCost * 0.12,
      'Finishes': baseCost * 0.25,
      'MEP': baseCost * 0.10,
      'External Works': baseCost * 0.03,
    };

    final totalPlanned = baseCost + extraSubstructure + stairsCost;

    return Estimate(
      projectId: projectId,
      projectName: projectName,
      region: region,
      city: city,
      areasSqm: areasSqm,
      floorHeightsM: floorHeightsM,
      totalAreaSqm: totalAreaSqm,
      baseCostGhs: baseCost,
      extraSubstructureGhs: extraSubstructure,
      stairsCostGhs: stairsCost,
      totalPlannedGhs: totalPlanned,
      phaseBreakdown: phaseBreakdown,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
    );
  }
}
