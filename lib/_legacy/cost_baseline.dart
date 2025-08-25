// lib/core/services/cost_baseline.dart
/// Encapsulates default per-region cost logic and phase breakdowns.
/// Keep this pure & deterministic so it’s easy to test.
class BaselineCostCalculator {
  // Cost per sqft (GHS) defaults — tweak as you like or load from Firestore later.
  static const Map<String, double> _costPerSqftGhs = {
    'Greater Accra': 950,
    'Ashanti': 850,
    'Central': 800,
    'Eastern': 820,
    'Western': 830,
    'Northern': 760,
    'Upper East': 720,
    'Upper West': 720,
    'Volta': 780,
    'Savannah': 740,
    'Oti': 740,
    'Bono': 800,
    'Bono East': 790,
    'Ahafo': 780,
    'Western North': 770,
    'North East': 730,
  };

  // Phase distribution (must sum to 1.0)
  static const Map<String, double> _phaseWeights = {
    'Foundation': 0.15,
    'Framing': 0.20,
    'Roofing': 0.12,
    'Electrical': 0.10,
    'Plumbing': 0.10,
    'Finishes': 0.25,
    'Contingency': 0.08,
  };

  const BaselineCostCalculator();

  /// Returns the planned amounts per phase (in GHS) for a region + sqft.
  Map<String, double> plannedByPhase({
    required String region,
    required double squareFootage,
  }) {
    final base = _costPerSqftGhs[region] ?? 800; // sensible default
    final total = base * (squareFootage < 0 ? 0 : squareFootage);
    return {for (final e in _phaseWeights.entries) e.key: total * e.value};
  }
}
