// lib/features/estimate/widgets/estimate_body.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/estimate_controller.dart' show EstimateController, BuildingTypology;

class EstimateBody extends StatefulWidget {
  const EstimateBody({super.key});
  @override
  State<EstimateBody> createState() => _EstimateBodyState();
}

class _EstimateBodyState extends State<EstimateBody> {
  // Numeric field controllers
  final Map<int, TextEditingController> _areaCtrls = {};
  final Map<int, TextEditingController> _heightCtrls = {};
  final _wallLenCtrl = TextEditingController();
  final _driveAreaCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();

  // Compact field decoration used everywhere
  InputDecoration get _decoration => const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  String _fmt(num v, int dp) => v.toStringAsFixed(dp);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = context.read<EstimateController>();

    _wallLenCtrl.text = _fmt(c.externalWallLenM, 1);
    _driveAreaCtrl.text = _fmt(c.drivewayAreaM2, 1);
    _budgetCtrl.text = c.budgetAmount == null ? '' : _fmt(c.budgetAmount!, 2);

    for (var i = 0; i < c.floors.length; i++) {
      _areaCtrls.putIfAbsent(i, () => TextEditingController());
      _heightCtrls.putIfAbsent(i, () => TextEditingController());
      _areaCtrls[i]!.text = _fmt(c.floors[i].areaM2, 1);
      _heightCtrls[i]!.text = _fmt(c.floors[i].heightM, 1);
    }

    // prune stale
    _areaCtrls.keys.where((k) => k >= c.floors.length).toList().forEach((k) {
      _areaCtrls.remove(k)?.dispose();
    });
    _heightCtrls.keys.where((k) => k >= c.floors.length).toList().forEach((k) {
      _heightCtrls.remove(k)?.dispose();
    });
  }

  @override
  void dispose() {
    for (final c in _areaCtrls.values) {
      c.dispose();
    }
    for (final c in _heightCtrls.values) {
      c.dispose();
    }
    _wallLenCtrl.dispose();
    _driveAreaCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EstimateController>();
    final label = Theme.of(context).textTheme.titleMedium;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project name
          Text('Project name', style: label),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl.projectNameCtrl,
            decoration:
                _decoration.copyWith(hintText: 'e.g., 3BR House, Adenta'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),

          // Region
          Text('Region', style: label),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: ctrl.region ??
                (ctrl.regions.isNotEmpty ? ctrl.regions.first : null),
            items: [
              for (final r in ctrl.regions)
                DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: (v) => ctrl.setRegion(v),
            decoration: _decoration,
            isDense: true,
          ),
          const SizedBox(height: 12),

          // Programme dropdowns (compact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Building type', style: label),
              const SizedBox(height: 6),
              DropdownButtonFormField<BuildingTypology>(
                initialValue: ctrl.typology,
                isDense: true,
                decoration: _decoration,
                items: [
                  for (final t in BuildingTypology.values)
                    DropdownMenuItem(value: t, child: Text(t.displayLabel)),
                ],
                onChanged: (v) {
                  if (v != null) ctrl.setProgramme(typology_: v);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Drop(
            title: 'Quality',
            value: ctrl.quality,
            options: const ['Economy', 'Standard', 'Premium'],
            onChanged: (v) => ctrl.setProgramme(quality_: v),
            decoration: _decoration,
          ),
          const SizedBox(height: 10),
          _Drop(
            title: 'Foundation',
            value: ctrl.foundation,
            options: const ['Strip', 'Raft', 'Pile', 'Pad'],
            onChanged: (v) => ctrl.setProgramme(foundation_: v),
            decoration: _decoration,
          ),
          const SizedBox(height: 10),
          _Drop(
            title: 'Soil',
            value: ctrl.soil,
            options: const ['Firm', 'Soft', 'Waterlogged', 'Laterite'],
            onChanged: (v) => ctrl.setProgramme(soil_: v),
            decoration: _decoration,
          ),
          const SizedBox(height: 10),
          _Drop(
            title: 'Roof',
            value: ctrl.roof,
            options: const ['Pitched sheet', 'Concrete flat', 'Tile'],
            onChanged: (v) => ctrl.setProgramme(roof_: v),
            decoration: _decoration,
          ),
          const SizedBox(height: 14),

          // Floors
          Text('Floors', style: label),
          const SizedBox(height: 6),
          ...List.generate(ctrl.floors.length, (i) {
            final areaC = _areaCtrls[i]!;
            final heightC = _heightCtrls[i]!;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.25),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Floor ${i + 1}', style: label),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: areaC,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true,),
                                  decoration: _decoration.copyWith(
                                      labelText: 'Area (m²)',),
                                  onEditingComplete: () {
                                    final v = double.tryParse(areaC.text);
                                    if (v != null) {
                                      ctrl.updateFloor(i, areaM2: v);
                                    }
                                    FocusScope.of(context).nextFocus();
                                  },
                                  onFieldSubmitted: (_) {
                                    final v = double.tryParse(areaC.text);
                                    if (v != null) {
                                      ctrl.updateFloor(i, areaM2: v);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: heightC,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true,),
                                  decoration: _decoration.copyWith(
                                      labelText: 'Height (m)',),
                                  onEditingComplete: () {
                                    final v = double.tryParse(heightC.text);
                                    if (v != null) {
                                      ctrl.updateFloor(i, heightM: v);
                                    }
                                    FocusScope.of(context).unfocus();
                                  },
                                  onFieldSubmitted: (_) {
                                    final v = double.tryParse(heightC.text);
                                    if (v != null) {
                                      ctrl.updateFloor(i, heightM: v);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      onPressed: ctrl.floors.length > 1
                          ? () => setState(() => ctrl.removeFloor(i))
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => ctrl.addFloor()),
              icon: const Icon(Icons.add),
              label: const Text('Add floor'),
              style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,),
            ),
          ),
          const SizedBox(height: 14),

          // External works
          Row(
            children: [
              Expanded(child: Text('Include external works', style: label)),
              Switch(
                value: ctrl.includeExternalWorks,
                onChanged: (v) => ctrl.setExternalWorks(enabled: v),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (ctrl.includeExternalWorks) ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _wallLenCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _decoration.copyWith(
                        labelText: 'External wall length (m)',),
                    onEditingComplete: () {
                      final v = double.tryParse(_wallLenCtrl.text);
                      ctrl.setExternalWorks(
                          wallLenM: v ?? ctrl.externalWallLenM,);
                    },
                    onFieldSubmitted: (_) {
                      final v = double.tryParse(_wallLenCtrl.text);
                      ctrl.setExternalWorks(
                          wallLenM: v ?? ctrl.externalWallLenM,);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _driveAreaCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        _decoration.copyWith(labelText: 'Driveway area (m²)'),
                    onEditingComplete: () {
                      final v = double.tryParse(_driveAreaCtrl.text);
                      ctrl.setExternalWorks(driveM2: v ?? ctrl.drivewayAreaM2);
                    },
                    onFieldSubmitted: (_) {
                      final v = double.tryParse(_driveAreaCtrl.text);
                      ctrl.setExternalWorks(driveM2: v ?? ctrl.drivewayAreaM2);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              value: ctrl.includeSeptic,
              onChanged: (v) => ctrl.setExternalWorks(septic: v ?? false),
              title: const Text('Include septic system (lump sum)'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 6),
          ],

          // Budget
          Text('Budget (GHS, optional)', style: label),
          const SizedBox(height: 6),
          TextFormField(
            controller: _budgetCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration.copyWith(
                hintText: 'Enter budget to see coverage after generating',),
            onEditingComplete: () {
              final v = double.tryParse(_budgetCtrl.text);
              ctrl.setBudgetAmount(v);
            },
            onFieldSubmitted: (_) {
              final v = double.tryParse(_budgetCtrl.text);
              ctrl.setBudgetAmount(v);
            },
          ),
          const SizedBox(height: 12),

          // Actions (overflow-safe)
          Row(
            children: [
              FilledButton.icon(
                onPressed: ctrl.isFormValid ? () => ctrl.compute() : null,
                icon: const Icon(Icons.calculate),
                label: const Text('Generate'),
                style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,),
              ),
              const SizedBox(width: 10),
              // Helper text should not overflow: wrap it in Expanded
              if (!ctrl.isFormValid)
                Expanded(
                  child: Text(
                    'Fill required fields (Region, Floors, Programme)',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Results
          if (ctrl.hasResult) ...[
            _Results(ctrl: ctrl),
          ],
        ],
      ),
    );
  }
}

class _Drop extends StatelessWidget {
  const _Drop({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.decoration,
  });

  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: value,
        isDense: true,
        decoration: decoration,
        items: [
          for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: (v) => onChanged(v ?? value),
      ),
    ],);
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.ctrl});
  final EstimateController ctrl;

  @override
  Widget build(BuildContext context) {
    final title = Theme.of(context).textTheme.titleLarge;
    final item = Theme.of(context).textTheme.bodyLarge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Results', style: title),
        const SizedBox(height: 6),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final e in ctrl.phaseBreakdown.entries)
                  _line(context, e.key, ctrl.money(e.value), item),
                if (ctrl.addOnsGhs.isNotEmpty) ...[
                  const Divider(),
                  for (final e in ctrl.addOnsGhs.entries)
                    _line(context, e.key, ctrl.money(e.value), item),
                ],
                const Divider(height: 18),
                _line(context, 'OHP', ctrl.money(ctrl.ohpGhs), item),
                _line(context, 'Contingency', ctrl.money(ctrl.contingencyGhs),
                    item,),
                _line(context, 'Taxes', ctrl.money(ctrl.taxesGhs), item),
                const Divider(height: 18),
                _line(
                  context,
                  'Total',
                  ctrl.money(ctrl.grandTotalGhs),
                  item?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _line(
      BuildContext context, String label, String value, TextStyle? style,) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
