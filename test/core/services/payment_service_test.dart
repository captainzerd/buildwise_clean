// test/core/services/payment_service_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wysebrix/core/models/payment_record.dart';
import 'package:wysebrix/core/services/payment_service.dart';

PaymentRecord _makePayment({
  double amount = 1000,
  PaymentDirection direction = PaymentDirection.outbound,
}) {
  return PaymentRecord(
    id: '',
    authorUid: 'uid1',
    direction: direction,
    amountGhs: amount,
    description: 'Test payment',
    method: PaymentMethod.mobileMoney,
    paymentDate: DateTime(2025, 6, 1),
    createdAt: DateTime(2025, 6, 1),
  );
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late PaymentService service;
  const projectId = 'project_abc';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = PaymentService(db: fakeFirestore);
  });

  group('addPayment', () {
    test('returns a non-empty ID', () async {
      final id = await service.addPayment(
        projectId: projectId,
        payment: _makePayment(),
      );
      expect(id, isNotEmpty);
    });

    test('payment appears in collection', () async {
      await service.addPayment(
        projectId: projectId,
        payment: _makePayment(amount: 5000),
      );

      final snap = await fakeFirestore
          .collection('projects')
          .doc(projectId)
          .collection('payments')
          .get();

      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['amountGhs'], 5000.0);
    });

    test('multiple payments stored independently', () async {
      await service.addPayment(
        projectId: projectId,
        payment: _makePayment(amount: 1000),
      );
      await service.addPayment(
        projectId: projectId,
        payment: _makePayment(amount: 2000),
      );

      final snap = await fakeFirestore
          .collection('projects')
          .doc(projectId)
          .collection('payments')
          .get();

      expect(snap.docs.length, 2);
      final amounts =
          snap.docs.map((d) => d.data()['amountGhs'] as double).toSet();
      expect(amounts, containsAll([1000.0, 2000.0]));
    });
  });

  group('deletePayment', () {
    test('payment removed after delete', () async {
      final id = await service.addPayment(
        projectId: projectId,
        payment: _makePayment(),
      );
      await service.deletePayment(projectId: projectId, paymentId: id);

      final snap = await fakeFirestore
          .collection('projects')
          .doc(projectId)
          .collection('payments')
          .doc(id)
          .get();
      expect(snap.exists, isFalse);
    });

    test('deleting one payment does not affect others', () async {
      final id1 = await service.addPayment(
        projectId: projectId,
        payment: _makePayment(amount: 100),
      );
      await service.addPayment(
        projectId: projectId,
        payment: _makePayment(amount: 200),
      );

      await service.deletePayment(projectId: projectId, paymentId: id1);

      final snap = await fakeFirestore
          .collection('projects')
          .doc(projectId)
          .collection('payments')
          .get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['amountGhs'], 200.0);
    });
  });

  group('paymentsStream', () {
    test('emits all payments for a project', () async {
      await service.addPayment(
        projectId: projectId,
        payment: _makePayment(amount: 500),
      );
      await service.addPayment(
        projectId: projectId,
        payment: _makePayment(amount: 750),
      );

      final payments = await service.paymentsStream(projectId).first;
      expect(payments.length, 2);
    });

    test('returns empty list when no payments', () async {
      final payments = await service.paymentsStream('no_payments').first;
      expect(payments, isEmpty);
    });
  });
}
