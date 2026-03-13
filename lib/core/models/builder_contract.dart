import 'package:cloud_firestore/cloud_firestore.dart';

enum ContractTemplateType {
  custom,
  ghbcResidential,
  fidicShortForm,
  necEngineering;

  String get displayName => switch (this) {
        ContractTemplateType.custom => 'Custom Contract',
        ContractTemplateType.ghbcResidential => 'GhBC Residential (Standard)',
        ContractTemplateType.fidicShortForm => 'FIDIC Short Form',
        ContractTemplateType.necEngineering =>
          'NEC Engineering & Construction',
      };

  /// Pre-populated clause titles for each template.
  /// Legal text is TODO — requires licensed clause text.
  List<String> get templateClauses => switch (this) {
        ContractTemplateType.custom => [],
        ContractTemplateType.ghbcResidential => [
            // TODO: Insert licensed GhBC residential clause text
            'Parties and Recitals',
            'Scope of Works',
            'Contract Sum',
            'Payment Terms',
            'Variations',
            'Practical Completion',
            'Defects Liability Period',
            'Dispute Resolution',
          ],
        ContractTemplateType.fidicShortForm => [
            // TODO: Insert licensed FIDIC Short Form clause text
            'General Provisions',
            'The Employer',
            'The Contractor',
            'The Engineer',
            'Design',
            'Commencement, Delays and Suspension',
            'Contract Price and Payment',
            'Termination',
            'Risk and Responsibility',
            'Disputes and Arbitration',
          ],
        ContractTemplateType.necEngineering => [
            // TODO: Insert licensed NEC ECC clause text
            'Core Clause 1: General',
            "Core Clause 2: Contractor's Main Responsibilities",
            'Core Clause 3: Time',
            'Core Clause 4: Testing and Defects',
            'Core Clause 5: Payment',
            'Core Clause 6: Compensation Events',
            'Core Clause 7: Title',
            'Core Clause 8: Risks and Insurance',
            'Core Clause 9: Disputes and Termination',
          ],
      };
}

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

/// Tracks the lifecycle of the actual funds transfer once PSP is connected.
/// Until then all milestones default to [notStarted].
enum MilestoneDisbursementStatus { notStarted, pending, disbursed, failed }

extension MilestoneDisbursementStatusLabel on MilestoneDisbursementStatus {
  String get label => switch (this) {
        MilestoneDisbursementStatus.notStarted => 'Not Started',
        MilestoneDisbursementStatus.pending => 'Processing',
        MilestoneDisbursementStatus.disbursed => 'Disbursed',
        MilestoneDisbursementStatus.failed => 'Failed',
      };

  String get firestoreValue => switch (this) {
        MilestoneDisbursementStatus.notStarted => 'notStarted',
        MilestoneDisbursementStatus.pending => 'pending',
        MilestoneDisbursementStatus.disbursed => 'disbursed',
        MilestoneDisbursementStatus.failed => 'failed',
      };
}

MilestoneDisbursementStatus milestoneDisbursementStatusFromString(String? s) =>
    switch (s) {
      'pending' => MilestoneDisbursementStatus.pending,
      'disbursed' => MilestoneDisbursementStatus.disbursed,
      'failed' => MilestoneDisbursementStatus.failed,
      _ => MilestoneDisbursementStatus.notStarted,
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
    this.disbursementStatus = MilestoneDisbursementStatus.notStarted,
    this.paystackReference,
    this.capturedAt,
    this.disbursedAt,
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
  final MilestoneDisbursementStatus disbursementStatus;
  /// Paystack transaction reference — null until PSP is connected.
  final String? paystackReference;
  /// When the owner's payment was captured — null until PSP is connected.
  final DateTime? capturedAt;
  /// When funds were disbursed to the builder — null until PSP is connected.
  final DateTime? disbursedAt;

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
        'disbursementStatus': disbursementStatus.firestoreValue,
        if (paystackReference != null) 'paystackReference': paystackReference,
        if (capturedAt != null) 'capturedAt': Timestamp.fromDate(capturedAt!),
        if (disbursedAt != null) 'disbursedAt': Timestamp.fromDate(disbursedAt!),
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
        disbursementStatus: milestoneDisbursementStatusFromString(
          m['disbursementStatus'] as String?,
        ),
        paystackReference: m['paystackReference'] as String?,
        capturedAt: (m['capturedAt'] as Timestamp?)?.toDate(),
        disbursedAt: (m['disbursedAt'] as Timestamp?)?.toDate(),
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
    MilestoneDisbursementStatus? disbursementStatus,
    String? paystackReference,
    DateTime? capturedAt,
    DateTime? disbursedAt,
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
        disbursementStatus: disbursementStatus ?? this.disbursementStatus,
        paystackReference: paystackReference ?? this.paystackReference,
        capturedAt: capturedAt ?? this.capturedAt,
        disbursedAt: disbursedAt ?? this.disbursedAt,
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
    this.templateType = ContractTemplateType.custom,
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
  final ContractTemplateType templateType;
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
        'templateType': templateType.name,
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
      templateType: ContractTemplateType.values.firstWhere(
        (t) => t.name == (d['templateType'] as String?),
        orElse: () => ContractTemplateType.custom,
      ),
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
