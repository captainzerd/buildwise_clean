// lib/features/estimate/widgets/step5_review.dart
//
// Step 5 of the estimate wizard: summary view and compute button.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/loading_button.dart';
import '../state/estimate_controller.dart';
import 'step_scaffold.dart';

// ── Step 5 ────────────────────────────────────────────────────────────────────

class Step5Review extends StatelessWidget {
  const Step5Review({
    super.key,
    required this.onBack,
    required this.onCompute,
  });
  final VoidCallback onBack;
  final Future<void> Function() onCompute;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<EstimateController>();

    return StepScaffold(
      onNext: null, // handled by ComputeButton below
      onBack: onBack,
      nextLabel: '',
      footer: ComputeButton(onCompute: onCompute),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(context, 'Summary'),
          const SizedBox(height: 16),
          SummaryRow(
            'Project name',
            c.projectNameCtrl.text.trim().isEmpty
                ? '—'
                : c.projectNameCtrl.text.trim(),
          ),
          SummaryRow('Region', c.region ?? 'Default'),
          SummaryRow('Currency', '${c.currency.code}  ${c.currency.symbol}'),
          const Divider(height: 24),
          SummaryRow('Building type', c.typology.shortLabel),
          SummaryRow('Quality', c.quality),
          SummaryRow('Foundation', c.foundation),
          SummaryRow('Soil', c.soil),
          SummaryRow('Roof', c.roof),
          const Divider(height: 24),
          SummaryRow(
            'Floors',
            '${c.floors.length} floor${c.floors.length == 1 ? '' : 's'}',
          ),
          for (int i = 0; i < c.floors.length; i++)
            SummaryRow(
              '  Floor ${i + 1}',
              '${c.floors[i].areaM2.toStringAsFixed(0)} m²  ·  '
                  '${c.floors[i].heightM.toStringAsFixed(1)} m high',
              secondary: true,
            ),
          const Divider(height: 24),
          SummaryRow(
            'External works',
            c.includeExternalWorks ? 'Yes' : 'No',
          ),
          SummaryRow(
            'Preliminaries',
            '${c.preliminariesPct.toStringAsFixed(1)}%',
          ),
          SummaryRow(
            'Contingency',
            c.contingencyEnabled
                ? '${c.contingencyPct.toStringAsFixed(1)}%'
                : 'Off',
          ),
          SummaryRow(
            'Budget',
            c.budgetAmount != null
                ? 'GHS ${c.budgetAmount!.toStringAsFixed(0)}'
                : 'Not set',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class SummaryRow extends StatelessWidget {
  const SummaryRow(this.label, this.value, {super.key, this.secondary = false});
  final String label;
  final String value;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = secondary
        ? Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface,
            );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: ts?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: ts?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Compute button ────────────────────────────────────────────────────────────

class ComputeButton extends StatelessWidget {
  const ComputeButton({super.key, required this.onCompute});
  final Future<void> Function() onCompute;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: LoadingButton(
        label: 'Compute estimate',
        icon: Icons.calculate_outlined,
        onPressed: onCompute,
      ),
    );
  }
}
