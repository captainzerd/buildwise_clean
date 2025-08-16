import 'package:buildwise_domain/buildwise_domain.dart';

class ExpenseRepositoryMemory implements ExpenseRepository {
  final _byProject = <String, List<Expense>>{};

  @override
  Future<void> add(Expense expense) async {
    final list = _byProject.putIfAbsent(expense.projectId, () => <Expense>[]);
    list.add(expense);
  }

  @override
  Future<List<Expense>> listByProject(
    String projectId, {
    String? phaseId,
  }) async {
    final all = _byProject[projectId] ?? const [];
    if (phaseId == null) return List.unmodifiable(all);
    return List.unmodifiable(all.where((e) => e.phaseId == phaseId));
  }
}
