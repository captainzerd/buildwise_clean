// lib/core/services/audit_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/audit_event.dart';
import 'logger_service.dart';

class AuditService {
  AuditService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('audit_log');

  /// Fire-and-forget audit log entry.
  Future<void> logEvent({
    required String projectId,
    required AuditEventType type,
    required String actorUid,
    required String actorName,
    required String description,
    String? ownerUid,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final event = AuditEvent(
        id: '',
        projectId: projectId,
        type: type,
        actorUid: actorUid,
        actorName: actorName,
        description: description,
        createdAt: DateTime.now(),
        ownerUid: ownerUid,
        metadata: metadata,
      );
      await _col.add(event.toMap());
    } catch (e) {
      // Audit logging must never block or crash the UI.
      LoggerService.warning('AuditService: failed to log event', error: e);
    }
  }

  /// Stream of audit events for a specific project, newest first.
  Stream<List<AuditEvent>> eventsStream(String projectId) {
    return _col
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => AuditEvent.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Stream of all audit events across all projects (admin use).
  Stream<List<AuditEvent>> allEventsStream({int limit = 100}) {
    return _col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => AuditEvent.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }
}
