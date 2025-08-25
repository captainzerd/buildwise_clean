// lib/features/estimate/state/estimate_compat.dart

/// Area unit used by inputs. Height uses the same unit as area for UX.
enum AreaUnit { sqm, sqft }

extension AreaUnitX on AreaUnit {
  bool get isSqm => this == AreaUnit.sqm;
  String get label => isSqm ? 'sqm' : 'sqft';
}

/// Supported currencies for display/output.
enum AppCurrency { ghs, usd, eur, gbp }

extension AppCurrencyX on AppCurrency {
  String get code {
    switch (this) {
      case AppCurrency.usd:
        return 'USD';
      case AppCurrency.eur:
        return 'EUR';
      case AppCurrency.gbp:
        return 'GBP';
      case AppCurrency.ghs:
        return 'GHS';
    }
  }

  String get symbol {
    switch (this) {
      case AppCurrency.usd:
        return r'$';
      case AppCurrency.eur:
        return '€';
      case AppCurrency.gbp:
        return '£';
      case AppCurrency.ghs:
        return 'GH₵';
    }
  }

  String get label => '$code $symbol';
}

/// Lightweight view consumed by UI/PDF.
class EstimateView {
  final String projectName;
  final String region;
  final String city;
  final List<double> areasSqm;
  final List<double> floorHeightsM;
  final double baseCostGhs;
  final double extraSubstructureGhs;
  final double stairsCostGhs;
  final Map<String, double> phasePlanned; // includes extras lines
  final AppCurrency currency;
  final AreaUnit unit;

  const EstimateView({
    required this.projectName,
    required this.region,
    required this.city,
    required this.areasSqm,
    required this.floorHeightsM,
    required this.baseCostGhs,
    required this.extraSubstructureGhs,
    required this.stairsCostGhs,
    required this.phasePlanned,
    required this.currency,
    required this.unit,
  });

  double get totalAreaSqm =>
      areasSqm.fold<double>(0.0, (p, e) => p + (e.isFinite ? e : 0));

  double get totalPlannedGhs =>
      phasePlanned.values.fold<double>(0.0, (p, e) => p + e);

  factory EstimateView.fromJson(Map<String, dynamic> json) {
    AppCurrency cur = AppCurrency.ghs;
    final curStr = (json['currency'] as String?)?.toLowerCase() ?? 'ghs';
    if (curStr == 'usd') cur = AppCurrency.usd;
    if (curStr == 'eur') cur = AppCurrency.eur;
    if (curStr == 'gbp') cur = AppCurrency.gbp;

    AreaUnit ua = AreaUnit.sqm;
    final unitStr = (json['unit'] as String?)?.toLowerCase() ?? 'sqm';
    if (unitStr == 'sqft') ua = AreaUnit.sqft;

    return EstimateView(
      projectName: (json['projectName'] ?? '') as String,
      region: (json['region'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      areasSqm: ((json['areasSqm'] as List?) ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      floorHeightsM: ((json['floorHeightsM'] as List?) ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      baseCostGhs: (json['baseCostGhs'] as num?)?.toDouble() ?? 0,
      extraSubstructureGhs:
          (json['extraSubstructureGhs'] as num?)?.toDouble() ?? 0,
      stairsCostGhs: (json['stairsCostGhs'] as num?)?.toDouble() ?? 0,
      phasePlanned: Map<String, double>.from(
        (json['phasePlanned'] as Map?)
                ?.map((k, v) => MapEntry('$k', (v as num).toDouble())) ??
            <String, double>{},
      ),
      currency: cur,
      unit: ua,
    );
  }
}
