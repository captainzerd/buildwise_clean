// lib/features/estimate/widgets/project_inputs_section.dart
import 'package:flutter/material.dart';
import '../state/estimate_controller.dart';

class ProjectInputsSection extends StatelessWidget {
  final EstimateController ctrl;

  /// Pass precomputed lists from the parent to avoid reaching into
  /// controller internals that may not exist in your current version.
  final List<String> regions;
  final List<String> cities;

  const ProjectInputsSection({
    super.key,
    required this.ctrl,
    required this.regions,
    required this.cities,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 380,
          child: TextFormField(
            controller: ctrl.projectNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Project name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
        ),

        // Region
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            initialValue: regions.contains(ctrl.regionCtrl.text)
                ? ctrl.regionCtrl.text
                : (regions.isNotEmpty ? regions.first : null),
            items: regions
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (r) {
              if (r == null) return;
              // Update region; set city blank to force user to pick (or let parent rebuild cities list)
              ctrl.regionCtrl.text = r;
              ctrl.cityCtrl.text = '';
              // Parent (EstimateBody) will rebuild with new `cities` for the selected region.
            },
            decoration: const InputDecoration(
              labelText: 'Region',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),

        // City
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            initialValue: cities.contains(ctrl.cityCtrl.text)
                ? ctrl.cityCtrl.text
                : (cities.isNotEmpty ? cities.first : null),
            items: cities
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (c) {
              ctrl.cityCtrl.text = c ?? '';
            },
            decoration: const InputDecoration(
              labelText: 'City',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),
      ],
    );
  }
}
