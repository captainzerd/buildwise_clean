/// Pure use case: computes budget utilisation as a fraction [0.0, 1.0+].
///
/// Returns `0.0` when [budget] is zero or negative (guards against
/// divide-by-zero). Values > 1.0 indicate over-budget.
class CalculateBudgetUtilisation {
  const CalculateBudgetUtilisation();

  double call(double spent, double budget) {
    if (budget <= 0) return 0.0;
    return spent / budget;
  }
}
