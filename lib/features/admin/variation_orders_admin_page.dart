// lib/features/admin/variation_orders_admin_page.dart
//
// Admin view: all pending variation (change) orders across all projects.
// Admins can see status, submitter, project, and approve/reject on behalf of
// the owner if needed (e.g. owner is unresponsive).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/variation_order.dart';

class VariationOrdersAdminPage extends StatelessWidget {
  const VariationOrdersAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Collection-group query: all variation_orders across all projects.
    final stream = FirebaseFirestore.instance
        .collectionGroup('variation_orders')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Change Orders — All Projects')),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No change orders found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final doc = docs[i] as DocumentSnapshot<Map<String, dynamic>>;
              final vo = VariationOrder.fromDoc(doc);
              final fmt = NumberFormat('#,##0.00');
              final isIncrease = vo.costDeltaGhs >= 0;

              Color statusColor;
              switch (vo.status) {
                case VoStatus.approved:
                  statusColor = Colors.green;
                case VoStatus.rejected:
                  statusColor =
                      Theme.of(context).colorScheme.error;
                case VoStatus.pending:
                  statusColor =
                      Theme.of(context).colorScheme.secondary;
              }

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isIncrease
                        ? Theme.of(context).colorScheme.errorContainer
                        : Colors.green.shade100,
                    child: Icon(
                      isIncrease
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: isIncrease
                          ? Theme.of(context).colorScheme.error
                          : Colors.green,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    vo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      'By ${vo.submittedByName}',
                      'GHS ${fmt.format(vo.costDeltaGhs.abs())} ${isIncrease ? '▲' : '▼'}',
                      DateFormat('d MMM yyyy').format(vo.createdAt),
                    ].join(' · '),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  trailing: Chip(
                    label: Text(vo.status.label),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    labelStyle: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    side: BorderSide(color: statusColor),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
