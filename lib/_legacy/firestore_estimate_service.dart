// Optional Firestore persistence aligned to the new Estimate model.
// If you don't have cloud_firestore configured, you can ignore this file.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/estimate.dart';

class FirestoreEstimateService {
  final FirebaseFirestore _db;
  FirestoreEstimateService(this._db);

  CollectionReference<Map<String, dynamic>> _col() =>
      _db.collection('estimates');

  Future<void> save(Estimate e) async {
    await _col().doc(e.projectId).set(e.toJson(), SetOptions(merge: true));
  }

  Future<Estimate?> getById(String id) async {
    final doc = await _col().doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return Estimate.fromJson(data);
  }

  Future<List<Estimate>> list() async {
    final qs = await _col().orderBy('createdAt', descending: true).get();
    return qs.docs
        .map((d) => Estimate.fromJson(d.data()))
        .toList(growable: false);
  }
}
