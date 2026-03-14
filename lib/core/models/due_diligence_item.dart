// lib/core/models/due_diligence_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum DueDiligenceStatus { pending, verified, failed }

extension DueDiligenceStatusLabel on DueDiligenceStatus {
  String get label => switch (this) {
        DueDiligenceStatus.pending => 'Pending',
        DueDiligenceStatus.verified => 'Verified',
        DueDiligenceStatus.failed => 'Failed',
      };

  String get firestoreValue => switch (this) {
        DueDiligenceStatus.pending => 'pending',
        DueDiligenceStatus.verified => 'verified',
        DueDiligenceStatus.failed => 'failed',
      };
}

DueDiligenceStatus dueDiligenceStatusFromString(String? s) => switch (s) {
      'verified' => DueDiligenceStatus.verified,
      'failed' => DueDiligenceStatus.failed,
      _ => DueDiligenceStatus.pending,
    };

class DueDiligenceItem {
  const DueDiligenceItem({
    required this.id,
    required this.title,
    required this.description,
    this.status = DueDiligenceStatus.pending,
    this.notes,
    this.verifiedAt,
    this.verifiedByName,
  });

  final String id;
  final String title;
  final String description;
  final DueDiligenceStatus status;
  final String? notes;
  final DateTime? verifiedAt;
  final String? verifiedByName;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status.firestoreValue,
        if (notes != null) 'notes': notes,
        if (verifiedAt != null) 'verifiedAt': Timestamp.fromDate(verifiedAt!),
        if (verifiedByName != null) 'verifiedByName': verifiedByName,
      };

  factory DueDiligenceItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return DueDiligenceItem(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      status: dueDiligenceStatusFromString(d['status'] as String?),
      notes: d['notes'] as String?,
      verifiedAt: (d['verifiedAt'] as Timestamp?)?.toDate(),
      verifiedByName: d['verifiedByName'] as String?,
    );
  }

  DueDiligenceItem copyWith({
    DueDiligenceStatus? status,
    String? notes,
    DateTime? verifiedAt,
    String? verifiedByName,
  }) =>
      DueDiligenceItem(
        id: id,
        title: title,
        description: description,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        verifiedAt: verifiedAt ?? this.verifiedAt,
        verifiedByName: verifiedByName ?? this.verifiedByName,
      );

  /// Default checklist seeded for every new project.
  static List<DueDiligenceItem> defaultItems() => const [
        DueDiligenceItem(
          id: 'lands_search',
          title: 'Lands Commission Search',
          description:
              'Official search report confirming ownership and any encumbrances on the land.',
        ),
        DueDiligenceItem(
          id: 'site_plan',
          title: 'Site Plan',
          description:
              'Approved site / layout plan from the relevant municipal authority.',
        ),
        DueDiligenceItem(
          id: 'indenture',
          title: 'Indenture / Title Deed',
          description:
              'Signed and stamped indenture or land certificate from the Land Title Registry.',
        ),
        DueDiligenceItem(
          id: 'building_permit',
          title: 'Building Permit',
          description:
              'Development permit from the District / Municipal / Metropolitan Assembly.',
        ),
        DueDiligenceItem(
          id: 'encumbrances',
          title: 'Encumbrance Check',
          description:
              'Confirm no outstanding mortgages, liens, or court orders on the property.',
        ),
        DueDiligenceItem(
          id: 'env_clearance',
          title: 'Environmental Clearance',
          description:
              'EPA environmental impact or clearance certificate (required for larger builds).',
        ),
      ];
}
