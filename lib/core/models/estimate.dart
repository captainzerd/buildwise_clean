import 'dart:convert';

/// Area input unit for floor areas.
enum AreaUnit { sqm, sqft }

/// Immutable estimate snapshot used across UI/services/PDF/storage.
class Estimate {
  final String projectId;
  final String projectName;
  final String region;
  final String city;

  /// Normalized inputs
  final List<double> areasSqm; // floor areas in m²
  final List<double> floorHeightsM; // floor heights (m)

  /// Computed totals
  final double totalAreaSqm;

  /// Costs in base currency (GHS internally)
  final double baseCostGhs;
  final double extraSubstructureGhs;
  final double stairsCostGhs;
  final double totalPlannedGhs;

  /// Phase breakdown (phase -> amount in GHS)
  final Map<String, double> phaseBreakdown;

  /// Currency meta (for display/export)
  final String currencyCode; // e.g. GHS, USD, EUR, GBP
  final String currencySymbol; // ₵, $, €, £

  const Estimate({
    required this.projectId,
    required this.projectName,
    required this.region,
    required this.city,
    required this.areasSqm,
    required this.floorHeightsM,
    required this.totalAreaSqm,
    required this.baseCostGhs,
    required this.extraSubstructureGhs,
    required this.stairsCostGhs,
    required this.totalPlannedGhs,
    required this.phaseBreakdown,
    required this.currencyCode,
    required this.currencySymbol,
  });

  /// Backward-compat helpers used by existing widgets
  double get squareFootage => totalAreaSqm / 0.09290304;
  Map<String, double> get phasePlanned => phaseBreakdown;

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'projectName': projectName,
        'region': region,
        'city': city,
        'areasSqm': areasSqm,
        'floorHeightsM': floorHeightsM,
        'totalAreaSqm': totalAreaSqm,
        'baseCostGhs': baseCostGhs,
        'extraSubstructureGhs': extraSubstructureGhs,
        'stairsCostGhs': stairsCostGhs,
        'totalPlannedGhs': totalPlannedGhs,
        'phaseBreakdown': phaseBreakdown,
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
      };

  static Estimate fromJson(Map<String, dynamic> json) {
    List<double> _asDoubles(dynamic v) =>
        (v as List<dynamic>).map((e) => (e as num).toDouble()).toList();

    Map<String, double> _asDoubleMap(dynamic v) =>
        (v as Map<String, dynamic>).map(
          (k, val) => MapEntry(k.toString(), (val as num).toDouble()),
        );

    return Estimate(
      projectId: (json['projectId'] ?? '').toString(),
      projectName: (json['projectName'] ?? '').toString(),
      region: (json['region'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      areasSqm: _asDoubles(json['areasSqm'] ?? const <double>[]),
      floorHeightsM: _asDoubles(json['floorHeightsM'] ?? const <double>[]),
      totalAreaSqm: (json['totalAreaSqm'] as num? ?? 0).toDouble(),
      baseCostGhs: (json['baseCostGhs'] as num? ?? 0).toDouble(),
      extraSubstructureGhs:
          (json['extraSubstructureGhs'] as num? ?? 0).toDouble(),
      stairsCostGhs: (json['stairsCostGhs'] as num? ?? 0).toDouble(),
      totalPlannedGhs: (json['totalPlannedGhs'] as num? ?? 0).toDouble(),
      phaseBreakdown:
          _asDoubleMap(json['phaseBreakdown'] ?? const <String, double>{}),
      currencyCode: (json['currencyCode'] ?? 'GHS').toString(),
      currencySymbol: (json['currencySymbol'] ?? '₵').toString(),
    );
  }

  String toJsonString() => jsonEncode(toJson());
  static Estimate fromJsonString(String s) =>
      fromJson(jsonDecode(s) as Map<String, dynamic>);

  Estimate copyWith({
    String? projectId,
    String? projectName,
    String? region,
    String? city,
    List<double>? areasSqm,
    List<double>? floorHeightsM,
    double? totalAreaSqm,
    double? baseCostGhs,
    double? extraSubstructureGhs,
    double? stairsCostGhs,
    double? totalPlannedGhs,
    Map<String, double>? phaseBreakdown,
    String? currencyCode,
    String? currencySymbol,
  }) {
    return Estimate(
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      region: region ?? this.region,
      city: city ?? this.city,
      areasSqm: areasSqm ?? this.areasSqm,
      floorHeightsM: floorHeightsM ?? this.floorHeightsM,
      totalAreaSqm: totalAreaSqm ?? this.totalAreaSqm,
      baseCostGhs: baseCostGhs ?? this.baseCostGhs,
      extraSubstructureGhs: extraSubstructureGhs ?? this.extraSubstructureGhs,
      stairsCostGhs: stairsCostGhs ?? this.stairsCostGhs,
      totalPlannedGhs: totalPlannedGhs ?? this.totalPlannedGhs,
      phaseBreakdown: phaseBreakdown ?? this.phaseBreakdown,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
    );
  }
}
