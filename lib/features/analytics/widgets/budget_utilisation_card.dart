// lib/features/analytics/widgets/budget_utilisation_card.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BudgetUtilisationCard extends StatelessWidget {
  const BudgetUtilisationCard({
    super.key,
    required this.budgetGhs,
    required this.spentGhs,
    required this.title,
  });

  final double budgetGhs;
  final double spentGhs;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00');

    final remaining = (budgetGhs - spentGhs).clamp(0.0, double.infinity);
    final pct = budgetGhs > 0 ? (spentGhs / budgetGhs).clamp(0.0, 1.0) : 0.0;
    final overBudget = budgetGhs > 0 && spentGhs > budgetGhs;

    final spentColor =
        overBudget ? cs.error : cs.primary;
    final remainColor = cs.surfaceContainerHighest;

    final sections = budgetGhs > 0
        ? [
            PieChartSectionData(
              value: spentGhs.clamp(0, double.infinity),
              color: spentColor,
              radius: 28,
              showTitle: false,
            ),
            PieChartSectionData(
              value: remaining,
              color: remainColor,
              radius: 24,
              showTitle: false,
            ),
          ]
        : [
            PieChartSectionData(
              value: 1,
              color: remainColor,
              radius: 24,
              showTitle: false,
            ),
          ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Semantics(
              label: '$title budget utilisation: '
                  '${(pct * 100).toStringAsFixed(0)}% used. '
                  'Spent GHS ${fmt.format(spentGhs)} of GHS ${fmt.format(budgetGhs)}. '
                  '${overBudget ? 'Over budget.' : 'Remaining: GHS ${fmt.format(remaining)}.'}',
              child: SizedBox(
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 36,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: overBudget ? cs.error : null,
                            ),
                      ),
                      Text(
                        'used',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
              ),
            ),
            const SizedBox(height: 12),
            _LegendRow(color: spentColor, label: 'Spent', value: 'GHS ${fmt.format(spentGhs)}'),
            const SizedBox(height: 4),
            _LegendRow(color: remainColor, label: 'Remaining', value: 'GHS ${fmt.format(remaining)}'),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const Spacer(),
        Text(value, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
