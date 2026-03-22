import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/work_experience.dart';

/// CRUD service for `builder_profiles/{uid}/work_history/{id}`.
class WorkExperienceService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('builder_profiles').doc(uid).collection('work_history');

  /// Live stream ordered by startDate descending.
  Stream<List<WorkExperience>> stream(String uid) {
    return _col(uid)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => WorkExperience.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  Future<void> add(String uid, WorkExperience experience) async {
    final id = const Uuid().v4();
    await _col(uid).doc(id).set(experience.toMap());
  }

  Future<void> update(String uid, WorkExperience experience) async {
    await _col(uid).doc(experience.id).update(experience.toMap());
  }

  Future<void> delete(String uid, String id) async {
    await _col(uid).doc(id).delete();
  }
}
