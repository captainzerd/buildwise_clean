import '../entities/expense.dart';

class PhaseVariance {
  final String phaseId;
  final double budget;
  final double actual;
  double get variance => actual - budget;
  const PhaseVariance({
    required this.phaseId,
    required this.budget,
    required this.actual,
  });
}

class GetPhaseVariance {
  const GetPhaseVariance();

  Map<String, PhaseVariance> call({
    required Map<String, double> phaseBudget,
    required List<Expense> expenses,
  }) {
    final actualByPhase = <String, double>{};
    for (final e in expenses) {
      actualByPhase.update(
        e.phaseId,
        (v) => v + e.amount,
        ifAbsent: () => e.amount,
      );
    }
    final result = <String, PhaseVariance>{};
    for (final entry in phaseBudget.entries) {
      final actual = actualByPhase[entry.key] ?? 0.0;
      result[entry.key] = PhaseVariance(
        phaseId: entry.key,
        budget: entry.value,
        actual: actual,
      );
    }
    return result;
  }
}
