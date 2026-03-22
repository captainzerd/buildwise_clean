// lib/features/analytics/widgets/spend_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/cost_entry.dart';

class SpendChart extends StatelessWidget {
  const SpendChart({super.key, required this.costs, required this.projectTitle});

  final List<CostEntry> costs;
  final String projectTitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (costs.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('No cost entries yet')),
      );
    }

    // Bucket costs by month (yyyy-MM)
    final buckets = <String, double>{};
    for (final entry in costs) {
      final key = DateFormat('yyyy-MM').format(entry.createdAt);
      buckets[key] = (buckets[key] ?? 0) + entry.amountGhs;
    }

    final sortedKeys = buckets.keys.toList()..sort();
    double cumulative = 0;
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedKeys.length; i++) {
      cumulative += buckets[sortedKeys[i]]!;
      spots.add(FlSpot(i.toDouble(), cumulative));
    }

    final maxY = cumulative * 1.2;
    final fmt = NumberFormat('#,##0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Cumulative Spend (GHS)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Semantics(
          label: 'Cumulative spend line chart for $projectTitle. '
              'Total spend: GHS ${fmt.format(cumulative)} over '
              '${spots.length} month${spots.length == 1 ? '' : 's'}.',
          child: SizedBox(
            height: 180,
            child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY > 0 ? maxY : 1,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: cs.primary,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: spots.length <= 6,
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: cs.primary.withValues(alpha: 0.12),
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        fmt.format(v),
                        style: const TextStyle(fontSize: 9),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= sortedKeys.length) {
                        return const SizedBox.shrink();
                      }
                      final label = sortedKeys[idx].substring(5); // MM
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 9),
                        ),
                      );
                    },
                    interval: 1,
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: cs.outlineVariant,
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map(
                        (s) => LineTooltipItem(
                          'GHS ${fmt.format(s.y)}',
                          TextStyle(
                            color: cs.onPrimary,
                            fontSize: 11,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
        ),
      ],
    );
  }
}
