// lib/features/estimate/state/estimate_controller.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/services/catalog_service.dart';
import '../../../core/services/regional_index_provider.dart';
import '../../../core/services/fx_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/services/snapshot.dart';

@immutable
class CurrencyInfo {
  const CurrencyInfo(this.code, this.symbol, {this.baseToUsd = 1.0});
  final String code; // e.g., "GHS"
  final String symbol; // e.g., "₵"
  final double baseToUsd;
}

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
class EstimateResult {
  const EstimateResult({
    required this.totalBuiltUpArea,
    required this.baseCostGhs,
    required this.phaseBreakdownGhs,
    required this.addOnsGhs,
    required this.ohpGhs,
    required this.contingencyGhs,
    required this.taxesGhs,
    required this.totalPlannedGhs,
  });

  final double totalBuiltUpArea;
  final double baseCostGhs; // phases + addOns (pre-OHP/cont/tax)
  final Map<String, double> phaseBreakdownGhs;
  final Map<String, double> addOnsGhs;
  final double ohpGhs;
  final double contingencyGhs;
  final double taxesGhs;
  final double totalPlannedGhs;
}

class EstimateController extends ChangeNotifier {
  EstimateController({
    required CatalogService catalogService,
    required RegionalIndexProvider regionalIndexProvider,
    FxService? fxService,
    StorageService? storageService,
  })  : _catalogService = catalogService,
        _regionalIndex = regionalIndexProvider,
        _fx = fxService ?? FxService(),
        _storage = storageService ?? StorageService();

  final CatalogService _catalogService;
  final RegionalIndexProvider _regionalIndex;
  final FxService _fx;
  final StorageService _storage;

  // UI Form key (validators).
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Legacy UI compatibility (kept)
  final TextEditingController projectNameCtrl = TextEditingController();

  // Project
  String projectName = '';
  String? region;

  // Units & Currency
  bool useMetric = true;
  CurrencyInfo currency = const CurrencyInfo('GHS', '₵');

  // Programme
  String buildingType = 'Residential';
  String quality = 'Standard';
  String roof = 'Pitched sheet';
  String foundation = 'Strip';
  String soil = 'Firm';

  // Floors (at least one)
  final List<FloorSpec> floors = <FloorSpec>[
    const FloorSpec(areaM2: 150, heightM: 10),
  ];

  // External works (optional)
  bool includeExternalWorks = false;
  double externalWallLenM = 0;
  double drivewayAreaM2 = 0;
  bool includeSeptic = false;

  // Commercial percentages (defaults loaded from catalog)
  double _ohpPct = 10;
  double _contingencyPct = 10;
  double _taxesPct = 15;

  // Optional budget (MVP+)
  double? budgetAmount;

  // Result
  EstimateResult? _result;
  bool _hasResult = false;

  // -------- Getters (for UI & legacy code) ----------
  bool get hasResult => _hasResult;
  EstimateResult? get result => _result;

  List<String> get regions => _regionalIndex.regions;

  // Legacy helpers still referenced by UI:
  String get currencyCode => currency.code;

  // GHS money (used for local summaries if needed)
  String _ghs(num v) => '₵ ${v.toStringAsFixed(2)}';

  // Display money (selected currency) with FX conversion
  String money(num vGhs) {
    final fx = _fx.convertFromGhs(vGhs.toDouble(), currency.code);
    return '${currency.symbol} ${fx.toStringAsFixed(2)}';
  }

  // GHS numbers for legacy bindings
  Map<String, double> get phasesGhs => _result?.phaseBreakdownGhs ?? const {};
  double get worksSubtotalGhs => _result?.baseCostGhs ?? 0.0;
  double get ohpGhs => _result?.ohpGhs ?? 0.0;
  double get contingencyGhs => _result?.contingencyGhs ?? 0.0;
  double get taxesGhs => _result?.taxesGhs ?? 0.0;
  double get grandTotalGhs => _result?.totalPlannedGhs ?? 0.0;

  // FX view (for UI totals shown in selected currency)
  double get grandTotalFx => _fx.convertFromGhs(grandTotalGhs, currency.code);

  bool get contingencyEnabled => _contingencyPct > 0;
  double get contingencyPct => _contingencyPct;

  // Derived: is form valid?
  bool get isFormValid {
    final hasRegion = (region ?? '').isNotEmpty;
    final hasFloor =
        floors.isNotEmpty && floors.every((f) => f.areaM2 > 0 && f.heightM > 0);
    final hasProgramme = buildingType.isNotEmpty &&
        quality.isNotEmpty &&
        foundation.isNotEmpty &&
        soil.isNotEmpty;
    return hasRegion && hasFloor && hasProgramme;
  }

  // -------- Lifecycle ----------
  Future<void> init() async {
    await Future.wait([
      _catalogService.ensureLoaded(),
      _regionalIndex.load(),
      _fx.refreshIfStale(),
    ]);

    region ??= regions.isNotEmpty ? regions.first : null;

    final cat = _catalogService.catalog!;
    _ohpPct = cat.ohpDefaultPct;
    _contingencyPct = cat.contingencyDefaultPct;
    _taxesPct = cat.taxesDefaultPct;

    if (projectName.isNotEmpty) {
      projectNameCtrl.text = projectName;
    }
    projectNameCtrl.addListener(() {
      projectName = projectNameCtrl.text;
    });

    notifyListeners();
  }

  // -------- Mutators ----------
  void setProjectName(String v) {
    projectName = v;
    if (projectNameCtrl.text != v) {
      projectNameCtrl.text = v;
      projectNameCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: projectNameCtrl.text.length),
      );
    }
    notifyListeners();
  }

  void setRegion(String? v) {
    region = v;
    notifyListeners();
  }

  void setUseMetric(bool v) {
    useMetric = v;
    notifyListeners();
  }

  Future<void> setCurrency(CurrencyInfo v) async {
    currency = v;
    await _fx.refreshIfStale(); // ensure we have a rate
    notifyListeners(); // redraw totals with FX
  }

  void setProgramme({
    String? buildingType_,
    String? quality_,
    String? roof_,
    String? foundation_,
    String? soil_,
  }) {
    buildingType = buildingType_ ?? buildingType;
    quality = quality_ ?? quality;
    roof = roof_ ?? roof;
    foundation = foundation_ ?? foundation;
    soil = soil_ ?? soil;
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

  void setBudgetAmount(double? v) {
    budgetAmount = v;
    notifyListeners();
  }

  void addFloor() {
    floors.add(const FloorSpec(areaM2: 100, heightM: 10));
    notifyListeners();
  }

  void removeFloor(int index) {
    if (index >= 0 && index < floors.length) {
      floors.removeAt(index);
      notifyListeners();
    }
  }

  void updateFloor(int index, {double? areaM2, double? heightM}) {
    if (index < 0 || index >= floors.length) return;
    floors[index] = floors[index].copyWith(
      areaM2: areaM2,
      heightM: heightM,
    );
    notifyListeners();
  }

  void setContingencyEnabled(bool enabled) {
    _contingencyPct = enabled ? math.max(_contingencyPct, 1) : 0;
    notifyListeners();
  }

  void setContingencyPct(double pct) {
    _contingencyPct = pct.clamp(0, 50);
    notifyListeners();
  }

  // -------- Compute ----------
  Future<void> compute() async {
    if (!isFormValid) {
      _hasResult = false;
      notifyListeners();
      return;
    }

    final cat = await _catalogService.ensureLoaded();

    if (region == null || region!.isEmpty) {
      region = regions.isNotEmpty ? regions.first : null;
    }

    final idx = _regionalIndex.indexFor(region ?? '');
    final ci = (idx['ci'] ?? 1.0).toDouble();
    final materialIdx = (idx['material'] ?? 1.0).toDouble();
    final labourIdx = (idx['labour'] ?? 1.0).toDouble();
    final transportIdx = (idx['transport'] ?? 1.0).toDouble();

    final totalArea = floors.fold<double>(0, (sum, f) => sum + f.areaM2);

    final isResidential = buildingType.toLowerCase().contains('res');
    final baseRate = (isResidential
            ? cat.baseRates['residential']
            : cat.baseRates['commercial']) ??
        3500;

    final soilKey = soil.toLowerCase();
    final soilMult = _pick(
      cat.soilFactor,
      {
        'firm': 'firm',
        'soft': 'soft',
        'waterlogged': 'waterlogged',
        'laterite': 'laterite',
      },
      soilKey,
      1.0,
    );

    final foundationKey = foundation.toLowerCase();
    final foundationPct = _pick(
      cat.foundationUpliftPct,
      {
        'strip': 'strip',
        'raft': 'raft',
        'pile': 'pile',
        'pad': 'pad',
      },
      foundationKey,
      0.0,
    );

    final qualityKey = quality.toLowerCase();
    final qualityMult = _pick(
      cat.finishes,
      {
        'economy': 'economy',
        'standard': 'standard',
        'premium': 'premium',
      },
      qualityKey,
      1.0,
    );

    final roofKey = roof.toLowerCase();
    final roofMult = _pick(
      cat.roof,
      {
        'pitched sheet': 'pitched_sheet',
        'concrete flat': 'concrete_flat',
        'tile': 'tile',
      },
      roofKey,
      1.0,
    );

    final regionalMult = (ci + materialIdx + labourIdx + transportIdx) / 4.0;

    final structureGhs = totalArea *
        baseRate *
        soilMult *
        (1 + foundationPct / 100.0) *
        regionalMult;

    final shares = cat.phaseSharesDefault;
    final substructure = structureGhs * (shares['substructure'] ?? 25) / 100.0;
    final superstructure =
        structureGhs * (shares['superstructure'] ?? 45) / 100.0;
    final roofing = structureGhs * (shares['roofing'] ?? 8) / 100.0 * roofMult;
    final services = structureGhs *
        (shares['services'] ?? 8) /
        100.0 *
        _pick(
          cat.services,
          {'standard': 'standard', 'enhanced': 'enhanced'},
          qualityKey,
          1.0,
        );
    final finishes =
        structureGhs * (shares['finishes'] ?? 10) / 100.0 * qualityMult;
    final openings = structureGhs *
        (shares['openings'] ?? 4) /
        100.0 *
        _pick(
          cat.openings,
          {'aluminium': 'aluminium', 'hardwood': 'hardwood', 'upvc': 'upvc'},
          'aluminium',
          1.0,
        );

    final extRates = cat.external;
    final wallRate = (extRates['external_wall_ghs_per_m'] ?? 0).toDouble();
    final driveRate = (extRates['driveway_ghs_per_m2'] ?? 0).toDouble();
    final septicLump =
        includeSeptic ? (extRates['septic_ghs_lump'] ?? 0).toDouble() : 0.0;

    final externalWall =
        includeExternalWorks ? externalWallLenM * wallRate : 0.0;
    final driveway = includeExternalWorks ? drivewayAreaM2 * driveRate : 0.0;

    final phaseBreakdown = <String, double>{
      'Substructure': substructure,
      'Superstructure': superstructure,
      'Roofing': roofing,
      'Services': services,
      'Finishes': finishes,
      'Openings': openings,
    };

    final addOns = <String, double>{
      if (includeExternalWorks && externalWall > 0)
        'External wall': externalWall,
      if (includeExternalWorks && driveway > 0) 'Driveway': driveway,
      if (includeSeptic && septicLump > 0) 'Septic system': septicLump,
    };

    final baseSum = _sum(phaseBreakdown.values) + _sum(addOns.values);

    final ohp = baseSum * _ohpPct / 100.0;
    final contingency = baseSum * _contingencyPct / 100.0;
    final net = baseSum + ohp + contingency;
    final taxes = net * _taxesPct / 100.0;
    final total = net + taxes;

    _result = EstimateResult(
      totalBuiltUpArea: totalArea,
      baseCostGhs: baseSum,
      phaseBreakdownGhs: phaseBreakdown,
      addOnsGhs: addOns,
      ohpGhs: ohp,
      contingencyGhs: contingency,
      taxesGhs: taxes,
      totalPlannedGhs: total,
    );

    _hasResult = true;
    notifyListeners();
  }

  /// Pure snapshot (no I/O). Used by UI (e.g., PDF export) and tests.
  EstimateSnapshot toSnapshot() {
    assert(_hasResult && region != null,
        'toSnapshot called before compute() or without region');

    final fxRate = _fx.rateTo(currency.code);

    return EstimateSnapshot.fromParts(
      name: projectName.isEmpty ? 'Untitled Project' : projectName,
      region: region!,
      currencyCode: currency.code,
      inputs: {
        'buildingType': buildingType,
        'quality': quality,
        'roof': roof,
        'foundation': foundation,
        'soil': soil,
        'floors': floors
            .map((f) => {'areaM2': f.areaM2, 'heightM': f.heightM})
            .toList(),
        'external': {
          'enabled': includeExternalWorks,
          'externalWallLenM': externalWallLenM,
          'drivewayAreaM2': drivewayAreaM2,
          'septic': includeSeptic,
        },
        'percentages': {
          'ohp': _ohpPct,
          'contingency': _contingencyPct,
          'taxes': _taxesPct,
        },
        'budget': budgetAmount,
      },
      outputs: {
        'areaM2Total': _result!.totalBuiltUpArea,
        'breakdownGhs': _result!.phaseBreakdownGhs,
        'addonsGhs': _result!.addOnsGhs,
        'ohpGhs': _result!.ohpGhs,
        'contingencyGhs': _result!.contingencyGhs,
        'taxesGhs': _result!.taxesGhs,
        'totalGhs': _result!.totalPlannedGhs,
        'fx': {
          'code': currency.code,
          'rate': fxRate,
          'total': _fx.convertFromGhs(_result!.totalPlannedGhs, currency.code),
        },
      },
    );
  }

  // Save snapshot (local JSON). Returns saved path.
  Future<String?> saveSnapshot() async {
    if (!_hasResult || region == null) return null;

    final snap = toSnapshot(); // reuse the pure builder above
    final path = await _storage.writeJson(snap.filename(), snap.toJson());
    return path;
  }

  // -------- Helpers ----------
  double _sum(Iterable<double> xs) => xs.fold<double>(0, (a, b) => a + b);

  double _pick(
    Map<String, double> table,
    Map<String, String> aliases,
    String key,
    double fallback,
  ) {
    final normalized = key.replaceAll('_', ' ').trim();
    final asKey = aliases[normalized] ??
        aliases[normalized.toLowerCase()] ??
        key.toLowerCase().replaceAll(' ', '_');
    return (table[asKey] ?? fallback).toDouble();
  }
}
