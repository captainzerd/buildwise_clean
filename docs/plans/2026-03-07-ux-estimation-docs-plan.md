# UX, Estimation & Document Management Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the approved design at `docs/plans/2026-03-07-ux-estimation-docs-design.md` — covering estimation logic, document management, project creation alignment, and UX/UI fixes across all screens.

**Architecture:** BuildingTypology replaces the binary `buildingType` string throughout; EstimationEngine gains corrected multipliers + new inputs; DocumentCategory gains 4 new values; architecture plans are stored as ProjectDocuments instead of bare URLs.

**Tech Stack:** Flutter 3.x, Firebase Firestore/Storage, Provider (ChangeNotifier), GoRouter, shared_preferences.

---

## Task 1: Add BuildingTypology enum and update EstimationEngine multipliers

**Files:**
- Modify: `lib/core/use_cases/calculate_estimate.dart`
- Modify: `lib/features/estimate/state/estimate_controller.dart`

**Step 1: Add `BuildingTypology` enum at the top of `calculate_estimate.dart` (after the `PermitMode` enum)**

```dart
enum BuildingTypology {
  residentialStandard,
  residentialMediumRise,
  residentialHighRise,
  commercialOffice,
  commercialRetail,
  commercialWarehouse;

  double get costMultiplier => switch (this) {
        BuildingTypology.residentialStandard => 1.00,
        BuildingTypology.residentialMediumRise => 1.18,
        BuildingTypology.residentialHighRise => 1.40,
        BuildingTypology.commercialOffice => 1.22,
        BuildingTypology.commercialRetail => 1.28,
        BuildingTypology.commercialWarehouse => 0.88,
      };

  String get displayLabel => switch (this) {
        BuildingTypology.residentialStandard =>
          'Residential Standard (Bungalow / Duplex / Terraced)',
        BuildingTypology.residentialMediumRise =>
          'Residential Medium-rise (Apt Block 3–6 storeys)',
        BuildingTypology.residentialHighRise =>
          'Residential High-rise (Apt Block 7+ storeys)',
        BuildingTypology.commercialOffice =>
          'Commercial Office / Bank / Institution',
        BuildingTypology.commercialRetail => 'Commercial Retail / Mixed Use',
        BuildingTypology.commercialWarehouse =>
          'Commercial Warehouse / Factory / Store',
      };

  String get subtitle => switch (this) {
        BuildingTypology.residentialStandard =>
          'Bungalow, duplex or terraced house',
        BuildingTypology.residentialMediumRise =>
          'Apartment block, 3–6 storeys',
        BuildingTypology.residentialHighRise =>
          'High-rise apartments, 7+ storeys',
        BuildingTypology.commercialOffice =>
          'Office, bank or institution',
        BuildingTypology.commercialRetail =>
          'Retail shop, mall or mixed-use',
        BuildingTypology.commercialWarehouse =>
          'Warehouse, factory or store',
      };

  IconData get icon => switch (this) {
        BuildingTypology.residentialStandard => Icons.home_outlined,
        BuildingTypology.residentialMediumRise => Icons.apartment_outlined,
        BuildingTypology.residentialHighRise => Icons.location_city_outlined,
        BuildingTypology.commercialOffice => Icons.business_outlined,
        BuildingTypology.commercialRetail => Icons.storefront_outlined,
        BuildingTypology.commercialWarehouse => Icons.warehouse_outlined,
      };

  /// Parse from string stored in controller / Firestore.
  static BuildingTypology fromString(String? v) => switch (v) {
        'residentialMediumRise' =>
          BuildingTypology.residentialMediumRise,
        'residentialHighRise' => BuildingTypology.residentialHighRise,
        'commercialOffice' => BuildingTypology.commercialOffice,
        'commercialRetail' => BuildingTypology.commercialRetail,
        'commercialWarehouse' => BuildingTypology.commercialWarehouse,
        _ => BuildingTypology.residentialStandard,
      };
}
```

Add `import 'package:flutter/material.dart';` at the top of `calculate_estimate.dart` (it already imports `flutter/foundation.dart` — replace that import so `Icons` is available):

Actually, `Icons` requires the full Flutter material package. Instead, use `String` icon name keys and let the UI resolve icons. Replace the `IconData get icon` getter above with a simple `String get iconKey` and let Step 2 UI map these to actual Icons. Update the enum:

```dart
  String get iconKey => switch (this) {
        BuildingTypology.residentialStandard => 'home',
        BuildingTypology.residentialMediumRise => 'apartment',
        BuildingTypology.residentialHighRise => 'location_city',
        BuildingTypology.commercialOffice => 'business',
        BuildingTypology.commercialRetail => 'storefront',
        BuildingTypology.commercialWarehouse => 'warehouse',
      };
```

**Step 2: Replace `buildingType: String` field in `EstimateInput` with `typology: BuildingTypology`**

In `calculate_estimate.dart`, change in `EstimateInput`:
```dart
// Remove:
  final String buildingType;

// Add:
  final BuildingTypology typology;
```

Also add the new M&E tier and curtain wall fields (Task 2 extends these — stub them here):
```dart
  // Services tier
  final bool enhancedServices;   // true = Enhanced (×1.18)
  // Curtain wall / large glazing
  final bool curtainWall;        // true = openings at 8% instead of 4%
  // New external works
  final bool includeWaterTank;
  final bool includeGeneratorHouse;
  final bool includeSwimmingPool;
  final double swimmingPoolGhs;
  final double securityWallLenM;
  final double securityWallRatePerM;
```

Set defaults throughout: `enhancedServices = false`, `curtainWall = false`, etc. These are `required` parameters in the constructor — the controller must pass them.

**Step 3: Update `EstimationEngine.calculate()` — corrected multipliers and new typology logic**

Replace the multiplier block in `EstimationEngine.calculate()`:

```dart
    // ── Specification multipliers (GhBC 2024) ──────────────────────────────
    final foundationMul = switch (i.foundation) {
      'Raft' => 1.22,   // was 1.25
      'Pad' => 1.15,
      'Pile' => 1.55,   // was 1.65
      _ => 1.00,
    };
    final soilMul = switch (i.soil) {
      'Soft' => 1.15,
      'Waterlogged' => 1.25,  // was 1.30
      _ => 1.00,
    };
    final roofMul = switch (i.roof) {
      'Concrete flat' => 1.38,  // was 1.45
      'Tile' => 1.25,
      _ => 1.00,
    };
    final typologyMul = i.typology.costMultiplier;
    final servicesMul = i.enhancedServices ? 1.18 : 1.00;
    final storeyPremium =
        i.floors.length > 1 ? 1.0 + (i.floors.length - 1) * 0.10 : 1.00;
```

Update the phase adjustment loop to use `typologyMul` instead of `typeMul`:

```dart
    for (final key in phaseGhs.keys.toList()) {
      final lc = key.toLowerCase();
      if (lc.contains('sub') || lc.contains('foundation')) {
        phaseGhs[key] = phaseGhs[key]! * foundationMul * soilMul;
      } else if (lc.contains('super') || lc.contains('walling')) {
        phaseGhs[key] = phaseGhs[key]! * typologyMul * storeyPremium;
      } else if (lc.contains('roof')) {
        phaseGhs[key] = phaseGhs[key]! * roofMul;
      } else if (lc.contains('service') ||
          lc.contains('mep') ||
          lc.contains('m&e') ||
          lc.contains('plumbing') ||
          lc.contains('electrical')) {
        phaseGhs[key] = phaseGhs[key]! * typologyMul * servicesMul;
      }
    }
```

**Step 4: Add new external works to addOns block**

After the existing septic block, add:

```dart
      if (i.includeWaterTank) {
        addOns['Water storage tank'] = 5000.0;
        addOnsTotal += 5000.0;
      }
      if (i.includeGeneratorHouse) {
        addOns['Generator house'] = 12000.0;
        addOnsTotal += 12000.0;
      }
      if (i.includeSwimmingPool) {
        addOns['Swimming pool'] = i.swimmingPoolGhs;
        addOnsTotal += i.swimmingPoolGhs;
      }
      if (i.securityWallLenM > 0) {
        final sw = i.securityWallLenM * i.securityWallRatePerM;
        addOns['Security wall'] = sw;
        addOnsTotal += sw;
      }
```

**Step 5: Add `specificationBreakdownGhs` to `EstimateResult`**

In `EstimateResult`, add new field:
```dart
  final Map<String, double> specificationBreakdownGhs;
```

In the `calculate()` method, compute the breakdown after all multipliers are applied. The baseline is `baseGhs` before any spec multipliers. Compute each premium as the _difference_ from baseline phases:

```dart
    // ── Specification cost attribution ─────────────────────────────────────
    // Baseline = phases computed on base cost with no spec multipliers
    final Map<String, double> baselinePhases = {};
    i.phasePercents.forEach((name, pct) => baselinePhases[name] = baseGhs * pct);
    final baselineDirect = baselinePhases.values.fold<double>(0, (a, b) => a + b);

    final specBreakdown = <String, double>{
      'Baseline': baselineDirect,
      if (i.typology != BuildingTypology.residentialStandard)
        'Building typology ${i.typology.costMultiplier > 1 ? "premium" : "discount"}':
            adjustedDirectCost - baselineDirect,
    };
    // Foundation uplift on substructure phases only
    final subPhasesBaseline = baselinePhases.entries
        .where((e) => e.key.toLowerCase().contains('sub') ||
            e.key.toLowerCase().contains('foundation'))
        .fold<double>(0, (a, e) => a + e.value);
    if (foundationMul != 1.00) {
      specBreakdown['Foundation uplift'] =
          subPhasesBaseline * (foundationMul - 1.0);
    }
    if (soilMul != 1.00) {
      specBreakdown['Soil condition uplift'] =
          subPhasesBaseline * foundationMul * (soilMul - 1.0);
    }
    final roofPhaseBaseline = baselinePhases.entries
        .where((e) => e.key.toLowerCase().contains('roof'))
        .fold<double>(0, (a, e) => a + e.value);
    if (roofMul != 1.00) {
      specBreakdown['Roof type uplift'] =
          roofPhaseBaseline * (roofMul - 1.0);
    }
    final servicePhaseBaseline = baselinePhases.entries
        .where((e) {
          final lc = e.key.toLowerCase();
          return lc.contains('service') || lc.contains('mep') ||
              lc.contains('m&e') || lc.contains('plumbing') ||
              lc.contains('electrical');
        })
        .fold<double>(0, (a, e) => a + e.value);
    if (servicesMul != 1.00) {
      specBreakdown['Services tier uplift'] =
          servicePhaseBaseline * typologyMul * (servicesMul - 1.0);
    }
    if (addOnsTotal > 0) {
      specBreakdown['External works'] = addOnsTotal;
    }
```

Then pass it to `EstimateResult(specificationBreakdownGhs: specBreakdown, ...)`.

**Step 6: Update `EstimateController` — change `buildingType` to `typology`**

In `lib/features/estimate/state/estimate_controller.dart`:

```dart
// Remove:
  String buildingType = 'Residential';

// Add:
  BuildingTypology typology = BuildingTypology.residentialStandard;
  bool enhancedServices = false;
  bool curtainWall = false;
  bool includeWaterTank = false;
  bool includeGeneratorHouse = false;
  bool includeSwimmingPool = false;
  double swimmingPoolGhs = 62500;
  double securityWallLenM = 0;
  static const double _securityWallRatePerM = 1400.0;
```

Update `setProgramme` to accept `typology_`:
```dart
  void setProgramme({
    BuildingTypology? typology_,
    String? quality_,
    String? foundation_,
    String? soil_,
    String? roof_,
    int? storeys_,
  }) {
    if (typology_ != null) typology = typology_;
    // ... rest unchanged
  }
```

Add setters for the new fields:
```dart
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
```

Update `compute()` — the `EstimateInput` construction must use `typology:` instead of `buildingType:` and pass all new fields.

Update `saveFormState()` / `restoreFormState()` to persist `typology` as its name string.

Update `toMap()` to include `typology: typology.name`.

**Step 7: Verify no compile errors — run**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/core/use_cases/calculate_estimate.dart lib/features/estimate/state/estimate_controller.dart 2>&1 | head -40
```

Expected: 0 errors.

**Step 8: Commit**

```bash
git add lib/core/use_cases/calculate_estimate.dart lib/features/estimate/state/estimate_controller.dart
git commit -m "feat(estimate): BuildingTypology enum, corrected GhBC 2024 multipliers, new inputs"
```

---

## Task 2: Step 2 UI — illustrated ChoiceChip grid for typology + M&E tier

**Files:**
- Modify: `lib/features/estimate/widgets/step2_building.dart`

**Step 1: Replace the binary dropdown with a 2-column ChoiceChip grid**

The grid uses a `Wrap` with 2 cards per row. Each card shows: icon + label + subtitle. Selecting a card calls `controller.setProgramme(typology_: t)`.

Replace the current `DropdownButtonFormField<String>` for building type (lines 35–44) with:

```dart
          // ── Building typology grid ─────────────────────────────────────
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BuildingTypology.values.map((t) {
              final selected = controller.typology == t;
              final cs = Theme.of(context).colorScheme;
              return GestureDetector(
                onTap: () => controller.setProgramme(typology_: t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: (MediaQuery.of(context).size.width - 48) / 2,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primaryContainer
                        : cs.surfaceContainerHighest,
                    border: Border.all(
                      color: selected ? cs.primary : cs.outlineVariant,
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _typologyIcon(t),
                        color: selected ? cs.primary : cs.onSurfaceVariant,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _typologyShortLabel(t),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? cs.onPrimaryContainer
                                  : cs.onSurface,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: selected
                                  ? cs.onPrimaryContainer.withValues(alpha: 0.75)
                                  : cs.onSurfaceVariant,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
```

Add the helper methods at the bottom of the file (outside the widget class but in same file):

```dart
IconData _typologyIcon(BuildingTypology t) => switch (t) {
      BuildingTypology.residentialStandard => Icons.home_outlined,
      BuildingTypology.residentialMediumRise => Icons.apartment_outlined,
      BuildingTypology.residentialHighRise => Icons.location_city_outlined,
      BuildingTypology.commercialOffice => Icons.business_outlined,
      BuildingTypology.commercialRetail => Icons.storefront_outlined,
      BuildingTypology.commercialWarehouse => Icons.warehouse_outlined,
    };

String _typologyShortLabel(BuildingTypology t) => switch (t) {
      BuildingTypology.residentialStandard => 'Residential Standard',
      BuildingTypology.residentialMediumRise => 'Medium-rise Apt',
      BuildingTypology.residentialHighRise => 'High-rise Apt',
      BuildingTypology.commercialOffice => 'Office / Institution',
      BuildingTypology.commercialRetail => 'Retail / Mixed Use',
      BuildingTypology.commercialWarehouse => 'Warehouse / Factory',
    };
```

Add the import at the top of step2_building.dart:
```dart
import '../../../core/use_cases/calculate_estimate.dart' show BuildingTypology;
```

**Step 2: Add M&E services tier toggle below roof dropdown**

After the `roof` dropdown, add:

```dart
          const SizedBox(height: 16),
          sectionLabel(context, 'Services & Openings'),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enhanced M&E services'),
            subtitle: const Text(
              'AC, solar-ready, smart wiring, 3-phase power (+18%)',
            ),
            value: controller.enhancedServices,
            onChanged: controller.setEnhancedServices,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Curtain wall / large glazing'),
            subtitle: const Text('Openings allocation raised to 8% of base'),
            value: controller.curtainWall,
            onChanged: controller.setCurtainWall,
          ),
```

**Step 3: Analyze**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/features/estimate/widgets/step2_building.dart 2>&1 | head -30
```

**Step 4: Commit**

```bash
git add lib/features/estimate/widgets/step2_building.dart
git commit -m "feat(estimate): illustrated ChoiceChip typology grid, M&E tier toggle in Step 2"
```

---

## Task 3: Step 4 UI — ExpansionTile sections + new external works

**Files:**
- Modify: `lib/features/estimate/widgets/step4_extras.dart`

**Step 1: Wrap all sections in ExpansionTiles**

Replace the existing flat column structure with `ExpansionTile` sections. The full replacement for the `child:` of `StepScaffold`:

```dart
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── External works ─────────────────────────────────────────────
          ExpansionTile(
            initiallyExpanded: true,
            title: const Text('External Works'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include external works'),
                value: controller.includeExternalWorks,
                onChanged: (v) => controller.setExternalWorks(enabled: v),
              ),
              if (controller.includeExternalWorks) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue:
                            controller.externalWallLenM.toStringAsFixed(0),
                        decoration: const InputDecoration(
                          labelText: 'Compound wall',
                          suffixText: 'm',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (v) => controller.setExternalWorks(
                          wallLenM: double.tryParse(v) ?? 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue:
                            controller.drivewayAreaM2.toStringAsFixed(0),
                        decoration: const InputDecoration(
                          labelText: 'Driveway',
                          suffixText: 'm²',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (v) => controller.setExternalWorks(
                          driveM2: double.tryParse(v) ?? 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include septic/soakaway'),
                  value: controller.includeSeptic,
                  onChanged: (v) =>
                      controller.setExternalWorks(septic: v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Water storage tank'),
                  subtitle: const Text('Fixed: GH\u20b5 5,000'),
                  value: controller.includeWaterTank,
                  onChanged: (v) => controller.setWaterTank(v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Generator house'),
                  subtitle: const Text('Fixed: GH\u20b5 12,000'),
                  value: controller.includeGeneratorHouse,
                  onChanged: (v) => controller.setGeneratorHouse(v ?? false),
                ),
                // Swimming pool
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Swimming pool'),
                  value: controller.includeSwimmingPool,
                  onChanged: (v) =>
                      controller.setSwimmingPool(enabled: v),
                ),
                if (controller.includeSwimmingPool) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        const Text('GH\u20b5 '),
                        Expanded(
                          child: Slider(
                            value: controller.swimmingPoolGhs
                                .clamp(45000, 80000),
                            min: 45000,
                            max: 80000,
                            divisions: 35,
                            label: 'GH\u20b5 '
                                '${controller.swimmingPoolGhs.toStringAsFixed(0)}',
                            onChanged: (v) =>
                                controller.setSwimmingPool(amountGhs: v),
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            controller.swimmingPoolGhs.toStringAsFixed(0),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Security wall
                const SizedBox(height: 4),
                TextFormField(
                  initialValue:
                      controller.securityWallLenM.toStringAsFixed(0),
                  decoration: const InputDecoration(
                    labelText: 'Security wall with barbed wire',
                    suffixText: 'm  @ GH\u20b5 1,400/m',
                    helperText: 'Enter linear metres (0 = not included)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) =>
                      controller.setSecurityWall(double.tryParse(v) ?? 0),
                ),
              ],
            ],
          ),

          // ── Commercials ────────────────────────────────────────────────
          ExpansionTile(
            initiallyExpanded: true,
            title: const Text('Commercials'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              LabeledSlider(
                label: 'Preliminaries',
                value: controller.preliminariesPct,
                min: 0,
                max: 20,
                onChanged: controller.setPreliminariesPct,
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Contingency'),
                value: controller.contingencyEnabled,
                onChanged: controller.setContingencyEnabled,
              ),
              if (controller.contingencyEnabled)
                LabeledSlider(
                  label: 'Contingency',
                  value: controller.contingencyPct,
                  min: 0,
                  max: 20,
                  onChanged: controller.setContingencyPct,
                ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Professional fees'),
                value: controller.professionalFeesEnabled,
                onChanged: controller.setProfessionalFeesEnabled,
              ),
              if (controller.professionalFeesEnabled)
                LabeledSlider(
                  label: 'Professional fees',
                  value: controller.professionalFeesPct,
                  min: 0,
                  max: 15,
                  onChanged: controller.setProfessionalFeesPct,
                ),
            ],
          ),

          // ── Permit ─────────────────────────────────────────────────────
          ExpansionTile(
            title: const Text('Permit'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              // Retain existing permit UI unchanged
              _PermitSection(),
            ],
          ),

          // ── Budget Comparison ──────────────────────────────────────────
          ExpansionTile(
            title: const Text('Budget Comparison'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              _BudgetSection(),
            ],
          ),
        ],
      ),
```

Note: `_PermitSection` and `_BudgetSection` are extracted private helper widgets. Extract the existing permit and budget UI code from the current file into these two private StatelessWidget classes. Look at the existing code below the external works section (around lines 87–200+) and extract unchanged.

**Step 2: Analyze**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/features/estimate/widgets/step4_extras.dart 2>&1 | head -30
```

**Step 3: Commit**

```bash
git add lib/features/estimate/widgets/step4_extras.dart
git commit -m "feat(estimate): ExpansionTile sections in Step 4, new external works (tank, generator, pool, security wall)"
```

---

## Task 4: Result page — Specification Breakdown tab

**Files:**
- Modify: `lib/features/estimate/estimate_result_page.dart`

**Step 1: Add a `TabBar` with two tabs below the total card**

Wrap the current list body in a `DefaultTabController`. Replace the `ListView` with a `Column` that has a `TabBar` + `TabBarView`.

Add at the top of `_EstimateResultPageState`:
```dart
  final _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
```

The class needs `with SingleTickerProviderStateMixin`:
```dart
class _EstimateResultPageState extends State<EstimateResultPage>
    with SingleTickerProviderStateMixin {
```

In the `build` method, below the total card and budget compare, add:

```dart
          // ── Tab toggle ──────────────────────────────────────────────────
          Card(
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Phase Breakdown'),
                Tab(text: 'Specification'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Tab views ───────────────────────────────────────────────────
          SizedBox(
            height: 500, // approximate content height
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Tab 1: existing phase/trade breakdown
                Column(
                  children: [
                    if (r.phaseBreakdownGhs.isNotEmpty)
                      _PhaseChart(
                        phases: r.phaseBreakdownGhs,
                        moneyFn: controller.money,
                      ),
                    const SizedBox(height: 16),
                    _TradeBreakdownCard(
                      phases: r.phaseBreakdownGhs,
                      moneyFn: controller.money,
                    ),
                  ],
                ),
                // Tab 2: specification breakdown
                _SpecificationBreakdownCard(
                  breakdown: r.specificationBreakdownGhs,
                  moneyFn: controller.money,
                ),
              ],
            ),
          ),
```

Remove the existing standalone `_PhaseChart` and `_TradeBreakdownCard` from the ListView (they're now inside Tab 1).

**Step 2: Add `_SpecificationBreakdownCard` widget at bottom of file**

```dart
class _SpecificationBreakdownCard extends StatelessWidget {
  const _SpecificationBreakdownCard({
    required this.breakdown,
    required this.moneyFn,
  });

  final Map<String, double> breakdown;
  final String Function(double) moneyFn;

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No specification breakdown available.'),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cost by Specification',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...breakdown.entries.map((e) {
              final isNegative = e.value < 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(e.key)),
                    Text(
                      '${isNegative ? '-' : '+'}${moneyFn(e.value.abs())}',
                      style: TextStyle(
                        color: isNegative ? cs.error : cs.primary,
                        fontWeight: e.key == 'Baseline'
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
```

**Step 3: Analyze + commit**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/features/estimate/estimate_result_page.dart 2>&1 | head -30
git add lib/features/estimate/estimate_result_page.dart
git commit -m "feat(estimate): Specification Breakdown tab on result page"
```

---

## Task 5: Expand DocumentCategory enum

**Files:**
- Modify: `lib/core/models/project_document.dart`

**Step 1: Add 4 new enum values**

Replace the existing `enum DocumentCategory` block with:

```dart
enum DocumentCategory {
  architecturalDrawing,
  structuralDrawing,
  landTitle,
  indenture,
  permit,
  boq,
  receipt,
  contract,
  other;

  String get label => switch (this) {
        DocumentCategory.architecturalDrawing => 'Architectural Drawing',
        DocumentCategory.structuralDrawing => 'Structural Drawing',
        DocumentCategory.landTitle => 'Land Title',
        DocumentCategory.indenture => 'Indenture / Deed',
        DocumentCategory.permit => 'Building Permit',
        DocumentCategory.boq => 'Bill of Quantities',
        DocumentCategory.receipt => 'Receipt / Invoice',
        DocumentCategory.contract => 'Contract',
        DocumentCategory.other => 'Other',
      };

  String get firestoreValue => switch (this) {
        DocumentCategory.architecturalDrawing => 'architecturalDrawing',
        DocumentCategory.structuralDrawing => 'structuralDrawing',
        DocumentCategory.landTitle => 'landTitle',
        DocumentCategory.indenture => 'indenture',
        DocumentCategory.permit => 'permit',
        DocumentCategory.boq => 'boq',
        DocumentCategory.receipt => 'receipt',
        DocumentCategory.contract => 'contract',
        DocumentCategory.other => 'other',
      };

  IconData get icon => switch (this) {
        DocumentCategory.architecturalDrawing => Icons.architecture,
        DocumentCategory.structuralDrawing => Icons.engineering,
        DocumentCategory.landTitle => Icons.landscape,
        DocumentCategory.indenture => Icons.gavel,
        DocumentCategory.permit => Icons.approval,
        DocumentCategory.boq => Icons.format_list_numbered,
        DocumentCategory.receipt => Icons.receipt_long,
        DocumentCategory.contract => Icons.handshake,
        DocumentCategory.other => Icons.attach_file,
      };

  static DocumentCategory fromString(String? value) => switch (value) {
        'architecturalDrawing' => DocumentCategory.architecturalDrawing,
        'structuralDrawing' => DocumentCategory.structuralDrawing,
        'landTitle' => DocumentCategory.landTitle,
        'indenture' => DocumentCategory.indenture,
        'permit' => DocumentCategory.permit,
        'boq' => DocumentCategory.boq,
        'receipt' => DocumentCategory.receipt,
        'contract' => DocumentCategory.contract,
        _ => DocumentCategory.other,
      };
}
```

Add `import 'package:flutter/material.dart';` at the top (replace `import 'package:cloud_firestore/cloud_firestore.dart';` if needed — keep both).

**Step 2: Analyze + commit**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/core/models/project_document.dart 2>&1 | head -20
git add lib/core/models/project_document.dart
git commit -m "feat(docs): expand DocumentCategory enum — architecturalDrawing, structuralDrawing, boq, contract"
```

---

## Task 6: Architecture plan → ProjectDocument integration

**Files:**
- Modify: `lib/core/models/project.dart`
- Modify: `lib/features/project/create_project_page.dart`
- Modify: `lib/core/services/project_service.dart`

**Step 1: Read project.dart first, then add a deprecation note on `architecturePlanUrl`**

Read the file: look for `architecturePlanUrl` field. Add a doc comment:
```dart
  /// Deprecated. Architecture plans are now stored as ProjectDocument
  /// with category: DocumentCategory.architecturalDrawing.
  /// This field is kept for backward compatibility with existing data.
  final String? architecturePlanUrl;
```

**Step 2: Update `_uploadArchitecturePlan` in `create_project_page.dart` to create a `ProjectDocument`**

The current `_uploadArchitecturePlan` uploads to `project_docs/$uid/arch_plans/` and stores a URL in `_architecturePlanUrl`. After project creation (`projectId` is returned from `createProject`), the architecture plan must be saved as a document.

The upload in `create_project_page.dart` currently runs _before_ project creation. Change the flow:
1. At upload time: store the file path and download URL in local state fields `_archPlanLocalPath` and `_archPlanFileName`.
2. After `createProject` returns `projectId`, call a new `_saveArchPlanAsDocument(projectId, ...)` helper.

Add to state:
```dart
  String? _archPlanLocalPath;
  String? _archPlanFileName;
  String? _archPlanContentType;
```

Update `_uploadArchitecturePlan`:
```dart
  Future<void> _uploadArchitecturePlan() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'dwg'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    setState(() {
      _archPlanLocalPath = file.path;
      _archPlanFileName = file.name;
      _archPlanContentType = _inferContentType(file.name);
      _uploadingPlan = true;
    });
    try {
      final uid = context.read<AuthService>().currentUser?.uid ?? 'anon';
      final ref = FirebaseStorage.instance
          .ref('project_docs/$uid/arch_plans/${file.name}');
      await ref.putFile(File(file.path!));
      final url = await ref.getDownloadURL();
      // Keep the URL for backward compat (passes into Project.architecturePlanUrl)
      setState(() => _architecturePlanUrl = url);
    } catch (_) {
      // Ignore
    } finally {
      if (mounted) setState(() => _uploadingPlan = false);
    }
  }

  String? _inferContentType(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };
  }
```

Add after `saveBoq` call inside `_save()`:
```dart
      // Save architecture plan as a ProjectDocument.
      if (_architecturePlanUrl != null && _archPlanFileName != null) {
        final uid = auth.currentUser!.uid;
        final doc = ProjectDocument(
          id: '',
          uploaderUid: uid,
          name: _archPlanFileName!,
          url: _architecturePlanUrl!,
          category: DocumentCategory.architecturalDrawing,
          storagePath:
              'project_docs/$uid/arch_plans/$_archPlanFileName',
          contentType: _archPlanContentType,
          visibility: DocumentVisibility.all,
          createdAt: DateTime.now(),
        );
        await projectService.uploadDocument(projectId, doc);
      }
```

Add required imports at top of `create_project_page.dart`:
```dart
import '../../core/models/project_document.dart';
```

**Step 3: Analyze + commit**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/features/project/create_project_page.dart 2>&1 | head -30
git add lib/core/models/project.dart lib/features/project/create_project_page.dart
git commit -m "feat(docs): architecture plan upload creates ProjectDocument, architecturePlanUrl deprecated"
```

---

## Task 7: Documents tab — FAB, category filters, drawings pinned

**Files:**
- Modify: `lib/features/project/tabs/documents_tab.dart`

**Step 1: Read the file first**

Read `lib/features/project/tabs/documents_tab.dart` to understand current structure.

**Step 2: Add category filter state and FAB**

At the top of the tab's State class, add:
```dart
  DocumentCategory? _filterCategory;
```

Replace the existing upload button (whatever it is — an AppBar action or a plain button) with a `floatingActionButton` on the `Scaffold`:

Since `documents_tab.dart` is a tab widget (no Scaffold of its own), the upload FAB must be injected from the parent shell or via a `Stack`. The cleanest approach: return a `Stack` wrapping the document list, with a positioned FAB at bottom-right:

```dart
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // main content
        Column(
          children: [
            _CategoryFilterRow(
              selected: _filterCategory,
              onSelected: (c) => setState(() => _filterCategory = c),
            ),
            Expanded(child: _DocumentList(filter: _filterCategory, ...)),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'docs_fab',
            onPressed: _uploadDocument,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Upload Document'),
          ),
        ),
      ],
    );
  }
```

**Step 3: Add `_CategoryFilterRow` widget**

```dart
class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow({
    required this.selected,
    required this.onSelected,
  });

  final DocumentCategory? selected;
  final void Function(DocumentCategory?) onSelected;

  static const _filters = <(String, DocumentCategory?)>[
    ('All', null),
    ('Drawings', null), // special — covers arch + structural
    ('Land', DocumentCategory.landTitle),
    ('Permits', DocumentCategory.permit),
    ('BOQ', DocumentCategory.boq),
    ('Contracts', DocumentCategory.contract),
    ('Other', DocumentCategory.other),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _filters.map((f) {
          final label = f.$1;
          final cat = f.$2;
          final isDrawings = label == 'Drawings';
          final isSelected = isDrawings
              ? selected == DocumentCategory.architecturalDrawing ||
                  selected == DocumentCategory.structuralDrawing
              : selected == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) {
                if (isDrawings) {
                  onSelected(
                    isSelected
                        ? null
                        : DocumentCategory.architecturalDrawing,
                  );
                } else {
                  onSelected(isSelected ? null : cat);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
```

**Step 4: Pin drawings at top, show icon per category**

In the document list, sort so that `architecturalDrawing` and `structuralDrawing` appear first. When `_filterCategory == null`, show all with drawings pinned:

```dart
  List<ProjectDocument> _sorted(List<ProjectDocument> docs) {
    final drawings = docs
        .where((d) =>
            d.category == DocumentCategory.architecturalDrawing ||
            d.category == DocumentCategory.structuralDrawing)
        .toList();
    final others = docs
        .where((d) =>
            d.category != DocumentCategory.architecturalDrawing &&
            d.category != DocumentCategory.structuralDrawing)
        .toList();
    return [...drawings, ...others];
  }
```

**Step 5: Empty state improvement**

When `docs.isEmpty`, show:
```dart
  Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        const Text(
          'No documents yet.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Upload land title, permits, drawings or contracts.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    ),
  )
```

**Step 6: Analyze + commit**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/features/project/tabs/documents_tab.dart 2>&1 | head -30
git add lib/features/project/tabs/documents_tab.dart
git commit -m "feat(docs): FAB upload, category filter chips, drawings pinned at top, improved empty state"
```

---

## Task 8: Project creation — unified building typology + QS spec fields

**Files:**
- Modify: `lib/features/project/create_project_page.dart`

**Step 1: Replace `_buildingTypes` list with the 6 typology values**

Remove the old `_buildingTypes` list:
```dart
static const _buildingTypes = [ ... ];
```

Replace the Building Type `DropdownButtonFormField` in the form build with:
```dart
          DropdownButtonFormField<String>(
            initialValue: _buildingType,
            decoration: const InputDecoration(labelText: 'Building type'),
            items: const [
              DropdownMenuItem(
                value: 'residentialStandard',
                child: Text('Residential Standard (Bungalow / Duplex)'),
              ),
              DropdownMenuItem(
                value: 'residentialMediumRise',
                child: Text('Residential Medium-rise (Apt 3–6 storeys)'),
              ),
              DropdownMenuItem(
                value: 'residentialHighRise',
                child: Text('Residential High-rise (7+ storeys)'),
              ),
              DropdownMenuItem(
                value: 'commercialOffice',
                child: Text('Commercial Office / Bank / Institution'),
              ),
              DropdownMenuItem(
                value: 'commercialRetail',
                child: Text('Commercial Retail / Mixed Use'),
              ),
              DropdownMenuItem(
                value: 'commercialWarehouse',
                child: Text('Commercial Warehouse / Factory'),
              ),
            ],
            onChanged: (v) => setState(() => _buildingType = v),
          ),
```

**Step 2: Add optional QS Specification Details collapsible section**

Add state fields for spec details:
```dart
  String? _specQuality;     // Economy | Standard | Premium
  String? _specFoundation;  // Strip | Raft | Pad | Pile
  String? _specSoil;        // Firm | Soft | Waterlogged | Laterite
  String? _specRoof;        // Pitched sheet | Concrete flat | Tile
  String? _specMETier;      // Basic | Enhanced
```

Add after the existing Building Type + Region fields in the form, an `ExpansionTile` labelled "Specification Details (optional)":

```dart
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('Specification Details'),
            subtitle: const Text(
              'Optional — unlocks Quick Re-estimate in Finance tab',
            ),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _specQuality,
                decoration:
                    const InputDecoration(labelText: 'Quality / Finish Level'),
                items: const [
                  DropdownMenuItem(
                      value: 'Economy', child: Text('Economy')),
                  DropdownMenuItem(
                      value: 'Standard', child: Text('Standard')),
                  DropdownMenuItem(
                      value: 'Premium', child: Text('Premium')),
                ],
                onChanged: (v) => setState(() => _specQuality = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _specFoundation,
                decoration:
                    const InputDecoration(labelText: 'Foundation Type'),
                items: const [
                  DropdownMenuItem(value: 'Strip', child: Text('Strip')),
                  DropdownMenuItem(value: 'Raft', child: Text('Raft')),
                  DropdownMenuItem(value: 'Pad', child: Text('Pad')),
                  DropdownMenuItem(value: 'Pile', child: Text('Pile')),
                ],
                onChanged: (v) => setState(() => _specFoundation = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _specSoil,
                decoration:
                    const InputDecoration(labelText: 'Soil Condition'),
                items: const [
                  DropdownMenuItem(value: 'Firm', child: Text('Firm')),
                  DropdownMenuItem(value: 'Soft', child: Text('Soft')),
                  DropdownMenuItem(
                      value: 'Waterlogged', child: Text('Waterlogged')),
                  DropdownMenuItem(
                      value: 'Laterite', child: Text('Laterite')),
                ],
                onChanged: (v) => setState(() => _specSoil = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _specRoof,
                decoration: const InputDecoration(labelText: 'Roof Type'),
                items: const [
                  DropdownMenuItem(
                      value: 'Pitched sheet',
                      child: Text('Pitched sheet')),
                  DropdownMenuItem(
                      value: 'Concrete flat',
                      child: Text('Concrete flat')),
                  DropdownMenuItem(value: 'Tile', child: Text('Tile')),
                ],
                onChanged: (v) => setState(() => _specRoof = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _specMETier,
                decoration:
                    const InputDecoration(labelText: 'M&E Services Tier'),
                items: const [
                  DropdownMenuItem(
                      value: 'Basic', child: Text('Basic')),
                  DropdownMenuItem(
                      value: 'Enhanced', child: Text('Enhanced')),
                ],
                onChanged: (v) => setState(() => _specMETier = v),
              ),
            ],
          ),
```

**Step 3: Pass spec fields into `Project` constructor**

Read `lib/core/models/project.dart` to find the Project model fields. If `specQuality`, `specFoundation`, `specSoil`, `specRoof`, `specMETier` fields don't exist on Project, add them as optional `String?` fields with `fromDoc` parsing and `toMap` serialization.

In `create_project_page.dart _save()`, pass them:
```dart
      final project = Project(
        // ... existing fields ...
        specQuality: _specQuality,
        specFoundation: _specFoundation,
        specSoil: _specSoil,
        specRoof: _specRoof,
        specMETier: _specMETier,
      );
```

**Step 4: Pre-fill from estimate on result page**

In `lib/features/estimate/estimate_result_page.dart`, update the "Create project from estimate" button handler to pass spec details:

```dart
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CreateProjectPage(
                    initialTitle: controller.projectNameCtrl.text.trim(),
                    initialBudget: r.totalPlannedGhs,
                    initialRegion: controller.region,
                    initialBoqItems: boqItems,
                    initialFloorAreaSqm: r.totalBuiltUpArea,
                    initialBuildingType: controller.typology.name,
                    initialSpecQuality: controller.quality,
                    initialSpecFoundation: controller.foundation,
                    initialSpecSoil: controller.soil,
                    initialSpecRoof: controller.roof,
                    initialSpecMETier:
                        controller.enhancedServices ? 'Enhanced' : 'Basic',
                    initialContingencyGhs: r.contingencyGhs,
                  ),
                ),
              );
```

Add those parameters to `CreateProjectPage` constructor:
```dart
  final String? initialBuildingType;
  final String? initialSpecQuality;
  final String? initialSpecFoundation;
  final String? initialSpecSoil;
  final String? initialSpecRoof;
  final String? initialSpecMETier;
  final double? initialContingencyGhs;
```

In `initState`, apply them:
```dart
    if (widget.initialBuildingType != null) _buildingType = widget.initialBuildingType;
    if (widget.initialSpecQuality != null) _specQuality = widget.initialSpecQuality;
    if (widget.initialSpecFoundation != null) _specFoundation = widget.initialSpecFoundation;
    if (widget.initialSpecSoil != null) _specSoil = widget.initialSpecSoil;
    if (widget.initialSpecRoof != null) _specRoof = widget.initialSpecRoof;
    if (widget.initialSpecMETier != null) _specMETier = widget.initialSpecMETier;
    if (widget.initialContingencyGhs != null) {
      _contingencyCtrl.text = widget.initialContingencyGhs!.toStringAsFixed(0);
    }
```

**Step 5: Analyze + commit**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/features/project/create_project_page.dart lib/core/models/project.dart lib/features/estimate/estimate_result_page.dart 2>&1 | head -40
git add lib/features/project/create_project_page.dart lib/core/models/project.dart lib/features/estimate/estimate_result_page.dart
git commit -m "feat(project): unified building typology, QS spec fields, pre-fill from estimate"
```

---

## Task 9: UX fixes — projects list, project cards, tab rename, Finance tab

**Files:**
- Modify: `lib/features/project/projects_page.dart`
- Modify: `lib/features/project/tabs/work_tab.dart` (rename tab label)
- Modify: `lib/features/project/tabs/finance_tab.dart`
- Modify: `lib/features/shell/home_shell.dart` (if tab label is defined there)

**Step 1: Projects list empty state**

Read `lib/features/project/projects_page.dart`. Find where the empty list state is returned. Replace with:

```dart
  Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.construction_outlined,
          size: 72,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        Text(
          'No projects yet',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Start with an estimate, then create your first project.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.go('/estimate'),
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Get Estimate'),
        ),
      ],
    ),
  )
```

**Step 2: Project card subtitle**

Find the project card widget in `projects_page.dart`. In the `subtitle` or below the title, add:

```dart
  Text(
    [
      if (p.region.isNotEmpty) p.region,
      if (p.buildingType != null && p.buildingType!.isNotEmpty) p.buildingType!,
    ].join(' · '),
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
  ),
```

**Step 3: Rename "Work" tab to "Progress"**

Search for where the tab label "Work" is defined. Run:
```bash
grep -rn '"Work"' /Users/donaldduodu/wysebrix/lib/ --include="*.dart"
```

Replace `'Work'` with `'Progress'` in the tab definition (likely in `project_details_page.dart` or the tab bar setup).

**Step 4: Finance tab — consolidate Costs + Payments into single scroll**

Read `lib/features/project/tabs/finance_tab.dart`. The tab currently shows phases/costs and payments as separate sections. Ensure they scroll together in one `ListView` with section headers. Look for any `TabBarView` inside the finance tab and collapse it into labelled sections. Add a `Text('Payments', style: textTheme.titleSmall)` section header before the payments list.

**Step 5: Finance tab "Load more" button**

Replace any standalone widget that breaks layout (e.g., a `ListTile` or `Card` just for "Load more") with:

```dart
  TextButton(
    onPressed: _loadMore,
    child: const Text('Load more'),
  ),
```

With a `Divider` above it.

**Step 6: Analyze + commit**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/features/project/projects_page.dart lib/features/project/tabs/finance_tab.dart 2>&1 | head -30
git add lib/features/project/ lib/features/shell/
git commit -m "ux: projects empty state CTA, card subtitle, Work→Progress tab, Finance tab consolidation"
```

---

## Task 10: UX fixes — Account page, Auth pages, Onboarding, cross-cutting

**Files:**
- Modify: `lib/features/account/account_page.dart`
- Modify: `lib/features/auth/sign_in_page.dart`
- Modify: `lib/features/auth/email_verification_page.dart`
- Modify: `lib/features/onboarding/onboarding_page.dart`

**Step 1: Account page — role tooltip**

Read `lib/features/account/account_page.dart`. Find the role `Chip` or `Container` displaying the role label. Add `Tooltip(message: 'Contact support to change your role', child: ...)` wrapping it.

**Step 2: Account page — Trust score info button**

Find the trust score display widget. Add an `IconButton(icon: Icon(Icons.info_outline), ...)` next to the trust score. On press, show a bottom sheet:

```dart
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trust Score',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Your trust score is calculated from 5 dimensions:\n\n'
            '1. Identity verification (Ghana Card / Passport)\n'
            '2. Certifications & licences on file\n'
            '3. Work experience history\n'
            '4. Portfolio items uploaded\n'
            '5. Contract completion rate\n\n'
            'A higher score increases visibility to project owners.',
          ),
        ],
      ),
    ),
  );
```

**Step 3: Account page — Subscription badge days remaining**

Find the subscription badge/chip. Add days remaining text for Project Pass:
```dart
  // Assuming you have access to the user's subscriptionTier and projectPassExpiresAt
  if (subscriptionTier == 'project_pass' && expiresAt != null) {
    final days = expiresAt.difference(DateTime.now()).inDays;
    Text('Project Pass · $days days left');
  }
```

**Step 4: Sign-in page — "Continue without account" button**

Read `lib/features/auth/sign_in_page.dart`. Below the sign-in form, add:

```dart
  TextButton(
    onPressed: () => context.go('/estimate'),
    child: const Text('Continue without account'),
  ),
```

**Step 5: Email verification page — immediate Resend button with countdown**

Read `lib/features/auth/email_verification_page.dart`. Replace the delayed resend button with a timer that starts immediately at 60 seconds and counts down:

```dart
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown = (_countdown - 1).clamp(0, 60));
      if (_countdown == 0) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
```

Show resend button enabled when `_countdown == 0`:
```dart
  FilledButton(
    onPressed: _countdown == 0 ? _resendEmail : null,
    child: Text(
      _countdown > 0 ? 'Resend in ${_countdown}s' : 'Resend verification email',
    ),
  ),
```

**Step 6: Onboarding — Skip button**

Read `lib/features/onboarding/onboarding_page.dart`. On each page / in the AppBar, add a `TextButton('Skip', ...)` that navigates directly to the main app (past onboarding):

```dart
  actions: [
    TextButton(
      onPressed: _skip,
      child: const Text('Skip'),
    ),
  ],
```

Where `_skip` calls:
```dart
  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    context.go('/');
  }
```

**Step 7: Cross-cutting — `showDragHandle` on all bottom sheets**

Search for all `showModalBottomSheet` calls in the project:
```bash
grep -rn 'showModalBottomSheet' /Users/donaldduodu/wysebrix/lib/ --include="*.dart" -l
```

For each file returned, read it and add `showDragHandle: true` to every `showModalBottomSheet` call that doesn't already have it.

**Step 8: Cross-cutting — error snackbar duration**

Search for error snackbars showing exceptions or errors:
```bash
grep -rn 'SnackBar.*error\|error.*SnackBar\|catch.*SnackBar\|SnackBar.*catch' /Users/donaldduodu/wysebrix/lib/ --include="*.dart" -l
```

Add `duration: const Duration(seconds: 10)` to error snackbars (those showing `e.toString()` or similar).

**Step 9: Analyze + commit**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/features/account/ lib/features/auth/ lib/features/onboarding/ 2>&1 | head -30
git add lib/features/account/ lib/features/auth/ lib/features/onboarding/ lib/
git commit -m "ux: account role tooltip, trust info sheet, subscription days, skip onboarding, email countdown, drag handles"
```

---

## Task 11: Final analysis and verification

**Step 1: Full analyze**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/ 2>&1 | grep -E "error|warning" | head -50
```

Fix any remaining errors. Common issues to watch for:
- `EstimateInput` constructor calls that still pass `buildingType:` instead of `typology:`
- `toMap()` / `fromMap()` in estimate_controller not updated for `typology`
- Missing import of `BuildingTypology` in files that reference it
- `EstimateResult` constructor calls missing `specificationBreakdownGhs:`

**Step 2: Run on simulator**

```bash
cd /Users/donaldduodu/wysebrix && flutter run -d "iPhone 16 Pro" --no-sound-null-safety 2>&1 | tail -20
```

**Step 3: Final commit**

```bash
git add -A
git commit -m "fix: resolve post-refactor analysis errors"
```
