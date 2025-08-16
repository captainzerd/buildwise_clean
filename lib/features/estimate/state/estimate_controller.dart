// lib/features/estimate/state/estimate_controller.dart
//
// Controller centralizing estimator state + conversions + orchestration.
// Depends only on EstimateService for the math. UI should remain thin.

import 'package:flutter/material.dart';

import '../../../core/repositories/location_repository.dart';
import '../../../core/services/estimate_service.dart';
import '../../../core/services/expense_service.dart';
import '../../../core/services/pdf_service.dart';

/// Area/height units the UI can toggle between.
enum AreaUnit { sqm, sqft }

/// Currencies kept deliberately simple here.
enum Currency { ghs, usd, eur }

extension CurrencyX on Currency {
  String get symbol {
    switch (this) {
      case Currency.ghs:
        return 'GHS';
      case Currency.usd:
        return '\$';
      case Currency.eur:
        return '€';
    }
  }
}

/// Thin DTO for the computed results we render in the UI.
class EstimateView {
  final String projectId;
  final String projectName;
  final String region;
  final String city;
  final double totalAreaSqm;
  final double baseCost;
  final double extraSubstructure;
  final double stairsCost;
  final Map<String, double> phaseBreakdown;
  double get grandTotal =>
      baseCost + extraSubstructure + stairsCost; // phaseBreakdown sums to base

  /// Backwards-compat for older widgets like `phase_editor.dart`
  Map<String, double> get phasePlanned => phaseBreakdown;

  const EstimateView({
    required this.projectId,
    required this.projectName,
    required this.region,
    required this.city,
    required this.totalAreaSqm,
    required this.baseCost,
    required this.extraSubstructure,
    required this.stairsCost,
    required this.phaseBreakdown,
  });

  EstimateView copyWith({
    String? projectId,
    String? projectName,
    String? region,
    String? city,
    double? totalAreaSqm,
    double? baseCost,
    double? extraSubstructure,
    double? stairsCost,
    Map<String, double>? phaseBreakdown,
  }) {
    return EstimateView(
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      region: region ?? this.region,
      city: city ?? this.city,
      totalAreaSqm: totalAreaSqm ?? this.totalAreaSqm,
      baseCost: baseCost ?? this.baseCost,
      extraSubstructure: extraSubstructure ?? this.extraSubstructure,
      stairsCost: stairsCost ?? this.stairsCost,
      phaseBreakdown: phaseBreakdown ?? this.phaseBreakdown,
    );
  }
}

class EstimateController extends ChangeNotifier {
  // --- Dependencies ----------------------------------------------------------
  final EstimateService estimateService;
  final ExpenseService expenseService;
  final LocationRepository locationRepo;
  final PdfService pdf;

  EstimateController({
    required this.estimateService,
    required this.expenseService,
    required this.locationRepo,
    required this.pdf,
  });

  // --- Form state ------------------------------------------------------------
  final formKey = GlobalKey<FormState>();

  final projectNameCtrl = TextEditingController();
  final regionCtrl = TextEditingController();
  final cityCtrl = TextEditingController();

  /// One controller per floor for AREA.
  final List<TextEditingController> floorAreaCtrls = [];

  /// One controller per floor for HEIGHT.
  final List<TextEditingController> floorHeightCtrls = [];

  /// Number of floors.
  int _floors = 1;
  int get floors => _floors;

  /// Area unit toggle.
  AreaUnit _areaUnit = AreaUnit.sqm;
  AreaUnit get areaUnit => _areaUnit;

  /// Currency selection.
  Currency _currency = Currency.ghs;
  Currency get currency => _currency;

  // --- Data from repos -------------------------------------------------------
  Map<String, List<String>> _regionsCities = {};
  bool loadingLocations = false;
  String? locationError;

  List<String> get regions {
    final keys = _regionsCities.keys.toList()..sort();
    return keys;
  }

  List<String> get citiesForSelected {
    final r = regionCtrl.text;
    final list = _regionsCities[r] ?? const <String>[];
    final sorted = [...list]..sort();
    return sorted;
  }

  // --- Files (optional UI surface) ------------------------------------------
  // Public type to avoid "private type in public API" lint.
  final List<PickedFileRef> files = [];

  // --- Computed results ------------------------------------------------------
  EstimateView? result;

  // --- Lifecycle -------------------------------------------------------------
  Future<void> init() async {
    loadingLocations = true;
    locationError = null;
    notifyListeners();
    try {
      _regionsCities = await locationRepo.load();
      // Seed sensible defaults for region/city.
      final regs = regions;
      if (regs.isNotEmpty) {
        regionCtrl.text = regs.first;
        final cts = citiesForSelected;
        cityCtrl.text = cts.isNotEmpty ? cts.first : '';
      }
      // Seed one floor with empty inputs.
      _ensureFloorControllers(1);
    } catch (e) {
      locationError = 'Failed to load locations: $e';
    } finally {
      loadingLocations = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (var c in floorAreaCtrls) c.dispose();
    for (var c in floorHeightCtrls) c.dispose();
    projectNameCtrl.dispose();
    regionCtrl.dispose();
    cityCtrl.dispose();
    super.dispose();
  }

  // --- Files -----------------------------------------------------------------
  Future<void> pickFiles() async {
    // Hook your file picker here if/when needed.
    // Example push:
    // files.add(PickedFileRef('plan.pdf')); notifyListeners();
  }

  // --- Floors ----------------------------------------------------------------
  void setFloors(int n) {
    if (n < 1) n = 1;
    _floors = n;
    _ensureFloorControllers(n);
    notifyListeners();
  }

  void _ensureFloorControllers(int n) {
    // Grow
    while (floorAreaCtrls.length < n) {
      floorAreaCtrls.add(TextEditingController());
    }
    while (floorHeightCtrls.length < n) {
      floorHeightCtrls.add(TextEditingController());
    }
    // Shrink
    while (floorAreaCtrls.length > n) {
      floorAreaCtrls.removeLast().dispose();
    }
    while (floorHeightCtrls.length > n) {
      floorHeightCtrls.removeLast().dispose();
    }
  }

  // --- Units & conversion ----------------------------------------------------
  void setAreaUnit(AreaUnit next) {
    if (next == _areaUnit) return;

    if (next == AreaUnit.sqft && _areaUnit == AreaUnit.sqm) {
      // sqm -> sqft, m -> ft
      _convertAreas((x) => x * 10.7639);
      _convertHeights((x) => x * 3.28084);
    } else if (next == AreaUnit.sqm && _areaUnit == AreaUnit.sqft) {
      // sqft -> sqm, ft -> m
      _convertAreas((x) => x / 10.7639);
      _convertHeights((x) => x / 3.28084);
    }

    _areaUnit = next;
    notifyListeners();
  }

  void _convertAreas(double Function(double) f) {
    for (var i = 0; i < floorAreaCtrls.length; i++) {
      final t = floorAreaCtrls[i].text.trim();
      if (t.isEmpty) continue;
      final d = double.tryParse(t);
      if (d == null) continue;
      floorAreaCtrls[i].text = _toCleanNumber(f(d));
    }
  }

  void _convertHeights(double Function(double) f) {
    for (var i = 0; i < floorHeightCtrls.length; i++) {
      final t = floorHeightCtrls[i].text.trim();
      if (t.isEmpty) continue;
      final d = double.tryParse(t);
      if (d == null) continue;
      floorHeightCtrls[i].text = _toCleanNumber(f(d));
    }
  }

  // --- Currency --------------------------------------------------------------
  void setCurrency(Currency c) {
    if (_currency == c) return;
    _currency = c;
    notifyListeners();
  }

  // --- Generate --------------------------------------------------------------
  Future<void> generate() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (regionCtrl.text.isEmpty || cityCtrl.text.isEmpty) return;

    // Read and convert inputs to service’s base units (sqm / meters).
    final areasSqm = <double>[];
    final heightsM = <double>[];

    for (var i = 0; i < floors; i++) {
      final at = floorAreaCtrls[i].text.trim();
      final ht = floorHeightCtrls[i].text.trim();
      final a = double.tryParse(at);
      final h = double.tryParse(ht);
      if (a == null || h == null || a <= 0 || h <= 0) continue;

      if (areaUnit == AreaUnit.sqft) {
        areasSqm.add(a / 10.7639);
        heightsM.add(h / 3.28084);
      } else {
        areasSqm.add(a);
        heightsM.add(h);
      }
    }

    if (areasSqm.isEmpty) return;

    final pid = 'est_${DateTime.now().millisecondsSinceEpoch}';
    final res = estimateService.create(
      projectId: pid,
      projectName: projectNameCtrl.text.trim(),
      region: regionCtrl.text.trim(),
      city: cityCtrl.text.trim(),
      areasSqm: areasSqm,
      heightsM: heightsM,
      floors: floors,
    );

    result = EstimateView(
      projectId: pid,
      projectName: projectNameCtrl.text.trim(),
      region: regionCtrl.text.trim(),
      city: cityCtrl.text.trim(),
      totalAreaSqm: areasSqm.fold(0.0, (p, e) => p + e),
      baseCost: res.baseCost,
      extraSubstructure: res.extraSubstructure,
      stairsCost: res.stairsCost,
      phaseBreakdown: res.phaseBreakdown,
    );

    notifyListeners();
  }

  // --- Phase editing (compat for phase_editor.dart) --------------------------
  void addPhase(String name, double amount) {
    if (result == null) return;
    final map = Map<String, double>.from(result!.phaseBreakdown);
    map[name] = amount;
    _applyPhasePlan(map);
  }

  void renamePhase(String oldName, String newName) {
    if (result == null || oldName == newName) return;
    final map = Map<String, double>.from(result!.phaseBreakdown);
    if (!map.containsKey(oldName)) return;
    final amt = map.remove(oldName)!;
    map[newName] = amt;
    _applyPhasePlan(map);
  }

  void setPhaseAmount(String name, double amount) {
    if (result == null) return;
    final map = Map<String, double>.from(result!.phaseBreakdown);
    if (!map.containsKey(name)) return;
    map[name] = amount;
    _applyPhasePlan(map);
  }

  void removePhase(String name) {
    if (result == null) return;
    final map = Map<String, double>.from(result!.phaseBreakdown)..remove(name);
    _applyPhasePlan(map);
  }

  void _applyPhasePlan(Map<String, double> map) {
    if (result == null) return;
    result = result!.copyWith(phaseBreakdown: map);
    notifyListeners();
  }

  // --- Helpers ---------------------------------------------------------------
  String formatMoney(num value) {
    final s = _currency.symbol;
    final fixed = value.abs() >= 1000
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$s $fixed';
  }

  String _toCleanNumber(double v) {
    final isInt = (v % 1).abs() < 1e-9;
    return isInt ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }
}

/// Public placeholder for file list UI (hook your picker to fill these).
class PickedFileRef {
  final String name;
  const PickedFileRef(this.name);
}
