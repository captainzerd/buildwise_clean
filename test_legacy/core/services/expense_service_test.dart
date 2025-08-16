import 'package:flutter_test/flutter_test.dart';
import 'package:buildwise/core/services/expense_service.dart';
import 'package:buildwise/core/models/expense.dart';

void main() {
  late ExpenseService svc;
  const projectId = 'P1';

  setUp(() {
    svc = ExpenseService();
  });

  Expense mk({
    required String id,
    required String phaseId,
    required double amount,
    DateTime? date,
    String vendor = 'Vendor',
    String note = 'Note',
  }) {
    return Expense(
      id: id,
      projectId: projectId,
      phaseId: phaseId,
      amount: amount,
      date: date ?? DateTime(2024, 1, 1),
      vendor: vendor,
      note: note,
    );
  }

  test('add + list (all + by phase)', () {
    svc.add(mk(id: 'e1', phaseId: 'foundation', amount: 1000));
    svc.add(mk(id: 'e2', phaseId: 'roofing', amount: 500));
    svc.add(mk(id: 'e3', phaseId: 'foundation', amount: 250));

    final all = svc.list(projectId);
    expect(all.length, 3);

    final foundation = svc.list(projectId, phaseId: 'foundation');
    expect(foundation.map((e) => e.id), containsAll(['e1', 'e3']));
  });

  test('remove', () {
    svc.add(mk(id: 'e1', phaseId: 'foundation', amount: 100));
    svc.add(mk(id: 'e2', phaseId: 'roofing', amount: 200));

    svc.remove(projectId, 'e1');
    final all = svc.list(projectId);
    expect(all.length, 1);
    expect(all.single.id, 'e2');
  });

  test('totals by phase', () {
    svc.add(mk(id: 'a', phaseId: 'foundation', amount: 100));
    svc.add(mk(id: 'b', phaseId: 'foundation', amount: 40));
    svc.add(mk(id: 'c', phaseId: 'finishing', amount: 10));

    final fnd = svc
        .list(projectId, phaseId: 'foundation')
        .fold<double>(0, (a, e) => a + e.amount);
    expect(fnd, 140);

    final all = svc.list(projectId).fold<double>(0, (a, e) => a + e.amount);
    expect(all, 150);
  });
}
