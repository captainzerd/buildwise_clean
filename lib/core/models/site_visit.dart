// lib/core/models/site_visit.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum VisitStatus {
  scheduled,
  completed,
  cancelled;

  String get label => switch (this) {
        VisitStatus.scheduled => 'Scheduled',
        VisitStatus.completed => 'Completed',
        VisitStatus.cancelled => 'Cancelled',
      };

  String get firestoreValue => name;

  static VisitStatus fromString(String? value) => switch (value) {
        'completed' => VisitStatus.completed,
        'cancelled' => VisitStatus.cancelled,
        _ => VisitStatus.scheduled,
      };
}

/// Inspection outcome recorded when a site visit is completed.
enum VisitOutcome {
  passed,
  failed,
  needsReinspection;

  String get label => switch (this) {
        VisitOutcome.passed => 'Passed',
        VisitOutcome.failed => 'Failed',
        VisitOutcome.needsReinspection => 'Needs Re-inspection',
      };

  String get firestoreValue => name;

  static VisitOutcome? fromString(String? value) => switch (value) {
        'passed' => VisitOutcome.passed,
        'failed' => VisitOutcome.failed,
        'needsReinspection' => VisitOutcome.needsReinspection,
        _ => null,
      };
}

class SiteVisit {
  const SiteVisit({
    required this.id,
    required this.projectId,
    required this.scheduledByUid,
    required this.scheduledByName,
    required this.scheduledAt,
    required this.purpose,
    required this.status,
    required this.createdAt,
    this.notes,
    this.outcome,
    this.recommendations,
  });

  final String id;
  final String projectId;
  final String scheduledByUid;
  final String scheduledByName;
  final DateTime scheduledAt;
  final String purpose;
  final VisitStatus status;
  final String? notes;
  final DateTime createdAt;

  /// Pass/Fail/Needs Re-inspection — set when status becomes completed.
  final VisitOutcome? outcome;

  /// Inspector recommendations after the visit.
  final String? recommendations;

  factory SiteVisit.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SiteVisit(
      id: doc.id,
      projectId: d['projectId'] as String? ?? '',
      scheduledByUid: d['scheduledByUid'] as String? ?? '',
      scheduledByName: d['scheduledByName'] as String? ?? '',
      scheduledAt:
          (d['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      purpose: d['purpose'] as String? ?? '',
      status: VisitStatus.fromString(d['status'] as String?),
      notes: d['notes'] as String?,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      outcome: VisitOutcome.fromString(d['outcome'] as String?),
      recommendations: d['recommendations'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'scheduledByUid': scheduledByUid,
        'scheduledByName': scheduledByName,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'purpose': purpose,
        'status': status.firestoreValue,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
        if (outcome != null) 'outcome': outcome!.firestoreValue,
        if (recommendations != null && recommendations!.isNotEmpty)
          'recommendations': recommendations,
      };
}
