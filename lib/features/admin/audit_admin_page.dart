import '../../core/config/service_locator.dart';
// lib/features/admin/audit_admin_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/audit_event.dart';
import '../../core/services/audit_service.dart';

class AuditAdminPage extends StatelessWidget {
  const AuditAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auditService = sl<AuditService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: StreamBuilder<List<AuditEvent>>(
        stream: auditService.allEventsStream(limit: 200),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data ?? [];
          if (events.isEmpty) {
            return const Center(
              child: Text('No audit events yet.'),
            );
          }
          return ListView.separated(
            itemCount: events.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _AdminAuditTile(event: events[i]),
          );
        },
      ),
    );
  }
}

class _AdminAuditTile extends StatelessWidget {
  const _AdminAuditTile({required this.event});
  final AuditEvent event;

  IconData _icon(AuditEventType type) => switch (type) {
        AuditEventType.phaseAdded => Icons.layers_outlined,
        AuditEventType.phaseStatusChanged => Icons.layers,
        AuditEventType.costEntryAdded => Icons.receipt_long_outlined,
        AuditEventType.costEntryDeleted => Icons.receipt_long,
        AuditEventType.paymentAdded => Icons.payments_outlined,
        AuditEventType.paymentDeleted => Icons.payments,
        AuditEventType.contractSigned => Icons.draw_outlined,
        AuditEventType.builderAssigned => Icons.person_add_outlined,
        AuditEventType.projectStatusChanged => Icons.flag_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd MMM yyyy, HH:mm');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.secondaryContainer,
        radius: 18,
        child: Icon(
          _icon(event.type),
          size: 16,
          color: cs.onSecondaryContainer,
        ),
      ),
      title: Text(event.description),
      subtitle: Text(
        '${event.actorName}  ·  project: ${event.projectId.substring(0, 8)}…  ·  ${fmt.format(event.createdAt)}',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      isThreeLine: true,
    );
  }
}
