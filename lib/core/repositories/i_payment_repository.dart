// lib/core/repositories/i_payment_repository.dart
//
// Abstract interface for payment data access. Concrete implementation:
//   PaymentService (lib/core/services/payment_service.dart)

import '../models/payment_record.dart';

abstract class IPaymentRepository {
  Stream<List<PaymentRecord>> paymentsStream(String projectId);

  Future<String> addPayment({
    required String projectId,
    required PaymentRecord payment,
  });

  Future<void> deletePayment({
    required String projectId,
    required String paymentId,
  });
}
