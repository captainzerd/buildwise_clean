// lib/core/models/snag_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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
    );
  }
}
