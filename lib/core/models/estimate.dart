// lib/core/models/estimate.dart
//
// Canonical project estimate model used across storage, Firestore, PDF,
// and UI. Includes serialization helpers and convenience getters.

class Estimate {
  final String projectId;
  final String projectName;
  final String region;
  final String city;

  /// Total building area in square feet (sum of all floors; imperial for UI).
  final double squareFootage;

  /// Planned costs split by phase (e.g., {"substructure": 12345.0, ...})
  final Map<String, double> phasePlanned;

  /// Optional bag for extra diagnostics (baseRatePerSqm, baseCost, etc.).
  final Map<String, dynamic>? meta;

  /// When this estimate was created.
  final DateTime createdAt;

  const Estimate({
    required this.projectId,
    required this.projectName,
    required this.region,
    required this.city,
    required this.squareFootage,
    required this.phasePlanned,
    this.meta,
    required this.createdAt,
  });

  /// Sum of all planned phases.
  double get totalPlanned =>
      phasePlanned.values.fold<double>(0.0, (s, v) => s + v);

  Estimate copyWith({
    String? projectId,
    String? projectName,
    String? region,
    String? city,
    double? squareFootage,
    Map<String, double>? phasePlanned,
    Map<String, dynamic>? meta,
    DateTime? createdAt,
  }) {
    return Estimate(
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      region: region ?? this.region,
      city: city ?? this.city,
      squareFootage: squareFootage ?? this.squareFootage,
      phasePlanned: phasePlanned ?? this.phasePlanned,
      meta: meta ?? this.meta,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // -------------------- Serialization --------------------

  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'projectName': projectName,
      'region': region,
      'city': city,
      'squareFootage': squareFootage,
      'phasePlanned': phasePlanned,
      'meta': meta,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static Estimate fromJson(Map<String, dynamic> json) {
    final ppRaw = (json['phasePlanned'] as Map?) ?? const {};
    final pp = <String, double>{};
    for (final e in ppRaw.entries) {
      final k = e.key.toString();
      final v = (e.value is num) ? (e.value as num).toDouble() : 0.0;
      pp[k] = v;
    }

    // meta is free-form; keep as-is.
    final meta = json['meta'] as Map<String, dynamic>?;

    return Estimate(
      projectId: json['projectId'] as String,
      projectName: (json['projectName'] ?? '') as String,
      region: json['region'] as String,
      city: json['city'] as String,
      squareFootage: (json['squareFootage'] as num).toDouble(),
      phasePlanned: pp,
      meta: meta,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch((json['createdAtMs'] as int?) ??
              DateTime.now().millisecondsSinceEpoch),
    );
  }
}
