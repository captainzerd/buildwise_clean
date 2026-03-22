// lib/core/models/permit.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum PermitStatus { notStarted, submitted, underReview, approved, rejected }

extension PermitStatusLabel on PermitStatus {
  String get label => switch (this) {
        PermitStatus.notStarted => 'Not Started',
        PermitStatus.submitted => 'Submitted',
        PermitStatus.underReview => 'Under Review',
        PermitStatus.approved => 'Approved',
        PermitStatus.rejected => 'Rejected',
      };

  Color get color => switch (this) {
        PermitStatus.notStarted => Colors.grey,
        PermitStatus.submitted => Colors.blue,
        PermitStatus.underReview => Colors.orange,
        PermitStatus.approved => Colors.green,
        PermitStatus.rejected => Colors.red,
      };

  /// Firestore-safe string value (uses underscore convention for storage).
  String get firestoreValue => switch (this) {
        PermitStatus.notStarted => 'not_started',
        PermitStatus.submitted => 'submitted',
        PermitStatus.underReview => 'under_review',
        PermitStatus.approved => 'approved',
        PermitStatus.rejected => 'rejected',
      };
}

PermitStatus permitStatusFromString(String? s) => switch (s) {
      'submitted' => PermitStatus.submitted,
      'under_review' => PermitStatus.underReview,
      'approved' => PermitStatus.approved,
      'rejected' => PermitStatus.rejected,
      _ => PermitStatus.notStarted,
    };

@immutable
class PermitItem {
  const PermitItem({
    required this.id,
    required this.type,
    required this.status,
    required this.notes,
    required this.updatedAt,
    required this.updatedBy,
    this.submittedAt,
    this.approvedAt,
    this.referenceNumber,
  });

  final String id;

  /// One of: "Building Permit" | "EPA Clearance" | "Structural Approval" | "Utility Connection"
  final String type;
  final PermitStatus status;
  final String notes;
  final DateTime updatedAt;
  final String updatedBy;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final String? referenceNumber;

  factory PermitItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PermitItem(
      id: doc.id,
      type: d['type'] as String? ?? 'Building Permit',
      status: permitStatusFromString(d['status'] as String?),
      notes: d['notes'] as String? ?? '',
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: d['updatedBy'] as String? ?? '',
      submittedAt: (d['submittedAt'] as Timestamp?)?.toDate(),
      approvedAt: (d['approvedAt'] as Timestamp?)?.toDate(),
      referenceNumber: d['referenceNumber'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'status': status.firestoreValue,
        'notes': notes,
        'updatedAt': Timestamp.fromDate(updatedAt),
        'updatedBy': updatedBy,
        if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
        if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
        if (referenceNumber != null) 'referenceNumber': referenceNumber,
      };
}

@immutable
class DaContact {
  const DaContact({
    required this.name,
    required this.phone,
    required this.region,
    this.website = '',
  });

  final String name;
  final String phone;
  final String region;
  final String website;
}

const daContacts = <DaContact>[
  DaContact(
    name: 'Accra Metropolitan Assembly',
    phone: '+233 302 664 941',
    region: 'Greater Accra',
    website: 'ama.com.gh',
  ),
  DaContact(
    name: 'Kumasi Metropolitan Assembly',
    phone: '+233 322 023 850',
    region: 'Ashanti',
    website: 'kma.gov.gh',
  ),
  DaContact(
    name: 'Tema Metropolitan Assembly',
    phone: '+233 303 315 000',
    region: 'Greater Accra',
    website: 'temametro.gov.gh',
  ),
  DaContact(
    name: 'Tamale Metropolitan Assembly',
    phone: '+233 372 022 830',
    region: 'Northern',
    website: 'tamalemetro.gov.gh',
  ),
  DaContact(
    name: 'Sekondi-Takoradi Metropolitan Assembly',
    phone: '+233 312 021 600',
    region: 'Western',
    website: 'stma.gov.gh',
  ),
  DaContact(
    name: 'Cape Coast Metropolitan Assembly',
    phone: '+233 332 130 002',
    region: 'Central',
    website: 'capecoastmetro.gov.gh',
  ),
  DaContact(
    name: 'Ho Municipal Assembly',
    phone: '+233 362 027 145',
    region: 'Volta',
    website: 'homca.gov.gh',
  ),
  DaContact(
    name: 'Koforidua Municipal Assembly',
    phone: '+233 342 022 428',
    region: 'Eastern',
  ),
  DaContact(
    name: 'Sunyani Municipal Assembly',
    phone: '+233 352 027 145',
    region: 'Bono',
  ),
  DaContact(
    name: 'Bolgatanga Municipal Assembly',
    phone: '+233 382 022 130',
    region: 'Upper East',
  ),
];
