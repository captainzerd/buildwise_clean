// lib/features/project/widgets/phases_timeline.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/phase.dart';

class PhasesTimeline extends StatelessWidget {
  const PhasesTimeline({super.key, required this.phases});

  final List<Phase> phases;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (phases.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text(
              'No phases yet',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.outline),
            ),
          ],
        ),
      );
    }

    // Compute date range
    final dated = phases
        .where((p) => p.startDate != null && p.endDate != null)
        .toList();

    DateTime minDate;
    DateTime maxDate;

    if (dated.isEmpty) {
      minDate = DateTime.now().subtract(const Duration(days: 7));
      maxDate = DateTime.now().add(const Duration(days: 30));
    } else {
      minDate = dated
          .map((p) => p.startDate!)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      maxDate = dated
          .map((p) => p.endDate!)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      if (maxDate.difference(minDate).inDays < 7) {
        maxDate = minDate.add(const Duration(days: 30));
      }
    }

    const double chartW = 600;
    const double labelW = 100;
    const double rowH = 44;
    const double barH = 24;
    final totalDays = maxDate.difference(minDate).inDays.toDouble();

    // Today-line position
    final today = DateTime.now();
    final todayFrac = today.difference(minDate).inDays / totalDays;
    final todayX = (todayFrac * chartW).clamp(0.0, chartW);

    // Build axis labels (month markers)
    final axisItems = <Widget>[];
    DateTime cursor = DateTime(minDate.year, minDate.month, 1);
    if (!cursor.isAfter(minDate)) {
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    while (cursor.isBefore(maxDate)) {
      final frac = cursor.difference(minDate).inDays / totalDays;
      axisItems.add(
        Positioned(
          left: frac * chartW - 16,
          top: 0,
          child: Text(
            DateFormat('MMM').format(cursor),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.outline,
                  fontSize: 9,
                ),
          ),
        ),
      );
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(0, 8, 16, 96),
      child: SizedBox(
        width: labelW + chartW + 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Axis row ──
            SizedBox(
              height: 20,
              child: Row(
                children: [
                  SizedBox(width: labelW),
                  SizedBox(
                    width: chartW,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: axisItems,
                    ),
                  ),
                ],
              ),
            ),
            // Axis divider
            Row(
              children: [
                SizedBox(width: labelW),
                Expanded(
                  child: Divider(height: 1, color: cs.outlineVariant),
                ),
              ],
            ),
            // ── Phase rows ──
            for (final phase in phases)
              SizedBox(
                height: rowH,
                child: Row(
                  children: [
                    // Label
                    SizedBox(
                      width: labelW,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (phase.isMilestone)
                              const Icon(
                                Icons.star,
                                size: 12,
                                color: Colors.amber,
                              ),
                            Expanded(
                              child: Text(
                                phase.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bar area
                    SizedBox(
                      width: chartW,
                      child: phase.startDate == null || phase.endDate == null
                          ? Stack(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: 60,
                                    height: barH,
                                    decoration: BoxDecoration(
                                      color: cs.outlineVariant,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'No dates',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: cs.outline,
                                      ),
                                    ),
                                  ),
                                ),
                                // Today-line (no-date case)
                                Positioned(
                                  left: todayX,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 1.5,
                                    color:
                                        Colors.red.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                // Main phase bar
                                Positioned(
                                  left: phase.startDate!
                                          .difference(minDate)
                                          .inDays /
                                      totalDays *
                                      chartW,
                                  child: Container(
                                    width: (phase.endDate!
                                                .difference(phase.startDate!)
                                                .inDays
                                                .clamp(1, 10000) /
                                            totalDays *
                                            chartW)
                                        .clamp(8.0, chartW),
                                    height: barH,
                                    decoration: BoxDecoration(
                                      color: _barColor(phase.status),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                // Delay extension bar (red, semi-transparent)
                                if (phase.isDelayed) ...[
                                  Positioned(
                                    left: phase.endDate!
                                            .difference(minDate)
                                            .inDays /
                                        totalDays *
                                        chartW,
                                    child: Container(
                                      width: ((phase.actualEndDate ??
                                                      DateTime.now())
                                                  .difference(phase.endDate!)
                                                  .inDays
                                                  .clamp(1, 10000) /
                                              totalDays *
                                              chartW)
                                          .clamp(4.0, chartW),
                                      height: barH,
                                      decoration: BoxDecoration(
                                        color: Colors.red
                                            .withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.red,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                // Milestone diamond icon above bar
                                if (phase.isMilestone)
                                  Positioned(
                                    left: (phase.endDate!
                                                    .difference(minDate)
                                                    .inDays /
                                                totalDays *
                                                chartW) -
                                        7,
                                    top: 2,
                                    child: const Icon(
                                      Icons.diamond_outlined,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                  ),
                                // Today-line
                                Positioned(
                                  left: todayX,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 1.5,
                                    color:
                                        Colors.red.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            // ── Legend ──
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(width: labelW),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final s in PhaseStatus.values)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _barColor(s),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            s.label,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontSize: 9),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _barColor(PhaseStatus status) => switch (status) {
        PhaseStatus.completed => Colors.green.shade400,
        PhaseStatus.inProgress => Colors.blue.shade400,
        PhaseStatus.pendingApproval => Colors.orange.shade400,
        PhaseStatus.pending => Colors.grey.shade300,
      };
}
