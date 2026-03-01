// lib/features/estimate/estimate_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/catalog_service.dart';
import '../../core/services/fx_service.dart';
import '../../core/services/regional_index_provider.dart';
import '../project/create_project_page.dart';
import 'saved_estimates_page.dart';
import 'state/estimate_controller.dart';
import 'widgets/budget_compare_card.dart';

class EstimatePage extends StatefulWidget {
  const EstimatePage({super.key});

  @override
  State<EstimatePage> createState() => _EstimatePageState();
}

class _EstimatePageState extends State<EstimatePage> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EstimateController>();
    final regional = context.watch<RegionalIndexProvider>();
    final fx = context.watch<FxService>();
    final catalog = context.watch<CatalogService>();

    final auth = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estimate'),
        actions: [
          IconButton(
            tooltip: 'Saved estimates',
            icon: const Icon(Icons.history),
            onPressed: auth.isSignedIn
                ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SavedEstimatesPage(),
                      ),
                    )
                : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sign in to view saved estimates'),
                      ),
                    ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: controller.formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'New Estimate',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),

              // Catalog fallback banner
              if (catalog.isUsingFallback)
                _InfoBanner(
                  icon: Icons.info_outline,
                  message: 'Using built-in rates — live catalog unavailable.',
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  textColor: Theme.of(context).colorScheme.onTertiaryContainer,
                ),

              const SizedBox(height: 8),

              // Project
              _card(
                context,
                title: 'Project',
                children: [
                  TextFormField(
                    controller: controller.projectNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Project name',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Region (optional)',
                    ),
                    initialValue: controller.region ??
                        (regional.regionCodes.isNotEmpty
                            ? regional.regionCodes.first
                            : 'DEFAULT'),
                    items: (regional.regionCodes.isNotEmpty
                            ? regional.regionCodes
                            : const ['DEFAULT'])
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          ),
                        )
                        .toList(),
                    onChanged: controller.setRegion,
                  ),
                  const SizedBox(height: 12),
                  _CurrencyPicker(
                    current: controller.currency,
                    onChanged: controller.setCurrency,
                    fxService: fx,
                  ),
                ],
              ),

              // Programme
              _card(
                context,
                title: 'Programme',
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: controller.buildingType,
                    items: const [
                      DropdownMenuItem(
                        value: 'Residential',
                        child: Text('Residential'),
                      ),
                      DropdownMenuItem(
                        value: 'Commercial',
                        child: Text('Commercial'),
                      ),
                    ],
                    onChanged: (v) => controller.setProgramme(buildingType_: v),
                    decoration: const InputDecoration(
                      labelText: 'Building type',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: controller.quality,
                    items: const [
                      DropdownMenuItem(
                        value: 'Economy',
                        child: Text('Economy'),
                      ),
                      DropdownMenuItem(
                        value: 'Standard',
                        child: Text('Standard'),
                      ),
                      DropdownMenuItem(
                        value: 'Premium',
                        child: Text('Premium'),
                      ),
                    ],
                    onChanged: (v) => controller.setProgramme(quality_: v),
                    decoration: const InputDecoration(labelText: 'Quality'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: controller.foundation,
                    items: const [
                      DropdownMenuItem(value: 'Strip', child: Text('Strip')),
                      DropdownMenuItem(value: 'Raft', child: Text('Raft')),
                      DropdownMenuItem(value: 'Pad', child: Text('Pad')),
                      DropdownMenuItem(value: 'Pile', child: Text('Pile')),
                    ],
                    onChanged: (v) => controller.setProgramme(foundation_: v),
                    decoration: const InputDecoration(labelText: 'Foundation'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
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
                    decoration: const InputDecoration(labelText: 'Soil'),
                  ),
                  const SizedBox(height: 12),
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
                    decoration: const InputDecoration(labelText: 'Roof'),
                  ),
                ],
              ),

              // Floors
              _card(
                context,
                title: 'Floors',
                trailing: IconButton(
                  onPressed: controller.addFloor,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add floor',
                ),
                children: [
                  for (int i = 0; i < controller.floors.length; i++)
                    _FloorRow(
                      index: i,
                      spec: controller.floors[i],
                      onChanged: (area, height) => controller.updateFloor(
                        i,
                        areaM2: area,
                        heightM: height,
                      ),
                      onRemove: controller.floors.length > 1
                          ? () => controller.removeFloor(i)
                          : null,
                    ),
                ],
              ),

              // External works
              _card(
                context,
                title: 'External works',
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include external works'),
                    value: controller.includeExternalWorks,
                    onChanged: (v) => controller.setExternalWorks(enabled: v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          enabled: controller.includeExternalWorks,
                          initialValue:
                              controller.externalWallLenM.toStringAsFixed(0),
                          decoration: const InputDecoration(
                            labelText: 'Compound wall length',
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
                          enabled: controller.includeExternalWorks,
                          initialValue:
                              controller.drivewayAreaM2.toStringAsFixed(0),
                          decoration: const InputDecoration(
                            labelText: 'Driveway area',
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
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include septic/soakaway'),
                    value: controller.includeSeptic,
                    onChanged: (v) =>
                        controller.setExternalWorks(septic: v ?? false),
                  ),
                ],
              ),

              // Commercials
              _card(
                context,
                title: 'Commercials',
                children: [
                  _LabeledSlider(
                    label: 'Preliminaries',
                    value: controller.preliminariesPct,
                    min: 0,
                    max: 20,
                    onChanged: controller.setPreliminariesPct,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Contingency'),
                          value: controller.contingencyEnabled,
                          onChanged: controller.setContingencyEnabled,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (controller.contingencyEnabled)
                        Expanded(
                          child: _LabeledSlider(
                            label: 'Contingency %',
                            value: controller.contingencyPct,
                            min: 0,
                            max: 30,
                            onChanged: controller.setContingencyPct,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Statutory & permits
              _card(
                context,
                title: 'Statutory & Permits',
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taxes/Levies (applied to net before tax)',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      for (final t in controller.taxLines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.name),
                              Text('${t.pct.toStringAsFixed(1)}%'),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  DropdownButtonFormField<PermitMode>(
                    initialValue: controller.permitMode,
                    items: const [
                      DropdownMenuItem(
                        value: PermitMode.percent,
                        child: Text('Permit as % (auto)'),
                      ),
                      DropdownMenuItem(
                        value: PermitMode.manual,
                        child: Text('Permit manual amount'),
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
                        labelText: 'Permit % (of base + externals)',
                        suffixText: '%',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) =>
                          controller.setPermitManual(double.tryParse(v)),
                    ),
                ],
              ),

              // Budget
              _card(
                context,
                title: 'Budget (optional)',
                children: [
                  TextFormField(
                    initialValue:
                        controller.budgetAmount?.toStringAsFixed(0) ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Budget amount',
                      suffixText: 'GHS',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) =>
                        controller.setBudgetAmount(double.tryParse(v)),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Compute button
              FilledButton.icon(
                onPressed: controller.isComputing
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await context.read<CatalogService>().ensureLoaded();
                        await controller.compute();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.hasResult
                                  ? 'Total: ${controller.money(controller.result!.totalPlannedGhs)}'
                                  : controller.computeError ??
                                      'Please complete the form',
                            ),
                          ),
                        );
                      },
                icon: controller.isComputing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.calculate_outlined),
                label: Text(
                  controller.isComputing ? 'Computing…' : 'Compute estimate',
                ),
              ),

              // Compute error banner
              if (controller.computeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _InfoBanner(
                    icon: Icons.error_outline,
                    message: controller.computeError!,
                    color: Theme.of(context).colorScheme.errorContainer,
                    textColor:
                        Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),

              const SizedBox(height: 16),

              // Comparison first (if both values exist), then detailed results
              if (controller.hasResult && controller.budgetAmount != null)
                const BudgetCompareCard(),
              if (controller.hasResult)
                _ResultsCard(
                  controller: controller,
                  onSave: auth.isSignedIn
                      ? () => _saveEstimate(context, controller, auth)
                      : null,
                ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveEstimate(
    BuildContext context,
    EstimateController controller,
    AuthService auth,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uid = auth.currentUser!.uid;
      final data = {
        ...controller.toMap(),
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('estimates')
          .add(data);
      messenger.showSnackBar(
        const SnackBar(content: Text('Estimate saved')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Widget _card(
    BuildContext context, {
    required String title,
    List<Widget> children = const [],
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ── Reusable info/error banner ─────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.message,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Currency picker ────────────────────────────────────────────────────────────

class _CurrencyPicker extends StatelessWidget {
  const _CurrencyPicker({
    required this.current,
    required this.onChanged,
    required this.fxService,
  });

  final CurrencyInfo current;
  final ValueChanged<CurrencyInfo> onChanged;
  final FxService fxService;

  String _rateLabel(CurrencyInfo c) {
    if (c.code == 'GHS') return 'Base currency';
    final rate = fxService.rateFor(c.code);
    if (rate <= 0) return c.name;
    return '1 GHS = ${c.symbol}${rate.toStringAsFixed(4)}';
  }

  String _subtitleText() {
    final updated = fxService.lastUpdated;
    final suffix = updated != null
        ? 'rates ${_timeAgo(updated)}'
        : 'estimated rates';
    return '${current.code}  •  $suffix';
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return 'updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'updated ${diff.inHours}h ago';
    return 'updated ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Currency'),
      subtitle: Text(_subtitleText()),
      trailing: const Icon(Icons.expand_more),
      onTap: () async {
        final picked = await showModalBottomSheet<CurrencyInfo>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Select currency',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                for (final c in CurrencyInfo.values)
                  ListTile(
                    leading: SizedBox(
                      width: 32,
                      child: Text(
                        c.symbol,
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    title: Text('${c.code}  —  ${c.name}'),
                    subtitle: Text(_rateLabel(c)),
                    trailing: c == current
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(ctx).colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(ctx).pop(c),
                  ),
                SizedBox(
                  height: MediaQuery.of(ctx).padding.bottom + 16,
                ),
              ],
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

// ── Floor row ──────────────────────────────────────────────────────────────────

class _FloorRow extends StatelessWidget {
  const _FloorRow({
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
        children: [
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
          const SizedBox(width: 12),
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
          const SizedBox(width: 8),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove floor',
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

// ── Results card ───────────────────────────────────────────────────────────────

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.controller, this.onSave});
  final EstimateController controller;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final r = controller.result!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estimate', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _row(
              'Built-up area',
              '${r.totalBuiltUpArea.toStringAsFixed(0)} m²',
            ),
            const Divider(height: 20),
            Text('Phases', style: Theme.of(context).textTheme.labelLarge),
            ...r.phaseBreakdownGhs.entries
                .map((e) => _row(e.key, controller.money(e.value))),
            if (r.addOnsGhs.isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                'External works',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              ...r.addOnsGhs.entries
                  .map((e) => _row(e.key, controller.money(e.value))),
            ],
            const Divider(height: 20),
            _row('Preliminaries', controller.money(r.preliminariesGhs)),
            _row('OHP', controller.money(r.ohpGhs)),
            _row('Contingency', controller.money(r.contingencyGhs)),
            const Divider(height: 20),
            Text('Taxes/Levies', style: Theme.of(context).textTheme.labelLarge),
            ...r.taxLinesGhs.entries
                .map((e) => _row(e.key, controller.money(e.value))),
            _row('Permit fees', controller.money(r.permitGhs)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total (${controller.currency.code})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  controller.money(r.totalPlannedGhs),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Create Project from Estimate'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CreateProjectPage(
                      initialTitle: controller.projectNameCtrl.text.trim(),
                      initialBudget: r.totalPlannedGhs,
                      initialRegion: controller.region,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save estimate'),
                onPressed: onSave ??
                    () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sign in to save estimates'),
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value)],
        ),
      );
}
