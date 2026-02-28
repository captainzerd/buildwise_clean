import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors/app_exception.dart';
import '../models/deletion_request.dart';

class DeletionRequestService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String projectId) => _db
      .collection('projects')
      .doc(projectId)
      .collection('deletionRequests');

  /// Stream of pending deletion requests for [projectId] (owner view).
  Stream<List<DeletionRequest>> pendingStream(String projectId) {
    return _col(projectId)
        .where('status', isEqualTo: DeletionStatus.pending.firestoreValue)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => DeletionRequest.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Admin: stream of all pending deletion requests across every project.
  Stream<List<DeletionRequest>> allPendingStream() {
    return _db
        .collectionGroup('deletionRequests')
        .where('status', isEqualTo: DeletionStatus.pending.firestoreValue)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => DeletionRequest.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Builder submits a deletion request. Doc ID = itemId (prevents duplicates).
  Future<void> request(DeletionRequest req) async {
    try {
      await _col(req.projectId).doc(req.itemId).set(req.toMap());
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Owner approves: deletes the actual item and marks request approved.
  /// For cost entries, atomically decrements project.amountSpent.
  Future<void> approve(DeletionRequest req) async {
    try {
      final projectRef = _db.collection('projects').doc(req.projectId);
      final reqRef = _col(req.projectId).doc(req.itemId);
      final now = Timestamp.fromDate(DateTime.now());
      final approvedData = <String, dynamic>{
        'status': DeletionStatus.approved.firestoreValue,
        'resolvedAt': now,
      };

      if (req.itemType == DeletionItemType.costEntry &&
          req.amountGhs != null) {
        // Transaction: atomically delete cost + reverse amountSpent + mark approved.
        await _db.runTransaction((tx) async {
          final snap = await tx.get(projectRef);
          final current =
              (snap.data()?['amountSpent'] as num?)?.toDouble() ?? 0;
          tx.delete(projectRef.collection('costs').doc(req.itemId));
          tx.update(reqRef, approvedData);
          tx.update(projectRef, {
            'amountSpent':
                (current - req.amountGhs!).clamp(0, double.infinity),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      } else {
        final subCol = switch (req.itemType) {
          DeletionItemType.costEntry => 'costs',
          DeletionItemType.payment => 'payments',
          DeletionItemType.document => 'documents',
          DeletionItemType.update => 'updates',
        };
        final batch = _db.batch();
        batch.delete(projectRef.collection(subCol).doc(req.itemId));
        batch.update(reqRef, approvedData);
        await batch.commit();
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Owner denies: marks request denied without deleting the item.
  Future<void> deny(DeletionRequest req, {String? ownerNote}) async {
    try {
      await _col(req.projectId).doc(req.itemId).update({
        'status': DeletionStatus.denied.firestoreValue,
        'resolvedAt': Timestamp.fromDate(DateTime.now()),
        if (ownerNote != null) 'ownerNote': ownerNote,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
