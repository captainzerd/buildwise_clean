import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A single published version of the Ghana construction cost catalog.
/// Stored in Firestore: cost_catalog/{versionId}
@immutable
class CatalogVersion {
  const CatalogVersion({
    required this.id,
    required this.effectiveDate,
    required this.baseRatesPerM2,
    required this.regionalIndices,
    required this.addOnRates,
    required this.phaseWeights,
    required this.preliminariesDefaultPct,
    required this.ohpDefaultPct,
    required this.permitDefaultPct,
    required this.contingencyDefaultPct,
    required this.taxLines,
    this.publishedBy,
    this.publishedByName,
    this.publishedAt,
  });

  final String id;
  final DateTime effectiveDate;

  /// When this catalog version was published. Used to show users how current
  /// the rates are. Falls back to [DateTime(2026, 1, 1)] when missing.
  final DateTime? publishedAt;

  final String? publishedBy;
  final String? publishedByName;

  /// GHS per m² keyed by quality tier: 'Economy' | 'Standard' | 'Premium'
  final Map<String, double> baseRatesPerM2;

  /// Region name → cost multiplier (1.0 = baseline)
  final Map<String, double> regionalIndices;

  /// Add-on rates: 'compoundWallPerM', 'drivewayPerM2', 'septicLump'
  final Map<String, double> addOnRates;

  /// Phase name → fraction of base cost (must sum to 1.0)
  final Map<String, double> phaseWeights;

  final double preliminariesDefaultPct;
  final double ohpDefaultPct;
  final double permitDefaultPct;
  final double contingencyDefaultPct;
  final List<TaxLineDefault> taxLines;

  // ── Firestore ──

  factory CatalogVersion.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final defaults = d['defaults'] as Map<String, dynamic>? ?? {};
    return CatalogVersion(
      id: doc.id,
      effectiveDate:
          (d['effectiveDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      publishedAt:
          (d['publishedAt'] as Timestamp?)?.toDate() ?? DateTime(2026, 1, 1),
      publishedBy: d['publishedBy'] as String?,
      publishedByName: d['publishedByName'] as String?,
      baseRatesPerM2: _asDoubleMap(d['baseRatesPerM2']),
      regionalIndices: _asDoubleMap(d['regionalIndices']),
      addOnRates: _asDoubleMap(d['addOnRates']),
      phaseWeights: _asDoubleMap(d['phaseWeights']),
      preliminariesDefaultPct:
          (defaults['preliminariesPct'] as num?)?.toDouble() ?? 10.0,
      ohpDefaultPct: (defaults['ohpPct'] as num?)?.toDouble() ?? 10.0,
      permitDefaultPct:
          (defaults['permitPct'] as num?)?.toDouble() ?? 1.5,
      contingencyDefaultPct:
          (defaults['contingencyPct'] as num?)?.toDouble() ?? 10.0,
      taxLines: _parseTaxLines(d['taxLines']),
    );
  }

  Map<String, dynamic> toMap() => {
        'effectiveDate': Timestamp.fromDate(effectiveDate),
        if (publishedBy != null) 'publishedBy': publishedBy,
        if (publishedByName != null) 'publishedByName': publishedByName,
        'baseRatesPerM2': baseRatesPerM2,
        'regionalIndices': regionalIndices,
        'addOnRates': addOnRates,
        'phaseWeights': phaseWeights,
        'defaults': {
          'preliminariesPct': preliminariesDefaultPct,
          'ohpPct': ohpDefaultPct,
          'permitPct': permitDefaultPct,
          'contingencyPct': contingencyDefaultPct,
        },
        'taxLines': [
          for (final t in taxLines) {'name': t.name, 'pct': t.pct},
        ],
      };

  // ── Fallback (used when Firestore is unavailable) ──

  /// Built-in defaults — always usable even with no connectivity.
  static CatalogVersion fallback() => CatalogVersion(
        id: 'built-in',
        effectiveDate: DateTime(2025, 1, 1),
        // GHS/m² — Ghana market averages, Q1 2026.
        // Economy : basic finish, no tiles, louvre windows.
        // Standard: ceramic tiles, aluminium windows, standard MEP.
        // Premium : imported fittings, large-format porcelain, quality sanitary ware.
        baseRatesPerM2: const {
          'Economy': 4500.0,
          'Standard': 6200.0,
          'Premium': 10500.0,
        },
        // Multipliers relative to DEFAULT (1.00). Accra and major commercial
        // cities carry a premium due to skilled-labour costs and logistics.
        regionalIndices: const {
          'DEFAULT': 1.00,
          'Greater Accra': 1.18,
          'Ashanti': 1.07,
          'Northern': 0.95,
          'Western': 1.10,
          'Eastern': 1.00,
          'Volta': 0.98,
          'Central': 0.99,
          'Brong Ahafo': 0.97,
          'Upper East': 0.94,
          'Upper West': 0.94,
          'Savannah': 0.93,
          'North East': 0.93,
          'Western North': 0.97,
          'Bono': 0.97,
          'Bono East': 0.97,
          'Oti': 0.96,
          'Ahafo': 0.97,
        },
        addOnRates: const {
          'compoundWallPerM': 1200.0,
          'drivewayPerM2': 350.0,
          'septicLump': 25000.0,
        },
        // Phase weights must sum to 1.00.
        // Pitched long-span roofing is relatively cheap in Ghana, so
        // Roofing is weighted lower and Superstructure higher.
        phaseWeights: const {
          'Substructure': 0.15,
          'Superstructure': 0.30,
          'Roofing': 0.11,
          'Finishes': 0.29,
          'Services (MEP)': 0.15,
        },
        preliminariesDefaultPct: 10.0,
        ohpDefaultPct: 10.0,
        permitDefaultPct: 1.5,
        contingencyDefaultPct: 10.0,
        taxLines: const [
          TaxLineDefault(name: 'VAT', pct: 15.0),
          TaxLineDefault(name: 'NHIL', pct: 2.5),
          TaxLineDefault(name: 'GETFund', pct: 2.5),
          TaxLineDefault(name: 'Health Recovery Levy', pct: 1.0),
        ],
      );

  // ── Helpers ──

  static Map<String, double> _asDoubleMap(dynamic v) {
    if (v == null) return {};
    return (v as Map<String, dynamic>)
        .map((k, val) => MapEntry(k, (val as num).toDouble()));
  }

  static List<TaxLineDefault> _parseTaxLines(dynamic v) {
    if (v == null) return [];
    return (v as List<dynamic>).map((e) {
      final m = e as Map<String, dynamic>;
      return TaxLineDefault(
        name: m['name'] as String,
        pct: (m['pct'] as num).toDouble(),
      );
    }).toList();
  }
}

@immutable
class TaxLineDefault {
  const TaxLineDefault({required this.name, required this.pct});
  final String name;
  final double pct;
}
