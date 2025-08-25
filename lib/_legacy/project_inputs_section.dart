import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:buildwise_clean/features/estimate/state/estimate_controller.dart';

/// Misc project inputs (like contingency, preliminaries).
/// Zero required args; wires to controller dynamically when possible.
class ProjectInputsSection extends StatelessWidget {
  const ProjectInputsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EstimateController>();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.tune_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Project inputs',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),

            // Contingency %
            Row(
              children: [
                const Expanded(child: Text('Contingency (%)')),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    initialValue: '0',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '%',
                    ),
                    onChanged: (txt) {
                      final v = num.tryParse(txt) ?? 0;
                      try {
                        (ctrl as dynamic).setContingencyPercent?.call(v);
                      } catch (_) {/* optional */}
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Preliminaries/Admin absolute
            Row(
              children: [
                const Expanded(child: Text('Preliminaries / Admin (abs)')),
                const SizedBox(width: 8),
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    initialValue: '0',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Amount (${ctrl.currencySymbol})',
                    ),
                    onChanged: (txt) {
                      final v = num.tryParse(txt) ?? 0;
                      try {
                        (ctrl as dynamic).setPreliminaries?.call(v);
                      } catch (_) {/* optional */}
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
