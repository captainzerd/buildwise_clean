// lib/features/estimate/widgets/step3_floors.dart
//
// Step 3 of the estimate wizard: dynamic floor dimensions list.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/tip_banner.dart';
import '../state/estimate_controller.dart';
import 'step_scaffold.dart';

// ── Step 3 ────────────────────────────────────────────────────────────────────

class Step3Floors extends StatelessWidget {
  const Step3Floors({
    super.key,
    required this.onNext,
    required this.onBack,
  });
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EstimateController>();
    final canAdvance = controller.isFormValid;

    return StepScaffold(
      onNext: canAdvance ? onNext : null,
      onBack: onBack,
      nextLabel: 'Next: Extras',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: sectionLabel(context, 'Floor dimensions')),
              TextButton.icon(
                onPressed: controller.addFloor,
                icon: const Icon(Icons.add),
                label: const Text('Add floor'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Enter area and ceiling height for each floor.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const TipBanner(
            tipKey: 'tip_floors_multifloor',
            message:
                'For multi-storey buildings tap "Add floor" — each floor can have a different footprint and ceiling height.',
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < controller.floors.length; i++)
            FloorRow(
              index: i,
              spec: controller.floors[i],
              onChanged: (area, height) =>
                  controller.updateFloor(i, areaM2: area, heightM: height),
              onRemove: controller.floors.length > 1
                  ? () => controller.removeFloor(i)
                  : null,
            ),
          if (!canAdvance && controller.floors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InfoBanner(
                icon: Icons.warning_amber_outlined,
                message: controller.validationError ??
                    'Please check floor dimensions.',
                color: Theme.of(context).colorScheme.errorContainer,
                textColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Floor row ──────────────────────────────────────────────────────────────────

class FloorRow extends StatelessWidget {
  const FloorRow({
    super.key,
    required this.index,
    required this.spec,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final FloorSpec spec;
  final void Function(double areaM2, double heightM) onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('floor_$index'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, right: 8),
            child: Text(
              'F${index + 1}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          Expanded(
            child: TextFormField(
              initialValue: spec.areaM2.toStringAsFixed(0),
              decoration: const InputDecoration(
                labelText: 'Area',
                suffixText: 'm²',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) =>
                  onChanged(double.tryParse(v) ?? spec.areaM2, spec.heightM),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: spec.heightM.toStringAsFixed(1),
              decoration: const InputDecoration(
                labelText: 'Height',
                suffixText: 'm',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) =>
                  onChanged(spec.areaM2, double.tryParse(v) ?? spec.heightM),
            ),
          ),
          const SizedBox(width: 4),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove floor',
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
