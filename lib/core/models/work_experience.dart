import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Stored at `builder_profiles/{uid}/work_history/{id}`.
@immutable
class WorkExperience {
  const WorkExperience({
    required this.id,
    required this.projectOrEmployer,
    required this.roleTitle,
    required this.startDate,
    this.region,
    this.contractValueGhs,
    this.endDate,
    this.description,
    this.clientReference,
  });

  final String id;
  final String projectOrEmployer;
  final String roleTitle;
  final DateTime startDate;
  final DateTime? endDate;
  final String? region;
  final double? contractValueGhs;
  final String? description;
  final String? clientReference;

  bool get isCurrent => endDate == null;

  factory WorkExperience.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return WorkExperience(
      id: doc.id,
      projectOrEmployer: d['projectOrEmployer'] as String? ?? '',
      roleTitle: d['roleTitle'] as String? ?? '',
      startDate:
          (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (d['endDate'] as Timestamp?)?.toDate(),
      region: d['region'] as String?,
      contractValueGhs: (d['contractValueGhs'] as num?)?.toDouble(),
      description: d['description'] as String?,
      clientReference: d['clientReference'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'projectOrEmployer': projectOrEmployer,
        'roleTitle': roleTitle,
        'startDate': Timestamp.fromDate(startDate),
        if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
        if (region != null) 'region': region,
        if (contractValueGhs != null) 'contractValueGhs': contractValueGhs,
        if (description != null) 'description': description,
        if (clientReference != null) 'clientReference': clientReference,
      };
}
