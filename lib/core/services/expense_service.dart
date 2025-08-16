// lib/core/services/expense_service.dart
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import 'storage_service.dart';

class ExpenseService {
  final StorageService storage;
  static const _uuid = Uuid();

  const ExpenseService({this.storage = const StorageService()});

  Future<List<Expense>> list(String estimateId) =>
      storage.listExpensesFor(estimateId);

  Future<void> add({
    required String estimateId,
    required String phase,
    required double amountGhs,
    String vendor = '',
    String note = '',
    DateTime? date,
  }) async {
    final e = Expense(
      id: _uuid.v4(),
      estimateId: estimateId,
      phase: phase,
      amount: amountGhs,
      vendor: vendor,
      note: note,
      date: date ?? DateTime.now(),
    );
    await storage.saveExpense(e);
  }

  Future<void> remove(String id) => storage.deleteExpense(id);

  Future<Map<String, double>> totalsByPhase(String estimateId) async {
    final items = await list(estimateId);
    final map = <String, double>{};
    for (final e in items) {
      map.update(e.phase, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
    return map;
  }
}
