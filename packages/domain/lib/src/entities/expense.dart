class Expense {
  final String id;
  final String projectId;
  final String phaseId;
  final double amount;
  final DateTime date;
  final String note;
  final String vendor;

  const Expense({
    required this.id,
    required this.projectId,
    required this.phaseId,
    required this.amount,
    required this.date,
    required this.note,
    required this.vendor,
  });
}
