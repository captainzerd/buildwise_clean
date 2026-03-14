// lib/core/models/labor_record.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum TradeType {
  mason,
  carpenter,
  electrician,
  plumber,
  tiler,
  painter,
  labourer,
  ironBender,
  other,
}

extension TradeTypeLabel on TradeType {
  String get label => switch (this) {
        TradeType.mason => 'Mason',
        TradeType.carpenter => 'Carpenter',
        TradeType.electrician => 'Electrician',
        TradeType.plumber => 'Plumber',
        TradeType.tiler => 'Tiler',
        TradeType.painter => 'Painter',
        TradeType.labourer => 'Labourer',
        TradeType.ironBender => 'Iron Bender',
        TradeType.other => 'Other',
      };

  String get firestoreValue => switch (this) {
        TradeType.mason => 'mason',
        TradeType.carpenter => 'carpenter',
        TradeType.electrician => 'electrician',
        TradeType.plumber => 'plumber',
        TradeType.tiler => 'tiler',
        TradeType.painter => 'painter',
        TradeType.labourer => 'labourer',
        TradeType.ironBender => 'ironBender',
        TradeType.other => 'other',
      };
}

TradeType tradeTypeFromString(String? s) => switch (s) {
      'mason' => TradeType.mason,
      'carpenter' => TradeType.carpenter,
      'electrician' => TradeType.electrician,
      'plumber' => TradeType.plumber,
      'tiler' => TradeType.tiler,
      'painter' => TradeType.painter,
      'labourer' => TradeType.labourer,
      'ironBender' => TradeType.ironBender,
      _ => TradeType.other,
    };

class LaborRecord {
  const LaborRecord({
    required this.id,
    required this.date,
    required this.tradeType,
    required this.headcount,
    required this.dailyRateGhs,
    required this.totalGhs,
    required this.recordedByUid,
    required this.recordedByName,
    required this.createdAt,
    this.notes,
    this.phaseId,
  });

  final String id;
  final DateTime date;
  final TradeType tradeType;
  final int headcount;
  final double dailyRateGhs;
  final double totalGhs;
  final String? notes;
  final String? phaseId;
  final String recordedByUid;
  final String recordedByName;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'tradeType': tradeType.firestoreValue,
        'headcount': headcount,
        'dailyRateGhs': dailyRateGhs,
        'totalGhs': totalGhs,
        if (notes != null) 'notes': notes,
        if (phaseId != null) 'phaseId': phaseId,
        'recordedByUid': recordedByUid,
        'recordedByName': recordedByName,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory LaborRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return LaborRecord(
      id: doc.id,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tradeType: tradeTypeFromString(d['tradeType'] as String?),
      headcount: (d['headcount'] as num?)?.toInt() ?? 1,
      dailyRateGhs: (d['dailyRateGhs'] as num?)?.toDouble() ?? 0,
      totalGhs: (d['totalGhs'] as num?)?.toDouble() ?? 0,
      notes: d['notes'] as String?,
      phaseId: d['phaseId'] as String?,
      recordedByUid: d['recordedByUid'] as String? ?? '',
      recordedByName: d['recordedByName'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
