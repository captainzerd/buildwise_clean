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

class PaymentMilestone {
  const PaymentMilestone({required this.description, required this.amountGhs});
  final String description;
  final double amountGhs;

  Map<String, dynamic> toMap() => {
        'description': description,
        'amountGhs': amountGhs,
      };

  factory PaymentMilestone.fromMap(Map<String, dynamic> m) => PaymentMilestone(
        description: m['description'] as String? ?? '',
        amountGhs: (m['amountGhs'] as num?)?.toDouble() ?? 0,
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
    this.builderSignatureName,
    this.builderSignedAt,
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
  final double totalAmountGhs;
  final List<PaymentMilestone> milestones;
  final ContractStatus status;
  final String ownerSignatureName;
  final DateTime ownerSignedAt;
  final String? builderSignatureName;
  final DateTime? builderSignedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'projectTitle': projectTitle,
        'ownerUid': ownerUid,
        'builderUid': builderUid,
        'builderName': builderName,
        'scope': scope,
        if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
        if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
        'totalAmountGhs': totalAmountGhs,
        'milestones': milestones.map((m) => m.toMap()).toList(),
        'status': status.firestoreValue,
        'ownerSignatureName': ownerSignatureName,
        'ownerSignedAt': Timestamp.fromDate(ownerSignedAt),
        if (builderSignatureName != null)
          'builderSignatureName': builderSignatureName,
        if (builderSignedAt != null)
          'builderSignedAt': Timestamp.fromDate(builderSignedAt!),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
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
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
