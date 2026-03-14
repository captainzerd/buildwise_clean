// lib/core/services/payment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_record.dart';
import '../repositories/i_payment_repository.dart';

class PaymentService implements IPaymentRepository {
  PaymentService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String projectId) =>
      _db.collection('projects').doc(projectId).collection('payments');

  @override
  Stream<List<PaymentRecord>> paymentsStream(String projectId) =>
      _col(projectId)
          .orderBy('paymentDate', descending: true)
          .limit(100)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map(
                  (d) => PaymentRecord.fromDoc(
                    d as DocumentSnapshot<Map<String, dynamic>>,
                  ),
                )
                .toList(),
          );

  @override
  Future<String> addPayment({
    required String projectId,
    required PaymentRecord payment,
  }) async {
    final ref = await _col(projectId).add(payment.toMap());
    return ref.id;
  }

  @override
  Future<void> deletePayment({
    required String projectId,
    required String paymentId,
  }) =>
      _col(projectId).doc(paymentId).delete();
}
