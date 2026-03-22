# Escrow-Lite: Data Model & UI (PSP-Ready Foundation) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extend the `PaymentMilestone` model with disbursement-tracking fields and add a confirmation bottom sheet to the "Release" button so the UI is fully PSP-ready — money doesn't move yet, but the flow is complete.

**Architecture:** Two self-contained tasks: (1) pure Dart model change with tests, (2) new Flutter widget wired into the existing contract view. The "Confirm Release" button calls the existing `ContractService.releaseMilestonePayment()` and shows a snackbar explaining automated disbursement is coming. No backend changes needed.

**Tech Stack:** Dart, Flutter, `fake_cloud_firestore` for tests, `flutter_test`

---

### Task 1: Add disbursement fields to `PaymentMilestone`

**Files:**
- Modify: `lib/core/models/builder_contract.dart`
- Test: `test/core/models/builder_contract_test.dart` (create new)

**Context:** `PaymentMilestone` currently tracks approval status (pending → pendingRelease → released) but has no fields for the future payment-capture lifecycle. We need `disbursementStatus`, `paystackReference`, `capturedAt`, and `disbursedAt`. These fields will default to safe values so all existing Firestore data continues to deserialise correctly.

---

**Step 1: Write the failing test**

Create `test/core/models/builder_contract_test.dart`:

```dart
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
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/donaldduodu/wysebrix
flutter test test/core/models/builder_contract_test.dart
```

Expected: FAIL — `MilestoneDisbursementStatus` not defined.

**Step 3: Add the enum to `builder_contract.dart`**

After the closing `}` of `MilestoneApprovalStatus` extension (around line 107), add:

```dart
/// Tracks the lifecycle of the actual funds transfer once PSP is connected.
/// Until then all milestones default to [notStarted].
enum MilestoneDisbursementStatus { notStarted, pending, disbursed, failed }

extension MilestoneDisbursementStatusLabel on MilestoneDisbursementStatus {
  String get label => switch (this) {
        MilestoneDisbursementStatus.notStarted => 'Not Started',
        MilestoneDisbursementStatus.pending => 'Processing',
        MilestoneDisbursementStatus.disbursed => 'Disbursed',
        MilestoneDisbursementStatus.failed => 'Failed',
      };

  String get firestoreValue => switch (this) {
        MilestoneDisbursementStatus.notStarted => 'notStarted',
        MilestoneDisbursementStatus.pending => 'pending',
        MilestoneDisbursementStatus.disbursed => 'disbursed',
        MilestoneDisbursementStatus.failed => 'failed',
      };
}

MilestoneDisbursementStatus milestoneDisbursementStatusFromString(String? s) =>
    switch (s) {
      'pending' => MilestoneDisbursementStatus.pending,
      'disbursed' => MilestoneDisbursementStatus.disbursed,
      'failed' => MilestoneDisbursementStatus.failed,
      _ => MilestoneDisbursementStatus.notStarted,
    };
```

**Step 4: Add four new fields to `PaymentMilestone`**

Update the `PaymentMilestone` class constructor, fields, `toMap`, `fromMap`, and `copyWith`:

In the constructor, add after `this.releasedByName,`:
```dart
    this.disbursementStatus = MilestoneDisbursementStatus.notStarted,
    this.paystackReference,
    this.capturedAt,
    this.disbursedAt,
```

Add four fields after `final String? releasedByName;`:
```dart
  final MilestoneDisbursementStatus disbursementStatus;
  /// Paystack transaction reference — null until PSP is connected.
  final String? paystackReference;
  /// When the owner's payment was captured — null until PSP is connected.
  final DateTime? capturedAt;
  /// When funds were disbursed to the builder — null until PSP is connected.
  final DateTime? disbursedAt;
```

In `toMap()`, add after the `releasedByName` line:
```dart
        'disbursementStatus': disbursementStatus.firestoreValue,
        if (paystackReference != null) 'paystackReference': paystackReference,
        if (capturedAt != null) 'capturedAt': Timestamp.fromDate(capturedAt!),
        if (disbursedAt != null) 'disbursedAt': Timestamp.fromDate(disbursedAt!),
```

In `fromMap()` factory, add after `releasedByName: m['releasedByName'] as String?,`:
```dart
        disbursementStatus: milestoneDisbursementStatusFromString(
          m['disbursementStatus'] as String?,
        ),
        paystackReference: m['paystackReference'] as String?,
        capturedAt: (m['capturedAt'] as Timestamp?)?.toDate(),
        disbursedAt: (m['disbursedAt'] as Timestamp?)?.toDate(),
```

In `copyWith()` signature, add after `String? releasedByName,`:
```dart
    MilestoneDisbursementStatus? disbursementStatus,
    String? paystackReference,
    DateTime? capturedAt,
    DateTime? disbursedAt,
```

In `copyWith()` body, add after `releasedByName: releasedByName ?? this.releasedByName,`:
```dart
        disbursementStatus: disbursementStatus ?? this.disbursementStatus,
        paystackReference: paystackReference ?? this.paystackReference,
        capturedAt: capturedAt ?? this.capturedAt,
        disbursedAt: disbursedAt ?? this.disbursedAt,
```

**Step 5: Run tests to verify they pass**

```bash
flutter test test/core/models/builder_contract_test.dart
```

Expected: All 5 tests PASS.

**Step 6: Make sure no existing tests broke**

```bash
flutter test test/
```

Expected: All tests PASS.

**Step 7: Commit**

```bash
git add lib/core/models/builder_contract.dart test/core/models/builder_contract_test.dart
git commit -m "feat: add disbursement fields to PaymentMilestone for escrow-lite PSP readiness"
```

---

### Task 2: Milestone release confirmation bottom sheet

**Files:**
- Create: `lib/features/project/widgets/milestone_release_sheet.dart`
- Modify: `lib/features/project/contract_view_page.dart` (lines 667–677)

**Context:** Currently the "Release" button in `_MilestoneTrackerSection` directly calls `ContractService.releaseMilestonePayment()` with no confirmation. We want to replace that with a bottom sheet that shows the amount, the 2% platform fee, and the net-to-builder figure, with a "Confirm Release" button. Since PSP isn't connected yet, tapping "Confirm Release" calls the existing service method and shows a snackbar: "Payment recorded. Automated disbursement coming soon." This gives owners full visibility of the fee structure before it goes live.

---

**Step 1: Create `milestone_release_sheet.dart`**

Create `lib/features/project/widgets/milestone_release_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/builder_contract.dart';
import '../../../core/services/contract_service.dart';
import '../../../core/config/service_locator.dart';

/// Bottom sheet shown when a project owner taps "Release" on a milestone.
/// Displays fee breakdown and requires explicit confirmation before calling
/// [ContractService.releaseMilestonePayment].
class MilestoneReleaseSheet extends StatefulWidget {
  const MilestoneReleaseSheet({
    super.key,
    required this.contract,
    required this.milestone,
    required this.releasedByName,
  });

  final BuilderContract contract;
  final PaymentMilestone milestone;
  final String releasedByName;

  /// Opens the sheet. Returns [true] if the milestone was successfully released.
  static Future<bool?> show(
    BuildContext context, {
    required BuilderContract contract,
    required PaymentMilestone milestone,
    required String releasedByName,
  }) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => MilestoneReleaseSheet(
          contract: contract,
          milestone: milestone,
          releasedByName: releasedByName,
        ),
      );

  @override
  State<MilestoneReleaseSheet> createState() => _MilestoneReleaseSheetState();
}

class _MilestoneReleaseSheetState extends State<MilestoneReleaseSheet> {
  bool _loading = false;
  static const double _platformFeePct = 0.02; // 2 %

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await sl<ContractService>().releaseMilestonePayment(
        widget.contract.id,
        widget.milestone.id,
        widget.releasedByName,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment recorded. Automated disbursement will be available '
              'once our payment partner is connected.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to release: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00');
    final m = widget.milestone;
    final fee = m.amountGhs * _platformFeePct;
    final netToBuilder = m.amountGhs - fee;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Release Payment',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            m.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.outline,
                ),
          ),
          const SizedBox(height: 24),

          // Fee breakdown card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _Row('Milestone amount', 'GHS ${fmt.format(m.amountGhs)}'),
                const SizedBox(height: 8),
                _Row(
                  'Platform fee (2%)',
                  '− GHS ${fmt.format(fee)}',
                  valueColor: cs.error,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 0),
                ),
                _Row(
                  'To ${widget.contract.builderName}',
                  'GHS ${fmt.format(netToBuilder)}',
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // PSP notice chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: cs.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Automated disbursement coming soon. Funds will be '
                    'transferred once our payment partner is connected.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSecondaryContainer,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _confirm,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm Release'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false, this.valueColor});

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: bold ? FontWeight.w700 : null,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          value,
          style: style?.copyWith(color: valueColor),
        ),
      ],
    );
  }
}
```

**Step 2: Wire the "Release" button in `contract_view_page.dart`**

In `lib/features/project/contract_view_page.dart`, find this block (around lines 667–677):

```dart
                } else if (m.approvalStatus ==
                        MilestoneApprovalStatus.pendingRelease &&
                    isOwner) {
                  trailingWidget = FilledButton.tonal(
                    onPressed: () => sl<ContractService>().releaseMilestonePayment(
                      contract.id,
                      m.id,
                      currentUserName,
                    ),
                    child: const Text('Release'),
                  );
                }
```

Replace with:

```dart
                } else if (m.approvalStatus ==
                        MilestoneApprovalStatus.pendingRelease &&
                    isOwner) {
                  trailingWidget = FilledButton.tonal(
                    onPressed: () => MilestoneReleaseSheet.show(
                      context,
                      contract: contract,
                      milestone: m,
                      releasedByName: currentUserName,
                    ),
                    child: const Text('Release'),
                  );
                }
```

Add the import at the top of `contract_view_page.dart` with the other local imports:

```dart
import 'widgets/milestone_release_sheet.dart';
```

**Step 3: Run all tests**

```bash
flutter test test/
```

Expected: All tests PASS.

**Step 4: Run the app and verify the sheet appears**

```bash
flutter run
```

Manual test checklist:
1. Open a contract with a milestone in `pendingRelease` state (builder must have tapped "Request Release" first)
2. As the owner, tap **"Release"** — the bottom sheet should open
3. Verify the fee breakdown shows the correct 2% fee and net-to-builder figure
4. Verify the PSP notice chip is visible
5. Tap **"Cancel"** — sheet closes, no change in Firestore
6. Tap **"Release"** again, then **"Confirm Release"** — sheet closes, snackbar appears, milestone status updates to `released`

**Step 5: Commit**

```bash
git add lib/features/project/widgets/milestone_release_sheet.dart lib/features/project/contract_view_page.dart
git commit -m "feat: add milestone release confirmation sheet with fee breakdown (escrow-lite PSP-ready)"
```

---
