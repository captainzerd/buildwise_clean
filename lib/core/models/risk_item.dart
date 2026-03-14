// lib/core/models/risk_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum RiskStatus { open, mitigated, closed }

extension RiskStatusLabel on RiskStatus {
  String get label => switch (this) {
        RiskStatus.open => 'Open',
        RiskStatus.mitigated => 'Mitigated',
        RiskStatus.closed => 'Closed',
      };

  String get firestoreValue => name;
}

RiskStatus riskStatusFromString(String? s) => switch (s) {
      'mitigated' => RiskStatus.mitigated,
      'closed' => RiskStatus.closed,
      _ => RiskStatus.open,
    };

@immutable
class RiskItem {
  const RiskItem({
    required this.id,
    required this.projectId,
    required this.title,
    required this.category,
    required this.probability,
    required this.impact,
    required this.status,
    required this.createdAt,
    this.mitigationPlan,
    this.notes,
  });

  final String id;
  final String projectId;
  final String title;

  /// Category: 'financial' | 'schedule' | 'quality' | 'safety' | 'legal' | 'other'
  final String category;

  /// 1 (Very Low) – 5 (Very High)
  final int probability;

  /// 1 (Very Low) – 5 (Very High)
  final int impact;

  final RiskStatus status;
  final String? mitigationPlan;
  final String? notes;
  final DateTime createdAt;

  int get riskScore => probability * impact;

  String get riskLevel => switch (riskScore) {
        >= 15 => 'Critical',
        >= 9 => 'High',
        >= 4 => 'Medium',
        _ => 'Low',
      };

  Color get riskColor => switch (riskLevel) {
        'Critical' => Colors.red,
        'High' => Colors.deepOrange,
        'Medium' => Colors.amber,
        _ => Colors.green,
      };

  factory RiskItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return RiskItem(
      id: doc.id,
      projectId: d['projectId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      category: d['category'] as String? ?? 'other',
      probability: (d['probability'] as num?)?.toInt() ?? 1,
      impact: (d['impact'] as num?)?.toInt() ?? 1,
      status: riskStatusFromString(d['status'] as String?),
      mitigationPlan: d['mitigationPlan'] as String?,
      notes: d['notes'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'title': title,
        'category': category,
        'probability': probability,
        'impact': impact,
        'status': status.firestoreValue,
        if (mitigationPlan != null) 'mitigationPlan': mitigationPlan,
        if (notes != null) 'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  RiskItem copyWith({
    String? title,
    String? category,
    int? probability,
    int? impact,
    RiskStatus? status,
    String? mitigationPlan,
    String? notes,
  }) =>
      RiskItem(
        id: id,
        projectId: projectId,
        title: title ?? this.title,
        category: category ?? this.category,
        probability: probability ?? this.probability,
        impact: impact ?? this.impact,
        status: status ?? this.status,
        mitigationPlan: mitigationPlan ?? this.mitigationPlan,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}

const riskCategories = [
  ('financial', 'Financial'),
  ('schedule', 'Schedule'),
  ('quality', 'Quality'),
  ('safety', 'Safety'),
  ('legal', 'Legal / Regulatory'),
  ('other', 'Other'),
];
