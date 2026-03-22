// lib/core/services/land_ownership_service.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/land_ownership_record.dart';

class LandOwnershipService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _col(String projectId) =>
      _db.collection('projects').doc(projectId).collection('land_ownership');

  /// Stream the single land ownership record for a project (0 or 1 docs).
  Stream<LandOwnershipRecord?> recordStream(String projectId) {
    return _col(projectId)
        .orderBy('createdAt', descending: false)
        .limit(1)
        .snapshots()
        .map(
          (s) => s.docs.isEmpty
              ? null
              : LandOwnershipRecord.fromDoc(
                  s.docs.first as DocumentSnapshot<Map<String, dynamic>>,
                ),
        );
  }

  /// Create or replace the land ownership record for a project.
  Future<String> saveRecord(
    String projectId,
    LandOwnershipRecord record,
  ) async {
    final id = record.id.isEmpty ? const Uuid().v4() : record.id;
    await _col(projectId).doc(id).set(record.toMap());
    return id;
  }

  /// Update specific fields on an existing record.
  Future<void> updateRecord(
    String projectId,
    String recordId,
    Map<String, dynamic> fields,
  ) async {
    await _col(projectId).doc(recordId).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Upload a document (title deed or site map) to Firebase Storage.
  /// Returns the download URL.
  Future<String> uploadDocument(
    String projectId,
    String ownerUid,
    String docType, // 'title_deed' or 'site_map'
    String filePath,
    String fileName,
  ) async {
    final ref = _storage
        .ref('project_docs/$ownerUid/land/$projectId/$docType/$fileName');
    await ref.putFile(File(filePath));
    return ref.getDownloadURL();
  }
}
