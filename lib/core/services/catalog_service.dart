// lib/core/services/catalog_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

@immutable
class GhCatalog {
  const GhCatalog({
    required this.ohpDefaultPct,
    required this.contingencyDefaultPct,
    required this.taxesDefaultPct,
    required this.baseRates,
    required this.soilFactor,
    required this.foundationUpliftPct,
    required this.phaseSharesDefault,
    required this.roof,
    required this.services,
    required this.finishes,
    required this.openings,
    required this.external,
  });

  final double ohpDefaultPct;
  final double contingencyDefaultPct;
  final double taxesDefaultPct;

  final Map<String, double> baseRates;
  final Map<String, double> soilFactor;
  final Map<String, double> foundationUpliftPct;
  final Map<String, double> phaseSharesDefault;
  final Map<String, double> roof;
  final Map<String, double> services;
  final Map<String, double> finishes;
  final Map<String, double> openings;
  final Map<String, double> external;

  factory GhCatalog.fromJson(Map<String, dynamic> m) {
    double _num(Object? x, [double d = 0]) => (x is num) ? x.toDouble() : d;
    Map<String, double> _toMap(Map? mm) => {
          for (final e in (mm ?? {}).entries)
            if (e.value is num) e.key.toString(): (e.value as num).toDouble(),
        };

    return GhCatalog(
      ohpDefaultPct: _num(m['ohpDefaultPct'], 10),
      contingencyDefaultPct: _num(m['contingencyDefaultPct'], 10),
      taxesDefaultPct: _num(m['taxesDefaultPct'], 15),
      baseRates: _toMap(m['baseRates']),
      soilFactor: _toMap(m['soilFactor']),
      foundationUpliftPct: _toMap(m['foundationUpliftPct']),
      phaseSharesDefault: _toMap(m['phaseSharesDefault']),
      roof: _toMap(m['roof']),
      services: _toMap(m['services']),
      finishes: _toMap(m['finishes']),
      openings: _toMap(m['openings']),
      external: _toMap(m['external']),
    );
  }
}

class CatalogService {
  GhCatalog? _catalog;

  Future<GhCatalog> ensureLoaded() async {
    if (_catalog != null) return _catalog!;
    try {
      final raw =
          await rootBundle.loadString('assets/data/cost_catalog_gh.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _catalog = GhCatalog.fromJson(json);
    } catch (_) {
      // Safe defaults if the asset is missing.
      _catalog = GhCatalog.fromJson(const {
        "ohpDefaultPct": 10,
        "contingencyDefaultPct": 10,
        "taxesDefaultPct": 15,
        "baseRates": {"residential": 3500, "commercial": 4200},
        "soilFactor": {
          "firm": 1.0,
          "soft": 1.08,
          "waterlogged": 1.15,
          "laterite": 1.05
        },
        "foundationUpliftPct": {"strip": 0, "raft": 8, "pile": 20, "pad": 5},
        "phaseSharesDefault": {
          "substructure": 25,
          "superstructure": 45,
          "roofing": 8,
          "services": 8,
          "finishes": 10,
          "openings": 4
        },
        "roof": {"pitched_sheet": 1.0, "concrete_flat": 1.12, "tile": 1.08},
        "services": {"standard": 1.0, "enhanced": 1.15},
        "finishes": {"economy": 0.92, "standard": 1.0, "premium": 1.12},
        "openings": {"aluminium": 1.0, "hardwood": 1.05, "upvc": 1.02},
        "external": {
          "external_wall_ghs_per_m": 650,
          "driveway_ghs_per_m2": 220,
          "septic_ghs_lump": 16000
        }
      });
    }
    return _catalog!;
  }

  GhCatalog? get catalog => _catalog;
}
