import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/currency.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/services/fx_service.dart';
import '../../../core/services/regional_index_provider.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/use_cases/calculate_estimate.dart';

export '../../../core/models/currency.dart' show CurrencyInfo;
export '../../../core/use_cases/calculate_estimate.dart'
    show BuildingTypology, EstimateResult, FloorSpec, PermitMode, TaxLine;

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

  BuildingTypology typology = BuildingTypology.residentialStandard;
  bool enhancedServices = false;
  bool curtainWall = false;
  bool includeWaterTank = false;
  bool includeGeneratorHouse = false;
  bool includeSwimmingPool = false;
  double swimmingPoolGhs = 62500;
  double securityWallLenM = 0;
  static const double _securityWallRatePerM = 1400.0;
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

  bool professionalFeesEnabled = false;
  double professionalFeesPct = 4.0;

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
  double get professionalFeesGhs => _result?.professionalFeesGhs ?? 0;

  static const _prefKeyCurrency = 'estimate_currency_code';
  static const _prefKeyDraft = 'estimate_draft_v1';

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

    await restoreFormState();

    // Auto-select currency based on device locale (only when user hasn't
    // already persisted a non-GHS preference).
    if (currency == CurrencyInfo.ghs) {
      final locale = PlatformDispatcher.instance.locale;
      final country = locale.countryCode?.toUpperCase() ?? '';
      final detected = switch (country) {
        'GB' => CurrencyInfo.gbp,
        'US' => CurrencyInfo.usd,
        'CA' => CurrencyInfo.cad,
        'AU' => CurrencyInfo.aud,
        'NG' => CurrencyInfo.ngn,
        'DE' ||
        'FR' ||
        'NL' ||
        'BE' ||
        'AT' ||
        'IE' ||
        'PT' ||
        'ES' ||
        'IT' ||
        'FI' ||
        'LU' ||
        'GR' ||
        'SK' ||
        'SI' ||
        'EE' ||
        'LV' ||
        'LT' ||
        'CY' ||
        'MT' =>
          CurrencyInfo.eur,
        _ => CurrencyInfo.ghs, // GH and all others default to GHS
      };
      if (detected != CurrencyInfo.ghs) {
        setCurrency(detected);
      }
    }

    notifyListeners();
  }

  /// Persists current form inputs to SharedPreferences (draft auto-save).
  Future<void> saveFormState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'projectName': projectNameCtrl.text,
        'region': region,
        'typology': typology.name,
        'quality': quality,
        'foundation': foundation,
        'soil': soil,
        'roof': roof,
        'storeys': storeys,
        'floors': [
          for (final f in floors)
            {'areaM2': f.areaM2, 'heightM': f.heightM},
        ],
        'enhancedServices': enhancedServices,
        'curtainWall': curtainWall,
        'includeWaterTank': includeWaterTank,
        'includeGeneratorHouse': includeGeneratorHouse,
        'includeSwimmingPool': includeSwimmingPool,
        'swimmingPoolGhs': swimmingPoolGhs,
        'securityWallLenM': securityWallLenM,
        'includeExternalWorks': includeExternalWorks,
        'externalWallLenM': externalWallLenM,
        'drivewayAreaM2': drivewayAreaM2,
        'includeSeptic': includeSeptic,
        'preliminariesPct': preliminariesPct,
        'contingencyEnabled': contingencyEnabled,
        'contingencyPct': contingencyPct,
        'permitMode': permitMode.name,
        'permitPct': permitPct,
        'permitManualGhs': permitManualGhs,
        'budgetAmount': budgetAmount,
        'professionalFeesEnabled': professionalFeesEnabled,
        'professionalFeesPct': professionalFeesPct,
      };
      await prefs.setString(_prefKeyDraft, jsonEncode(map));
    } catch (e) {
      debugPrint('EstimateController.saveFormState error: $e');
    }
  }

  /// Restores form inputs from SharedPreferences draft.
  Future<void> restoreFormState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKeyDraft);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      projectNameCtrl.text = map['projectName'] as String? ?? '';
      region = map['region'] as String?;
      typology = BuildingTypology.fromString(map['typology'] as String?);
      quality = map['quality'] as String? ?? quality;
      foundation = map['foundation'] as String? ?? foundation;
      soil = map['soil'] as String? ?? soil;
      roof = map['roof'] as String? ?? roof;
      storeys = (map['storeys'] as num?)?.toInt() ?? storeys;
      final rawFloors = map['floors'] as List?;
      if (rawFloors != null && rawFloors.isNotEmpty) {
        floors
          ..clear()
          ..addAll(
            rawFloors.cast<Map<String, dynamic>>().map(
                  (f) => FloorSpec(
                    areaM2: (f['areaM2'] as num?)?.toDouble() ?? 100,
                    heightM: (f['heightM'] as num?)?.toDouble() ?? 3.0,
                  ),
                ),
          );
      }
      enhancedServices = (map['enhancedServices'] as bool?) ?? false;
      curtainWall = (map['curtainWall'] as bool?) ?? false;
      includeWaterTank = (map['includeWaterTank'] as bool?) ?? false;
      includeGeneratorHouse = (map['includeGeneratorHouse'] as bool?) ?? false;
      includeSwimmingPool = (map['includeSwimmingPool'] as bool?) ?? false;
      swimmingPoolGhs = (map['swimmingPoolGhs'] as num?)?.toDouble() ?? 62500;
      securityWallLenM = (map['securityWallLenM'] as num?)?.toDouble() ?? 0;
      includeExternalWorks =
          map['includeExternalWorks'] as bool? ?? includeExternalWorks;
      externalWallLenM =
          (map['externalWallLenM'] as num?)?.toDouble() ?? externalWallLenM;
      drivewayAreaM2 =
          (map['drivewayAreaM2'] as num?)?.toDouble() ?? drivewayAreaM2;
      includeSeptic = map['includeSeptic'] as bool? ?? includeSeptic;
      preliminariesPct =
          (map['preliminariesPct'] as num?)?.toDouble() ?? preliminariesPct;
      contingencyEnabled =
          map['contingencyEnabled'] as bool? ?? contingencyEnabled;
      contingencyPct =
          (map['contingencyPct'] as num?)?.toDouble() ?? contingencyPct;
      final pmName = map['permitMode'] as String?;
      if (pmName != null) {
        permitMode = PermitMode.values.firstWhere(
          (m) => m.name == pmName,
          orElse: () => PermitMode.percent,
        );
      }
      permitPct = (map['permitPct'] as num?)?.toDouble() ?? permitPct;
      permitManualGhs = (map['permitManualGhs'] as num?)?.toDouble();
      budgetAmount = (map['budgetAmount'] as num?)?.toDouble();
      professionalFeesEnabled =
          map['professionalFeesEnabled'] as bool? ?? professionalFeesEnabled;
      professionalFeesPct =
          (map['professionalFeesPct'] as num?)?.toDouble() ?? professionalFeesPct;
    } catch (e) {
      debugPrint('EstimateController.restoreFormState error: $e');
    }
  }

  /// Removes saved draft (call after successful save).
  Future<void> clearFormState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyDraft);
    } catch (e) {
      debugPrint('EstimateController.clearFormState error: $e');
    }
  }

  // ── Mutations ──
  void setRegion(String? r) {
    region = r;
    notifyListeners();
    saveFormState();
  }

  void setCurrency(CurrencyInfo c) {
    currency = c;
    notifyListeners();
    // Persist for next session.
    SharedPreferences.getInstance()
        .then((p) => p.setString(_prefKeyCurrency, c.code));
  }

  void setProgramme({
    BuildingTypology? typology_,
    String? quality_,
    String? foundation_,
    String? soil_,
    String? roof_,
    int? storeys_,
  }) {
    if (typology_ != null) typology = typology_;
    if (quality_ != null) quality = quality_;
    if (foundation_ != null) foundation = foundation_;
    if (soil_ != null) soil = soil_;
    if (roof_ != null) roof = roof_;
    if (storeys_ != null) storeys = storeys_;
    notifyListeners();
    saveFormState();
  }

  void setEnhancedServices(bool v) {
    enhancedServices = v;
    notifyListeners();
  }

  void setCurtainWall(bool v) {
    curtainWall = v;
    notifyListeners();
  }

  void setWaterTank(bool v) {
    includeWaterTank = v;
    notifyListeners();
  }

  void setGeneratorHouse(bool v) {
    includeGeneratorHouse = v;
    notifyListeners();
  }

  void setSwimmingPool({bool? enabled, double? amountGhs}) {
    if (enabled != null) includeSwimmingPool = enabled;
    if (amountGhs != null) swimmingPoolGhs = amountGhs;
    notifyListeners();
  }

  void setSecurityWall(double lenM) {
    securityWallLenM = lenM;
    notifyListeners();
  }

  void addFloor() {
    floors.add(const FloorSpec(areaM2: 100, heightM: 3.0));
    notifyListeners();
    saveFormState();
  }

  void updateFloor(int i, {double? areaM2, double? heightM}) {
    floors[i] = floors[i].copyWith(areaM2: areaM2, heightM: heightM);
    notifyListeners();
    saveFormState();
  }

  void removeFloor(int i) {
    if (floors.length <= 1) return;
    floors.removeAt(i);
    notifyListeners();
    saveFormState();
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

  void setProfessionalFees({bool? enabled, double? pct}) {
    professionalFeesEnabled = enabled ?? professionalFeesEnabled;
    professionalFeesPct = pct ?? professionalFeesPct;
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
      final input = EstimateInput(
        floors: List.unmodifiable(floors),
        quality: quality,
        foundation: foundation,
        soil: soil,
        roof: roof,
        typology: typology,
        enhancedServices: enhancedServices,
        curtainWall: curtainWall,
        includeWaterTank: includeWaterTank,
        includeGeneratorHouse: includeGeneratorHouse,
        includeSwimmingPool: includeSwimmingPool,
        swimmingPoolGhs: swimmingPoolGhs,
        securityWallLenM: securityWallLenM,
        securityWallRatePerM: _securityWallRatePerM,
        unitRateGhsPerM2: catalogService.unitRatesGhsPerM2[quality] ??
            catalogService.unitRatesGhsPerM2['Standard'] ??
            6200.0,
        regionalIndex: regionalIndexProvider.indexFor(region),
        phasePercents: catalogService.phasePercents,
        includeExternalWorks: includeExternalWorks,
        externalWallLenM: externalWallLenM,
        drivewayAreaM2: drivewayAreaM2,
        includeSeptic: includeSeptic,
        compoundWallRatePerM: catalogService.compoundWallRatePerM,
        drivewayRatePerM2: catalogService.drivewayRatePerM2,
        septicLumpSum: catalogService.septicLumpSum,
        preliminariesPct: preliminariesPct,
        ohpPct: catalogService.ohpDefaultPct,
        contingencyEnabled: contingencyEnabled,
        contingencyPct: contingencyPct,
        permitMode: permitMode,
        permitPct: permitPct,
        permitManualGhs: permitManualGhs,
        taxLines: List.unmodifiable(taxLines),
        professionalFeesEnabled: professionalFeesEnabled,
        professionalFeesPct: professionalFeesPct,
      );
      _result = const EstimationEngine().calculate(input);
    } catch (e) {
      _computeError = AppException.from(e).message;
      debugPrint('EstimateController.compute error: $e');
    } finally {
      _isComputing = false;
      notifyListeners();
    }
  }

  // ── Display helpers ──

  static final _nf = NumberFormat('#,##0.##', 'en_US');

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

  String _fmt(double v) => _nf.format(v);

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
      'typology': typology.name,
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
      'professionalFeesGhs': r.professionalFeesGhs,
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
