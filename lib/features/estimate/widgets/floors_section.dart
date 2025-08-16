// lib/features/estimate/widgets/floors_section.dart
import 'package:flutter/material.dart';
import '../state/estimate_controller.dart';

/// Shows per-floor Area + Height fields side-by-side, with units tied to ctrl.areaUnit:
/// - If areaUnit == sqft => heights in feet
/// - If areaUnit == sqm  => heights in metres
class FloorsSection extends StatelessWidget {
  final EstimateController ctrl;
  const FloorsSection({super.key, required this.ctrl});

  String _heightUnit(AreaUnit unit) => unit == AreaUnit.sqft ? 'ft' : 'm';
  String _areaUnit(AreaUnit unit) => unit == AreaUnit.sqft ? 'sqft' : 'sqm';

  @override
  Widget build(BuildContext context) {
    final hu = _heightUnit(ctrl.areaUnit);
    final au = _areaUnit(ctrl.areaUnit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Floors (${ctrl.floors})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: List.generate(ctrl.floors, (i) {
            final areaCtrl = ctrl.floorAreaCtrls[i];
            final heightCtrl = ctrl.floorHeightCtrls[i];

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Area
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: areaCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Floor ${i + 1} area ($au)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      hintText: au == 'sqft' ? 'e.g. 1200' : 'e.g. 110',
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
                const SizedBox(width: 8),
                // Height
                SizedBox(
                  width: 150,
                  child: TextFormField(
                    controller: heightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Height ($hu)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      hintText: hu == 'ft' ? 'e.g. 10' : 'e.g. 3.0',
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
          }),
        ),
      ],
    );
  }
}
