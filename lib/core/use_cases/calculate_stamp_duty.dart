/// GRA 2024 stamp duty schedule for Ghana property transactions.
class StampDutyResult {
  const StampDutyResult({
    required this.stampDuty,
    required this.transferTax,
    required this.cgtPlaceholder,
    required this.propertyValueGhs,
    required this.isCommercial,
  });

  final double propertyValueGhs;
  final bool isCommercial;
  final double stampDuty; // 3% residential / 5% commercial
  final double transferTax; // 0.5%
  final double cgtPlaceholder; // 15% (requires cost basis — placeholder only)

  double get total => stampDuty + transferTax;
}

/// Pure use-case: compute GRA 2024 stamp duty for a Ghana property transaction.
class CalculateStampDuty {
  const CalculateStampDuty();

  StampDutyResult call({
    required double propertyValueGhs,
    required bool isCommercial,
  }) {
    final stampRate = isCommercial ? 0.05 : 0.03;
    return StampDutyResult(
      propertyValueGhs: propertyValueGhs,
      isCommercial: isCommercial,
      stampDuty: propertyValueGhs * stampRate,
      transferTax: propertyValueGhs * 0.005,
      cgtPlaceholder: propertyValueGhs * 0.15,
    );
  }
}
