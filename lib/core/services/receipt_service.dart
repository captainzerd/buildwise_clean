import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/material_receipt.dart';

class ReceiptService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Stream<List<MaterialReceipt>> receiptsStream(
    String projectId,
    String phaseId,
  ) =>
      _db
          .collection('projects')
          .doc(projectId)
          .collection('phases')
          .doc(phaseId)
          .collection('receipts')
          .orderBy('purchaseDate', descending: true)
          .snapshots()
          .map(
            (s) =>
                s.docs.map((d) => MaterialReceipt.fromMap(d.data())).toList(),
          );

  Future<String> uploadReceiptFile({
    required String projectId,
    required String phaseId,
    required File file,
    required String receiptId,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref(
      'projects/$projectId/phases/$phaseId/receipts/$receiptId.jpg',
    );
    final task = ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    StreamSubscription<TaskSnapshot>? sub;
    if (onProgress != null) {
      sub = task.snapshotEvents.listen((snap) {
        onProgress(
          snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes),
        );
      });
    }
    try {
      await task;
    } finally {
      await sub?.cancel();
    }
    return ref.getDownloadURL();
  }

  Future<void> addReceipt(MaterialReceipt receipt) async {
    await _db
        .collection('projects')
        .doc(receipt.projectId)
        .collection('phases')
        .doc(receipt.phaseId)
        .collection('receipts')
        .doc(receipt.id)
        .set(receipt.toMap());
  }

  Future<void> deleteReceipt({
    required String projectId,
    required String phaseId,
    required String receiptId,
  }) async {
    await _db
        .collection('projects')
        .doc(projectId)
        .collection('phases')
        .doc(phaseId)
        .collection('receipts')
        .doc(receiptId)
        .delete();

    // Best-effort: delete the Storage blob (ignore errors if already gone).
    try {
      await _storage
          .ref('projects/$projectId/phases/$phaseId/receipts/$receiptId.jpg')
          .delete();
    } catch (_) {}
  }

  String newReceiptId() => const Uuid().v4();
}
