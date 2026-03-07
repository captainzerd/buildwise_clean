// lib/core/models/variation_order.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum VoStatus {
  pending,
  approved,
  rejected;

  String get label => switch (this) {
        VoStatus.pending => 'Pending',
        VoStatus.approved => 'Approved',
        VoStatus.rejected => 'Rejected',
      };

  String get firestoreValue => name;

  static VoStatus fromString(String? value) => switch (value) {
        'approved' => VoStatus.approved,
        'rejected' => VoStatus.rejected,
        _ => VoStatus.pending,
      };
}

class VariationOrder {
  const VariationOrder({
    required this.id,
    required this.projectId,
    required this.submittedByUid,
    required this.submittedByName,
    required this.title,
    required this.description,
    required this.costDeltaGhs,
    required this.status,
    required this.createdAt,
    this.approverComment,
    this.decidedAt,
    this.certifiedByUid,
    this.certifiedByName,
    this.certifiedAt,
    this.projectBudgetGhs = 0.0,
  });

  final String id;
  final String projectId;
  final String submittedByUid;
  final String submittedByName;
  final String title;
  final String description;

  /// Positive = cost increase; negative = cost saving / reduction.
  final double costDeltaGhs;

  final VoStatus status;
  final String? approverComment;
  final DateTime createdAt;
  final DateTime? decidedAt;

  // Certification fields
  final String? certifiedByUid;
  final String? certifiedByName;
  final DateTime? certifiedAt;

  /// Total project budget in GHS, stored to compute certification threshold.
  final double projectBudgetGhs;

  /// True when the VO amount exceeds 5% of project budget.
  bool get requiresCertification =>
      projectBudgetGhs > 0 && costDeltaGhs.abs() > projectBudgetGhs * 0.05;

  /// True when this VO can be approved by the owner.
  bool get canBeApproved =>
      !requiresCertification || certifiedByUid != null;

  factory VariationOrder.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return VariationOrder(
      id: doc.id,
      projectId: d['projectId'] as String? ?? '',
      submittedByUid: d['submittedByUid'] as String? ?? '',
      submittedByName: d['submittedByName'] as String? ?? '',
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      costDeltaGhs: (d['costDeltaGhs'] as num?)?.toDouble() ?? 0,
      status: VoStatus.fromString(d['status'] as String?),
      approverComment: d['approverComment'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      decidedAt: (d['decidedAt'] as Timestamp?)?.toDate(),
      certifiedByUid: d['certifiedByUid'] as String?,
      certifiedByName: d['certifiedByName'] as String?,
      certifiedAt: (d['certifiedAt'] as Timestamp?)?.toDate(),
      projectBudgetGhs: (d['projectBudgetGhs'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'submittedByUid': submittedByUid,
        'submittedByName': submittedByName,
        'title': title,
        'description': description,
        'costDeltaGhs': costDeltaGhs,
        'status': status.firestoreValue,
        if (approverComment != null) 'approverComment': approverComment,
        'createdAt': Timestamp.fromDate(createdAt),
        if (decidedAt != null) 'decidedAt': Timestamp.fromDate(decidedAt!),
        if (certifiedByUid != null) 'certifiedByUid': certifiedByUid,
        if (certifiedByName != null) 'certifiedByName': certifiedByName,
        if (certifiedAt != null)
          'certifiedAt': Timestamp.fromDate(certifiedAt!),
        'projectBudgetGhs': projectBudgetGhs,
      };
}
