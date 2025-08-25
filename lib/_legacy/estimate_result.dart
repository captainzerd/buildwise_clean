import 'package:flutter/material.dart';
import '../state/estimate_controller.dart';

class EstimateResult extends StatelessWidget {
  const EstimateResult({super.key, required this.ctrl});
  final EstimateController ctrl;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    if (!ctrl.hasResult) {
      return Text('No results yet.', style: t.bodyMedium);
    }

    String money(num n) => ctrl.formatMoney(n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Summary', style: t.titleMedium),
        const SizedBox(height: 8),
        Text('Total planned: ${money(ctrl.totalPlannedGhs)}'),
        Text('Base cost: ${money(ctrl.baseCostGhs)}'),
        Text('Extra substructure: ${money(ctrl.extraSubstructureGhs)}'),
        Text('Stairs: ${money(ctrl.stairsCostGhs)}'),
        const SizedBox(height: 12),
        Text('Phase breakdown', style: t.titleSmall),
        const SizedBox(height: 4),
        ...ctrl.phaseBreakdown.entries.map(
          (e) => Text('${e.key}: ${money((e.value as num))}'),
        ),
      ],
    );
  }
}
