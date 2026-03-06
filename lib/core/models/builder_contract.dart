import 'package:cloud_firestore/cloud_firestore.dart';

enum ContractStatus { pendingBuilder, active, declined, cancelled }

extension ContractStatusLabel on ContractStatus {
  String get label => switch (this) {
        ContractStatus.pendingBuilder => 'Pending Builder Signature',
        ContractStatus.active => 'Active',
        ContractStatus.declined => 'Declined',
        ContractStatus.cancelled => 'Cancelled',
      };

  String get firestoreValue => switch (this) {
        ContractStatus.pendingBuilder => 'pendingBuilder',
        ContractStatus.active => 'active',
        ContractStatus.declined => 'declined',
        ContractStatus.cancelled => 'cancelled',
      };
}

ContractStatus contractStatusFromString(String? s) => switch (s) {
      'active' => ContractStatus.active,
      'declined' => ContractStatus.declined,
      'cancelled' => ContractStatus.cancelled,
      _ => ContractStatus.pendingBuilder,
    };

/// Approval status for a payment milestone release gate.
enum MilestoneApprovalStatus { pending, pendingRelease, released }

extension MilestoneApprovalStatusLabel on MilestoneApprovalStatus {
  String get label => switch (this) {
        MilestoneApprovalStatus.pending => 'Pending',
        MilestoneApprovalStatus.pendingRelease => 'Awaiting Release',
        MilestoneApprovalStatus.released => 'Released',
      };

  String get firestoreValue => switch (this) {
        MilestoneApprovalStatus.pending => 'pending',
        MilestoneApprovalStatus.pendingRelease => 'pendingRelease',
        MilestoneApprovalStatus.released => 'released',
      };
}

MilestoneApprovalStatus milestoneApprovalStatusFromString(String? s) =>
    switch (s) {
      'pendingRelease' => MilestoneApprovalStatus.pendingRelease,
      'released' => MilestoneApprovalStatus.released,
      _ => MilestoneApprovalStatus.pending,
    };

class PaymentMilestone {
  const PaymentMilestone({
    required this.id,
    required this.description,
    required this.amountGhs,
    this.dueDate,
    this.isPaid = false,
    this.paidAt,
    this.approvalStatus = MilestoneApprovalStatus.pending,
    this.releasedAt,
    this.releasedByName,
  });

  final String id;
  final String description;
  final double amountGhs;
  final DateTime? dueDate;
  final bool isPaid;
  final DateTime? paidAt;
  final MilestoneApprovalStatus approvalStatus;
  final DateTime? releasedAt;
  final String? releasedByName;

  bool get isOverdue =>
      dueDate != null && !isPaid && dueDate!.isBefore(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'amountGhs': amountGhs,
        if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
        'isPaid': isPaid,
        if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
        'approvalStatus': approvalStatus.firestoreValue,
        if (releasedAt != null) 'releasedAt': Timestamp.fromDate(releasedAt!),
        if (releasedByName != null) 'releasedByName': releasedByName,
      };

  factory PaymentMilestone.fromMap(Map<String, dynamic> m) => PaymentMilestone(
        id: m['id'] as String? ?? '',
        description: m['description'] as String? ?? '',
        amountGhs: (m['amountGhs'] as num?)?.toDouble() ?? 0,
        dueDate: (m['dueDate'] as Timestamp?)?.toDate(),
        isPaid: m['isPaid'] as bool? ?? false,
        paidAt: (m['paidAt'] as Timestamp?)?.toDate(),
        approvalStatus: milestoneApprovalStatusFromString(
          m['approvalStatus'] as String?,
        ),
        releasedAt: (m['releasedAt'] as Timestamp?)?.toDate(),
        releasedByName: m['releasedByName'] as String?,
      );

  PaymentMilestone copyWith({
    String? description,
    double? amountGhs,
    DateTime? dueDate,
    bool? isPaid,
    DateTime? paidAt,
    MilestoneApprovalStatus? approvalStatus,
    DateTime? releasedAt,
    String? releasedByName,
  }) =>
      PaymentMilestone(
        id: id,
        description: description ?? this.description,
        amountGhs: amountGhs ?? this.amountGhs,
        dueDate: dueDate ?? this.dueDate,
        isPaid: isPaid ?? this.isPaid,
        paidAt: paidAt ?? this.paidAt,
        approvalStatus: approvalStatus ?? this.approvalStatus,
        releasedAt: releasedAt ?? this.releasedAt,
        releasedByName: releasedByName ?? this.releasedByName,
      );
}

class BuilderContract {
  const BuilderContract({
    required this.id,
    required this.projectId,
    required this.projectTitle,
    required this.ownerUid,
    required this.builderUid,
    required this.builderName,
    required this.scope,
    required this.totalAmountGhs,
    required this.milestones,
    required this.status,
    required this.ownerSignatureName,
    required this.ownerSignedAt,
    required this.createdAt,
    required this.updatedAt,
    this.startDate,
    this.endDate,
    this.dlpEndDate,
    this.builderSignatureName,
    this.builderSignedAt,
    this.signedPdfUrl,
    this.retentionPct = 0,
    this.retentionReleasedAt,
    this.schemaVersion = 1,
  });

  final String id;
  final String projectId;
  final String projectTitle;
  final String ownerUid;
  final String builderUid;
  final String builderName;
  final String scope;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? dlpEndDate;
  final double totalAmountGhs;
  final List<PaymentMilestone> milestones;
  final ContractStatus status;
  final String ownerSignatureName;
  final DateTime ownerSignedAt;
  final String? builderSignatureName;
  final DateTime? builderSignedAt;
  final String? signedPdfUrl;
  final double retentionPct;
  final DateTime? retentionReleasedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  double get retentionAmountGhs => totalAmountGhs * (retentionPct / 100);

  double get amountReleasableGhs =>
      totalAmountGhs - retentionAmountGhs;

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'projectTitle': projectTitle,
        'ownerUid': ownerUid,
        'builderUid': builderUid,
        // memberUids enables arrayContains queries aligned with security rules.
        'memberUids': [ownerUid, builderUid],
        'builderName': builderName,
        'scope': scope,
        if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
        if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
        if (dlpEndDate != null) 'dlpEndDate': Timestamp.fromDate(dlpEndDate!),
        'totalAmountGhs': totalAmountGhs,
        'milestones': milestones.map((m) => m.toMap()).toList(),
        'status': status.firestoreValue,
        'ownerSignatureName': ownerSignatureName,
        'ownerSignedAt': Timestamp.fromDate(ownerSignedAt),
        if (builderSignatureName != null)
          'builderSignatureName': builderSignatureName,
        if (builderSignedAt != null)
          'builderSignedAt': Timestamp.fromDate(builderSignedAt!),
        if (signedPdfUrl != null) 'signedPdfUrl': signedPdfUrl,
        'retentionPct': retentionPct,
        if (retentionReleasedAt != null)
          'retentionReleasedAt': Timestamp.fromDate(retentionReleasedAt!),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'schemaVersion': schemaVersion,
      };

  factory BuilderContract.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return BuilderContract(
      id: doc.id,
      projectId: d['projectId'] as String? ?? '',
      projectTitle: d['projectTitle'] as String? ?? '',
      ownerUid: d['ownerUid'] as String? ?? '',
      builderUid: d['builderUid'] as String? ?? '',
      builderName: d['builderName'] as String? ?? '',
      scope: d['scope'] as String? ?? '',
      startDate: (d['startDate'] as Timestamp?)?.toDate(),
      endDate: (d['endDate'] as Timestamp?)?.toDate(),
      dlpEndDate: (d['dlpEndDate'] as Timestamp?)?.toDate(),
      totalAmountGhs: (d['totalAmountGhs'] as num?)?.toDouble() ?? 0,
      milestones: ((d['milestones'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(PaymentMilestone.fromMap)
          .toList(),
      status: contractStatusFromString(d['status'] as String?),
      ownerSignatureName: d['ownerSignatureName'] as String? ?? '',
      ownerSignedAt:
          (d['ownerSignedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      builderSignatureName: d['builderSignatureName'] as String?,
      builderSignedAt: (d['builderSignedAt'] as Timestamp?)?.toDate(),
      signedPdfUrl: d['signedPdfUrl'] as String?,
      retentionPct: (d['retentionPct'] as num?)?.toDouble() ?? 0,
      retentionReleasedAt:
          (d['retentionReleasedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      schemaVersion: (d['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
