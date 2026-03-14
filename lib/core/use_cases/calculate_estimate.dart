// lib/core/use_cases/calculate_estimate.dart
//
// Pure-Dart estimation engine — no Flutter, no services.
// EstimateController calls EstimationEngine.calculate() after assembling
// an EstimateInput snapshot from form state + catalog lookups.

import 'package:flutter/foundation.dart' show immutable;

// ── Shared value types ────────────────────────────────────────────────────────

enum PermitMode { percent, manual }

enum BuildingTypology {
  residentialStandard,
  residentialMediumRise,
  residentialHighRise,
  commercialOffice,
  commercialRetail,
  commercialWarehouse;

  double get costMultiplier => switch (this) {
        BuildingTypology.residentialStandard => 1.00,
        BuildingTypology.residentialMediumRise => 1.18,
        BuildingTypology.residentialHighRise => 1.40,
        BuildingTypology.commercialOffice => 1.22,
        BuildingTypology.commercialRetail => 1.28,
        BuildingTypology.commercialWarehouse => 0.88,
      };

  String get displayLabel => switch (this) {
        BuildingTypology.residentialStandard =>
          'Residential Standard (Bungalow / Duplex / Terraced)',
        BuildingTypology.residentialMediumRise =>
          'Residential Medium-rise (Apt Block 3–6 storeys)',
        BuildingTypology.residentialHighRise =>
          'Residential High-rise (Apt Block 7+ storeys)',
        BuildingTypology.commercialOffice =>
          'Commercial Office / Bank / Institution',
        BuildingTypology.commercialRetail => 'Commercial Retail / Mixed Use',
        BuildingTypology.commercialWarehouse =>
          'Commercial Warehouse / Factory / Store',
      };

  String get shortLabel => switch (this) {
        BuildingTypology.residentialStandard => 'Residential Standard',
        BuildingTypology.residentialMediumRise => 'Medium-rise Apt',
        BuildingTypology.residentialHighRise => 'High-rise Apt',
        BuildingTypology.commercialOffice => 'Office / Institution',
        BuildingTypology.commercialRetail => 'Retail / Mixed Use',
        BuildingTypology.commercialWarehouse => 'Warehouse / Factory',
      };

  String get subtitle => switch (this) {
        BuildingTypology.residentialStandard =>
          'Bungalow, duplex or terraced house',
        BuildingTypology.residentialMediumRise =>
          'Apartment block, 3–6 storeys',
        BuildingTypology.residentialHighRise =>
          'High-rise apartments, 7+ storeys',
        BuildingTypology.commercialOffice => 'Office, bank or institution',
        BuildingTypology.commercialRetail => 'Retail shop, mall or mixed-use',
        BuildingTypology.commercialWarehouse => 'Warehouse, factory or store',
      };

  String get iconKey => switch (this) {
        BuildingTypology.residentialStandard => 'home',
        BuildingTypology.residentialMediumRise => 'apartment',
        BuildingTypology.residentialHighRise => 'location_city',
        BuildingTypology.commercialOffice => 'business',
        BuildingTypology.commercialRetail => 'storefront',
        BuildingTypology.commercialWarehouse => 'warehouse',
      };

  static BuildingTypology fromString(String? v) => switch (v) {
        'residentialMediumRise' => BuildingTypology.residentialMediumRise,
        'residentialHighRise' => BuildingTypology.residentialHighRise,
        'commercialOffice' => BuildingTypology.commercialOffice,
        'commercialRetail' => BuildingTypology.commercialRetail,
        'commercialWarehouse' => BuildingTypology.commercialWarehouse,
        _ => BuildingTypology.residentialStandard,
      };
}

@immutable
class FloorSpec {
  const FloorSpec({required this.areaM2, required this.heightM});
  final double areaM2;
  final double heightM;

  FloorSpec copyWith({double? areaM2, double? heightM}) => FloorSpec(
        areaM2: areaM2 ?? this.areaM2,
        heightM: heightM ?? this.heightM,
      );
}

@immutable
class TaxLine {
  const TaxLine({required this.name, required this.pct});
  final String name;
  final double pct;
}

// ── Result ────────────────────────────────────────────────────────────────────

@immutable
class EstimateResult {
  const EstimateResult({
    required this.totalBuiltUpArea,
    required this.phaseBreakdownGhs,
    required this.addOnsGhs,
    required this.preliminariesGhs,
    required this.ohpGhs,
    required this.professionalFeesGhs,
    required this.contingencyGhs,
    required this.taxLinesGhs,
    required this.permitGhs,
    required this.totalPlannedGhs,
    required this.specificationBreakdownGhs,
  });

  final double totalBuiltUpArea;
  final Map<String, double> phaseBreakdownGhs;
  final Map<String, double> addOnsGhs;
  final double preliminariesGhs;
  final double ohpGhs;
  final double professionalFeesGhs;
  final double contingencyGhs;
  final Map<String, double> taxLinesGhs;
  final double permitGhs;
  final double totalPlannedGhs;
  final Map<String, double> specificationBreakdownGhs;
}

// ── Input ─────────────────────────────────────────────────────────────────────

@immutable
class EstimateInput {
  const EstimateInput({
    required this.floors,
    required this.quality,
    required this.foundation,
    required this.soil,
    required this.roof,
    required this.typology,
    required this.enhancedServices,
    required this.curtainWall,
    required this.includeWaterTank,
    required this.includeGeneratorHouse,
    required this.includeSwimmingPool,
    required this.swimmingPoolGhs,
    required this.securityWallLenM,
    required this.securityWallRatePerM,
    required this.unitRateGhsPerM2,
    required this.regionalIndex,
    required this.phasePercents,
    required this.includeExternalWorks,
    required this.externalWallLenM,
    required this.drivewayAreaM2,
    required this.includeSeptic,
    required this.compoundWallRatePerM,
    required this.drivewayRatePerM2,
    required this.septicLumpSum,
    required this.preliminariesPct,
    required this.ohpPct,
    required this.contingencyEnabled,
    required this.contingencyPct,
    required this.permitMode,
    required this.permitPct,
    required this.permitManualGhs,
    required this.taxLines,
    required this.professionalFeesEnabled,
    required this.professionalFeesPct,
  });

  final List<FloorSpec> floors;
  final String quality;
  final String foundation;
  final String soil;
  final String roof;
  final BuildingTypology typology;
  final bool enhancedServices;
  final bool curtainWall;
  final bool includeWaterTank;
  final bool includeGeneratorHouse;
  final bool includeSwimmingPool;
  final double swimmingPoolGhs;
  final double securityWallLenM;
  final double securityWallRatePerM;

  /// Pre-looked-up unit rate from catalog (GHS/m²).
  final double unitRateGhsPerM2;

  /// Pre-looked-up regional adjustment index.
  final double regionalIndex;

  /// Phase-name → fraction-of-base-cost mapping from catalog.
  final Map<String, double> phasePercents;

  final bool includeExternalWorks;
  final double externalWallLenM;
  final double drivewayAreaM2;
  final bool includeSeptic;
  final double compoundWallRatePerM;
  final double drivewayRatePerM2;
  final double septicLumpSum;

  final double preliminariesPct;
  final double ohpPct;
  final bool contingencyEnabled;
  final double contingencyPct;
  final PermitMode permitMode;
  final double permitPct;
  final double? permitManualGhs;
  final List<TaxLine> taxLines;
  final bool professionalFeesEnabled;
  final double professionalFeesPct;
}

// ── Engine ────────────────────────────────────────────────────────────────────

class EstimationEngine {
  const EstimationEngine();

  // Fixed lump-sum rates for add-ons (GhBC 2024)
  static const double _waterTankGhs = 5000.0;
  static const double _generatorHouseGhs = 12000.0;
  static const double _curtainWallExtraOpeningsPct = 0.04;

  // Typology-specific phase weights (fraction of base cost).
  // Each map must sum to 1.0. The engine selects the appropriate set based on
  // the input typology, overriding the generic catalog weights.
  static const Map<String, Map<String, double>> _phaseWeightsByTypology = {
    'residentialStandard': {
      'Substructure': 0.15,
      'Superstructure': 0.30,
      'Roofing': 0.12,
      'Finishes': 0.28,
      'Services (MEP)': 0.15,
    },
    'residentialMediumRise': {
      'Substructure': 0.16,
      'Superstructure': 0.32,
      'Roofing': 0.08,
      'Finishes': 0.22,
      'Services (MEP)': 0.22,
    },
    'residentialHighRise': {
      'Substructure': 0.17,
      'Superstructure': 0.33,
      'Roofing': 0.06,
      'Finishes': 0.20,
      'Services (MEP)': 0.24,
    },
  };

  /// Storey premium multiplier: first upper floor adds 16%, each subsequent
  /// floor adds a further 10% (compound cost increase for taller buildings).
  static double _storeyPremium(int floors) {
    if (floors <= 1) return 1.0;
    return 1.0 + 0.16 + (floors - 2).clamp(0, 99) * 0.10;
  }

  EstimateResult calculate(EstimateInput i) {
    final totalArea = i.floors.fold<double>(0, (p, f) => p + f.areaM2);

    // ── Base cost: area × quality rate × regional index ───────────────────────
    final baseGhs = totalArea * i.unitRateGhsPerM2 * i.regionalIndex;

    // ── Phase costs (before specification adjustments) ────────────────────────
    // Use typology-specific weights when available; fall back to catalog weights.
    final phasePercents =
        _phaseWeightsByTypology[i.typology.name] ?? i.phasePercents;
    final Map<String, double> phaseGhs = {};
    phasePercents.forEach((name, pct) {
      phaseGhs[name] = baseGhs * pct;
    });

    // ── Specification multipliers ─────────────────────────────────────────────
    final foundationMul = switch (i.foundation) {
      'Raft' => 1.22,
      'Pad' => 1.15,
      'Pile' => 1.55,
      _ => 1.00,
    };
    final soilMul = switch (i.soil) {
      'Soft' => 1.15,
      'Waterlogged' => 1.25,
      _ => 1.00,
    };
    final roofMul = switch (i.roof) {
      'Concrete flat' => 1.38,
      'Tile' => 1.25,
      _ => 1.00,
    };
    final typologyMul = i.typology.costMultiplier;
    final servicesMul = i.enhancedServices ? 1.18 : 1.00;
    final storeyPremium = _storeyPremium(i.floors.length);

    for (final key in phaseGhs.keys.toList()) {
      final lc = key.toLowerCase();
      if (lc.contains('sub') || lc.contains('foundation')) {
        phaseGhs[key] = phaseGhs[key]! * foundationMul * soilMul;
      } else if (lc.contains('super') || lc.contains('walling')) {
        phaseGhs[key] = phaseGhs[key]! * typologyMul * storeyPremium;
      } else if (lc.contains('roof')) {
        phaseGhs[key] = phaseGhs[key]! * roofMul;
      } else if (lc.contains('service') ||
          lc.contains('mep') ||
          lc.contains('m&e') ||
          lc.contains('plumbing') ||
          lc.contains('electrical')) {
        phaseGhs[key] = phaseGhs[key]! * typologyMul * servicesMul;
      }
    }

    // Curtain wall / large glazing: adds an extra 4% of baseGhs (on top of the
    // standard 4% already embedded in phase percents via the catalog).
    // Net effect: openings allocation doubles from 4% → 8%.
    if (i.curtainWall) {
      const curtainWallPct = _curtainWallExtraOpeningsPct;
      final curtainWallCost = baseGhs * curtainWallPct;
      phaseGhs['Curtain wall / glazing'] = curtainWallCost;
    }

    final adjustedDirectCost =
        phaseGhs.values.fold<double>(0, (a, b) => a + b);

    // ── Add-ons ───────────────────────────────────────────────────────────────
    final Map<String, double> addOns = {};
    double addOnsTotal = 0;
    if (i.includeExternalWorks) {
      if (i.externalWallLenM > 0) {
        final wall = i.externalWallLenM * i.compoundWallRatePerM;
        addOns['Compound wall'] = wall;
        addOnsTotal += wall;
      }
      if (i.drivewayAreaM2 > 0) {
        final drive = i.drivewayAreaM2 * i.drivewayRatePerM2;
        addOns['Driveway'] = drive;
        addOnsTotal += drive;
      }
      if (i.includeSeptic) {
        final septic = i.septicLumpSum;
        addOns['Septic/Soakaway'] = septic;
        addOnsTotal += septic;
      }
    }
    if (i.includeWaterTank) {
      addOns['Water storage tank'] = _waterTankGhs;
      addOnsTotal += _waterTankGhs;
    }
    if (i.includeGeneratorHouse) {
      addOns['Generator house'] = _generatorHouseGhs;
      addOnsTotal += _generatorHouseGhs;
    }
    if (i.includeSwimmingPool) {
      addOns['Swimming pool'] = i.swimmingPoolGhs;
      addOnsTotal += i.swimmingPoolGhs;
    }
    if (i.securityWallLenM > 0) {
      final sw = i.securityWallLenM * i.securityWallRatePerM;
      addOns['Security wall'] = sw;
      addOnsTotal += sw;
    }

    // ── Commercial additions ──────────────────────────────────────────────────
    final prelimGhs =
        (adjustedDirectCost + addOnsTotal) * (i.preliminariesPct / 100.0);
    final ohp = (adjustedDirectCost + addOnsTotal + prelimGhs) *
        (i.ohpPct / 100.0);
    final profFees = i.professionalFeesEnabled
        ? (adjustedDirectCost + addOnsTotal) * (i.professionalFeesPct / 100.0)
        : 0.0;
    final contingency = i.contingencyEnabled
        ? (adjustedDirectCost + addOnsTotal + prelimGhs + ohp + profFees) *
            (i.contingencyPct / 100.0)
        : 0.0;

    final netBeforeTax =
        adjustedDirectCost + addOnsTotal + prelimGhs + ohp + profFees + contingency;

    // ── Taxes ─────────────────────────────────────────────────────────────────
    final Map<String, double> taxLinesGhs = {};
    double taxesTotal = 0;
    for (final t in i.taxLines) {
      final line = netBeforeTax * (t.pct / 100.0);
      taxLinesGhs[t.name] = line;
      taxesTotal += line;
    }

    final permit = i.permitMode == PermitMode.percent
        ? (adjustedDirectCost + addOnsTotal) * (i.permitPct / 100.0)
        : (i.permitManualGhs ?? 0.0);

    final totalPlanned = netBeforeTax + taxesTotal + permit;

    // Baseline phases (no spec multipliers) — uses same typology-adjusted weights.
    final Map<String, double> baselinePhases = {};
    phasePercents.forEach((name, pct) => baselinePhases[name] = baseGhs * pct);
    final baselineDirect =
        baselinePhases.values.fold<double>(0, (a, b) => a + b);

    final specBreakdown = <String, double>{
      'Baseline': baselineDirect,
    };
    if (i.typology != BuildingTypology.residentialStandard) {
      specBreakdown[
              'Building typology ${i.typology.costMultiplier > 1 ? "premium" : "discount"}'] =
          adjustedDirectCost - baselineDirect;
    }
    final subBaseline = baselinePhases.entries
        .where(
          (e) =>
              e.key.toLowerCase().contains('sub') ||
              e.key.toLowerCase().contains('foundation'),
        )
        .fold<double>(0, (a, e) => a + e.value);
    if (foundationMul != 1.00) {
      specBreakdown['Foundation uplift'] = subBaseline * (foundationMul - 1.0);
    }
    if (soilMul != 1.00) {
      specBreakdown['Soil condition uplift'] =
          subBaseline * foundationMul * (soilMul - 1.0);
    }
    final roofBaseline = baselinePhases.entries
        .where((e) => e.key.toLowerCase().contains('roof'))
        .fold<double>(0, (a, e) => a + e.value);
    if (roofMul != 1.00) {
      specBreakdown['Roof type uplift'] = roofBaseline * (roofMul - 1.0);
    }
    final serviceBaseline = baselinePhases.entries
        .where((e) {
          final lc = e.key.toLowerCase();
          return lc.contains('service') ||
              lc.contains('mep') ||
              lc.contains('m&e') ||
              lc.contains('plumbing') ||
              lc.contains('electrical');
        })
        .fold<double>(0, (a, e) => a + e.value);
    if (servicesMul != 1.00) {
      specBreakdown['Services tier uplift'] =
          serviceBaseline * typologyMul * (servicesMul - 1.0);
    }
    if (i.curtainWall) {
      specBreakdown['Curtain wall uplift'] = baseGhs * _curtainWallExtraOpeningsPct;
    }
    if (addOnsTotal > 0) {
      specBreakdown['External works'] = addOnsTotal;
    }

    return EstimateResult(
      totalBuiltUpArea: totalArea,
      phaseBreakdownGhs: phaseGhs,
      addOnsGhs: addOns,
      preliminariesGhs: prelimGhs,
      ohpGhs: ohp,
      professionalFeesGhs: profFees,
      contingencyGhs: contingency,
      taxLinesGhs: taxLinesGhs,
      permitGhs: permit,
      totalPlannedGhs: totalPlanned,
      specificationBreakdownGhs: specBreakdown,
    );
  }
}
