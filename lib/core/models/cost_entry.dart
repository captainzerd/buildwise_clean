// lib/core/models/cost_entry.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class CostEntry {
  const CostEntry({
    required this.id,
    required this.authorUid,
    required this.description,
    required this.category,
    required this.amountGhs,
    required this.createdAt,
    this.receiptUrl,
    this.phaseId,
    this.originalCurrency,
    this.originalAmount,
  });

  final String id;
  final String authorUid;
  final String description;
  final String category;
  final double amountGhs;
  final String? receiptUrl;
  final String? phaseId;
  final DateTime createdAt;
  final String? originalCurrency;
  final double? originalAmount;

  static const categories = [
    'Materials',
    'Labour',
    'Equipment',
    'Professional Fees',
    'Permits & Levies',
    'Petty Cash',
    'Other',
  ];

  factory CostEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CostEntry(
      id: doc.id,
      authorUid: d['authorUid'] as String? ?? '',
      description: d['description'] as String? ?? '',
      category: d['category'] as String? ?? 'Other',
      amountGhs: (d['amountGhs'] as num?)?.toDouble() ?? 0,
      receiptUrl: d['receiptUrl'] as String?,
      phaseId: d['phaseId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      originalCurrency: d['originalCurrency'] as String?,
      originalAmount: (d['originalAmount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'description': description,
        'category': category,
        'amountGhs': amountGhs,
        if (receiptUrl != null) 'receiptUrl': receiptUrl,
        if (phaseId != null) 'phaseId': phaseId,
        'createdAt': Timestamp.fromDate(createdAt),
        if (originalCurrency != null) 'originalCurrency': originalCurrency,
        if (originalAmount != null) 'originalAmount': originalAmount,
      };
}
