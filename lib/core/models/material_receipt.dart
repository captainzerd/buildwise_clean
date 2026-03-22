import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class MaterialReceipt {
  const MaterialReceipt({
    required this.id,
    required this.projectId,
    required this.phaseId,
    required this.description,
    required this.supplierName,
    required this.amountGhs,
    required this.receiptUrl,
    required this.purchaseDate,
    required this.uploadedByUid,
    required this.uploadedAt,
  });

  final String id;
  final String projectId;
  final String phaseId;
  final String description;
  final String supplierName;
  final double amountGhs;
  final String receiptUrl;
  final DateTime purchaseDate;
  final String uploadedByUid;
  final DateTime uploadedAt;

  factory MaterialReceipt.fromMap(Map<String, dynamic> map) => MaterialReceipt(
        id: map['id'] as String,
        projectId: map['projectId'] as String,
        phaseId: map['phaseId'] as String,
        description: map['description'] as String,
        supplierName: map['supplierName'] as String,
        amountGhs: (map['amountGhs'] as num).toDouble(),
        receiptUrl: map['receiptUrl'] as String,
        purchaseDate: (map['purchaseDate'] as Timestamp).toDate(),
        uploadedByUid: map['uploadedByUid'] as String,
        uploadedAt: (map['uploadedAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'projectId': projectId,
        'phaseId': phaseId,
        'description': description,
        'supplierName': supplierName,
        'amountGhs': amountGhs,
        'receiptUrl': receiptUrl,
        'purchaseDate': Timestamp.fromDate(purchaseDate),
        'uploadedByUid': uploadedByUid,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
      };
}
