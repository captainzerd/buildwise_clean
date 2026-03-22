// lib/features/estimate/widgets/step4_extras.dart
//
// Step 4 of the estimate wizard: external works, commercials, permits, budget.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/estimate_controller.dart';
import 'step_scaffold.dart';

// ── Step 4 ────────────────────────────────────────────────────────────────────

class Step4Extras extends StatelessWidget {
  const Step4Extras({
    super.key,
    required this.onNext,
    required this.onBack,
  });
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EstimateController>();

    return StepScaffold(
      onNext: onNext,
      onBack: onBack,
      nextLabel: 'Review estimate',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section 1: External Works ────────────────────────────────────
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            initiallyExpanded: true,
            title: const Text('External works'),
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include external works'),
                value: controller.includeExternalWorks,
                onChanged: (v) => controller.setExternalWorks(enabled: v),
              ),
              if (controller.includeExternalWorks) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue:
                            controller.externalWallLenM.toStringAsFixed(0),
                        decoration: const InputDecoration(
                          labelText: 'Compound wall',
                          suffixText: 'm',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (v) => controller.setExternalWorks(
                          wallLenM: double.tryParse(v) ?? 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue:
                            controller.drivewayAreaM2.toStringAsFixed(0),
                        decoration: const InputDecoration(
                          labelText: 'Driveway',
                          suffixText: 'm²',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (v) => controller.setExternalWorks(
                          driveM2: double.tryParse(v) ?? 0,
                        ),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include septic/soakaway'),
                  value: controller.includeSeptic,
                  onChanged: (v) =>
                      controller.setExternalWorks(septic: v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Water storage tank'),
                  subtitle: const Text('Fixed: GH₵ 5,000'),
                  value: controller.includeWaterTank,
                  onChanged: (v) => controller.setWaterTank(v ?? false),
                ),
              ],
            ],
          ),
          // ── Section 2: Commercials ───────────────────────────────────────
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            initiallyExpanded: true,
            title: const Text('Commercials'),
            children: [
              _LabeledSlider(
                label: 'Preliminaries',
                value: controller.preliminariesPct,
                min: 0,
                max: 20,
                onChanged: controller.setPreliminariesPct,
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Contingency'),
                value: controller.contingencyEnabled,
                onChanged: controller.setContingencyEnabled,
              ),
              if (controller.contingencyEnabled)
                _LabeledSlider(
                  label: 'Contingency %',
                  value: controller.contingencyPct,
                  min: 0,
                  max: 30,
                  onChanged: controller.setContingencyPct,
                ),
              const SizedBox(height: 8),
            ],
          ),
          // ── Section 3: Permit ────────────────────────────────────────────
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: const Text('Permit'),
            children: [
              DropdownButtonFormField<PermitMode>(
                initialValue: controller.permitMode,
                items: const [
                  DropdownMenuItem(
                    value: PermitMode.percent,
                    child: Text('Permit as % (auto)'),
                  ),
                  DropdownMenuItem(
                    value: PermitMode.manual,
                    child: Text('Manual permit amount'),
                  ),
                ],
                onChanged: (m) =>
                    controller.setPermitMode(m ?? PermitMode.percent),
                decoration: const InputDecoration(labelText: 'Permit mode'),
              ),
              const SizedBox(height: 12),
              if (controller.permitMode == PermitMode.percent)
                TextFormField(
                  initialValue: controller.permitPct.toStringAsFixed(2),
                  decoration: const InputDecoration(
                    labelText: 'Permit % of base cost',
                    suffixText: '%',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => controller.setPermitPct(
                    double.tryParse(v) ?? controller.permitPct,
                  ),
                )
              else
                TextFormField(
                  initialValue:
                      (controller.permitManualGhs ?? 0).toStringAsFixed(0),
                  decoration: const InputDecoration(
                    labelText: 'Permit fee',
                    suffixText: 'GHS',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) =>
                      controller.setPermitManual(double.tryParse(v)),
                ),
            ],
          ),
          // ── Section 4: Budget Comparison ─────────────────────────────────
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: const Text('Budget comparison'),
            children: [
              TextFormField(
                initialValue:
                    controller.budgetAmount?.toStringAsFixed(0) ?? '',
                decoration: const InputDecoration(
                  labelText: 'Your target budget',
                  suffixText: 'GHS',
                  helperText: 'We\'ll compare this against the estimate',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    controller.setBudgetAmount(double.tryParse(v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Labeled slider ─────────────────────────────────────────────────────────────

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('${value.toStringAsFixed(1)}%'),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
