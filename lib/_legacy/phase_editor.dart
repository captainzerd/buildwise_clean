import 'package:flutter/material.dart';
import '../state/estimate_controller.dart';
import '../state/estimate_controller_shims.dart';

class PhaseEditor extends StatelessWidget {
  const PhaseEditor({super.key, required this.ctrl});
  final EstimateController ctrl;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final entries = ctrl.phasePlanned.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    String money(num n) => '${ctrl.currencyCode} ${n.toStringAsFixed(2)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Phase breakdown', style: t.titleMedium),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Text(
            'No phases yet. Press Generate above to auto-populate, or add values below.',
            style: t.bodySmall,
          ),
        ...entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: Text(e.key)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    initialValue: e.value.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final parsed = double.tryParse(v) ?? 0.0;
                      final next = Map<String, num>.from(ctrl.phasePlanned);
                      next[e.key] = parsed;
                      final total =
                          next.values.fold<num>(0, (a, b) => a + b).toDouble();
                      ctrl.primeResults(
                        phaseBreakdown: next,
                        totalPlannedGhs: total,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),
        if (entries.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Sum: ${money(ctrl.phasePlanned.values.fold<num>(0, (a, b) => a + b))}',
                style: t.labelLarge,
              ),
            ),
          ),
      ],
    );
  }
}
