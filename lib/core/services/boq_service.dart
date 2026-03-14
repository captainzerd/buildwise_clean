// lib/core/services/boq_service.dart
//
// Generates a Bill of Quantities from estimate phase breakdown data.
//
// Quantity methodology
// ────────────────────
// Quantities are derived from building geometry (floor area, estimated
// perimeter, roof area) rather than back-calculated from cost totals.
// All item quantities are then scaled proportionally so their subtotal
// exactly matches the estimate's phase budget — keeping the internal
// ratios realistic while reconciling to the estimate figure.
//
// Perimeter estimate: P ≈ 4.5 × √A
//   (slightly wider than a perfect square to account for non-rectangular plans)
//
// Unit rates are loaded from Firestore `boq_rates/default` on init;
// falls back to Ghana market averages (Q1 2026) if Firestore is unavailable.

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/boq_item.dart';
import '../models/boq_rate_config.dart';

class BoqService {
  BoqService();

  final _db = FirebaseFirestore.instance;
  BoqRateConfig _rates = BoqRateConfig.defaults();

  /// Fetch rates from Firestore `boq_rates/default`. Keeps defaults on error.
  Future<void> init() async {
    try {
      final doc = await _db.collection('boq_rates').doc('default').get();
      if (doc.exists) {
        _rates = BoqRateConfig.fromDoc(doc);
      }
    } catch (e) {
      debugPrint('BoqService.init: failed to load rates, using defaults. $e');
    }
  }

  BoqRateConfig get rates => _rates;

  /// Generate a BoQ from [phaseBreakdown] (phase name → GHS amount).
  /// [floorAreaSqm] is the total built floor area.
  List<BoqItem> generate({
    required Map<String, double> phaseBreakdown,
    required double floorAreaSqm,
  }) {
    final items = <BoqItem>[];
    for (final entry in phaseBreakdown.entries) {
      items.addAll(_itemsForPhase(entry.key, entry.value, floorAreaSqm));
    }
    return items;
  }

  // ── Phase dispatcher ─────────────────────────────────────────────────────────

  List<BoqItem> _itemsForPhase(String phase, double total, double area) {
    final lc = phase.toLowerCase();
    if (lc.contains('substructure') || lc.contains('foundation')) {
      return _substructureItems(phase, total, area);
    } else if (lc.contains('superstructure') || lc.contains('walling')) {
      return _superstructureItems(phase, total, area);
    } else if (lc.contains('roof')) {
      return _roofingItems(phase, total, area);
    } else if (lc.contains('finish') || lc.contains('plaster')) {
      return _finishesItems(phase, total, area);
    } else if (lc.contains('mechanical') ||
        lc.contains('electrical') ||
        lc.contains('m&e') ||
        lc.contains('plumbing')) {
      return _meItems(phase, total, area);
    } else if (lc.contains('external') || lc.contains('compound')) {
      return _externalItems(phase, total);
    } else {
      return _genericItems(phase, total);
    }
  }

  // ── Substructure ─────────────────────────────────────────────────────────────
  //
  //   Excavation    : strip trenches = P × 0.6m wide × 0.9m deep
  //   Blinding      : ground slab footprint × 0.05m thick
  //   DPM           : area m²
  //   Anti-termite  : area m²
  //   Concrete      : strip footings (P×0.3×0.45) + ground slab (area×0.15m)
  //   Steel         : 25 kg/m² of floor area
  //   Formwork      : both faces of strip trench = P × 0.45m × 2
  //   Hardcore fill : area m² at implied 150mm depth (rate is all-in)
  //   Backfill      : 30% of excavation volume

  List<BoqItem> _substructureItems(
    String phase,
    double total,
    double area,
  ) {
    final r = _rates.substructure;
    final p = _perim(area);

    final excavVol = _r(p * 0.6 * 0.9);
    final blindingVol = _r(area * 0.05);
    final dpmArea = _r(area);
    final antiTArea = _r(area);
    final concVol = _r(p * 0.3 * 0.45 + area * 0.15);
    final steelTon = _r(area * 0.025);
    final fwkArea = _r(p * 0.45 * 2);
    final hcArea = _r(area);
    final bfillVol = _r(excavVol * 0.30);

    final raw = [
      _i(
        phase,
        'Excavation to reduced level & strip trenches',
        'm³',
        excavVol,
        r['excavation'] ?? 90.0,
      ),
      _i(
        phase,
        'Blinding concrete (50mm lean mix 1:3:6)',
        'm³',
        blindingVol,
        r['blinding'] ?? 380.0,
      ),
      _i(
        phase,
        'Polythene damp-proof membrane (1000g)',
        'm²',
        dpmArea,
        r['dpm'] ?? 12.0,
      ),
      _i(
        phase,
        'Anti-termite chemical treatment',
        'm²',
        antiTArea,
        r['antiTermite'] ?? 15.0,
      ),
      _i(
        phase,
        'C25 concrete — strip footings & ground floor slab',
        'm³',
        concVol,
        r['concrete'] ?? 650.0,
      ),
      _i(
        phase,
        'Reinforcement bars Y12–Y16 (foundations)',
        'ton',
        steelTon,
        r['steel'] ?? 8000.0,
      ),
      _i(
        phase,
        'Softwood formwork to foundation walls',
        'm²',
        fwkArea,
        r['formwork'] ?? 95.0,
      ),
      _i(
        phase,
        'Hardcore fill & compaction (150mm)',
        'm²',
        hcArea,
        r['hardcore'] ?? 75.0,
      ),
      _i(
        phase,
        'Earthwork backfill after foundation',
        'm³',
        bfillVol,
        r['backfill'] ?? 60.0,
      ),
    ];
    return _scaleItems(raw, total);
  }

  // ── Superstructure ───────────────────────────────────────────────────────────
  //
  //   Net wall area : 1.6 × P × 3m height × 0.80 (minus openings) = 3.84P
  //   Blocks        : net wall area × 10 blocks/m²
  //   Cement        : 1 bag per 25 blocks (1:4 mortar)
  //   Sand          : 0.005 m³ per block (≈ 1m³ per 200 blocks)
  //   Steel         : 30 kg/m² of floor area (columns + ring beam)
  //   Concrete      : area × 0.08 m³ (columns + ring beam)

  List<BoqItem> _superstructureItems(
    String phase,
    double total,
    double area,
  ) {
    final r = _rates.superstructure;
    final p = _perim(area);

    final blocks = _r(3.84 * p * 10);
    final cementBags = _r(blocks / 25);
    final sandVol = _r(blocks * 0.005);
    final steelTon = _r(area * 0.030);
    final concVol = _r(area * 0.08);

    final raw = [
      _i(
        phase,
        '6" hollow sandcrete blocks (supply)',
        'block',
        blocks,
        r['blocks'] ?? 9.0,
      ),
      _i(
        phase,
        'Block-laying labour',
        'block',
        blocks,
        r['blockLabour'] ?? 3.5,
      ),
      _i(
        phase,
        'OPC cement 50 kg bags (mortar & plaster base)',
        'bag',
        cementBags,
        r['cement'] ?? 105.0,
      ),
      _i(
        phase,
        'River/pit sand',
        'm³',
        sandVol,
        r['sand'] ?? 1100.0,
      ),
      _i(
        phase,
        'Reinforcement bars — columns & ring beam',
        'ton',
        steelTon,
        r['steel'] ?? 8000.0,
      ),
      _i(
        phase,
        'C25 concrete — columns, ring beam & suspended slab',
        'm³',
        concVol,
        r['concrete'] ?? 650.0,
      ),
    ];
    return _scaleItems(raw, total);
  }

  // ── Roofing ──────────────────────────────────────────────────────────────────
  //
  //   Roof area   : floor area × 1.35 (moderate pitch factor)
  //   Rafters     : roof area × 0.75 lin m
  //   Fascia      : perimeter lin m
  //   Gutters     : perimeter × 0.55 (eaves only, not gable ends)
  //   Downpipes   : max(2, gutterLength / 12)

  List<BoqItem> _roofingItems(String phase, double total, double area) {
    final r = _rates.roofing;
    final p = _perim(area);
    final roofArea = _r(area * 1.35);
    final rafterLm = _r(roofArea * 0.75);
    final fasciaLm = _r(p);
    final gutterLm = _r(p * 0.55);
    final dpCount = _r(math.max(2, (gutterLm / 12).ceilToDouble()));
    final ceilArea = _r(area);

    final raw = [
      _i(
        phase,
        'Long-span aluminium roofing sheets (supply & fix)',
        'm²',
        roofArea,
        r['aluminiumSheets'] ?? 130.0,
      ),
      _i(
        phase,
        'Purlins & battens (MS/timber, 600mm c/c)',
        'm²',
        roofArea,
        r['purlins'] ?? 50.0,
      ),
      _i(
        phase,
        'Timber rafters (50×100mm)',
        'lin m',
        rafterLm,
        r['rafters'] ?? 40.0,
      ),
      _i(
        phase,
        'Timber/UPVC fascia board',
        'lin m',
        fasciaLm,
        r['fascia'] ?? 55.0,
      ),
      _i(
        phase,
        'UPVC half-round gutters (supply & fix)',
        'lin m',
        gutterLm,
        r['gutters'] ?? 45.0,
      ),
      _i(
        phase,
        'UPVC downpipes incl. brackets & shoe',
        'No.',
        dpCount,
        r['downpipes'] ?? 280.0,
      ),
      _i(
        phase,
        'Ceiling board (Gyproc/POP) incl. framing',
        'm²',
        ceilArea,
        r['ceiling'] ?? 120.0,
      ),
    ];
    return _scaleItems(raw, total);
  }

  // ── Finishes ─────────────────────────────────────────────────────────────────
  //
  //   Wall plaster : P × 3m × 2 faces × 0.85 (minus openings) = 5.1P m²
  //   Screed       : floor area m²
  //   Floor tiles  : floor area m²
  //   Wall tiles   : 12% of floor area (bathrooms + kitchen splashbacks)
  //   Paint        : wall plaster area + ceiling area
  //   Ceiling(POP) : floor area m²
  //   Skirting     : 2× perimeter lin m (all rooms)
  //   Doors/Windows: derived from area ratios

  List<BoqItem> _finishesItems(String phase, double total, double area) {
    final r = _rates.finishes;
    final p = _perim(area);

    final wallArea = _r(p * 5.1);
    final screedArea = _r(area);
    final floorArea = _r(area);
    final wetWallArea = _r(area * 0.12);
    final paintArea = _r(wallArea + area);
    final ceilArea = _r(area);
    final skirtingLm = _r((p * 2).clamp(20, 300));
    final doorCount = _r((area / 15).clamp(3, 25));
    final winCount = _r((area / 10).clamp(4, 35));

    final raw = [
      _i(
        phase,
        'Sand/cement plaster — walls (2 coats)',
        'm²',
        wallArea,
        r['plaster'] ?? 70.0,
      ),
      _i(
        phase,
        'Cement/sand floor screed (50mm)',
        'm²',
        screedArea,
        r['screed'] ?? 65.0,
      ),
      _i(
        phase,
        'Ceramic floor tiles — all rooms (supply & lay)',
        'm²',
        floorArea,
        r['tiles'] ?? 195.0,
      ),
      _i(
        phase,
        'Glazed wall tiles — bathrooms & kitchen',
        'm²',
        wetWallArea,
        r['wallTiles'] ?? 220.0,
      ),
      _i(
        phase,
        'Interior & exterior paint (2 coats emulsion/gloss)',
        'm²',
        paintArea,
        r['paint'] ?? 50.0,
      ),
      _i(
        phase,
        'POP/gypsum ceiling (flat with cornice)',
        'm²',
        ceilArea,
        r['ceiling'] ?? 120.0,
      ),
      _i(
        phase,
        'Tile skirting (supply & fix)',
        'lin m',
        skirtingLm,
        r['skirting'] ?? 35.0,
      ),
      _i(
        phase,
        'Flush doors incl. frame & ironmongery',
        'No.',
        doorCount,
        r['doors'] ?? 2500.0,
      ),
      _i(
        phase,
        'Aluminium windows incl. louvres & fixings',
        'No.',
        winCount,
        r['windows'] ?? 1800.0,
      ),
    ];
    return _scaleItems(raw, total);
  }

  // ── Mechanical & Electrical ──────────────────────────────────────────────────
  //
  //   All items unit-rate based (no more % allocations).
  //   Power points  : 1 per 8 m², min 8, max 50
  //   Light fittings: 1 per 10 m², min 6, max 40
  //   Sanitary sets : 1 per 30 m², min 1, max 6 (≈ number of bathrooms)

  List<BoqItem> _meItems(String phase, double total, double area) {
    final r = _rates.mep;

    final ppCount = _r((area / 8).clamp(8, 50));
    final lfCount = _r((area / 10).clamp(6, 40));
    final sanCount = _r((area / 30).clamp(1, 6));

    final raw = [
      _i(
        phase,
        'Electrical conduit wiring, cables & accessories',
        'm²',
        _r(area),
        r['wiring'] ?? 280.0,
      ),
      _i(
        phase,
        'Consumer unit / distribution board (12-way)',
        'No.',
        1,
        r['consumerUnit'] ?? 2200.0,
      ),
      _i(
        phase,
        '13A double power points incl. conduit run',
        'No.',
        ppCount,
        r['powerPoints'] ?? 180.0,
      ),
      _i(
        phase,
        'LED light fittings incl. switches & wiring',
        'No.',
        lfCount,
        r['lightFittings'] ?? 220.0,
      ),
      _i(
        phase,
        'Plumbing — CPVC/uPVC supply & drainage',
        'm²',
        _r(area),
        r['plumbing'] ?? 240.0,
      ),
      _i(
        phase,
        '2000L polyethylene overhead tank & galv. stand',
        'No.',
        1,
        r['overheadTank'] ?? 3500.0,
      ),
      _i(
        phase,
        'Surface pump incl. pressure switch & fittings',
        'No.',
        1,
        r['pump'] ?? 2800.0,
      ),
      _i(
        phase,
        'Sanitary set — WC, pedestal basin, shower & taps',
        'set',
        sanCount,
        r['sanitarySet'] ?? 8500.0,
      ),
      _i(
        phase,
        'Concrete septic tank (2-chamber)',
        'No.',
        1,
        r['septicTank'] ?? 9000.0,
      ),
    ];
    return _scaleItems(raw, total);
  }

  // ── External Works ───────────────────────────────────────────────────────────
  // Plot dimensions unknown — % splits of phase total used.

  List<BoqItem> _externalItems(String phase, double total) {
    final r = _rates.external;
    final wallPct = (r['wallPct'] ?? 50) / 100;
    final pavePct = (r['pavingPct'] ?? 30) / 100;
    final landPct = (r['landscapingPct'] ?? 20) / 100;

    return [
      _i(
        phase,
        'Compound wall, gate & boundary fencing',
        'Lump sum',
        1,
        total * wallPct,
      ),
      _i(
        phase,
        'Paving, driveway & car port',
        'Lump sum',
        1,
        total * pavePct,
      ),
      _i(
        phase,
        'Landscaping, site clearance & top-soil',
        'Lump sum',
        1,
        total * landPct,
      ),
    ];
  }

  // ── Generic fallback ─────────────────────────────────────────────────────────

  List<BoqItem> _genericItems(String phase, double total) {
    final matPct = (_rates.generic['materialsPct'] ?? 65) / 100;
    final labPct = (_rates.generic['labourPct'] ?? 35) / 100;
    return [
      _i(phase, 'Materials allowance', 'Lump sum', 1, total * matPct),
      _i(phase, 'Labour allowance', 'Lump sum', 1, total * labPct),
    ];
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Estimate building perimeter from floor area.
  static double _perim(double area) => 4.5 * math.sqrt(area);

  /// Scale all item quantities so that Σ(qty × rate) == [target].
  List<BoqItem> _scaleItems(List<BoqItem> items, double target) {
    final geomTotal = items.fold<double>(0.0, (acc, e) => acc + e.totalGhs);
    if (geomTotal <= 0) return items;
    final factor = target / geomTotal;
    return items
        .map(
          (it) => BoqItem(
            phase: it.phase,
            description: it.description,
            unit: it.unit,
            quantity: _r(it.quantity * factor),
            unitRateGhs: it.unitRateGhs,
          ),
        )
        .toList();
  }

  /// Convenience constructor for a BOQ line item.
  static BoqItem _i(
    String phase,
    String description,
    String unit,
    double quantity,
    double unitRateGhs,
  ) =>
      BoqItem(
        phase: phase,
        description: description,
        unit: unit,
        quantity: quantity,
        unitRateGhs: unitRateGhs,
      );

  /// Round to 2 decimal places.
  static double _r(double v) => (v * 100).roundToDouble() / 100;
}
