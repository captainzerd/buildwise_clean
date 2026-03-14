/// A payment milestone as used by the domain layer.
class PaymentMilestone {
  final String id;
  final String description;
  final double amountGhs;
  final DateTime dueDate;
  final bool isPaid;

  const PaymentMilestone({
    required this.id,
    required this.description,
    required this.amountGhs,
    required this.dueDate,
    required this.isPaid,
  });
}

/// Pure use case: filters a list of payment milestones to those that are
/// overdue (unpaid and past their due date) relative to [asOf].
///
/// [asOf] defaults to `DateTime.now()` when not provided.
class GetOverdueMilestones {
  const GetOverdueMilestones();

  List<PaymentMilestone> call(
    List<PaymentMilestone> milestones, {
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    return milestones
        .where((m) => !m.isPaid && m.dueDate.isBefore(now))
        .toList();
  }
}
