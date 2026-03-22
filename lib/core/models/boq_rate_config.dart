// lib/core/models/boq_rate_config.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BoqRateConfig {
  final Map<String, double> substructure;
  final Map<String, double> superstructure;
  final Map<String, double> roofing;
  final Map<String, double> finishes;
  final Map<String, double> mep;
  final Map<String, double> external;
  final Map<String, double> generic;
  final double ssnitEmployerRate;
  final double ssnitEmployeeRate;

  const BoqRateConfig({
    required this.substructure,
    required this.superstructure,
    required this.roofing,
    required this.finishes,
    required this.mep,
    required this.external,
    required this.generic,
    this.ssnitEmployerRate = 0.13,
    this.ssnitEmployeeRate = 0.055,
  });

  factory BoqRateConfig.defaults() => const BoqRateConfig(
        substructure: {
          'excavation':  90.0,    // GHS/m³ — hand/machine excavation
          'blinding':   380.0,    // GHS/m³ — 50mm lean-mix (1:3:6)
          'dpm':         12.0,    // GHS/m² — polythene damp-proof membrane
          'antiTermite': 15.0,    // GHS/m² — chemical anti-termite treatment
          'concrete':   650.0,    // GHS/m³ — C25 strip/pad footings + ground slab
          'steel':     8000.0,    // GHS/ton — Y12–Y16 deformed bars
          'formwork':    95.0,    // GHS/m² — softwood formwork
          'hardcore':    75.0,    // GHS/m² — hardcore fill at 150mm (rate incl. compaction)
          'backfill':    60.0,    // GHS/m³ — earthwork backfill after foundation
        },
        superstructure: {
          'blocks':       9.0,    // GHS/block — 6" hollow sandcrete block (supply)
          'blockLabour':  3.5,    // GHS/block — block-laying labour only
          'cement':     105.0,    // GHS/bag  — OPC 50 kg bag (Q1 2026)
          'sand':      1100.0,    // GHS/m³   — river/pit sand (≈ 1 trip ÷ 0.8 m³)
          'steel':     8000.0,    // GHS/ton  — Y10–Y16 bars for columns/ring beam
          'concrete':   650.0,    // GHS/m³   — C25 columns, ring beam, suspended slab
        },
        roofing: {
          'aluminiumSheets': 130.0, // GHS/m² — long-span Al roofing sheet (supply & fix)
          'purlins':          50.0, // GHS/m² — 50×75mm MS/timber purlins at 600mm c/c
          'rafters':          40.0, // GHS/lin m — 50×100mm timber rafters
          'fascia':           55.0, // GHS/lin m — timber/UPVC fascia board
          'gutters':          45.0, // GHS/lin m — UPVC half-round gutter (supply & fix)
          'downpipes':       280.0, // GHS/No.  — UPVC downpipe incl. brackets & shoe
          'ceiling':         120.0, // GHS/m²   — Gyproc or POP ceiling board
        },
        finishes: {
          'plaster':    70.0,   // GHS/m² — sand/cement render (walls, 2 coats)
          'screed':     65.0,   // GHS/m² — cement/sand floor screed (50mm)
          'tiles':     195.0,   // GHS/m² — ceramic floor tiles all-in (supply & lay)
          'wallTiles': 220.0,   // GHS/m² — bathroom/kitchen wall tiles all-in
          'paint':      50.0,   // GHS/m² — 2-coat emulsion/gloss (walls & ceiling)
          'ceiling':   120.0,   // GHS/m² — POP cornice/flat ceiling (labour & material)
          'skirting':   35.0,   // GHS/lin m — tile skirting (supply & fix)
          'doors':    2500.0,   // GHS/No. — flush door incl. frame & ironmongery
          'windows':  1800.0,   // GHS/No. — aluminium window incl. louvres & fixings
        },
        mep: {
          // Unit-rate basis (replaces the old % allocation approach)
          'wiring':        280.0,   // GHS/m² — conduit, cables, accessories all-in
          'consumerUnit': 2200.0,   // GHS/No. — DB board (12-way) incl. MCBs
          'powerPoints':   180.0,   // GHS/No. — 13A double socket incl. conduit run
          'lightFittings': 220.0,   // GHS/No. — LED fitting incl. switch & wiring
          'plumbing':      240.0,   // GHS/m² — supply & drainage (CPVC/uPVC)
          'overheadTank': 3500.0,   // GHS/No. — 2000L poly tank incl. galv. stand
          'pump':         2800.0,   // GHS/No. — surface pump incl. pressure switch
          'sanitarySet':  8500.0,   // GHS/set — WC + pedestal basin + shower tray + taps
          'septicTank':   9000.0,   // GHS/No. — concrete septic tank (2-chamber)
        },
        external: {
          'wallPct':        50.0,   // % of external budget — compound wall & gate
          'pavingPct':      30.0,   // % — paving / driveway
          'landscapingPct': 20.0,   // % — landscaping & site clearance
        },
        generic: {
          'materialsPct': 65.0,
          'labourPct':    35.0,
        },
      );

  factory BoqRateConfig.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    Map<String, double> parseMap(String key, Map<String, double> defaults) {
      final raw = data[key];
      if (raw is Map) {
        // Start with defaults so any new keys not yet in Firestore are present.
        final result = Map<String, double>.from(defaults);
        for (final e in raw.entries) {
          if (e.value is num) {
            result[e.key as String] = (e.value as num).toDouble();
          }
        }
        return result;
      }
      return defaults;
    }

    final d = BoqRateConfig.defaults();
    return BoqRateConfig(
      substructure: parseMap('substructure', d.substructure),
      superstructure: parseMap('superstructure', d.superstructure),
      roofing: parseMap('roofing', d.roofing),
      finishes: parseMap('finishes', d.finishes),
      mep: parseMap('mep', d.mep),
      external: parseMap('external', d.external),
      generic: parseMap('generic', d.generic),
      ssnitEmployerRate:
          (data['ssnitEmployerRate'] as num?)?.toDouble() ?? 0.13,
      ssnitEmployeeRate:
          (data['ssnitEmployeeRate'] as num?)?.toDouble() ?? 0.055,
    );
  }

  Map<String, dynamic> toMap() => {
        'substructure': substructure,
        'superstructure': superstructure,
        'roofing': roofing,
        'finishes': finishes,
        'mep': mep,
        'external': external,
        'generic': generic,
        'ssnitEmployerRate': ssnitEmployerRate,
        'ssnitEmployeeRate': ssnitEmployeeRate,
      };
}
