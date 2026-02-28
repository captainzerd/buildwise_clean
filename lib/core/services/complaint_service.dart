import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint.dart';

class ComplaintService {
  final _col =
      FirebaseFirestore.instance.collection('complaints').withConverter(
            fromFirestore: (snap, _) => Complaint.fromDoc(snap),
            toFirestore: (Complaint c, _) => c.toMap(),
          );

  Future<String> create(Complaint complaint) async {
    final ref = await _col.add(complaint);
    return ref.id;
  }

  Stream<List<Complaint>> listForUser(String userUid) {
    return _col
        .where('userUid', isEqualTo: userUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Future<void> delete(String complaintId) =>
      FirebaseFirestore.instance
          .collection('complaints')
          .doc(complaintId)
          .delete();

  /// Admin: stream of all complaints, newest first.
  Stream<List<Complaint>> listAll() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  /// Admin: update complaint status.
  Future<void> updateStatus(String complaintId, String status) =>
      FirebaseFirestore.instance
          .collection('complaints')
          .doc(complaintId)
          .update({'status': status});
}
