// lib/features/analytics/widgets/phase_progress_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/models/phase.dart';

class PhaseProgressChart extends StatelessWidget {
  const PhaseProgressChart({super.key, required this.phases});

  final List<Phase> phases;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (phases.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('No phases yet')),
      );
    }

    final counts = <PhaseStatus, int>{
      for (final s in PhaseStatus.values)
        s: phases.where((p) => p.status == s).length,
    };

    final colors = {
      PhaseStatus.pending: cs.surfaceContainerHighest,
      PhaseStatus.inProgress: cs.primary,
      PhaseStatus.pendingApproval: cs.tertiary,
      PhaseStatus.completed: Colors.green,
    };

    final maxY =
        counts.values.fold(0, (a, b) => a > b ? a : b).toDouble();

    final barGroups = PhaseStatus.values
        .asMap()
        .entries
        .map((e) => BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: counts[e.value]!.toDouble(),
                  color: colors[e.value],
                  width: 22,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Phase Status Breakdown',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Semantics(
          label: 'Phase status bar chart: '
              '${counts[PhaseStatus.pending]} pending, '
              '${counts[PhaseStatus.inProgress]} in progress, '
              '${counts[PhaseStatus.pendingApproval]} awaiting approval, '
              '${counts[PhaseStatus.completed]} completed.',
          child: SizedBox(
            height: 160,
            child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxY + 1).clamp(2, double.infinity),
              barGroups: barGroups,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (v, _) => v % 1 == 0
                        ? Text(
                            v.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final label = switch (v.toInt()) {
                        0 => 'Pending',
                        1 => 'In\nProgress',
                        2 => 'Approval',
                        3 => 'Done',
                        _ => '',
                      };
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 9),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                    reservedSize: 36,
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
            ),
          ),
          ),
        ),
      ],
    );
  }
}
