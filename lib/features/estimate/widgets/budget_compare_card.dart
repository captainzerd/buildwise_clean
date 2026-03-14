// lib/features/estimate/widgets/budget_compare_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../estimate/state/estimate_controller.dart';

class BudgetCompareCard extends StatelessWidget {
  const BudgetCompareCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EstimateController>();

    if (controller.budgetAmount == null || !controller.hasResult) {
      return const SizedBox.shrink();
    }

    final budget = controller.budgetAmount!;
    final estimate = controller.result!.totalPlannedGhs;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Budget vs Estimate',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text('Budget: ${controller.money(budget)}')),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Estimate: ${controller.money(estimate)}',
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (budget > 0) ? (estimate / budget).clamp(0.0, 1.5) : 0,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              color: estimate <= budget ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  estimate <= budget ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: estimate <= budget ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    estimate <= budget
                        ? 'Within budget'
                        : 'Over budget (${((estimate - budget) / budget * 100).toStringAsFixed(1)}% over)',
                    style: TextStyle(
                      color: estimate <= budget ? Colors.green : Colors.red,
                    ),
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
