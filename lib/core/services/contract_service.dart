import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors/app_exception.dart';
import '../models/builder_contract.dart';

class ContractService {
  final _db = FirebaseFirestore.instance;
  final _col = FirebaseFirestore.instance.collection('contracts');

  // ── Read ──

  /// Stream all contracts for a project (newest first).
  Stream<List<BuilderContract>> contractsForProject(String projectId) {
    return _col
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => BuilderContract.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Stream of the most recent non-cancelled/declined contract for a project.
  Stream<BuilderContract?> activeContractStream(String projectId) {
    return contractsForProject(projectId).map(
      (list) => list.where((c) {
        return c.status == ContractStatus.pendingBuilder ||
            c.status == ContractStatus.active;
      }).firstOrNull,
    );
  }

  /// Stream contracts pending this builder's signature.
  Stream<List<BuilderContract>> pendingForBuilder(String builderUid) {
    return _col
        .where('builderUid', isEqualTo: builderUid)
        .where('status', isEqualTo: ContractStatus.pendingBuilder.firestoreValue)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => BuilderContract.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  // ── Write ──

  /// Owner creates + signs a contract in one step (status: pendingBuilder).
  Future<String> createContract(BuilderContract contract) async {
    try {
      final ref = _col.doc();
      await ref.set(contract.toMap());
      return ref.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Builder accepts: signs contract and assigns themselves to the project.
  Future<void> builderAccept({
    required BuilderContract contract,
    required String signatureName,
  }) async {
    try {
      final now = DateTime.now();
      final batch = _db.batch();

      // Update contract
      batch.update(_col.doc(contract.id), {
        'status': ContractStatus.active.firestoreValue,
        'builderSignatureName': signatureName,
        'builderSignedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Assign builder to project
      batch.update(
        _db.collection('projects').doc(contract.projectId),
        {
          'assignedPmUid': contract.builderUid,
          'assignedPmName': contract.builderName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Builder declines the contract.
  Future<void> builderDecline(String contractId) async {
    try {
      await _col.doc(contractId).update({
        'status': ContractStatus.declined.firestoreValue,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Owner cancels a pending contract.
  Future<void> ownerCancel(String contractId) async {
    try {
      await _col.doc(contractId).update({
        'status': ContractStatus.cancelled.firestoreValue,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
