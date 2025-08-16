// lib/features/estimate/widgets/estimate_body.dart
//
// Thin UI shell. Relies on the controller for all state & logic.

import 'package:flutter/material.dart';

import '../state/estimate_controller.dart';
import 'estimate_header.dart';

class EstimateBody extends StatelessWidget {
  final EstimateController ctrl;
  const EstimateBody({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final regions = ctrl.regions;
    final cities = ctrl.citiesForSelected;

    return Column(
      children: [
        // Use this header only if your enclosing Scaffold doesn't already set appBar.
        EstimateHeader(
          currency: ctrl.currency,
          onCurrencyChanged: ctrl.setCurrency,
          onOpenSaved: null,
        ),

        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Quick Estimate',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              if (ctrl.loadingLocations) const LinearProgressIndicator(),
              if (ctrl.locationError != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(ctrl.locationError!)),
                    TextButton(
                      onPressed: ctrl.init,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              Form(
                key: ctrl.formKey,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _input(
                      label: 'Project name',
                      controller: ctrl.projectNameCtrl,
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Required' : null,
                      width: 380,
                    ),

                    // Region
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        value: regions.contains(ctrl.regionCtrl.text)
                            ? ctrl.regionCtrl.text
                            : (regions.isNotEmpty ? regions.first : null),
                        items: regions
                            .map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)),
                            )
                            .toList(),
                        onChanged: (r) {
                          if (r == null) return;
                          ctrl.regionCtrl.text = r;
                          final cts = ctrl.citiesForSelected;
                          ctrl.cityCtrl.text = cts.isNotEmpty ? cts.first : '';
                          ctrl.notifyListeners();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Region',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),

                    // City
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        value: cities.contains(ctrl.cityCtrl.text)
                            ? ctrl.cityCtrl.text
                            : (cities.isNotEmpty ? cities.first : null),
                        items: cities
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (c) {
                          ctrl.cityCtrl.text = c ?? '';
                          ctrl.notifyListeners();
                        },
                        decoration: const InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),

                    // Floors
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<int>(
                        value: ctrl.floors,
                        items: List.generate(
                          10,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1} floor${i == 0 ? '' : 's'}'),
                          ),
                        ),
                        onChanged: (v) => ctrl.setFloors(v ?? 1),
                        decoration: const InputDecoration(
                          labelText: 'Floors',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),

                    // Unit toggle
                    SizedBox(
                      width: 220,
                      child: SegmentedButton<AreaUnit>(
                        segments: const [
                          ButtonSegment(
                            value: AreaUnit.sqm,
                            label: Text('sqm / m'),
                          ),
                          ButtonSegment(
                            value: AreaUnit.sqft,
                            label: Text('sqft / ft'),
                          ),
                        ],
                        selected: {ctrl.areaUnit},
                        onSelectionChanged: (s) {
                          ctrl.setAreaUnit(s.first);
                        },
                      ),
                    ),

                    // Generate
                    SizedBox(
                      width: 220,
                      child: FilledButton.icon(
                        onPressed: ctrl.generate,
                        icon: const Icon(Icons.calculate),
                        label: const Text('Generate'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Floors grid (area + height rows, responsive)
              _floorsSection(context),

              const SizedBox(height: 16),

              // Files (names)
              if (ctrl.files.isNotEmpty) ...[
                const Text(
                  'Uploaded files',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ctrl.files
                      .map(
                        (f) => Chip(
                          avatar: const Icon(Icons.insert_drive_file, size: 16),
                          label: Text(f.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Results
              if (ctrl.result != null) ...[
                const Divider(height: 24),
                _resultSection(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // --- Floors section ---------------------------------------------------------
  Widget _floorsSection(BuildContext context) {
    final unitArea = ctrl.areaUnit == AreaUnit.sqft ? 'sqft' : 'sqm';
    final unitHeight = ctrl.areaUnit == AreaUnit.sqft ? 'ft' : 'm';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Floors — area & height',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: List.generate(ctrl.floors, (i) {
            return _floorInputsRow(
              context: context,
              index: i,
              areaCtrl: ctrl.floorAreaCtrls[i],
              heightCtrl: ctrl.floorHeightCtrls[i],
              unitLabelArea: unitArea,
              unitLabelHeight: unitHeight,
            );
          }),
        ),
      ],
    );
  }

  // --- Results ---------------------------------------------------------------
  Widget _resultSection(BuildContext context) {
    final r = ctrl.result!;
    final total = r.grandTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          r.projectName.isEmpty ? 'Estimate' : r.projectName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          '${r.region} • ${r.city} • ${r.totalAreaSqm.toStringAsFixed(0)} sqm total',
        ),
        const SizedBox(height: 12),

        // Totals summary
        Card(
          elevation: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _kv('Base cost', ctrl.formatMoney(r.baseCost)),
                _kv('Extra substructure',
                    ctrl.formatMoney(r.extraSubstructure)),
                _kv('Stairs', ctrl.formatMoney(r.stairsCost)),
                _kv('Grand Total', ctrl.formatMoney(total)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Phase breakdown
        if (r.phaseBreakdown.isNotEmpty)
          Card(
            elevation: 0.5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Phase breakdown',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...r.phaseBreakdown.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text(e.key)),
                          Text(ctrl.formatMoney(e.value)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- Small UI helpers ------------------------------------------------------
  Widget _kv(String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 4),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _input({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    double? width,
  }) {
    final field = TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
    if (width != null) return SizedBox(width: width, child: field);
    return field;
  }

  // --- Responsive row for a single floor's inputs -----------------------------
  Widget _floorInputsRow({
    required BuildContext context,
    required int index,
    required TextEditingController areaCtrl,
    required TextEditingController heightCtrl,
    required String unitLabelArea, // 'sqft' or 'sqm'
    required String unitLabelHeight, // 'ft' or 'm'
  }) {
    const fieldMin = 280.0; // keeps fields usable before wrapping
    const gap = 12.0;

    return LayoutBuilder(
      builder: (context, con) {
        final canPlaceSideBySide = con.maxWidth >= (fieldMin * 2 + gap);
        final fieldWidth =
            canPlaceSideBySide ? (con.maxWidth - gap) / 2 : con.maxWidth;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: fieldWidth,
              child: TextFormField(
                controller: areaCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Floor ${index + 1} area ($unitLabelArea)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  final d = double.tryParse(t);
                  if (t.isEmpty) return 'Required';
                  if (d == null || d <= 0) return 'Must be > 0';
                  return null;
                },
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: TextFormField(
                controller: heightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Height ($unitLabelHeight)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  final d = double.tryParse(t);
                  if (t.isEmpty) return 'Required';
                  if (d == null || d <= 0) return 'Must be > 0';
                  return null;
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
