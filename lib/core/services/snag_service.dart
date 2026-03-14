// lib/core/services/snag_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/snag_item.dart';

class SnagService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String projectId) =>
      _db.collection('projects').doc(projectId).collection('snag_items');

  /// Stream all snag items for a project (newest first).
  Stream<List<SnagItem>> itemsStream(String projectId) {
    return _col(projectId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => SnagItem.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Create a new snag item.
  Future<String> addItem(String projectId, SnagItem item) async {
    final ref = _col(projectId).doc();
    await ref.set(item.toMap());
    return ref.id;
  }

  /// Builder marks an item as resolved.
  Future<void> resolveItem(
    String projectId,
    String snagId, {
    String? notes,
  }) async {
    await _col(projectId).doc(snagId).update({
      'status': SnagStatus.resolved.firestoreValue,
      'resolvedAt': FieldValue.serverTimestamp(),
      if (notes != null) 'notes': notes,
    });
  }

  /// Owner confirms resolution of a snag item.
  Future<void> confirmItem(String projectId, String snagId) async {
    await _col(projectId).doc(snagId).update({
      'status': SnagStatus.confirmed.firestoreValue,
      'confirmedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reopen a confirmed / resolved item.
  Future<void> reopenItem(String projectId, String snagId) async {
    await _col(projectId).doc(snagId).update({
      'status': SnagStatus.open.firestoreValue,
      'resolvedAt': FieldValue.delete(),
      'confirmedAt': FieldValue.delete(),
    });
  }

  /// Delete a snag item (owner only).
  Future<void> deleteItem(String projectId, String snagId) async {
    await _col(projectId).doc(snagId).delete();
  }
}
