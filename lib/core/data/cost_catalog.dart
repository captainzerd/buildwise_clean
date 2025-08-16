// lib/core/data/cost_catalog.dart
//
// Ghana-focused cost catalog with sane defaults and knobs you can tune.
// All inputs are SI: area in m², height in meters, costs in base currency (GHS by default).

enum BuildType { residential, commercial }

enum Quality { basic, standard, premium }

enum SiteComplexity { easy, normal, difficult }

class GhanaCostCatalog {
  /// Base construction cost per m² for the shell+core portion.
  /// Adjusts with build quality and site complexity multipliers.
  static double baseCostPerSqm({
    required BuildType buildType,
    required Quality quality,
    required SiteComplexity site,
  }) {
    // Baselines (GHS/m²). These are indicative and can be tuned.
    double base;
    switch (buildType) {
      case BuildType.residential:
        base = 3500; // typical modest residential shell/core
        break;
      case BuildType.commercial:
        base = 4200;
        break;
    }

    final qualityMult = switch (quality) {
      Quality.basic => 0.90,
      Quality.standard => 1.00,
      Quality.premium => 1.18,
    };

    final siteMult = switch (site) {
      SiteComplexity.easy => 0.95,
      SiteComplexity.normal => 1.00,
      SiteComplexity.difficult => 1.12,
    };

    return base * qualityMult * siteMult;
  }

  /// Phase weights by region. They should sum ~1.0 and apply to baseCost.
  /// You can tailor these by region if there are known variations.
  static Map<String, double> phaseWeightsForRegion(String region) {
    // Default Ghana practice split (adjust as needed).
    return const {
      'Preliminaries & OH': 0.07,
      'Substructure': 0.18,
      'Superstructure': 0.30,
      'Roofing': 0.08,
      'Finishes': 0.22,
      'Services (MEP)': 0.12,
      'External works': 0.03,
    };
  }

  /// Additional substructure cost per m² for each extra floor (above ground),
  /// driven primarily by the upper floor’s design height (more height -> heavier columns/footings).
  ///
  /// floorIndex: 0 = ground (returns 0), 1 = 1st floor, etc.
  static double additionalSubstructurePerSqmForExtraFloor({
    required int floorIndex,
    required double heightM,
  }) {
    if (floorIndex <= 0) return 0.0;

    // Baseline extra substructure load: GHS/m² at 3.0m design height.
    // Each additional meter adds proportional cost.
    const double baselineAt3m =
        220; // per m² for typical frame reinforcement footprint effect
    final double heightMult = (heightM <= 0) ? 1.0 : (heightM / 3.0);
    return baselineAt3m * heightMult;
  }

  /// Stairs cost per flight for a given rise (m). A typical flight covers one floor rise.
  static double stairsCostPerFlight({required double riseM}) {
    if (riseM <= 0) return 0.0;
    // Baseline for 3.0m rise, scaled linearly.
    const double baselineAt3m =
        14500; // GHS per flight (formwork, reinforcement, concrete, finish)
    final double heightMult = riseM / 3.0;
    return baselineAt3m * heightMult;
  }
}
