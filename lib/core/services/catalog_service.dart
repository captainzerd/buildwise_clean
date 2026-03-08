import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../errors/app_exception.dart';
import '../models/catalog_version.dart';

export '../models/catalog_version.dart' show TaxLineDefault;

/// Loads the active Ghana construction cost catalog.
///
/// Priority:
///   1. Firestore  cost_catalog/config → cost_catalog/{activeVersionId}
///   2. Built-in [CatalogVersion.fallback()] when Firestore is unavailable.
///
/// Firestore offline persistence (enabled in main.dart) means the last
/// fetched version is available even without connectivity.
class CatalogService extends ChangeNotifier {
  CatalogVersion _version = CatalogVersion.fallback();
  bool _isLoading = false;
  bool _loaded = false;
  String? _error;

  // ── State ──

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUsingFallback => _version.id == 'built-in';
  CatalogVersion get activeVersion => _version;

  // ── Catalog version metadata ──

  /// The date this catalog version was published, or null for the fallback.
  DateTime? get ratesPublishedAt => _version.publishedAt;

  /// Human-readable label for the active rates version, e.g. "Q1 2026".
  /// Appends "(estimated rates)" when falling back to built-in defaults.
  String get ratesVersionLabel {
    final date = _version.publishedAt ?? DateTime(2026, 1, 1);
    final month = date.month;
    final quarter =
        month <= 3 ? 'Q1' : month <= 6 ? 'Q2' : month <= 9 ? 'Q3' : 'Q4';
    final year = DateFormat('yyyy').format(date);
    final label = '$quarter $year';
    return isUsingFallback ? '$label (estimated rates)' : label;
  }

  // ── Accessors consumed by EstimateController ──

  /// GHS/m² by quality tier ('Economy' | 'Standard' | 'Premium').
  Map<String, double> get unitRatesGhsPerM2 => _version.baseRatesPerM2;

  /// Phase name → fraction of base cost.
  Map<String, double> get phasePercents => _version.phaseWeights;

  /// Region name → cost multiplier.
  Map<String, double> get regionalIndices => _version.regionalIndices;

  double get compoundWallRatePerM =>
      _version.addOnRates['compoundWallPerM'] ?? 1200.0;
  double get drivewayRatePerM2 =>
      _version.addOnRates['drivewayPerM2'] ?? 350.0;
  double get septicLumpSum =>
      _version.addOnRates['septicLump'] ?? 18000.0;

  double get preliminariesDefaultPct => _version.preliminariesDefaultPct;
  double get ohpDefaultPct => _version.ohpDefaultPct;
  double get permitDefaultPct => _version.permitDefaultPct;
  List<TaxLineDefault> get taxLinesDefault => _version.taxLines;

  // ── Lifecycle ──

  /// Called once on app startup. Safe to call multiple times.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
  }

  /// Force a fresh fetch from Firestore (e.g. admin just published a version).
  Future<void> refresh() => _load();

  // ── Internal ──

  Future<void> _load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = FirebaseFirestore.instance;

      // 1. Get the active version ID from the config document.
      final configSnap =
          await db.collection('cost_catalog').doc('config').get();

      if (!configSnap.exists) {
        // No catalog published yet — use fallback silently.
        _version = CatalogVersion.fallback();
        return;
      }

      final activeVersionId =
          configSnap.data()?['activeVersion'] as String?;

      if (activeVersionId == null || activeVersionId.isEmpty) {
        _version = CatalogVersion.fallback();
        return;
      }

      // 2. Fetch the version document.
      final versionSnap = await db
          .collection('cost_catalog')
          .doc(activeVersionId)
          .get();

      if (!versionSnap.exists) {
        throw AppException(
          'Catalog version "$activeVersionId" not found in Firestore.',
        );
      }

      _version = CatalogVersion.fromDoc(versionSnap);
    } catch (e) {
      _error =
          'Could not load latest rates — using built-in defaults. '
          '(${AppException.from(e).message})';
      _version = CatalogVersion.fallback();
      debugPrint('CatalogService._load error: $e');
    } finally {
      _isLoading = false;
      _loaded = true;
      notifyListeners();
    }
  }
}
