import '../entities/expense.dart';

abstract class ExpenseRepository {
  Future<void> add(Expense expense);
  Future<List<Expense>> listByProject(String projectId, {String? phaseId});
}
