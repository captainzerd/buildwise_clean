// lib/core/models/project.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ProjectStatus { planning, active, paused, completed }

extension ProjectStatusLabel on ProjectStatus {
  String get label => switch (this) {
        ProjectStatus.planning => 'Planning',
        ProjectStatus.active => 'Active',
        ProjectStatus.paused => 'Paused',
        ProjectStatus.completed => 'Completed',
      };

  String get firestoreValue => switch (this) {
        ProjectStatus.planning => 'planning',
        ProjectStatus.active => 'active',
        ProjectStatus.paused => 'paused',
        ProjectStatus.completed => 'completed',
      };
}

ProjectStatus projectStatusFromString(String? s) => switch (s) {
      'active' => ProjectStatus.active,
      'paused' => ProjectStatus.paused,
      'completed' => ProjectStatus.completed,
      _ => ProjectStatus.planning,
    };

@immutable
class Project {
  const Project({
    required this.id,
    required this.ownerUid,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.ownerName,
    this.description,
    this.location,
    this.region = '',
    this.currency = 'GHS',
    this.currencySymbol = 'GH₵',
    this.budget = 0,
    this.estimateTotalGhs = 0,
    this.amountSpent = 0,
    this.status = ProjectStatus.planning,
    this.assignedPmUid,
    this.assignedPmName,
    this.budgetAlertThreshold = 0.8,
    this.schemaVersion = 1,
    this.permitNumber,
    this.permitApprovalDate,
    this.contingencyGhs = 0,
  });

  final String id;
  final String ownerUid;
  final String? ownerName;
  final String title;
  final String? description;
  final String? location;
  final String region;
  final String currency;
  final String currencySymbol;
  final double budget;
  final double estimateTotalGhs;
  final double amountSpent;
  final ProjectStatus status;
  final String? assignedPmUid;
  final String? assignedPmName;
  final double budgetAlertThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Firestore document schema version for forward-compatible migrations.
  final int schemaVersion;
  final String? permitNumber;
  final DateTime? permitApprovalDate;
  final double contingencyGhs;

  // ── Firestore ──

  factory Project.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Project(
      id: doc.id,
      ownerUid: d['ownerUid'] as String? ?? '',
      ownerName: d['ownerName'] as String?,
      title: d['title'] as String? ?? '',
      description: d['description'] as String?,
      location: d['location'] as String?,
      region: d['region'] as String? ?? '',
      currency: d['currency'] as String? ?? 'GHS',
      currencySymbol: d['currencySymbol'] as String? ?? 'GH₵',
      budget: (d['budget'] as num?)?.toDouble() ?? 0,
      estimateTotalGhs: (d['estimateTotalGhs'] as num?)?.toDouble() ?? 0,
      amountSpent: (d['amountSpent'] as num?)?.toDouble() ?? 0,
      status: projectStatusFromString(d['status'] as String?),
      assignedPmUid: d['assignedPmUid'] as String?,
      assignedPmName: d['assignedPmName'] as String?,
      budgetAlertThreshold:
          (d['budgetAlertThreshold'] as num?)?.toDouble() ?? 0.8,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      schemaVersion: (d['schemaVersion'] as num?)?.toInt() ?? 1,
      permitNumber: d['permitNumber'] as String?,
      permitApprovalDate: (d['permitApprovalDate'] as Timestamp?)?.toDate(),
      contingencyGhs: (d['contingencyGhs'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        if (ownerName != null) 'ownerName': ownerName,
        'title': title,
        if (description != null) 'description': description,
        if (location != null) 'location': location,
        'region': region,
        'currency': currency,
        'currencySymbol': currencySymbol,
        'budget': budget,
        'estimateTotalGhs': estimateTotalGhs,
        'amountSpent': amountSpent,
        'status': status.firestoreValue,
        if (assignedPmUid != null) 'assignedPmUid': assignedPmUid,
        if (assignedPmName != null) 'assignedPmName': assignedPmName,
        'budgetAlertThreshold': budgetAlertThreshold,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'schemaVersion': schemaVersion,
        if (permitNumber != null) 'permitNumber': permitNumber,
        if (permitApprovalDate != null)
          'permitApprovalDate': Timestamp.fromDate(permitApprovalDate!),
        'contingencyGhs': contingencyGhs,
      };

  Project copyWith({
    String? title,
    String? description,
    String? location,
    String? region,
    double? budget,
    double? amountSpent,
    ProjectStatus? status,
    String? assignedPmUid,
    String? assignedPmName,
    double? budgetAlertThreshold,
    String? permitNumber,
    DateTime? permitApprovalDate,
    double? contingencyGhs,
  }) =>
      Project(
        id: id,
        ownerUid: ownerUid,
        ownerName: ownerName,
        title: title ?? this.title,
        description: description ?? this.description,
        location: location ?? this.location,
        region: region ?? this.region,
        currency: currency,
        currencySymbol: currencySymbol,
        budget: budget ?? this.budget,
        estimateTotalGhs: estimateTotalGhs,
        amountSpent: amountSpent ?? this.amountSpent,
        status: status ?? this.status,
        assignedPmUid: assignedPmUid ?? this.assignedPmUid,
        assignedPmName: assignedPmName ?? this.assignedPmName,
        budgetAlertThreshold:
            budgetAlertThreshold ?? this.budgetAlertThreshold,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        permitNumber: permitNumber ?? this.permitNumber,
        permitApprovalDate: permitApprovalDate ?? this.permitApprovalDate,
        contingencyGhs: contingencyGhs ?? this.contingencyGhs,
      );
}
