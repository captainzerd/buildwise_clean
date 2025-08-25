// lib/features/estimate/widgets/estimate_body.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/estimate_controller.dart';
import 'contingency_controls.dart';

class EstimateBody extends StatelessWidget {
  const EstimateBody({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EstimateController>();
    final theme = Theme.of(context);

    return Form(
      key: ctrl.formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            initialValue: ctrl.projectName,
            decoration: const InputDecoration(
              labelText: 'Project name',
              border: OutlineInputBorder(),
            ),
            onChanged: ctrl.setProjectName,
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: ctrl.region,
            items: ctrl.regions
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: ctrl.setRegion,
            validator: (v) => (v == null || v.isEmpty) ? 'Select region' : null,
            decoration: const InputDecoration(
              labelText: 'Region',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: ctrl.buildingType,
                  items: const [
                    DropdownMenuItem(
                        value: 'Residential', child: Text('Residential')),
                    DropdownMenuItem(
                        value: 'Commercial', child: Text('Commercial')),
                  ],
                  onChanged: (v) => ctrl.setProgramme(buildingType_: v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                  decoration: const InputDecoration(
                    labelText: 'Building type',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: ctrl.quality,
                  items: const [
                    DropdownMenuItem(value: 'Economy', child: Text('Economy')),
                    DropdownMenuItem(
                        value: 'Standard', child: Text('Standard')),
                    DropdownMenuItem(value: 'Premium', child: Text('Premium')),
                  ],
                  onChanged: (v) => ctrl.setProgramme(quality_: v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                  decoration: const InputDecoration(
                    labelText: 'Quality',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: ctrl.foundation,
                  items: const [
                    DropdownMenuItem(value: 'Strip', child: Text('Strip')),
                    DropdownMenuItem(value: 'Raft', child: Text('Raft')),
                    DropdownMenuItem(value: 'Pile', child: Text('Pile')),
                    DropdownMenuItem(value: 'Pad', child: Text('Pad')),
                  ],
                  onChanged: (v) => ctrl.setProgramme(foundation_: v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                  decoration: const InputDecoration(
                    labelText: 'Foundation',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: ctrl.soil,
                  items: const [
                    DropdownMenuItem(value: 'Firm', child: Text('Firm')),
                    DropdownMenuItem(value: 'Soft', child: Text('Soft')),
                    DropdownMenuItem(
                        value: 'Waterlogged', child: Text('Waterlogged')),
                    DropdownMenuItem(
                        value: 'Laterite', child: Text('Laterite')),
                  ],
                  onChanged: (v) => ctrl.setProgramme(soil_: v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                  decoration: const InputDecoration(
                    labelText: 'Soil',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text('Floors', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Selector<EstimateController, int>(
            selector: (_, c) => c.floors.length,
            builder: (context, count, _) {
              return Column(
                children: List.generate(count, (i) {
                  return _FloorTile(index: i, key: ValueKey('floor-$i'));
                }),
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: context.read<EstimateController>().addFloor,
              icon: const Icon(Icons.add),
              label: const Text('Add floor'),
            ),
          ),
          const SizedBox(height: 16),

          SwitchListTile.adaptive(
            value: ctrl.includeExternalWorks,
            onChanged: (v) => ctrl.setExternalWorks(enabled: v),
            title: const Text('Include external works'),
            contentPadding: EdgeInsets.zero,
          ),
          if (ctrl.includeExternalWorks) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: ctrl.externalWallLenM.toString(),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'External wall length (m)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (s) => ctrl.setExternalWorks(
                      wallLenM: double.tryParse(s) ?? 0,
                    ),
                    validator: (s) {
                      if (!ctrl.includeExternalWorks) return null;
                      final v = double.tryParse(s ?? '');
                      if (v == null || v < 0) return 'Enter a valid length';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: ctrl.drivewayAreaM2.toString(),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Driveway area (m²)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (s) => ctrl.setExternalWorks(
                      driveM2: double.tryParse(s) ?? 0,
                    ),
                    validator: (s) {
                      if (!ctrl.includeExternalWorks) return null;
                      final v = double.tryParse(s ?? '');
                      if (v == null || v < 0) return 'Enter a valid area';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: ctrl.includeSeptic,
              onChanged: (v) =>
                  ctrl.setExternalWorks(septic: v ?? ctrl.includeSeptic),
              title: const Text('Include septic system'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
          const SizedBox(height: 16),

          // Budget (optional)
          TextFormField(
            initialValue: ctrl.budgetAmount?.toString() ?? '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Budget (GHS, optional)',
              helperText: 'Enter budget to see coverage after generating',
              border: OutlineInputBorder(),
            ),
            onChanged: (s) => ctrl.setBudgetAmount(double.tryParse(s)),
          ),
          const SizedBox(height: 16),

          ContingencyControls(ctrl: ctrl),
          const SizedBox(height: 24),

          Selector<EstimateController, bool>(
            selector: (_, c) => c.isFormValid,
            builder: (context, valid, _) {
              return SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: valid
                      ? () async {
                          final ok =
                              ctrl.formKey.currentState?.validate() ?? false;
                          if (ok) {
                            await context.read<EstimateController>().compute();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Estimate generated')),
                              );
                            }
                          }
                        }
                      : null,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Generate Estimate'),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          if (ctrl.hasResult) ...[
            _Totals(),
            const SizedBox(height: 8),
            if ((ctrl.budgetAmount ?? 0) > 0) _BudgetCoverageCard(),
          ],
        ],
      ),
    );
  }
}

class _FloorTile extends StatelessWidget {
  const _FloorTile({required this.index, super.key});
  final int index;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<EstimateController>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text('Floor ${index + 1}'),
            const Spacer(),
            SizedBox(
              width: 110,
              child: TextFormField(
                initialValue: ctrl.floors[index].areaM2.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Area (m²)',
                  isDense: true,
                ),
                validator: (s) {
                  final v = double.tryParse(s ?? '');
                  if (v == null || v <= 0) return 'Required';
                  return null;
                },
                onChanged: (s) {
                  final v = double.tryParse(s);
                  if (v != null) ctrl.updateFloor(index, areaM2: v);
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: TextFormField(
                initialValue: ctrl.floors[index].heightM.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Height (m)',
                  isDense: true,
                ),
                validator: (s) {
                  final v = double.tryParse(s ?? '');
                  if (v == null || v <= 0) return 'Required';
                  return null;
                },
                onChanged: (s) {
                  final v = double.tryParse(s);
                  if (v != null) ctrl.updateFloor(index, heightM: v);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Remove floor',
              onPressed: () => ctrl.removeFloor(index),
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EstimateController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _line(
                'Base (GHS)', '₵ ${ctrl.worksSubtotalGhs.toStringAsFixed(2)}'),
            _line('OHP (GHS)', '₵ ${ctrl.ohpGhs.toStringAsFixed(2)}'),
            _line('Contingency (GHS)',
                '₵ ${ctrl.contingencyGhs.toStringAsFixed(2)}'),
            _line('Taxes (GHS)', '₵ ${ctrl.taxesGhs.toStringAsFixed(2)}'),
            const Divider(),
            _line('Grand Total (GHS)',
                '₵ ${ctrl.grandTotalGhs.toStringAsFixed(2)}',
                isBold: true),
            _line('Grand Total (${ctrl.currency.code})',
                '${ctrl.currency.symbol} ${ctrl.grandTotalFx.toStringAsFixed(2)}',
                isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _line(String a, String b, {bool isBold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
                child: Text(a,
                    style: isBold
                        ? const TextStyle(fontWeight: FontWeight.w600)
                        : null)),
            Text(b,
                style: isBold
                    ? const TextStyle(fontWeight: FontWeight.w600)
                    : null),
          ],
        ),
      );
}

class _BudgetCoverageCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.watch<EstimateController>();
    final budget = c.budgetAmount ?? 0;
    final total = c.grandTotalGhs;
    if (budget <= 0 || total <= 0) return const SizedBox.shrink();
    final pct = (budget / total).clamp(0, 1.0);
    final shortfall = (total - budget).clamp(0, double.infinity);
    final surplus = (budget - total).clamp(0, double.infinity);
    String line;
    if (budget >= total) {
      line =
          'Your budget covers 100% of this estimate. Surplus: ₵ ${surplus.toStringAsFixed(2)}';
    } else {
      line =
          'Your budget covers ${(pct * 100).toStringAsFixed(1)}%. Shortfall: ₵ ${shortfall.toStringAsFixed(2)}';
    }
    return Card(
      color: Colors.blueGrey.withOpacity(.05),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Budget coverage',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(line),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: pct.toDouble()),
        ]),
      ),
    );
  }
}
