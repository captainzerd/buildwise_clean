// lib/core/services/variation_order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';
import '../models/variation_order.dart';

class VariationOrderService extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String projectId) => _db
      .collection('projects')
      .doc(projectId)
      .collection('variation_orders');

  Stream<List<VariationOrder>> ordersStream(String projectId) {
    return _col(projectId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => VariationOrder.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  Future<void> submitOrder(VariationOrder order) async {
    try {
      final ref = _col(order.projectId).doc();
      await ref.set(
        VariationOrder(
          id: ref.id,
          projectId: order.projectId,
          submittedByUid: order.submittedByUid,
          submittedByName: order.submittedByName,
          title: order.title,
          description: order.description,
          costDeltaGhs: order.costDeltaGhs,
          status: VoStatus.pending,
          createdAt: DateTime.now(),
          projectBudgetGhs: order.projectBudgetGhs,
        ).toMap(),
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> approveOrder(
    String projectId,
    String orderId, {
    String? comment,
  }) async {
    try {
      await _col(projectId).doc(orderId).update({
        'status': VoStatus.approved.firestoreValue,
        if (comment != null && comment.isNotEmpty) 'approverComment': comment,
        'decidedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> rejectOrder(
    String projectId,
    String orderId, {
    String? comment,
  }) async {
    try {
      await _col(projectId).doc(orderId).update({
        'status': VoStatus.rejected.firestoreValue,
        if (comment != null && comment.isNotEmpty) 'approverComment': comment,
        'decidedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> certifyVariationOrder({
    required String projectId,
    required String voId,
    required String certifierUid,
    required String certifierName,
  }) async {
    try {
      await _db
          .collection('projects')
          .doc(projectId)
          .collection('variation_orders')
          .doc(voId)
          .update({
        'certifiedByUid': certifierUid,
        'certifiedByName': certifierName,
        'certifiedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
