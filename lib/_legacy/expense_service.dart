// lib/core/services/expense_service.dart
import 'storage/storage_service.dart';

/// Thin wrapper around StorageService for expenses. Uses `dynamic` to avoid
/// compile-time coupling to a specific Expense model while your domain settles.
class ExpenseService {
  ExpenseService(this.storage);
  final StorageService storage;

  Future<List<dynamic>> listExpensesFor(String projectId) async {
    // Expects StorageService.listExpensesFor(projectId) to exist.
    return storage.listExpensesFor(projectId);
  }

  Future<void> saveExpense(String projectId, dynamic expense) {
    // Expects StorageService.saveExpense(projectId, expense) to exist.
    return storage.saveExpense(projectId, expense);
  }

  Future<void> deleteExpense(String projectId, dynamic expense) {
    // Expects StorageService.deleteExpense(projectId, expense) to exist.
    return storage.deleteExpense(projectId, expense);
  }
}
