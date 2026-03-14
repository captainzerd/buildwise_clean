import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Stored at `builder_profiles/{uid}/certifications/{id}`.
@immutable
class Certification {
  const Certification({
    required this.id,
    required this.name,
    required this.issuingBody,
    required this.issueDate,
    this.certificateNumber,
    this.expiryDate,
    this.documentUrl,
    this.verificationStatus = 'unverified',
  });

  final String id;
  final String name;
  final String issuingBody;
  final DateTime issueDate;
  final DateTime? expiryDate;
  final String? certificateNumber;
  final String? documentUrl;
  /// 'unverified' | 'pending' | 'verified' | 'rejected'
  final String verificationStatus;

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  bool get isExpiringSoon =>
      expiryDate != null &&
      !isExpired &&
      expiryDate!.isBefore(
        DateTime.now().add(const Duration(days: 30)),
      );

  factory Certification.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return Certification(
      id: doc.id,
      name: d['name'] as String? ?? '',
      issuingBody: d['issuingBody'] as String? ?? '',
      issueDate:
          (d['issueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (d['expiryDate'] as Timestamp?)?.toDate(),
      certificateNumber: d['certificateNumber'] as String?,
      documentUrl: d['documentUrl'] as String?,
      verificationStatus:
          d['verificationStatus'] as String? ?? 'unverified',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'issuingBody': issuingBody,
        'issueDate': Timestamp.fromDate(issueDate),
        if (expiryDate != null) 'expiryDate': Timestamp.fromDate(expiryDate!),
        if (certificateNumber != null) 'certificateNumber': certificateNumber,
        if (documentUrl != null) 'documentUrl': documentUrl,
        'verificationStatus': verificationStatus,
      };
}
