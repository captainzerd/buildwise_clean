import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/id_verification.dart';

/// Service for `users/{uid}/id_verification/doc`.
class IdVerificationService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> _docRef(String uid) =>
      _db.collection('users').doc(uid).collection('id_verification').doc('doc');

  /// Live stream of the current user's ID verification status.
  Stream<IdVerification?> streamVerification(String uid) {
    return _docRef(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return IdVerification.fromMap(snap.data()!, uid);
    });
  }

  /// Submit for verification. Uploads images then writes status='pending'.
  Future<void> submitVerification(
    String uid,
    IdVerification verification, {
    File? frontFile,
    File? backFile,
  }) async {
    String? frontUrl;
    String? backUrl;

    if (frontFile != null) {
      final ref = _storage.ref('id_verification/$uid/front.jpg');
      final task = await ref.putFile(frontFile);
      frontUrl = await task.ref.getDownloadURL();
    }
    if (backFile != null) {
      final ref = _storage.ref('id_verification/$uid/back.jpg');
      final task = await ref.putFile(backFile);
      backUrl = await task.ref.getDownloadURL();
    }

    final toWrite = verification.copyWith(
      status: 'pending',
      frontImageUrl: frontUrl ?? verification.frontImageUrl,
      backImageUrl: backUrl ?? verification.backImageUrl,
      submittedAt: DateTime.now(),
    );

    await _docRef(uid).set(toWrite.toMap(), SetOptions(merge: true));

    // Update top-level users doc
    await _db.collection('users').doc(uid).update({
      'idVerificationStatus': 'pending',
    });
  }

  /// Admin: approve or reject a verification.
  Future<void> adminReview(
    String uid,
    String status, {
    String? note,
    required String reviewerUid,
  }) async {
    await _docRef(uid).update({
      'status': status,
      if (note != null) 'adminNote': note,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedByUid': reviewerUid,
    });

    // Sync to users doc
    await _db.collection('users').doc(uid).update({
      'idVerificationStatus': status,
    });
  }

  /// Admin: stream all pending verifications (collection group query).
  Stream<List<Map<String, dynamic>>> streamAllPending() {
    return _db
        .collectionGroup('id_verification')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => {'uid': d.reference.parent.parent!.id, ...d.data()})
              .toList(),
        );
  }
}
