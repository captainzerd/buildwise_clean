// lib/features/estimate/widgets/result_section.dart
import 'package:flutter/material.dart';
import '../../../core/models/estimate.dart';

class ResultSection extends StatelessWidget {
  final Estimate estimate;
  final String currencyCode; // e.g. 'GHS'

  const ResultSection({
    super.key,
    required this.estimate,
    this.currencyCode = 'GHS',
  });

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    final b = StringBuffer();
    var c = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      b.write(s[i]);
      c++;
      if (c == 3 && i != 0) {
        b.write(',');
        c = 0;
      }
    }
    return '$currencyCode ${b.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    final entries = estimate.phasePlanned.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final total = estimate.phasePlanned.values.fold<double>(0, (p, n) => p + n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          estimate.projectName.isEmpty ? 'Estimate' : estimate.projectName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          '${estimate.region} • ${estimate.city} • '
          '${estimate.squareFootage.toStringAsFixed(0)} sqft',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.key)),
                        Text(_fmt(e.value)),
                      ],
                    ),
                  ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total (planned)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      _fmt(total),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
