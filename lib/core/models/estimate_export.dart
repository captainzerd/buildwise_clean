// lib/core/models/estimate_export.dart
class PhaseLine {
  final String label;
  final String value; // already formatted for display
  const PhaseLine({required this.label, required this.value});
}

class EstimateExport {
  final String? projectName;
  final String? region;
  final String? city;
  final String? currencyPretty;
  final String? unitPretty;
  final String? totalPlanned;
  final List<PhaseLine>? phaseBreakdown;

  const EstimateExport({
    this.projectName,
    this.region,
    this.city,
    this.currencyPretty,
    this.unitPretty,
    this.totalPlanned,
    this.phaseBreakdown,
  });
}
