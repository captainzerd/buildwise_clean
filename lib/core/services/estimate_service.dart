// lib/core/services/estimate_service.dart
//
// Single source for cost math + currency formatting used by the UI.
// Wires into the Ghana catalog through the adapter you already created.

import 'dart:math' as math;

import '../data/ghana_catalog_adapter.dart';
import '../data/cost_catalog.dart';

// ===== Public API =====

enum AreaUnit { sqm, sqft }

enum Currency { ghs, usd, eur, gbp }

extension CurrencySymbol on Currency {
  String get symbol {
    switch (this) {
      case Currency.ghs:
        return 'GHS ';
      case Currency.usd:
        return '\$ ';
      case Currency.eur:
        return '€ ';
      case Currency.gbp:
        return '£ ';
    }
  }
}

String formatMoney(num value,
    {Currency currency = Currency.ghs, int decimals = 2}) {
  // No intl dependency — simple, fast formatter with thousand separators
  final sign = value < 0 ? '-' : '';
  final absVal = value.abs();
  final whole = absVal.floor();
  final frac = ((absVal - whole) * math.pow(10, decimals)).round();

  String withCommas(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      final isGroupBoundary = idxFromEnd > 1 && idxFromEnd % 3 == 1;
      if (isGroupBoundary) buf.write(',');
    }
    return buf.toString();
  }

  String fracStr() {
    if (decimals == 0) return '';
    final raw = frac.toString().padLeft(decimals, '0');
    return '.$raw';
  }

  return '${currency.symbol}$sign${withCommas(whole)}${fracStr()}';
}

// Shape returned to the UI after generation.
class EstimateView {
  final String projectId;
  final String projectName;
  final String region;
  final String city;
  final Currency currency;

  final AreaUnit unit; // how the user entered data (sqm or sqft)
  final List<double> areasSqm; // normalized to sqm for cost calc
  final List<double> heightsM; // normalized to meters

  final double baseRatePerSqm; // from catalog
  final double baseCost; // baseRate * totalArea
  final double extraSubstructure;
  final double stairsCost;

  final Map<String, double> phaseBreakdown; // includes extras
  final DateTime createdAt;

  double get totalAreaSqm => areasSqm.fold(0.0, (a, b) => a + b);
  double get grandTotal => baseCost + extraSubstructure + stairsCost;

  const EstimateView({
    required this.projectId,
    required this.projectName,
    required this.region,
    required this.city,
    required this.currency,
    required this.unit,
    required this.areasSqm,
    required this.heightsM,
    required this.baseRatePerSqm,
    required this.baseCost,
    required this.extraSubstructure,
    required this.stairsCost,
    required this.phaseBreakdown,
    required this.createdAt,
  });
}

// Port type (your Ghana adapter implements this).
abstract class CostCatalogPort {
  double baseCostPerSqm({required String region, required String city});
  Map<String, double> phaseWeightsForRegion(String region);
  double additionalSubstructurePerSqmForExtraFloor({
    required int floorIndex,
    required double heightM,
  });
  double stairsCostPerFlight({required double riseM});
}

// ===== Service =====

class EstimateService {
  final CostCatalogPort catalog;
  const EstimateService({this.catalog = const GhanaCatalogAdapter()});

  static const double _SQFT_TO_SQM = 0.09290304;
  static const double _FT_TO_M = 0.3048;

  static double _areaToSqm(double area, AreaUnit unit) =>
      unit == AreaUnit.sqm ? area : area * _SQFT_TO_SQM;

  static double _heightToM(double h, AreaUnit unit) =>
      unit == AreaUnit.sqm ? h : h * _FT_TO_M;

  EstimateView create({
    required String projectId,
    required String projectName,
    required String region,
    required String city,
    required Currency currency,
    required AreaUnit inputUnit,
    required List<double> areas,
    required List<double> heights,
    DateTime? createdAt,
  }) {
    // Normalize
    final areasSqm = List<double>.generate(
      areas.length,
      (i) => _areaToSqm(areas[i], inputUnit),
    );
    final heightsM = List<double>.generate(
      heights.length,
      (i) => _heightToM(heights[i], inputUnit),
    );

    // Base
    final baseRate = catalog.baseCostPerSqm(region: region, city: city);
    final totalArea = areasSqm.fold(0.0, (a, b) => a + b);
    final baseCost = baseRate * totalArea;

    // Extra substructure for floors >= 2
    double extraSubstructure = 0.0;
    for (int i = 1; i < areasSqm.length; i++) {
      final addPerSqm = catalog.additionalSubstructurePerSqmForExtraFloor(
        floorIndex: i + 1,
        heightM: heightsM[i],
      );
      extraSubstructure += addPerSqm * areasSqm[i];
    }

    // Stairs: one flight per extra floor using that rise
    double stairsCost = 0.0;
    for (int i = 1; i < heightsM.length; i++) {
      stairsCost += catalog.stairsCostPerFlight(riseM: heightsM[i]);
    }

    // Phase split (weights per region) on baseCost only
    final weights = catalog.phaseWeightsForRegion(region);
    final phasePlanned = <String, double>{
      for (final e in weights.entries) e.key: baseCost * e.value,
      'Extra Substructure': extraSubstructure,
      'Stairs': stairsCost,
    };

    return EstimateView(
      projectId: projectId,
      projectName: projectName,
      region: region,
      city: city,
      currency: currency,
      unit: inputUnit,
      areasSqm: areasSqm,
      heightsM: heightsM,
      baseRatePerSqm: baseRate,
      baseCost: baseCost,
      extraSubstructure: extraSubstructure,
      stairsCost: stairsCost,
      phaseBreakdown: phasePlanned,
      createdAt: createdAt ?? DateTime.now(),
    );
  }
}
