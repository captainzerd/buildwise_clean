// lib/src/utils/stats.dart
double variance(Iterable<num> values, {bool sample = false}) {
  final n = values.length;
  if (n == 0) return 0.0;
  if (sample && n < 2) return 0.0;

  final mean = values.fold<double>(0.0, (s, v) => s + v) / n;
  final ss = values.fold<double>(0.0, (s, v) {
    final d = v.toDouble() - mean;
    return s + d * d; // non-negative by definition
  });

  return ss / (sample ? (n - 1) : n);
}
