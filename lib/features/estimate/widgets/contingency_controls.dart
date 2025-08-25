// lib/features/estimate/widgets/contingency_controls.dart
import 'package:flutter/material.dart';
import '../state/estimate_controller.dart';

class ContingencyControls extends StatelessWidget {
  const ContingencyControls({super.key, required this.ctrl});
  final EstimateController ctrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch.adaptive(
          value: ctrl.contingencyEnabled,
          onChanged: (v) => ctrl.setContingencyEnabled(v),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(width: 8),
        Text('Contingency', style: theme.textTheme.bodyMedium),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: TextFormField(
            enabled: ctrl.contingencyEnabled,
            initialValue: ctrl.contingencyPct.toStringAsFixed(0),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Percent',
              suffixText: '%',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (s) {
              final v = double.tryParse(s.trim());
              if (v != null) ctrl.setContingencyPct(v);
            },
          ),
        ),
      ],
    );
  }
}
