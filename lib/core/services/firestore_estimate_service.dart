// lib/core/services/firestore_estimate_service.dart
//
// Firestore gateway using typed converters. Safe if Firebase isn't initialized;
// just don't call it until Firebase is set up.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/estimate.dart';

class FirestoreEstimateService {
  FirestoreEstimateService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Estimate> get _col =>
      _db.collection('estimates').withConverter<Estimate>(
            fromFirestore: (snap, _) {
              final data = snap.data();
              if (data == null) {
                // Shouldn't happen, but keep analyzer happy.
                return Estimate(
                  projectId: snap.id,
                  projectName: '',
                  region: '',
                  city: '',
                  squareFootage: 0,
                  phasePlanned: const {},
                  createdAt: DateTime.now(),
                );
              }
              // Ensure projectId comes from doc id.
              final map = Map<String, dynamic>.from(data)
                ..['projectId'] = snap.id;
              return Estimate.fromJson(map);
            },
            toFirestore: (e, _) => e.toJson(),
          );

  Future<void> create(Estimate e) async {
    await _col.doc(e.projectId).set(e);
  }

  Future<void> update(Estimate e) async {
    await _col.doc(e.projectId).set(e, SetOptions(merge: true));
  }

  Future<Estimate?> getById(String id) async {
    final doc = await _col.doc(id).get();
    return doc.data();
  }

  Future<List<Estimate>> list({int limit = 100}) async {
    final qs =
        await _col.orderBy('createdAt', descending: true).limit(limit).get();
    return qs.docs.map((d) => d.data()).toList(growable: false);
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
