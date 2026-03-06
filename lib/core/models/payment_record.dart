// lib/core/models/payment_record.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum PaymentDirection {
  outbound('Paid Out'),
  inbound('Received');

  const PaymentDirection(this.label);
  final String label;
}

enum PaymentMethod {
  cash('Cash'),
  mobileMoney('Mobile Money'),
  bankTransfer('Bank Transfer'),
  cheque('Cheque'),
  other('Other');

  const PaymentMethod(this.label);
  final String label;
}

enum MobileMoneyNetwork {
  mtn('MTN MoMo'),
  vodafone('Vodafone Cash'),
  airtelTigo('AirtelTigo Money');

  const MobileMoneyNetwork(this.label);
  final String label;
}

@immutable
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.authorUid,
    required this.direction,
    required this.amountGhs,
    required this.description,
    required this.method,
    required this.paymentDate,
    required this.createdAt,
    this.reference,
    this.phaseId,
    this.phaseTitle,
    this.mobileMoneyNetwork,
    this.mobileMoneyPhone,
    this.milestoneId,
    this.costEntryId,
  });

  final String id;
  final String authorUid;
  final PaymentDirection direction;
  final double amountGhs;
  final String description;
  final PaymentMethod method;
  final DateTime paymentDate;
  final DateTime createdAt;
  final String? reference;
  final String? phaseId;
  final String? phaseTitle;
  final MobileMoneyNetwork? mobileMoneyNetwork;
  final String? mobileMoneyPhone;
  final String? milestoneId;
  final String? costEntryId;

  factory PaymentRecord.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,) {
    final d = doc.data() ?? {};
    return PaymentRecord(
      id: doc.id,
      authorUid: d['authorUid'] as String? ?? '',
      direction: PaymentDirection.values.firstWhere(
        (e) => e.name == d['direction'],
        orElse: () => PaymentDirection.outbound,
      ),
      amountGhs: (d['amountGhs'] as num?)?.toDouble() ?? 0,
      description: d['description'] as String? ?? '',
      method: PaymentMethod.values.firstWhere(
        (e) => e.name == d['method'],
        orElse: () => PaymentMethod.cash,
      ),
      paymentDate:
          (d['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reference: d['reference'] as String?,
      phaseId: d['phaseId'] as String?,
      phaseTitle: d['phaseTitle'] as String?,
      mobileMoneyNetwork: MobileMoneyNetwork.values.where(
        (e) => e.name == d['mobileMoneyNetwork'],
      ).firstOrNull,
      mobileMoneyPhone: d['mobileMoneyPhone'] as String?,
      milestoneId: d['milestoneId'] as String?,
      costEntryId: d['costEntryId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'direction': direction.name,
        'amountGhs': amountGhs,
        'description': description,
        'method': method.name,
        'paymentDate': Timestamp.fromDate(paymentDate),
        'createdAt': Timestamp.fromDate(createdAt),
        if (reference != null && reference!.isNotEmpty) 'reference': reference,
        if (phaseId != null) 'phaseId': phaseId,
        if (phaseTitle != null) 'phaseTitle': phaseTitle,
        if (mobileMoneyNetwork != null)
          'mobileMoneyNetwork': mobileMoneyNetwork!.name,
        if (mobileMoneyPhone != null && mobileMoneyPhone!.isNotEmpty)
          'mobileMoneyPhone': mobileMoneyPhone,
        if (milestoneId != null) 'milestoneId': milestoneId,
        if (costEntryId != null) 'costEntryId': costEntryId,
      };
}
