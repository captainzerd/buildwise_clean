import '../../core/config/service_locator.dart';
// lib/features/estimate/estimate_result_page.dart
//
// Full-screen result page pushed after a successful estimate computation.
// Shows an animated count-up total, phase breakdown pie chart, expandable
// line rows, and two CTAs: Save and Create Project.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/boq_service.dart';
import '../../core/services/catalog_service.dart';
import '../project/create_project_page.dart';
import 'boq_page.dart';
import 'state/estimate_controller.dart';
import 'widgets/budget_compare_card.dart';

class EstimateResultPage extends StatefulWidget {
  const EstimateResultPage({super.key});

  @override
  State<EstimateResultPage> createState() => _EstimateResultPageState();
}

class _EstimateResultPageState extends State<EstimateResultPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  late final String _saveDocId = const Uuid().v4();
  bool _saving = false;
  bool _saved = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EstimateController>();
    final auth = context.read<AuthService>();
    final r = controller.result!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          controller.projectNameCtrl.text.trim().isEmpty
              ? 'Estimate Result'
              : controller.projectNameCtrl.text.trim(),
        ),
        actions: [
          IconButton(
            tooltip: 'Share estimate',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareEstimate(context, controller),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Animated total ───────────────────────────────────────────────
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  Text(
                    'Total Estimate',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: r.totalPlannedGhs),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOut,
                    builder: (_, v, __) => Text(
                      controller.money(v),
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.totalBuiltUpArea.toStringAsFixed(0)} m²  ·  '
                    '${controller.currency.code}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Rates version disclaimer ─────────────────────────────────────
          Consumer<CatalogService>(
            builder: (context, catalog, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rates current as of ${catalog.ratesVersionLabel}. '
                      'Actual costs may vary — obtain a professional QS '
                      'estimate before tendering.',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Budget compare (only when budget set) ───────────────────────
          if (controller.budgetAmount != null) ...[
            const BudgetCompareCard(),
            const SizedBox(height: 16),
          ],

          // ── Tab toggle ─────────────────────────────────────────────────
          Card(
            clipBehavior: Clip.antiAlias,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Phase Breakdown'),
                Tab(text: 'Specification'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Tab content ────────────────────────────────────────────────
          _TabContent(
            tabController: _tabController,
            r: r,
            moneyFn: controller.money,
          ),
          const SizedBox(height: 16),

          // ── Detailed line items ──────────────────────────────────────────
          _DetailCard(controller: controller),

          const SizedBox(height: 24),

          // ── CTAs ─────────────────────────────────────────────────────────
          if (auth.isSignedIn)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving || _saved
                    ? null
                    : () => _save(context, controller, auth),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_saved ? Icons.check : Icons.bookmark_add_outlined),
                label: Text(
                  _saved
                      ? 'Saved'
                      : _saving
                          ? 'Saving…'
                          : 'Save estimate',
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sign in to save estimates')),
                ),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save estimate'),
              ),
            ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit estimate'),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BoqPage(
                    phaseBreakdown: r.phaseBreakdownGhs,
                    floorAreaSqm: r.totalBuiltUpArea,
                    boqService: sl<BoqService>(),
                  ),
                ),
              ),
              icon: const Icon(Icons.table_chart_outlined, size: 18),
              label: const Text('View Bill of Quantities'),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () {
                final boqItems = sl<BoqService>()
                    .generate(
                      phaseBreakdown: r.phaseBreakdownGhs,
                      floorAreaSqm: r.totalBuiltUpArea,
                    )
                    .map((e) => e.toMap())
                    .toList();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CreateProjectPage(
                      initialTitle: controller.projectNameCtrl.text.trim(),
                      initialBudget: r.totalPlannedGhs,
                      initialRegion: controller.region,
                      initialBoqItems: boqItems,
                      initialFloorAreaSqm: r.totalBuiltUpArea,
                      initialBuildingType: controller.typology.name,
                      initialSpecQuality: controller.quality,
                      initialSpecFoundation: controller.foundation,
                      initialSpecSoil: controller.soil,
                      initialSpecRoof: controller.roof,
                      initialSpecMETier: controller.enhancedServices ? 'Enhanced' : 'Basic',
                      initialContingencyGhs: r.contingencyGhs,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Create project from estimate'),
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  void _shareEstimate(BuildContext context, EstimateController controller) {
    final r = controller.result!;
    final name = controller.projectNameCtrl.text.trim();
    final title = name.isEmpty ? 'WyseBrix Estimate' : name;
    final total = controller.money(r.totalPlannedGhs);
    final area = r.totalBuiltUpArea.toStringAsFixed(0);

    final buf = StringBuffer();
    buf.writeln(title);
    buf.writeln('Generated with WyseBrix (wysebrix.com)');
    buf.writeln();
    buf.writeln('Total: $total');
    buf.writeln('Built-up area: ${area}m²');
    buf.writeln();
    buf.writeln('Phase breakdown:');
    for (final e in r.phaseBreakdownGhs.entries) {
      buf.writeln('  ${e.key}: ${controller.money(e.value)}');
    }

    Share.share(buf.toString(), subject: title);
  }

  Future<void> _save(
    BuildContext context,
    EstimateController controller,
    AuthService auth,
  ) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uid = auth.currentUser!.uid;
      final r = controller.result!;
      // Freeze the BOQ at the moment of saving so it doesn't drift
      // if unit rates change in the future.
      final boqItems = sl<BoqService>()
          .generate(
            phaseBreakdown: r.phaseBreakdownGhs,
            floorAreaSqm: r.totalBuiltUpArea,
          )
          .map((e) => e.toMap())
          .toList();
      final data = {
        ...controller.toMap(),
        'userId': uid,
        'boqItems': boqItems,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('estimates')
          .doc(_saveDocId)
          .set(data);
      if (mounted) setState(() => _saved = true);
      messenger.showSnackBar(const SnackBar(content: Text('Estimate saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e'), duration: const Duration(seconds: 10)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Tab content (Phase Breakdown / Specification toggle) ─────────────────────

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.tabController,
    required this.r,
    required this.moneyFn,
  });

  final TabController tabController;
  final EstimateResult r;
  final String Function(double) moneyFn;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tabController,
      builder: (context, _) {
        if (tabController.index == 0) {
          return Column(
            children: [
              if (r.phaseBreakdownGhs.isNotEmpty)
                _PhaseChart(
                  phases: r.phaseBreakdownGhs,
                  moneyFn: moneyFn,
                ),
              const SizedBox(height: 16),
              _TradeBreakdownCard(
                phases: r.phaseBreakdownGhs,
                moneyFn: moneyFn,
              ),
            ],
          );
        }
        return _SpecificationBreakdownCard(
          breakdown: r.specificationBreakdownGhs,
          moneyFn: moneyFn,
        );
      },
    );
  }
}

// ── Specification breakdown card ─────────────────────────────────────────────

class _SpecificationBreakdownCard extends StatelessWidget {
  const _SpecificationBreakdownCard({
    required this.breakdown,
    required this.moneyFn,
  });

  final Map<String, double> breakdown;
  final String Function(double) moneyFn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (breakdown.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No specification breakdown available.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cost by Specification',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...breakdown.entries.map((e) {
              final isNegative = e.value < 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(e.key)),
                    Text(
                      '${isNegative ? '-' : '+'}${moneyFn(e.value.abs())}',
                      style: TextStyle(
                        color: isNegative ? cs.error : cs.primary,
                        fontWeight: e.key == 'Baseline'
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Trade breakdown card ──────────────────────────────────────────────────────
//
// Groups the phase cost map into four QS trade categories so that a QS or
// owner can quickly see where the money is going at the highest level.

class _TradeBreakdownCard extends StatelessWidget {
  const _TradeBreakdownCard({
    required this.phases,
    required this.moneyFn,
  });

  final Map<String, double> phases;
  final String Function(double) moneyFn;

  // Returns the trade category label for a phase name.
  static String _category(String phaseName) {
    final lc = phaseName.toLowerCase();
    if (lc.contains('sub') || lc.contains('foundation') || lc.contains('ground')) {
      return 'Substructure';
    }
    if (lc.contains('super') || lc.contains('wall') || lc.contains('frame') ||
        lc.contains('roof') || lc.contains('slab') || lc.contains('column')) {
      return 'Superstructure';
    }
    if (lc.contains('service') || lc.contains('mep') || lc.contains('m&e') ||
        lc.contains('plumb') || lc.contains('electric') || lc.contains('hvac') ||
        lc.contains('mechanical')) {
      return 'MEP & Services';
    }
    // Default: everything else (finishes, doors, windows, external works etc.)
    return 'Finishes & Others';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Aggregate phases into 4 buckets
    final totals = <String, double>{};
    for (final e in phases.entries) {
      final cat = _category(e.key);
      totals[cat] = (totals[cat] ?? 0) + e.value;
    }
    final grandTotal = totals.values.fold<double>(0, (a, b) => a + b);

    const icons = <String, IconData>{
      'Substructure': Icons.foundation,
      'Superstructure': Icons.apartment_outlined,
      'MEP & Services': Icons.electrical_services_outlined,
      'Finishes & Others': Icons.brush_outlined,
    };
    const colors = <String, Color>{
      'Substructure': Color(0xFF795548),
      'Superstructure': Color(0xFF6750A4),
      'MEP & Services': Color(0xFF009688),
      'Finishes & Others': Color(0xFFFF9800),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trade breakdown',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...['Substructure', 'Superstructure', 'MEP & Services', 'Finishes & Others']
                .where((cat) => totals.containsKey(cat))
                .map((cat) {
              final amount = totals[cat]!;
              final pct = grandTotal > 0 ? amount / grandTotal : 0.0;
              final color = colors[cat] ?? cs.primary;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      icons[cat] ?? Icons.category_outlined,
                      color: color,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                cat,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                '${(pct * 100).toStringAsFixed(1)}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: cs.surfaceContainerHighest,
                              color: color,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            moneyFn(amount),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Phase breakdown pie chart ────────────────────────────────────────────────

class _PhaseChart extends StatefulWidget {
  const _PhaseChart({required this.phases, required this.moneyFn});
  final Map<String, double> phases;
  final String Function(double) moneyFn;

  @override
  State<_PhaseChart> createState() => _PhaseChartState();
}

class _PhaseChartState extends State<_PhaseChart> {
  int _touched = -1;

  static const _palette = [
    Color(0xFF6750A4),
    Color(0xFF009688),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFF795548),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = widget.phases.entries.toList();
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phase breakdown',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        pieTouchData: PieTouchData(
                          touchCallback: (ev, resp) {
                            setState(() {
                              _touched =
                                  (ev.isInterestedForInteractions &&
                                          resp?.touchedSection != null)
                                      ? resp!.touchedSection!
                                          .touchedSectionIndex
                                      : -1;
                            });
                          },
                        ),
                        sections: [
                          for (int i = 0; i < entries.length; i++)
                            PieChartSectionData(
                              color: _palette[i % _palette.length],
                              value: entries[i].value,
                              title: _touched == i
                                  ? '${(entries[i].value / total * 100).toStringAsFixed(0)}%'
                                  : '',
                              radius: _touched == i ? 72 : 60,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < entries.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _palette[i % _palette.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    entries[i].key,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detailed line items card ─────────────────────────────────────────────────

class _DetailCard extends StatefulWidget {
  const _DetailCard({required this.controller});
  final EstimateController controller;

  @override
  State<_DetailCard> createState() => _DetailCardState();
}

class _DetailCardState extends State<_DetailCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final r = c.result!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cost breakdown',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: _expanded ? 'Collapse' : 'Expand',
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
            _row(
              context,
              'Construction phases',
              c.money(
                r.phaseBreakdownGhs.values.fold(0, (a, b) => a + b),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  children: [
                    for (final e in r.phaseBreakdownGhs.entries)
                      _row(context, e.key, c.money(e.value), secondary: true),
                  ],
                ),
              ),
            if (r.addOnsGhs.isNotEmpty) ...[
              _row(
                context,
                'External works',
                c.money(r.addOnsGhs.values.fold(0, (a, b) => a + b)),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    children: [
                      for (final e in r.addOnsGhs.entries)
                        _row(context, e.key, c.money(e.value), secondary: true),
                    ],
                  ),
                ),
            ],
            _row(context, 'Preliminaries', c.money(r.preliminariesGhs)),
            _row(context, 'OHP', c.money(r.ohpGhs)),
            if (r.professionalFeesGhs > 0)
              _row(context, 'Professional fees', c.money(r.professionalFeesGhs)),
            if (r.contingencyGhs > 0)
              _row(context, 'Contingency', c.money(r.contingencyGhs)),
            if (r.taxLinesGhs.isNotEmpty) ...[
              _row(
                context,
                'Taxes & levies',
                c.money(r.taxLinesGhs.values.fold(0, (a, b) => a + b)),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    children: [
                      for (final e in r.taxLinesGhs.entries)
                        _row(context, e.key, c.money(e.value), secondary: true),
                    ],
                  ),
                ),
            ],
            if (r.permitGhs > 0)
              _row(context, 'Permit fees', c.money(r.permitGhs)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total (${c.currency.code})',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  c.money(r.totalPlannedGhs),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool secondary = false,
  }) {
    final style = secondary
        ? Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
