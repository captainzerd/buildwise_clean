import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/models/builder_contract.dart';

void main() {
  group('MilestoneDisbursementStatus', () {
    test('firestoreValue round-trips for all values', () {
      expect(
        milestoneDisbursementStatusFromString('notStarted'),
        MilestoneDisbursementStatus.notStarted,
      );
      expect(
        milestoneDisbursementStatusFromString('pending'),
        MilestoneDisbursementStatus.pending,
      );
      expect(
        milestoneDisbursementStatusFromString('disbursed'),
        MilestoneDisbursementStatus.disbursed,
      );
      expect(
        milestoneDisbursementStatusFromString('failed'),
        MilestoneDisbursementStatus.failed,
      );
    });

    test('unknown string defaults to notStarted', () {
      expect(
        milestoneDisbursementStatusFromString(null),
        MilestoneDisbursementStatus.notStarted,
      );
      expect(
        milestoneDisbursementStatusFromString('GARBAGE'),
        MilestoneDisbursementStatus.notStarted,
      );
    });
  });

  group('PaymentMilestone disbursement fields', () {
    test('toMap omits null disbursement fields', () {
      final m = PaymentMilestone(
        id: 'm1',
        description: 'Foundation',
        amountGhs: 5000,
      );
      final map = m.toMap();
      expect(map['disbursementStatus'], 'notStarted');
      expect(map.containsKey('paystackReference'), isFalse);
      expect(map.containsKey('capturedAt'), isFalse);
      expect(map.containsKey('disbursedAt'), isFalse);
    });

    test('toMap includes disbursement fields when set', () {
      final now = DateTime(2026, 3, 13);
      final m = PaymentMilestone(
        id: 'm1',
        description: 'Foundation',
        amountGhs: 5000,
        disbursementStatus: MilestoneDisbursementStatus.disbursed,
        paystackReference: 'PSK-REF-001',
        capturedAt: now,
        disbursedAt: now,
      );
      final map = m.toMap();
      expect(map['disbursementStatus'], 'disbursed');
      expect(map['paystackReference'], 'PSK-REF-001');
      expect(map['capturedAt'], isA<Timestamp>());
      expect(map['disbursedAt'], isA<Timestamp>());
    });

    test('fromMap defaults disbursementStatus to notStarted for legacy docs', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final col = fakeFirestore.collection('contracts').doc('c1').collection('x');
      // Legacy document with no disbursementStatus field
      await col.add({
        'id': 'm1',
        'description': 'Foundation',
        'amountGhs': 5000.0,
        'isPaid': false,
        'approvalStatus': 'pending',
      });
      final snap = await col.get();
      final raw = snap.docs.first.data();
      final parsed = PaymentMilestone.fromMap(raw);
      expect(parsed.disbursementStatus, MilestoneDisbursementStatus.notStarted);
      expect(parsed.paystackReference, isNull);
      expect(parsed.capturedAt, isNull);
      expect(parsed.disbursedAt, isNull);
    });

    test('copyWith preserves disbursement fields', () {
      final original = PaymentMilestone(
        id: 'm1',
        description: 'Foundation',
        amountGhs: 5000,
        paystackReference: 'PSK-001',
      );
      final updated = original.copyWith(
        disbursementStatus: MilestoneDisbursementStatus.pending,
      );
      expect(updated.disbursementStatus, MilestoneDisbursementStatus.pending);
      expect(updated.paystackReference, 'PSK-001'); // preserved
      expect(updated.id, 'm1'); // preserved
    });
  });
}
