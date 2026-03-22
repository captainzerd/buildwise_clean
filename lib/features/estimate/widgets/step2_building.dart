// lib/features/estimate/widgets/step2_building.dart
//
// Step 2 of the estimate wizard: building type, quality, foundation, soil, roof.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/estimate_controller.dart' show EstimateController, BuildingTypology;
import 'step_scaffold.dart';

// ── Phase 1: visible building types ──────────────────────────────────────────

const _kPhase1Typologies = [
  BuildingTypology.residentialStandard,
  BuildingTypology.residentialMediumRise,
];

// ── Icon mapping ───────────────────────────────────────────────────────────────

IconData _typologyIcon(BuildingTypology t) => switch (t) {
      BuildingTypology.residentialStandard => Icons.home_outlined,
      BuildingTypology.residentialMediumRise => Icons.apartment_outlined,
      BuildingTypology.residentialHighRise => Icons.location_city_outlined,
      BuildingTypology.commercialOffice => Icons.business_outlined,
      BuildingTypology.commercialRetail => Icons.storefront_outlined,
      BuildingTypology.commercialWarehouse => Icons.warehouse_outlined,
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
          // ── Typology card list ──────────────────────────────────────────────
          for (final t in _kPhase1Typologies) ...[
            GestureDetector(
              key: t == BuildingTypology.residentialStandard
                  ? const Key('step2_typology_residential_standard')
                  : null,
              onTap: () => controller.setProgramme(typology_: t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                child: Row(
                  children: [
                    Icon(
                      _typologyIcon(t),
                      color: controller.typology == t
                          ? cs.primary
                          : cs.onSurfaceVariant,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.shortLabel,
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
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: controller.typology == t
                                      ? cs.onPrimaryContainer
                                      : cs.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (controller.typology == t)
                      Icon(Icons.check_circle, color: cs.primary, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          // ── Quality ────────────────────────────────────────────────────────
          DropdownButtonFormField<String>(
            key: const Key('step3_quality_dropdown'),
            initialValue: controller.quality,
            items: const [
              DropdownMenuItem(value: 'Economy', child: Text('Economy')),
              DropdownMenuItem(
                key: Key('step3_quality_standard'),
                value: 'Standard',
                child: Text('Standard'),
              ),
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
