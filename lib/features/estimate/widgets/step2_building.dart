// lib/features/estimate/widgets/step2_building.dart
//
// Step 2 of the estimate wizard: building type, quality, foundation, soil, roof,
// M&E tier and curtain wall toggles.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/estimate_controller.dart' show EstimateController, BuildingTypology;
import 'step_scaffold.dart';

// ── Icon mapping ───────────────────────────────────────────────────────────────

IconData _typologyIcon(BuildingTypology t) => switch (t) {
      BuildingTypology.residentialStandard => Icons.home_outlined,
      BuildingTypology.residentialMediumRise => Icons.apartment_outlined,
      BuildingTypology.residentialHighRise => Icons.location_city_outlined,
      // Reserved for future expansion — not shown in MVP residential-only UI.
      BuildingTypology.commercialOffice => Icons.business_outlined,
      BuildingTypology.commercialRetail => Icons.storefront_outlined,
      BuildingTypology.commercialWarehouse => Icons.warehouse_outlined,
    };

// ── Short label mapping ────────────────────────────────────────────────────────

String _typologyShortLabel(BuildingTypology t) => switch (t) {
      BuildingTypology.residentialStandard => 'Residential Standard',
      BuildingTypology.residentialMediumRise => 'Medium-rise Apt',
      BuildingTypology.residentialHighRise => 'High-rise Apt',
      // Reserved for future expansion — not shown in MVP residential-only UI.
      BuildingTypology.commercialOffice => 'Office / Institution',
      BuildingTypology.commercialRetail => 'Retail / Mixed Use',
      BuildingTypology.commercialWarehouse => 'Warehouse / Factory',
    };

// ── Step 2 ────────────────────────────────────────────────────────────────────

class Step2Building extends StatelessWidget {
  const Step2Building({
    super.key,
    required this.onNext,
    required this.onBack,
  });
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EstimateController>();
    final cardWidth = (MediaQuery.of(context).size.width - 48) / 2;
    final cs = Theme.of(context).colorScheme;

    return StepScaffold(
      onNext: onNext,
      onBack: onBack,
      nextLabel: 'Next: Floors',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(context, 'Building specification'),
          const SizedBox(height: 16),
          // ── Typology card grid ──────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in const [
                BuildingTypology.residentialStandard,
                BuildingTypology.residentialMediumRise,
                BuildingTypology.residentialHighRise,
              ])
                GestureDetector(
                  onTap: () => controller.setProgramme(typology_: t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: cardWidth,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: controller.typology == t
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      border: Border.all(
                        color: controller.typology == t
                            ? cs.primary
                            : cs.outlineVariant,
                        width: controller.typology == t ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _typologyIcon(t),
                          color: controller.typology == t
                              ? cs.primary
                              : cs.onSurfaceVariant,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _typologyShortLabel(t),
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: controller.typology == t
                                    ? cs.onPrimaryContainer
                                    : cs.onSurface,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.subtitle,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: controller.typology == t
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Quality ────────────────────────────────────────────────────────
          DropdownButtonFormField<String>(
            initialValue: controller.quality,
            items: const [
              DropdownMenuItem(value: 'Economy', child: Text('Economy')),
              DropdownMenuItem(value: 'Standard', child: Text('Standard')),
              DropdownMenuItem(value: 'Premium', child: Text('Premium')),
            ],
            onChanged: (v) => controller.setProgramme(quality_: v),
            decoration:
                const InputDecoration(labelText: 'Quality / finish level'),
          ),
          const SizedBox(height: 12),
          // ── Foundation ─────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: controller.foundation,
                  items: const [
                    DropdownMenuItem(value: 'Strip', child: Text('Strip')),
                    DropdownMenuItem(value: 'Raft', child: Text('Raft')),
                    DropdownMenuItem(value: 'Pad', child: Text('Pad')),
                    DropdownMenuItem(value: 'Pile', child: Text('Pile')),
                  ],
                  onChanged: (v) => controller.setProgramme(foundation_: v),
                  decoration: const InputDecoration(
                    labelText: 'Foundation type',
                    helperText:
                        'Strip: standard soil · Raft/Pile: soft or waterlogged',
                  ),
                ),
              ),
              FieldHelp(
                title: 'Foundation types',
                body:
                    'Strip — continuous concrete strip; suitable for firm or laterite soil.\n\n'
                    'Raft — reinforced slab over the whole footprint; used on soft or expansive soil.\n\n'
                    'Pad — isolated column footings; for commercial or frame structures.\n\n'
                    'Pile — deep concrete piles; required on waterlogged or very soft ground.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Soil ───────────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: controller.soil,
                  items: const [
                    DropdownMenuItem(value: 'Firm', child: Text('Firm')),
                    DropdownMenuItem(value: 'Soft', child: Text('Soft')),
                    DropdownMenuItem(
                      value: 'Waterlogged',
                      child: Text('Waterlogged'),
                    ),
                    DropdownMenuItem(
                      value: 'Laterite',
                      child: Text('Laterite'),
                    ),
                  ],
                  onChanged: (v) => controller.setProgramme(soil_: v),
                  decoration: const InputDecoration(
                    labelText: 'Soil condition',
                    helperText: 'Affects excavation depth and material costs',
                  ),
                ),
              ),
              FieldHelp(
                title: 'Soil conditions',
                body:
                    'Firm — compacted gravel or hard clay; standard excavation cost.\n\n'
                    'Laterite — reddish iron-rich soil common in Ghana; generally stable.\n\n'
                    'Soft — loose or sandy soil; needs deeper footings and more fill.\n\n'
                    'Waterlogged — high water table; significant extra cost for drainage and piling.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Roof ───────────────────────────────────────────────────────────
          DropdownButtonFormField<String>(
            initialValue: controller.roof,
            items: const [
              DropdownMenuItem(
                value: 'Pitched sheet',
                child: Text('Pitched sheet'),
              ),
              DropdownMenuItem(
                value: 'Concrete flat',
                child: Text('Concrete flat'),
              ),
              DropdownMenuItem(value: 'Tile', child: Text('Tile')),
            ],
            onChanged: (v) => controller.setProgramme(roof_: v),
            decoration: const InputDecoration(labelText: 'Roof type'),
          ),
          const SizedBox(height: 16),
          // ── Services & Openings ────────────────────────────────────────────
          sectionLabel(context, 'Services & Openings'),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enhanced M&E services'),
            subtitle: const Text(
              'AC, solar-ready, smart wiring, 3-phase power (+18%)',
            ),
            value: controller.enhancedServices,
            onChanged: controller.setEnhancedServices,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Curtain wall / large glazing'),
            subtitle: const Text(
              'Openings allocation raised to 8% of base (+4%)',
            ),
            value: controller.curtainWall,
            onChanged: controller.setCurtainWall,
          ),
        ],
      ),
    );
  }
}

// ── Field help popover ────────────────────────────────────────────────────────

class FieldHelp extends StatelessWidget {
  const FieldHelp({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: IconButton(
        icon: const Icon(Icons.help_outline, size: 18),
        color: Theme.of(context).colorScheme.outline,
        tooltip: title,
        onPressed: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
