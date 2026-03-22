// lib/core/services/due_diligence_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/due_diligence_item.dart';

class DueDiligenceService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String projectId) =>
      _db.collection('projects').doc(projectId).collection('due_diligence');

  /// Stream all due-diligence items for a project.
  Stream<List<DueDiligenceItem>> itemsStream(String projectId) {
    return _col(projectId).orderBy('title').snapshots().map(
          (s) => s.docs
              .map(
                (d) => DueDiligenceItem.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Seeds the default checklist if the sub-collection is empty.
  Future<void> seedDefaultItems(String projectId) async {
    final snap = await _col(projectId).limit(1).get();
    if (snap.docs.isNotEmpty) return; // already seeded

    final batch = _db.batch();
    for (final item in DueDiligenceItem.defaultItems()) {
      batch.set(_col(projectId).doc(item.id), item.toMap());
    }
    await batch.commit();
  }

  /// Update the status of a single item.
  Future<void> updateItem(
    String projectId,
    String itemId, {
    required DueDiligenceStatus status,
    String? notes,
    String? verifiedByName,
  }) async {
    await _col(projectId).doc(itemId).update({
      'status': status.firestoreValue,
      if (notes != null) 'notes': notes,
      if (status == DueDiligenceStatus.verified) ...{
        'verifiedAt': FieldValue.serverTimestamp(),
        if (verifiedByName != null) 'verifiedByName': verifiedByName,
      },
      if (status != DueDiligenceStatus.verified) ...{
        'verifiedAt': FieldValue.delete(),
        'verifiedByName': FieldValue.delete(),
      },
    });
  }
}
