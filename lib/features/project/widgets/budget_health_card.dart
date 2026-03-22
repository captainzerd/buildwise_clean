// lib/features/project/widgets/budget_health_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/phase.dart';
import '../../../core/models/project.dart';

enum _BudgetStatus { noBudget, green, amber, red, critical }

class BudgetHealthCard extends StatelessWidget {
  const BudgetHealthCard({
    super.key,
    required this.project,
    required this.phases,
  });

  final Project project;
  final List<Phase> phases;

  static final _pctFmt = NumberFormat('0.#', 'en');

  _BudgetStatus _computeStatus(double spendPct, double completionPct) {
    if (spendPct >= 90) return _BudgetStatus.critical;
    if (spendPct > completionPct + 25) return _BudgetStatus.red;
    if (spendPct > completionPct + 10) return _BudgetStatus.amber;
    return _BudgetStatus.green;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final effectiveBudget = project.budget > 0
        ? project.budget
        : project.estimateTotalGhs > 0
            ? project.estimateTotalGhs
            : 0.0;

    if (effectiveBudget == 0) {
      return _NoBudgetCard(cs: cs, tt: tt);
    }

    final spendPct =
        (project.amountSpent / effectiveBudget * 100).clamp(0.0, 999.0);
    final totalPhases = phases.length;
    final completedPhases =
        phases.where((p) => p.status == PhaseStatus.completed).length;
    final completionPct =
        totalPhases > 0 ? (completedPhases / totalPhases * 100) : 0.0;

    final status = _computeStatus(spendPct, completionPct);

    final Color statusColor;
    final String statusLabel;
    final String advisory;
    final IconData trafficIcon;

    switch (status) {
      case _BudgetStatus.green:
        statusColor = cs.tertiary;
        statusLabel = 'On Track';
        advisory = 'Spending is in line with progress.';
        trafficIcon = Icons.circle;
      case _BudgetStatus.amber:
        statusColor = Colors.amber.shade700;
        statusLabel = 'Caution';
        advisory =
            'Budget is being used faster than progress. Review costs.';
        trafficIcon = Icons.circle;
      case _BudgetStatus.red:
        statusColor = cs.error;
        statusLabel = 'At Risk';
        advisory = 'Significant budget overrun risk. Review urgently.';
        trafficIcon = Icons.circle;
      case _BudgetStatus.critical:
        statusColor = cs.error;
        statusLabel = 'Critical';
        advisory = 'Over 90% of budget committed. Caution needed.';
        trafficIcon = Icons.circle;
      case _BudgetStatus.noBudget:
        // Handled above — unreachable here.
        statusColor = cs.outline;
        statusLabel = '';
        advisory = '';
        trafficIcon = Icons.circle;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(trafficIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Budget Health',
                    style: tt.titleSmall,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: tt.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Budget used progress bar
            _ProgressRow(
              label: 'Budget used',
              pct: spendPct,
              color: statusColor,
              pctFmt: _pctFmt,
            ),

            const SizedBox(height: 10),

            // Phases complete progress bar
            _ProgressRow(
              label: 'Phases complete',
              pct: completionPct,
              color: cs.tertiary,
              pctFmt: _pctFmt,
            ),

            const SizedBox(height: 12),

            // Advisory message
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: statusColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    advisory,
                    style: tt.bodySmall?.copyWith(color: statusColor),
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

class _NoBudgetCard extends StatelessWidget {
  const _NoBudgetCard({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.circle, color: cs.outline, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Budget Health',
                style: tt.titleSmall,
              ),
            ),
            Text(
              'Set a budget to track health',
              style: tt.bodySmall?.copyWith(color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.pct,
    required this.color,
    required this.pctFmt,
  });

  final String label;
  final double pct;
  final Color color;
  final NumberFormat pctFmt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final displayPct = pct.clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: tt.labelSmall),
            Text(
              '${pctFmt.format(pct)}%',
              style: tt.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: displayPct / 100,
          backgroundColor: cs.surfaceContainerHighest,
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
