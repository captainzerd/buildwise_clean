import '../../core/config/service_locator.dart';
// lib/features/project/project_audit_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/audit_event.dart';
import '../../core/services/audit_service.dart';

class ProjectAuditPage extends StatelessWidget {
  const ProjectAuditPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  final String projectId;
  final String projectTitle;

  @override
  Widget build(BuildContext context) {
    final auditService = sl<AuditService>();

    return Scaffold(
      appBar: AppBar(title: Text('Audit Log — $projectTitle')),
      body: StreamBuilder<List<AuditEvent>>(
        stream: auditService.eventsStream(projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data ?? [];
          if (events.isEmpty) {
            return const Center(
              child: Text('No audit events recorded yet.'),
            );
          }
          return ListView.separated(
            itemCount: events.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _AuditEventTile(event: events[i]),
          );
        },
      ),
    );
  }
}

class _AuditEventTile extends StatelessWidget {
  const _AuditEventTile({required this.event});
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
        backgroundColor: cs.primaryContainer,
        radius: 18,
        child: Icon(
          _icon(event.type),
          size: 16,
          color: cs.onPrimaryContainer,
        ),
      ),
      title: Text(event.description),
      subtitle: Text(
        '${event.actorName} · ${fmt.format(event.createdAt)}',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      isThreeLine: false,
    );
  }
}
