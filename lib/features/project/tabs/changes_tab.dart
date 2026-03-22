// lib/features/project/tabs/changes_tab.dart
//
// Phase 1 simplified variation-orders tab.
// Read-only stream list. FAB (defined in ProjectDetailsPage) pushes
// the full VariationOrdersPage route for creating new changes.

import 'package:flutter/material.dart';
import '../../../core/config/service_locator.dart';
import '../../../core/models/variation_order.dart';
import '../../../core/services/variation_order_service.dart';

class ChangesTab extends StatelessWidget {
  const ChangesTab({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<List<VariationOrder>>(
      stream: sl<VariationOrderService>().ordersStream(projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snap.data ?? [];
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.compare_arrows_outlined,
                    size: 48, color: cs.outlineVariant),
                const SizedBox(height: 12),
                Text('No changes logged yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        )),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final vo = orders[i];
            final isIncrease = vo.costDeltaGhs >= 0;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    isIncrease ? cs.errorContainer : cs.tertiaryContainer,
                child: Icon(
                  isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isIncrease
                      ? cs.onErrorContainer
                      : cs.onTertiaryContainer,
                  size: 18,
                ),
              ),
              title: Text(vo.title),
              subtitle: Text(
                '${isIncrease ? '+' : ''}GH\u20B5 ${vo.costDeltaGhs.toStringAsFixed(0)}',
              ),
              trailing: Chip(
                label: Text(vo.status.label,
                    style: const TextStyle(fontSize: 11)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            );
          },
        );
      },
    );
  }
}
