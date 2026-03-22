/// A phase date range as used by the domain validator.
class PhaseDateRange {
  final String phaseId;
  final String phaseName;
  final DateTime? startDate;
  final DateTime? endDate;

  const PhaseDateRange({
    required this.phaseId,
    required this.phaseName,
    this.startDate,
    this.endDate,
  });
}

/// Pure use case: validates phase date ranges and returns human-readable errors.
///
/// Checks performed:
///  1. `endDate` must not be before `startDate` for the same phase.
///  2. Phases must not have overlapping date ranges (start–end).
class ValidatePhaseDates {
  const ValidatePhaseDates();

  List<String> call(List<PhaseDateRange> phases) {
    final errors = <String>[];

    for (final phase in phases) {
      final start = phase.startDate;
      final end = phase.endDate;
      if (start != null && end != null && end.isBefore(start)) {
        errors.add(
          '"${phase.phaseName}" end date is before start date.',
        );
      }
    }

    // Check pairwise overlaps
    for (int i = 0; i < phases.length; i++) {
      for (int j = i + 1; j < phases.length; j++) {
        final a = phases[i];
        final b = phases[j];
        if (_overlaps(a, b)) {
          errors.add(
            '"${a.phaseName}" and "${b.phaseName}" have overlapping dates.',
          );
        }
      }
    }

    return errors;
  }

  bool _overlaps(PhaseDateRange a, PhaseDateRange b) {
    final aStart = a.startDate;
    final aEnd = a.endDate;
    final bStart = b.startDate;
    final bEnd = b.endDate;
    if (aStart == null || aEnd == null || bStart == null || bEnd == null) {
      return false;
    }
    // Two ranges overlap if neither ends before the other starts.
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }
}
