class Variance {
  final double budget;
  final double actual;

  const Variance(this.budget, this.actual);

  double get delta => actual - budget;
  double get pct => budget == 0 ? 0 : delta / budget;
}
