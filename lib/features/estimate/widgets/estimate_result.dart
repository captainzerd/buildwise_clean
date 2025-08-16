import 'package:flutter/material.dart';
import '../../../core/models/estimate.dart';

class EstimateResult extends StatelessWidget {
  final Estimate estimate;
  final String currencyLabel;
  final String Function(double) format;
  final Future<Map<String, double>> actualsFuture;

  const EstimateResult({
    super.key,
    required this.estimate,
    required this.currencyLabel,
    required this.format,
    required this.actualsFuture,
  });

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, double>>(
          future: actualsFuture,
          builder: (context, snap) {
            final actuals = snap.data ?? const <String, double>{};
            final totalActual = actuals.values.fold<double>(0, (a, b) => a + b);
            final variance = totalActual - estimate.totalPlanned;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        estimate.projectName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _chip(
                      label: 'Region',
                      value: estimate.region,
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      label: 'City',
                      value: estimate.city,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${estimate.squareFootage.toStringAsFixed(0)} sqft • $currencyLabel',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Divider(height: 24),

                // Totals row
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _kv('Planned total', format(estimate.totalPlanned)),
                    _kv('Actual total', format(totalActual)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Variance: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          format(variance),
                          style: TextStyle(
                            color: variance > 0
                                ? Colors.red
                                : (variance < 0 ? Colors.green : null),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Phase breakdown
                Text(
                  'Phase breakdown ($currencyLabel)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),

                _PhaseTable(
                  planned: estimate.phasePlanned,
                  actuals: actuals,
                  format: format,
                ),

                if (snap.connectionState == ConnectionState.waiting) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(v),
      ],
    );
  }

  Widget _chip({required String label, required String value}) {
    return Chip(
      side: BorderSide(color: Colors.grey.shade300),
      backgroundColor: Colors.grey.shade50,
      label: Text('$label: $value'),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PhaseTable extends StatelessWidget {
  final Map<String, double> planned;
  final Map<String, double> actuals;
  final String Function(double) format;

  const _PhaseTable({
    required this.planned,
    required this.actuals,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final phases = planned.keys.toList()..sort();

    return Column(
      children: [
        // Header
        Row(
          children: const [
            Expanded(
              flex: 3,
              child: Text(
                'Phase',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Text(
                'Planned',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Actual',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Variance',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const Divider(height: 16),

        // Rows
        ...phases.map((p) {
          final plannedAmt = planned[p] ?? 0.0;
          final actualAmt = actuals[p] ?? 0.0;
          final diff = actualAmt - plannedAmt;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(p)),
                Expanded(
                  child: Text(
                    format(plannedAmt),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    format(actualAmt),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    format(diff),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: diff > 0
                          ? Colors.red
                          : (diff < 0 ? Colors.green : null),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
