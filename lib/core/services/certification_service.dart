import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/certification.dart';

/// CRUD service for `builder_profiles/{uid}/certifications/{id}`.
class CertificationService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('builder_profiles').doc(uid).collection('certifications');

  /// Live stream of certifications ordered by issueDate descending.
  Stream<List<Certification>> stream(String uid) {
    return _col(uid)
        .orderBy('issueDate', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => Certification.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  Future<void> add(String uid, Certification cert) async {
    final id = const Uuid().v4();
    await _col(uid).doc(id).set(cert.toMap());
  }

  Future<void> update(String uid, Certification cert) async {
    await _col(uid).doc(cert.id).update(cert.toMap());
  }

  Future<void> delete(String uid, String id) async {
    await _col(uid).doc(id).delete();
  }

  /// Uploads a certificate document and returns the download URL.
  /// Stores at `profile_docs/{uid}/certifications/{certId}.{ext}`.
  Future<String> uploadCertDocument(
    String uid,
    String certId,
    File file,
    String extension,
  ) async {
    final ref = _storage.ref(
      'profile_docs/$uid/certifications/$certId.$extension',
    );
    final task = await ref.putFile(file);
    final url = await task.ref.getDownloadURL();

    // Update the doc with the new URL
    await _col(uid).doc(certId).update({'documentUrl': url});
    return url;
  }
}
