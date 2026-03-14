import '../../core/config/service_locator.dart';
// lib/features/project/cost_analytics_page.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/cost_entry.dart';
import '../../core/models/payment_record.dart';
import '../../core/models/phase.dart';
import '../../core/models/project.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/project_service.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class CostAnalyticsPage extends StatelessWidget {
  const CostAnalyticsPage({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final svc = sl<ProjectService>();
    final paySvc = sl<PaymentService>();

    return Scaffold(
      appBar: AppBar(title: Text('${project.title} — Analytics')),
      body: FutureBuilder<_PageData>(
        future: _load(svc, paySvc),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final d = snap.data!;
          return _Body(
            project: project,
            costs: d.costs,
            phases: d.phases,
            payments: d.payments,
          );
        },
      ),
    );
  }

  Future<_PageData> _load(ProjectService svc, PaymentService paySvc) async {
    final results = await Future.wait([
      svc.costEntriesStream(project.id).first,
      svc.phasesStream(project.id).first,
      paySvc.paymentsStream(project.id).first,
    ]);
    return _PageData(
      costs: results[0] as List<CostEntry>,
      phases: results[1] as List<Phase>,
      payments: results[2] as List<PaymentRecord>,
    );
  }
}

class _PageData {
  const _PageData({
    required this.costs,
    required this.phases,
    required this.payments,
  });
  final List<CostEntry> costs;
  final List<Phase> phases;
  final List<PaymentRecord> payments;
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.project,
    required this.costs,
    required this.phases,
    required this.payments,
  });

  final Project project;
  final List<CostEntry> costs;
  final List<Phase> phases;
  final List<PaymentRecord> payments;

  static final _ghs = NumberFormat.currency(
    locale: 'en_GH',
    symbol: '₵',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final phasesWithCost =
        phases.where((p) => (p.estimatedCostGhs ?? 0) > 0 || (p.actualCostGhs ?? 0) > 0).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        _BudgetCard(project: project, ghs: _ghs),
        const SizedBox(height: 16),
        _CategoryCard(costs: costs, ghs: _ghs),
        if (phasesWithCost.isNotEmpty) ...[
          const SizedBox(height: 16),
          _PhaseCard(phases: phasesWithCost, ghs: _ghs),
        ],
        const SizedBox(height: 16),
        _PaymentCard(payments: payments, ghs: _ghs),
      ],
    );
  }
}

// ── Budget Overview card ──────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.project, required this.ghs});
  final Project project;
  final NumberFormat ghs;

  @override
  Widget build(BuildContext context) {
    final budget = project.budget;
    final spent = project.amountSpent;
    final remaining = (budget - spent).clamp(0.0, double.infinity);
    final pct = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final overBudget = budget > 0 && spent > budget;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget Overview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Budget',
                    value: ghs.format(budget),
                    color: cs.primary,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Spent',
                    value: ghs.format(spent),
                    color: overBudget ? cs.error : cs.tertiary,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Remaining',
                    value: ghs.format(remaining),
                    color: cs.secondary,
                  ),
                ),
              ],
            ),
            if (budget > 0) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 12,
                  backgroundColor: cs.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(
                    overBudget ? cs.error : cs.primary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                overBudget
                    ? 'Over budget by ${ghs.format(spent - budget)}'
                    : '${(pct * 100).toStringAsFixed(0)}% of budget used',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: overBudget ? cs.error : cs.outline,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Cost by Category card (PieChart) ─────────────────────────────────────────

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.costs, required this.ghs});
  final List<CostEntry> costs;
  final NumberFormat ghs;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  int _touchedIndex = -1;

  static const _palette = [
    Color(0xFF1565C0), // blue 800  — Materials
    Color(0xFFE65100), // orange 900 — Labour
    Color(0xFF6A1B9A), // purple 800 — Equipment
    Color(0xFF2E7D32), // green 800  — Professional Fees
    Color(0xFFC62828), // red 800    — Permits & Levies
    Color(0xFF546E7A), // blue grey  — Other
  ];

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, double>{};
    for (final c in widget.costs) {
      byCategory[c.category] = (byCategory[c.category] ?? 0) + c.amountGhs;
    }

    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total =
        entries.isEmpty ? 0.0 : entries.map((e) => e.value).reduce((a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cost by Category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No cost entries yet')),
              )
            else ...[
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex =
                              response.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    centerSpaceRadius: 44,
                    sectionsSpace: 2,
                    sections: entries.asMap().entries.map((e) {
                      final idx = e.key;
                      final amount = e.value.value;
                      final pct = total > 0 ? amount / total * 100 : 0.0;
                      final isTouched = idx == _touchedIndex;
                      return PieChartSectionData(
                        value: amount,
                        color: _palette[idx % _palette.length],
                        radius: isTouched ? 90.0 : 78.0,
                        title: '${pct.toStringAsFixed(0)}%',
                        showTitle: pct >= 5,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: entries.asMap().entries.map((e) {
                  final idx = e.key;
                  final cat = e.value.key;
                  final amount = e.value.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _palette[idx % _palette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$cat  ${widget.ghs.format(amount)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Phase Budget vs Actual card ───────────────────────────────────────────────

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.phases, required this.ghs});
  final List<Phase> phases;
  final NumberFormat ghs;

  @override
  Widget build(BuildContext context) {
    final maxVal = phases.fold<double>(
      0,
      (m, p) => [m, p.estimatedCostGhs ?? 0, p.actualCostGhs ?? 0]
          .reduce((a, b) => a > b ? a : b),
    );
    if (maxVal == 0) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phase Budget vs Actual',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _LegendDot(color: cs.primary, label: 'Estimated'),
                const SizedBox(width: 12),
                _LegendDot(color: cs.tertiary, label: 'Actual'),
              ],
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < phases.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _PhaseRow(phase: phases[i], maxVal: maxVal, ghs: ghs, cs: cs),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({
    required this.phase,
    required this.maxVal,
    required this.ghs,
    required this.cs,
  });
  final Phase phase;
  final double maxVal;
  final NumberFormat ghs;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final estimated = phase.estimatedCostGhs ?? 0;
    final actual = phase.actualCostGhs ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          phase.name,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (estimated > 0)
                  _HBar(
                    frac: estimated / maxVal,
                    totalWidth: w,
                    color: cs.primary,
                    label: ghs.format(estimated),
                  ),
                if (estimated > 0 && actual > 0) const SizedBox(height: 3),
                if (actual > 0)
                  _HBar(
                    frac: actual / maxVal,
                    totalWidth: w,
                    color: (actual > estimated && estimated > 0)
                        ? cs.error
                        : cs.tertiary,
                    label: ghs.format(actual),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HBar extends StatelessWidget {
  const _HBar({
    required this.frac,
    required this.totalWidth,
    required this.color,
    required this.label,
  });
  final double frac;
  final double totalWidth;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final barW = (totalWidth * frac).clamp(4.0, totalWidth * 0.75);
    return Row(
      children: [
        Container(
          width: barW,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

// ── Payment Summary card ──────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payments, required this.ghs});
  final List<PaymentRecord> payments;
  final NumberFormat ghs;

  @override
  Widget build(BuildContext context) {
    final outbound = payments
        .where((p) => p.direction == PaymentDirection.outbound)
        .fold(0.0, (s, p) => s + p.amountGhs);
    final inbound = payments
        .where((p) => p.direction == PaymentDirection.inbound)
        .fold(0.0, (s, p) => s + p.amountGhs);
    final net = inbound - outbound;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (payments.isEmpty)
              Text(
                'No payments recorded',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.outline),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'Paid Out',
                      value: ghs.format(outbound),
                      color: cs.error,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'Received',
                      value: ghs.format(inbound),
                      color: cs.secondary,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'Net',
                      value: ghs.format(net),
                      color: net >= 0 ? cs.primary : cs.error,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
