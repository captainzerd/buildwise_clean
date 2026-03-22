// lib/core/models/rfq_request.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum RfqStatus { sent, responded, accepted, declined }

extension RfqStatusLabel on RfqStatus {
  String get label => switch (this) {
        RfqStatus.sent => 'Sent',
        RfqStatus.responded => 'Responded',
        RfqStatus.accepted => 'Accepted',
        RfqStatus.declined => 'Declined',
      };

  String get firestoreValue => switch (this) {
        RfqStatus.sent => 'sent',
        RfqStatus.responded => 'responded',
        RfqStatus.accepted => 'accepted',
        RfqStatus.declined => 'declined',
      };
}

RfqStatus rfqStatusFromString(String? s) => switch (s) {
      'responded' => RfqStatus.responded,
      'accepted' => RfqStatus.accepted,
      'declined' => RfqStatus.declined,
      _ => RfqStatus.sent,
    };

class RfqRequest {
  const RfqRequest({
    required this.id,
    required this.projectId,
    required this.projectTitle,
    required this.ownerUid,
    required this.vendorId,
    required this.vendorName,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.responseText,
    this.quotedAmountGhs,
  });

  final String id;
  final String projectId;
  final String projectTitle;
  final String ownerUid;
  final String vendorId;
  final String vendorName;
  final String description;
  final DateTime? dueDate;
  final RfqStatus status;
  final String? responseText;
  final double? quotedAmountGhs;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'projectTitle': projectTitle,
        'ownerUid': ownerUid,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'description': description,
        if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
        'status': status.firestoreValue,
        if (responseText != null) 'responseText': responseText,
        if (quotedAmountGhs != null) 'quotedAmountGhs': quotedAmountGhs,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory RfqRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return RfqRequest(
      id: doc.id,
      projectId: d['projectId'] as String? ?? '',
      projectTitle: d['projectTitle'] as String? ?? '',
      ownerUid: d['ownerUid'] as String? ?? '',
      vendorId: d['vendorId'] as String? ?? '',
      vendorName: d['vendorName'] as String? ?? '',
      description: d['description'] as String? ?? '',
      dueDate: (d['dueDate'] as Timestamp?)?.toDate(),
      status: rfqStatusFromString(d['status'] as String?),
      responseText: d['responseText'] as String?,
      quotedAmountGhs: (d['quotedAmountGhs'] as num?)?.toDouble(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
