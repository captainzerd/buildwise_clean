// lib/core/services/labor_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/labor_record.dart';

class LaborService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String projectId) =>
      _db.collection('projects').doc(projectId).collection('labor_records');

  /// Stream all labor records for a project (newest date first).
  Stream<List<LaborRecord>> recordsStream(String projectId) {
    return _col(projectId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => LaborRecord.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Add a new labor record.
  Future<String> addRecord(String projectId, LaborRecord record) async {
    final ref = _col(projectId).doc();
    await ref.set(record.toMap());
    return ref.id;
  }

  /// Update an existing labor record.
  Future<void> updateRecord(
    String projectId,
    String recordId,
    Map<String, dynamic> updates,
  ) async {
    await _col(projectId).doc(recordId).update(updates);
  }

  /// Delete a labor record.
  Future<void> deleteRecord(String projectId, String recordId) async {
    await _col(projectId).doc(recordId).delete();
  }

  /// Calculate total labor cost for a project.
  Future<double> totalLaborCost(String projectId) async {
    final snap = await _col(projectId).get();
    return snap.docs
        .map((d) => (d.data()['totalGhs'] as num?)?.toDouble() ?? 0.0)
        .fold<double>(0.0, (a, b) => a + b);
  }
}
