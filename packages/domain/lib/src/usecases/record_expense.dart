// lib/src/usecases/record_expense.dart

class RecordExpenseInput {
  final String projectId;
  final double amount;
  final String category;
  final DateTime when;

  // NOTE: non-const because we use DateTime.now()
  RecordExpenseInput({
    required this.projectId,
    required this.amount,
    required this.category,
    DateTime? when,
  }) : when = when ?? DateTime.now();
}

/// Domain-level use case stub. Data-layer will implement persistence.
class RecordExpense {
  Future<void> call(RecordExpenseInput input) async {
    // TODO: Inject and call a repository in the data layer.
  }
}
