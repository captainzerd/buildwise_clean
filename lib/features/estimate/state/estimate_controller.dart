import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/currency.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/services/fx_service.dart';
import '../../../core/services/regional_index_provider.dart';
import '../../../core/storage/storage_service.dart';

export '../../../core/models/currency.dart' show CurrencyInfo;

enum PermitMode { percent, manual }

@immutable
class FloorSpec {
  const FloorSpec({required this.areaM2, required this.heightM});
  final double areaM2;
  final double heightM;

  FloorSpec copyWith({double? areaM2, double? heightM}) => FloorSpec(
        areaM2: areaM2 ?? this.areaM2,
        heightM: heightM ?? this.heightM,
      );
}

@immutable
class TaxLine {
  const TaxLine({required this.name, required this.pct});
  final String name;
  final double pct;
}

@immutable
class EstimateResult {
  const EstimateResult({
    required this.totalBuiltUpArea,
    required this.phaseBreakdownGhs,
    required this.addOnsGhs,
    required this.preliminariesGhs,
    required this.ohpGhs,
    required this.contingencyGhs,
    required this.taxLinesGhs,
    required this.permitGhs,
    required this.totalPlannedGhs,
  });

  final double totalBuiltUpArea;
  final Map<String, double> phaseBreakdownGhs;
  final Map<String, double> addOnsGhs;
  final double preliminariesGhs;
  final double ohpGhs;
  final double contingencyGhs;
  final Map<String, double> taxLinesGhs;
  final double permitGhs;
  final double totalPlannedGhs;
}

class EstimateController extends ChangeNotifier {
  EstimateController({
    required this.catalogService,
    required this.regionalIndexProvider,
    required this.fxService,
    required this.storageService,
  });

  final CatalogService catalogService;
  final RegionalIndexProvider regionalIndexProvider;
  final FxService fxService;
  final StorageService storageService;

  // ── Form state ──
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController projectNameCtrl = TextEditingController();

  String? region;
  CurrencyInfo currency = CurrencyInfo.ghs;

  String buildingType = 'Residential';
  String quality = 'Standard';
  String foundation = 'Strip';
  String soil = 'Firm';
  String roof = 'Pitched sheet';
  int storeys = 1;

  final List<FloorSpec> floors = <FloorSpec>[
    const FloorSpec(areaM2: 120, heightM: 3.0),
  ];

  bool includeExternalWorks = false;
  double externalWallLenM = 0;
  double drivewayAreaM2 = 0;
  bool includeSeptic = false;

  double preliminariesPct = 0;
  bool contingencyEnabled = false;
  double contingencyPct = 10.0;

  PermitMode permitMode = PermitMode.percent;
  double permitPct = 0;
  double? permitManualGhs;

  List<TaxLine> taxLines = const [];

  double? budgetAmount;

  // ── Async state ──
  bool _isComputing = false;
  String? _computeError;

  bool get isComputing => _isComputing;
  String? get computeError => _computeError;

  // ── Derived ──
  List<String> get regions => regionalIndexProvider.regionCodes;

  /// True when the minimum required inputs are present for a valid computation.
  bool get isFormValid {
    if (floors.isEmpty) return false;
    for (final f in floors) {
      if (f.areaM2 <= 0 || f.areaM2 > 50000) return false;
      if (f.heightM <= 0 || f.heightM > 12.0) return false;
    }
    return true;
  }

  /// Human-readable reason why the form is invalid, or null if valid.
  String? get validationError {
    if (floors.isEmpty) return 'Add at least one floor.';
    for (int i = 0; i < floors.length; i++) {
      final f = floors[i];
      if (f.areaM2 <= 0) {
        return 'Floor ${i + 1}: area must be greater than 0 m².';
      }
      if (f.areaM2 > 50000) {
        return 'Floor ${i + 1}: area seems too large (max 50,000 m²).';
      }
      if (f.heightM <= 0) {
        return 'Floor ${i + 1}: height must be greater than 0.';
      }
      if (f.heightM > 12.0) {
        return 'Floor ${i + 1}: height seems too large (max 12 m).';
      }
    }
    return null;
  }

  // ── Result ──
  EstimateResult? _result;
  bool get hasResult => _result != null;
  EstimateResult? get result => _result;

  // Compatibility getters consumed by existing widgets.
  double get grandTotalGhs => _result?.totalPlannedGhs ?? 0;
  Map<String, double> get phaseBreakdown =>
      _result?.phaseBreakdownGhs ?? const {};
  Map<String, double> get addOnsGhs => _result?.addOnsGhs ?? const {};
  double get ohpGhs => _result?.ohpGhs ?? 0;
  double get contingencyGhs => _result?.contingencyGhs ?? 0;
  double get taxesGhs =>
      _result?.taxLinesGhs.values.fold<double>(0, (a, b) => a + b) ?? 0;

  static const _prefKeyCurrency = 'estimate_currency_code';

  // ── Lifecycle ──
  Future<void> init() async {
    await catalogService.ensureLoaded();
    preliminariesPct = catalogService.preliminariesDefaultPct;
    permitPct = catalogService.permitDefaultPct;
    taxLines = [
      for (final t in catalogService.taxLinesDefault)
        TaxLine(name: t.name, pct: t.pct),
    ];

    // Restore last-used currency from SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKeyCurrency);
    if (saved != null) {
      final match = CurrencyInfo.values.where((c) => c.code == saved).firstOrNull;
      if (match != null) currency = match;
    }

    notifyListeners();
  }

  // ── Mutations ──
  void setRegion(String? r) {
    region = r;
    notifyListeners();
  }

  void setCurrency(CurrencyInfo c) {
    currency = c;
    notifyListeners();
    // Persist for next session.
    SharedPreferences.getInstance()
        .then((p) => p.setString(_prefKeyCurrency, c.code));
  }

  void setProgramme({
    String? buildingType_,
    String? quality_,
    String? foundation_,
    String? soil_,
    String? roof_,
    int? storeys_,
  }) {
    buildingType = buildingType_ ?? buildingType;
    quality = quality_ ?? quality;
    foundation = foundation_ ?? foundation;
    soil = soil_ ?? soil;
    roof = roof_ ?? roof;
    storeys = storeys_ ?? storeys;
    notifyListeners();
  }

  void addFloor() {
    floors.add(const FloorSpec(areaM2: 100, heightM: 3.0));
    notifyListeners();
  }

  void updateFloor(int i, {double? areaM2, double? heightM}) {
    floors[i] = floors[i].copyWith(areaM2: areaM2, heightM: heightM);
    notifyListeners();
  }

  void removeFloor(int i) {
    if (floors.length <= 1) return;
    floors.removeAt(i);
    notifyListeners();
  }

  void setExternalWorks({
    bool? enabled,
    double? wallLenM,
    double? driveM2,
    bool? septic,
  }) {
    includeExternalWorks = enabled ?? includeExternalWorks;
    externalWallLenM = wallLenM ?? externalWallLenM;
    drivewayAreaM2 = driveM2 ?? drivewayAreaM2;
    includeSeptic = septic ?? includeSeptic;
    notifyListeners();
  }

  void setPreliminariesPct(double v) {
    preliminariesPct = v;
    notifyListeners();
  }

  void setContingencyEnabled(bool v) {
    contingencyEnabled = v;
    notifyListeners();
  }

  void setContingencyPct(double v) {
    contingencyPct = v;
    notifyListeners();
  }

  void setPermitMode(PermitMode m) {
    permitMode = m;
    notifyListeners();
  }

  void setPermitPct(double v) {
    permitPct = v;
    notifyListeners();
  }

  void setPermitManual(double? ghs) {
    permitManualGhs = ghs;
    notifyListeners();
  }

  void setBudgetAmount(double? ghs) {
    budgetAmount = ghs;
    notifyListeners();
  }

  // ── Compute ──
  Future<void> compute() async {
    _computeError = null;

    if (!isFormValid) {
      _computeError = validationError ?? 'Please check your inputs.';
      notifyListeners();
      return;
    }

    _isComputing = true;
    notifyListeners();

    try {
      final totalArea = floors.fold<double>(0, (p, f) => p + f.areaM2);

      // Rates come from CatalogService (Firestore or built-in fallback).
      final rate = catalogService.unitRatesGhsPerM2[quality] ??
          catalogService.unitRatesGhsPerM2['Standard'] ??
          4500.0;

      final idx = regionalIndexProvider.indexFor(region);
      final baseGhs = totalArea * rate * idx;

      final Map<String, double> phaseGhs = {};
      catalogService.phasePercents.forEach((name, pct) {
        phaseGhs[name] = baseGhs * pct;
      });

      // Add-ons — rates from catalog, not hardcoded.
      final Map<String, double> addOns = {};
      double addOnsTotal = 0;
      if (includeExternalWorks) {
        if (externalWallLenM > 0) {
          final wall =
              externalWallLenM * catalogService.compoundWallRatePerM;
          addOns['Compound wall'] = wall;
          addOnsTotal += wall;
        }
        if (drivewayAreaM2 > 0) {
          final drive = drivewayAreaM2 * catalogService.drivewayRatePerM2;
          addOns['Driveway'] = drive;
          addOnsTotal += drive;
        }
        if (includeSeptic) {
          final septic = catalogService.septicLumpSum;
          addOns['Septic/Soakaway'] = septic;
          addOnsTotal += septic;
        }
      }

      final prelimGhs = baseGhs * (preliminariesPct / 100.0);
      final ohp =
          (baseGhs + prelimGhs) * (catalogService.ohpDefaultPct / 100.0);
      final contingency = contingencyEnabled
          ? (baseGhs + prelimGhs + ohp + addOnsTotal) *
              (contingencyPct / 100.0)
          : 0.0;

      final netBeforeTax =
          baseGhs + prelimGhs + ohp + addOnsTotal + contingency;

      final Map<String, double> taxLinesGhs = {};
      double taxesTotal = 0;
      for (final t in taxLines) {
        final line = netBeforeTax * (t.pct / 100.0);
        taxLinesGhs[t.name] = line;
        taxesTotal += line;
      }

      final permit = permitMode == PermitMode.percent
          ? (baseGhs + addOnsTotal) * (permitPct / 100.0)
          : (permitManualGhs ?? 0.0);

      final totalPlanned = netBeforeTax + taxesTotal + permit;

      _result = EstimateResult(
        totalBuiltUpArea: totalArea,
        phaseBreakdownGhs: phaseGhs,
        addOnsGhs: addOns,
        preliminariesGhs: prelimGhs,
        ohpGhs: ohp,
        contingencyGhs: contingency,
        taxLinesGhs: taxLinesGhs,
        permitGhs: permit,
        totalPlannedGhs: totalPlanned,
      );
    } catch (e) {
      _computeError = AppException.from(e).message;
      debugPrint('EstimateController.compute error: $e');
    } finally {
      _isComputing = false;
      notifyListeners();
    }
  }

  // ── Display helpers ──

  /// Format [ghs] in the currently selected currency.
  String money(double ghs) {
    final sym = currency.symbol;
    if (currency.code == 'GHS') {
      return '$sym${_fmt(ghs)}';
    }
    final converted = fxService.convertFromGhs(
      amountGhs: ghs,
      to: currency.code,
    );
    return '$sym${_fmt(converted)}';
  }

  String _fmt(double v) =>
      v >= 1000 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// Serialises current inputs + result to a plain map for cloud/local storage.
  /// [userId] must be provided by the caller before persisting.
  /// Caller should also add `createdAt: FieldValue.serverTimestamp()`.
  Map<String, dynamic> toMap() {
    assert(_result != null, 'Call compute() before toMap().');
    final r = _result!;
    final fxRate = currency.code == 'GHS'
        ? 1.0
        : fxService.rateFor(currency.code);
    return {
      'projectName': projectNameCtrl.text.trim(),
      'region': region ?? '',
      'buildingType': buildingType,
      'quality': quality,
      'foundation': foundation,
      'soil': soil,
      'roof': roof,
      'floors': [
        for (final f in floors) {'areaM2': f.areaM2, 'heightM': f.heightM},
      ],
      'includeExternalWorks': includeExternalWorks,
      'externalWallLenM': externalWallLenM,
      'drivewayAreaM2': drivewayAreaM2,
      'includeSeptic': includeSeptic,
      if (budgetAmount != null) 'budgetAmount': budgetAmount,
      'grandTotalGhs': r.totalPlannedGhs,
      'grandTotalFx': r.totalPlannedGhs * fxRate,
      'fxCode': currency.code,
      'fxSymbol': currency.symbol,
      'phaseBreakdownGhs': r.phaseBreakdownGhs,
      'addOnsGhs': r.addOnsGhs,
      'preliminariesGhs': r.preliminariesGhs,
      'ohpGhs': r.ohpGhs,
      'contingencyGhs': r.contingencyGhs,
      'taxLinesGhs': r.taxLinesGhs,
      'permitGhs': r.permitGhs,
      'totalBuiltUpArea': r.totalBuiltUpArea,
    };
  }

  @override
  void dispose() {
    projectNameCtrl.dispose();
    super.dispose();
  }
}
