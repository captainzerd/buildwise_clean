// test/core/models/payment_record_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wysebrix/core/models/payment_record.dart';

void main() {
  group('PaymentRecord model', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    final basePayment = PaymentRecord(
      id: '',
      authorUid: 'uid1',
      direction: PaymentDirection.outbound,
      amountGhs: 5000.0,
      description: 'Foundation labour',
      method: PaymentMethod.mobileMoney,
      paymentDate: DateTime(2025, 3, 10),
      createdAt: DateTime(2025, 3, 11),
      reference: 'MOM-123',
      phaseId: 'phase1',
      phaseTitle: 'Substructure',
    );

    test('toMap contains required fields', () {
      final map = basePayment.toMap();
      expect(map['authorUid'], 'uid1');
      expect(map['direction'], 'outbound');
      expect(map['amountGhs'], 5000.0);
      expect(map['description'], 'Foundation labour');
      expect(map['method'], 'mobileMoney');
      expect(map['reference'], 'MOM-123');
      expect(map['phaseId'], 'phase1');
      expect(map['phaseTitle'], 'Substructure');
    });

    test('toMap omits null optional fields', () {
      final payment = PaymentRecord(
        id: '',
        authorUid: 'uid1',
        direction: PaymentDirection.inbound,
        amountGhs: 1000,
        description: 'Deposit',
        method: PaymentMethod.cash,
        paymentDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      final map = payment.toMap();
      expect(map.containsKey('reference'), isFalse);
      expect(map.containsKey('phaseId'), isFalse);
      expect(map.containsKey('phaseTitle'), isFalse);
    });

    test('round-trips through Firestore correctly', () async {
      final col =
          fakeFirestore.collection('projects').doc('p1').collection('payments');
      await col.add(basePayment.toMap());

      final snap = await col.get();
      final doc = snap.docs.first as DocumentSnapshot<Map<String, dynamic>>;
      final parsed = PaymentRecord.fromDoc(doc);

      expect(parsed.authorUid, 'uid1');
      expect(parsed.direction, PaymentDirection.outbound);
      expect(parsed.amountGhs, 5000.0);
      expect(parsed.description, 'Foundation labour');
      expect(parsed.method, PaymentMethod.mobileMoney);
      expect(parsed.reference, 'MOM-123');
      expect(parsed.phaseId, 'phase1');
      expect(parsed.phaseTitle, 'Substructure');
    });

    test('fromDoc defaults to outbound and cash on unknown enum values', () async {
      final col =
          fakeFirestore.collection('projects').doc('p2').collection('payments');
      await col.add({
        'authorUid': 'uid2',
        'direction': 'UNKNOWN',
        'amountGhs': 100,
        'description': 'Test',
        'method': 'UNKNOWN',
        'paymentDate': Timestamp.now(),
        'createdAt': Timestamp.now(),
      });
      final snap = await col.get();
      final doc = snap.docs.first as DocumentSnapshot<Map<String, dynamic>>;
      final parsed = PaymentRecord.fromDoc(doc);
      expect(parsed.direction, PaymentDirection.outbound);
      expect(parsed.method, PaymentMethod.cash);
    });

    test('PaymentDirection and PaymentMethod have non-empty labels', () {
      for (final d in PaymentDirection.values) {
        expect(d.label, isNotEmpty);
      }
      for (final m in PaymentMethod.values) {
        expect(m.label, isNotEmpty);
      }
    });
  });
}
