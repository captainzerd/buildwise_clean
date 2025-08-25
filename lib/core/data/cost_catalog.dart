// lib/core/data/cost_catalog.dart
//
// Ghana cost model + enums. Keeps all functionality;
// aligns phase labels with tests.

enum BuildType { residential, commercial }

enum Quality { basic, standard, premium }

// Keep both "hard" and add "difficult" for test compatibility.
enum SiteComplexity { easy, normal, hard, difficult }

class GhanaCostCatalog {
  /// Base rate per m² (GHS) by build type, quality, site complexity.
  static double baseCostPerSqm({
    required BuildType buildType,
    required Quality quality,
    required SiteComplexity site,
  }) {
    final base = switch (buildType) {
      BuildType.residential => 2500.0,
      BuildType.commercial => 3000.0,
    };

    final qMul = switch (quality) {
      Quality.basic => 0.9,
      Quality.standard => 1.0,
      Quality.premium => 1.2,
    };

    // Treat "difficult" like "hard"
    final sMul = switch (site) {
      SiteComplexity.easy => 0.95,
      SiteComplexity.normal => 1.0,
      SiteComplexity.hard || SiteComplexity.difficult => 1.15,
    };

    return base * qMul * sMul;
  }

  /// Phase weights per region (normalized).
  /// NOTE: labels match tests exactly.
  static Map<String, double> phaseWeightsForRegion(String region) {
    final weights = <String, double>{
      'Substructure': 0.20,
      'Superstructure': 0.35,
      'Roofing': 0.12,
      'Finishes': 0.18,
      'Mechanical & Electrical': 0.10, // was "MEP"
      'Preliminaries / Admin': 0.05, // was "External Works"
    };
    return _normalize(weights);
  }

  /// Extra substructure per m² for extra floors (index>0).
  static double additionalSubstructurePerSqmForExtraFloor({
    required int floorIndex,
    required double heightM,
  }) {
    if (floorIndex <= 0) return 0.0;
    const firstExtra = 220.0; // matches your earlier assumption @ ~3m
    final hMul = (heightM <= 0 ? 1.0 : (heightM / 3.0)).clamp(0.7, 1.6);
    final indexMul = 1.0 + 0.10 * (floorIndex - 1); // +10% per extra level
    return firstExtra * hMul * indexMul;
  }

  /// Cost per stair flight (GHS) by total rise.
  static double stairsCostPerFlight({required double riseM}) {
    const base = 3500.0; // ~3m
    final rMul = (riseM <= 0 ? 1.0 : (riseM / 3.0)).clamp(0.7, 1.5);
    return base * rMul;
  }

  // ---- helpers ----
  static Map<String, double> _normalize(Map<String, double> w) {
    final total = w.values.fold<double>(0.0, (a, b) => a + b);
    if (total <= 0) return w;
    return {for (final e in w.entries) e.key: e.value / total};
  }
}
