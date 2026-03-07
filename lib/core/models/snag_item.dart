// lib/core/models/snag_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum SnagStatus { open, resolved, confirmed }

extension SnagStatusLabel on SnagStatus {
  String get label => switch (this) {
        SnagStatus.open => 'Open',
        SnagStatus.resolved => 'Resolved',
        SnagStatus.confirmed => 'Confirmed',
      };

  String get firestoreValue => switch (this) {
        SnagStatus.open => 'open',
        SnagStatus.resolved => 'resolved',
        SnagStatus.confirmed => 'confirmed',
      };
}

SnagStatus snagStatusFromString(String? s) => switch (s) {
      'resolved' => SnagStatus.resolved,
      'confirmed' => SnagStatus.confirmed,
      _ => SnagStatus.open,
    };

// ── Issue type ─────────────────────────────────────────────────────────────────

enum IssueType { defect, safetyIncident, qualityIssue }

extension IssueTypeLabel on IssueType {
  String get label => switch (this) {
        IssueType.defect => 'Defect',
        IssueType.safetyIncident => 'Safety Incident',
        IssueType.qualityIssue => 'Quality Issue',
      };

  IconData get icon => switch (this) {
        IssueType.defect => Icons.build_outlined,
        IssueType.safetyIncident => Icons.warning_amber_outlined,
        IssueType.qualityIssue => Icons.verified_outlined,
      };

  String get firestoreValue => name;
}

IssueType issueTypeFromString(String? s) => switch (s) {
      'safetyIncident' => IssueType.safetyIncident,
      'qualityIssue' => IssueType.qualityIssue,
      _ => IssueType.defect,
    };

// ── Issue severity ─────────────────────────────────────────────────────────────

enum IssueSeverity { low, medium, high, critical }

extension IssueSeverityExt on IssueSeverity {
  String get label => switch (this) {
        IssueSeverity.low => 'Low',
        IssueSeverity.medium => 'Medium',
        IssueSeverity.high => 'High',
        IssueSeverity.critical => 'Critical',
      };

  Color get color => switch (this) {
        IssueSeverity.low => Colors.green,
        IssueSeverity.medium => Colors.amber.shade700,
        IssueSeverity.high => Colors.deepOrange,
        IssueSeverity.critical => Colors.red,
      };

  String get firestoreValue => name;
}

IssueSeverity issueSeverityFromString(String? s) => switch (s) {
      'medium' => IssueSeverity.medium,
      'high' => IssueSeverity.high,
      'critical' => IssueSeverity.critical,
      _ => IssueSeverity.low,
    };

// ── Snag category ──────────────────────────────────────────────────────────────

enum SnagCategory {
  structural,
  weatherproofing,
  finishes,
  services,
  externalWorks,
  other;

  String get displayName => switch (this) {
        SnagCategory.structural => 'Structural',
        SnagCategory.weatherproofing => 'Weatherproofing',
        SnagCategory.finishes => 'Finishes',
        SnagCategory.services => 'Services (M&E)',
        SnagCategory.externalWorks => 'External Works',
        SnagCategory.other => 'Other',
      };
}

class SnagItem {
  const SnagItem({
    required this.id,
    required this.description,
    required this.createdAt,
    required this.createdByUid,
    required this.createdByName,
    this.status = SnagStatus.open,
    this.photoUrls = const [],
    this.assignedToUid,
    this.assignedToName,
    this.dueDate,
    this.resolvedAt,
    this.confirmedAt,
    this.notes,
    this.issueType = IssueType.defect,
    this.severity = IssueSeverity.medium,
    this.contractorUid,
    this.contractorName,
    this.category = SnagCategory.other,
  });

  final String id;
  final String description;
  final SnagStatus status;
  final List<String> photoUrls;
  final String? assignedToUid;
  final String? assignedToName;
  final DateTime? dueDate;
  final DateTime createdAt;
  final String createdByUid;
  final String createdByName;
  final DateTime? resolvedAt;
  final DateTime? confirmedAt;
  final String? notes;
  final IssueType issueType;
  final IssueSeverity severity;
  final String? contractorUid;
  final String? contractorName;
  final SnagCategory category;

  Map<String, dynamic> toMap() => {
        'description': description,
        'status': status.firestoreValue,
        if (photoUrls.isNotEmpty) 'photoUrls': photoUrls,
        if (assignedToUid != null) 'assignedToUid': assignedToUid,
        if (assignedToName != null) 'assignedToName': assignedToName,
        if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
        'createdAt': Timestamp.fromDate(createdAt),
        'createdByUid': createdByUid,
        'createdByName': createdByName,
        if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
        if (confirmedAt != null)
          'confirmedAt': Timestamp.fromDate(confirmedAt!),
        if (notes != null) 'notes': notes,
        'issueType': issueType.firestoreValue,
        'severity': severity.firestoreValue,
        if (contractorUid != null) 'contractorUid': contractorUid,
        if (contractorName != null) 'contractorName': contractorName,
        'category': category.name,
      };

  factory SnagItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SnagItem(
      id: doc.id,
      description: d['description'] as String? ?? '',
      status: snagStatusFromString(d['status'] as String?),
      photoUrls: d['photoUrls'] is List
          ? List<String>.from(d['photoUrls'] as List)
          : (d['photoUrl'] as String?) != null
              ? [d['photoUrl'] as String]
              : const [],
      assignedToUid: d['assignedToUid'] as String?,
      assignedToName: d['assignedToName'] as String?,
      dueDate: (d['dueDate'] as Timestamp?)?.toDate(),
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByUid: d['createdByUid'] as String? ?? '',
      createdByName: d['createdByName'] as String? ?? '',
      resolvedAt: (d['resolvedAt'] as Timestamp?)?.toDate(),
      confirmedAt: (d['confirmedAt'] as Timestamp?)?.toDate(),
      notes: d['notes'] as String?,
      issueType: issueTypeFromString(d['issueType'] as String?),
      severity: issueSeverityFromString(d['severity'] as String?),
      contractorUid: d['contractorUid'] as String?,
      contractorName: d['contractorName'] as String?,
      category: SnagCategory.values.firstWhere(
        (e) => e.name == (d['category'] as String? ?? 'other'),
        orElse: () => SnagCategory.other,
      ),
    );
  }
}
