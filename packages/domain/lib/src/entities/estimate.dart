// lib/src/entities/estimate.dart
class Estimate {
  final String id;
  final String projectName;
  final Map<String, double> phaseBudget;

  const Estimate({
    required this.id,
    required this.projectName,
    required this.phaseBudget,
  });

  // Compute at runtime so we can keep the constructor const-safe.
  double get total => phaseBudget.values.fold<double>(0.0, (a, b) => a + b);
}
