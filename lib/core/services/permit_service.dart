// lib/core/services/permit_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/permit.dart';

class PermitService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String projectId) =>
      _db.collection('projects').doc(projectId).collection('permits');

  /// Stream all permits for a project, ordered by updatedAt desc.
  Stream<List<PermitItem>> permitsStream(String projectId) {
    return _col(projectId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => PermitItem.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Add a new permit with auto-generated ID.
  Future<void> addPermit(String projectId, PermitItem permit) async {
    final data = permit.toMap()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await _col(projectId).add(data);
  }

  /// Update permit status, notes, and referenceNumber.
  Future<void> updateStatus(
    String projectId,
    String permitId, {
    required PermitStatus status,
    String? referenceNumber,
    String? notes,
    required String updatedByUid,
  }) async {
    final data = <String, dynamic>{
      'status': status.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedByUid,
      if (notes != null) 'notes': notes,
      if (referenceNumber != null) 'referenceNumber': referenceNumber,
    };

    // Set submittedAt / approvedAt timestamps when transitioning
    if (status == PermitStatus.submitted) {
      data['submittedAt'] = FieldValue.serverTimestamp();
    } else if (status == PermitStatus.approved) {
      data['approvedAt'] = FieldValue.serverTimestamp();
    }

    await _col(projectId).doc(permitId).update(data);
  }
}
