import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Stored at `users/{uid}/id_verification/doc`.
@immutable
class IdVerification {
  const IdVerification({
    required this.uid,
    required this.idType,
    required this.idNumber,
    required this.status,
    this.frontImageUrl,
    this.backImageUrl,
    this.adminNote,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedByUid,
  });

  final String uid;
  /// e.g. 'ghana_card' | 'passport' | 'drivers_licence' | 'voters_id'
  final String idType;
  final String idNumber;
  /// 'unverified' | 'pending' | 'verified' | 'rejected'
  final String status;
  final String? frontImageUrl;
  final String? backImageUrl;
  final String? adminNote;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedByUid;

  factory IdVerification.fromMap(Map<String, dynamic> d, String uid) {
    return IdVerification(
      uid: uid,
      idType: d['idType'] as String? ?? '',
      idNumber: d['idNumber'] as String? ?? '',
      status: d['status'] as String? ?? 'unverified',
      frontImageUrl: d['frontImageUrl'] as String?,
      backImageUrl: d['backImageUrl'] as String?,
      adminNote: d['adminNote'] as String?,
      submittedAt: (d['submittedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (d['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedByUid: d['reviewedByUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'idType': idType,
        'idNumber': idNumber,
        'status': status,
        if (frontImageUrl != null) 'frontImageUrl': frontImageUrl,
        if (backImageUrl != null) 'backImageUrl': backImageUrl,
        if (adminNote != null) 'adminNote': adminNote,
        if (submittedAt != null)
          'submittedAt': Timestamp.fromDate(submittedAt!),
        if (reviewedAt != null)
          'reviewedAt': Timestamp.fromDate(reviewedAt!),
        if (reviewedByUid != null) 'reviewedByUid': reviewedByUid,
      };

  IdVerification copyWith({
    String? idType,
    String? idNumber,
    String? status,
    String? frontImageUrl,
    String? backImageUrl,
    String? adminNote,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedByUid,
  }) =>
      IdVerification(
        uid: uid,
        idType: idType ?? this.idType,
        idNumber: idNumber ?? this.idNumber,
        status: status ?? this.status,
        frontImageUrl: frontImageUrl ?? this.frontImageUrl,
        backImageUrl: backImageUrl ?? this.backImageUrl,
        adminNote: adminNote ?? this.adminNote,
        submittedAt: submittedAt ?? this.submittedAt,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        reviewedByUid: reviewedByUid ?? this.reviewedByUid,
      );
}
