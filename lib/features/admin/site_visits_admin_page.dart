// lib/features/admin/site_visits_admin_page.dart
//
// Admin view: upcoming and recent site visits across all projects.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/site_visit.dart';

class SiteVisitsAdminPage extends StatelessWidget {
  const SiteVisitsAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Collection-group query: all site_visits across all projects.
    final stream = FirebaseFirestore.instance
        .collectionGroup('site_visits')
        .orderBy('scheduledAt', descending: false)
        .limit(200)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Site Inspections — All Projects')),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No site visits found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final doc = docs[i] as DocumentSnapshot<Map<String, dynamic>>;
              final visit = SiteVisit.fromDoc(doc);
              final isPast = visit.scheduledAt.isBefore(DateTime.now());
              final cs = Theme.of(context).colorScheme;

              Color statusColor;
              switch (visit.status) {
                case VisitStatus.completed:
                  statusColor = Colors.green;
                case VisitStatus.cancelled:
                  statusColor = cs.outline;
                case VisitStatus.scheduled:
                  statusColor = isPast ? Colors.orange : cs.primary;
              }

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Icon(
                      Icons.location_city_outlined,
                      color: cs.onPrimaryContainer,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    visit.purpose,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      'By ${visit.scheduledByName}',
                      DateFormat('EEE d MMM yyyy, h:mm a').format(visit.scheduledAt),
                    ].join(' · '),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.outline,
                        ),
                  ),
                  trailing: Chip(
                    label: Text(
                      visit.status == VisitStatus.scheduled && isPast
                          ? 'Overdue'
                          : visit.status.label,
                    ),
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
