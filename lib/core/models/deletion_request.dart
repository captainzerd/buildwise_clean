import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum DeletionItemType { costEntry, payment, document, update }

extension DeletionItemTypeLabel on DeletionItemType {
  String get label => switch (this) {
        DeletionItemType.costEntry => 'Cost Entry',
        DeletionItemType.payment => 'Payment',
        DeletionItemType.document => 'Document',
        DeletionItemType.update => 'Update',
      };

  String get firestoreValue => switch (this) {
        DeletionItemType.costEntry => 'costEntry',
        DeletionItemType.payment => 'payment',
        DeletionItemType.document => 'document',
        DeletionItemType.update => 'update',
      };
}

DeletionItemType deletionItemTypeFromString(String? s) => switch (s) {
      'payment' => DeletionItemType.payment,
      'document' => DeletionItemType.document,
      'update' => DeletionItemType.update,
      _ => DeletionItemType.costEntry,
    };

enum DeletionStatus { pending, approved, denied }

extension DeletionStatusLabel on DeletionStatus {
  String get label => switch (this) {
        DeletionStatus.pending => 'Pending',
        DeletionStatus.approved => 'Approved',
        DeletionStatus.denied => 'Denied',
      };

  String get firestoreValue => switch (this) {
        DeletionStatus.pending => 'pending',
        DeletionStatus.approved => 'approved',
        DeletionStatus.denied => 'denied',
      };
}

DeletionStatus deletionStatusFromString(String? s) => switch (s) {
      'approved' => DeletionStatus.approved,
      'denied' => DeletionStatus.denied,
      _ => DeletionStatus.pending,
    };

@immutable
class DeletionRequest {
  const DeletionRequest({
    required this.itemId,
    required this.projectId,
    required this.itemType,
    required this.itemDescription,
    required this.requestedByUid,
    required this.requestedByName,
    required this.status,
    required this.createdAt,
    this.amountGhs,
    this.resolvedAt,
    this.ownerNote,
  });

  /// Doc ID equals the itemId — prevents duplicate requests per item.
  final String itemId;
  final String projectId;
  final DeletionItemType itemType;
  final String itemDescription;
  final String requestedByUid;
  final String requestedByName;
  final DeletionStatus status;
  final DateTime createdAt;

  /// For cost entries: stored so amountSpent can be reversed on approve.
  final double? amountGhs;
  final DateTime? resolvedAt;
  final String? ownerNote;

  factory DeletionRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return DeletionRequest(
      itemId: doc.id,
      projectId: d['projectId'] as String? ?? '',
      itemType: deletionItemTypeFromString(d['itemType'] as String?),
      itemDescription: d['itemDescription'] as String? ?? '',
      requestedByUid: d['requestedByUid'] as String? ?? '',
      requestedByName: d['requestedByName'] as String? ?? '',
      status: deletionStatusFromString(d['status'] as String?),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      amountGhs: (d['amountGhs'] as num?)?.toDouble(),
      resolvedAt: (d['resolvedAt'] as Timestamp?)?.toDate(),
      ownerNote: d['ownerNote'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'itemType': itemType.firestoreValue,
        'itemDescription': itemDescription,
        'requestedByUid': requestedByUid,
        'requestedByName': requestedByName,
        'status': status.firestoreValue,
        'createdAt': Timestamp.fromDate(createdAt),
        if (amountGhs != null) 'amountGhs': amountGhs,
        if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
        if (ownerNote != null) 'ownerNote': ownerNote,
      };
}
