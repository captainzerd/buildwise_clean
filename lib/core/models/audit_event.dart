// lib/core/models/audit_event.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum AuditEventType {
  phaseAdded,
  phaseStatusChanged,
  costEntryAdded,
  costEntryDeleted,
  paymentAdded,
  paymentDeleted,
  contractSigned,
  builderAssigned,
  projectStatusChanged,
}

extension AuditEventTypeLabel on AuditEventType {
  String get label => switch (this) {
        AuditEventType.phaseAdded => 'Phase Added',
        AuditEventType.phaseStatusChanged => 'Phase Status Changed',
        AuditEventType.costEntryAdded => 'Cost Entry Added',
        AuditEventType.costEntryDeleted => 'Cost Entry Deleted',
        AuditEventType.paymentAdded => 'Payment Recorded',
        AuditEventType.paymentDeleted => 'Payment Deleted',
        AuditEventType.contractSigned => 'Contract Signed',
        AuditEventType.builderAssigned => 'Builder Assigned',
        AuditEventType.projectStatusChanged => 'Project Status Changed',
      };

  String get icon => switch (this) {
        AuditEventType.phaseAdded => 'layers',
        AuditEventType.phaseStatusChanged => 'layers',
        AuditEventType.costEntryAdded => 'receipt_long',
        AuditEventType.costEntryDeleted => 'receipt_long',
        AuditEventType.paymentAdded => 'payments',
        AuditEventType.paymentDeleted => 'payments',
        AuditEventType.contractSigned => 'draw',
        AuditEventType.builderAssigned => 'person_add',
        AuditEventType.projectStatusChanged => 'flag',
      };
}

AuditEventType auditEventTypeFromString(String? s) {
  return AuditEventType.values.firstWhere(
    (e) => e.name == s,
    orElse: () => AuditEventType.costEntryAdded,
  );
}

@immutable
class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.projectId,
    required this.type,
    required this.actorUid,
    required this.actorName,
    required this.description,
    required this.createdAt,
    this.ownerUid,
    this.metadata = const {},
  });

  final String id;
  final String projectId;
  final AuditEventType type;
  final String actorUid;
  final String actorName;
  final String description;
  final DateTime createdAt;
  final String? ownerUid;
  final Map<String, dynamic> metadata;

  factory AuditEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AuditEvent(
      id: doc.id,
      projectId: d['projectId'] as String? ?? '',
      type: auditEventTypeFromString(d['type'] as String?),
      actorUid: d['actorUid'] as String? ?? '',
      actorName: d['actorName'] as String? ?? '',
      description: d['description'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ownerUid: d['ownerUid'] as String?,
      metadata: d['metadata'] is Map
          ? Map<String, dynamic>.from(d['metadata'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'type': type.name,
        'actorUid': actorUid,
        'actorName': actorName,
        'description': description,
        'createdAt': Timestamp.fromDate(createdAt),
        if (ownerUid != null) 'ownerUid': ownerUid,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}
