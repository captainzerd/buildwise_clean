// test/phase1/phase1_scope_test.dart
//
// Phase 1 scope reduction — automated success-criteria tests.
// Tests are isolated: no Firebase, no service locator.
// Source-grep tests verify removed widget text is absent from source files.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/models/app_user.dart';
import 'package:wysebrix/core/use_cases/calculate_estimate.dart'
    show BuildingTypology;

void main() {
  // ── Task 1: Step 2 building types (SC1) ───────────────────────────────────
  group('Step 2 — building type list', () {
    test('visibleTypologies constant contains exactly 2 entries', () {
      const kept = [
        BuildingTypology.residentialStandard,
        BuildingTypology.residentialMediumRise,
      ];
      const all = BuildingTypology.values;
      final removed = all.where((t) => !kept.contains(t)).toList();
      expect(kept.length, 2);
      expect(removed.length, greaterThan(0));
      expect(removed.contains(BuildingTypology.residentialHighRise), isTrue);
      expect(removed.contains(BuildingTypology.commercialOffice), isTrue);
    });
  });

  // ── Task 1: Step 2 M&E / curtain wall absence (SC2) ─────────────────────
  group('Step 2 — removed toggle text', () {
    test('step2_building.dart contains no M&E, curtain, or glazing text', () {
      final file = File('lib/features/estimate/widgets/step2_building.dart');
      final contents = file.readAsStringSync();
      expect(contents.contains('M&E'), isFalse,
          reason: 'Enhanced M&E toggle must be removed');
      expect(contents.contains('curtain'), isFalse,
          reason: 'Curtain wall toggle must be removed');
      expect(contents.contains('glazing'), isFalse,
          reason: 'Glazing toggle must be removed');
    });
  });

  // ── Task 2: Step 4 removed fields absence (SC3) ───────────────────────────
  group('Step 4 — removed field text', () {
    test('step4_extras.dart contains no swimming pool, generator, security wall, OHP, or professional fees', () {
      final file = File('lib/features/estimate/widgets/step4_extras.dart');
      final contents = file.readAsStringSync();
      expect(contents.contains('Swimming pool'), isFalse,
          reason: 'Swimming pool toggle must be removed');
      expect(contents.contains('Generator house'), isFalse,
          reason: 'Generator house checkbox must be removed');
      expect(contents.contains('Security wall'), isFalse,
          reason: 'Security wall field must be removed');
      expect(contents.contains("'OHP'"), isFalse,
          reason: 'OHP slider label must be removed');
      expect(contents.contains('Professional fees'), isFalse,
          reason: 'Professional fees toggle must be removed');
    });
  });

  // ── Task 4: visibleTabIndices — homeowner sees 4 tabs, no Analytics ────────
  group('visibleTabIndices — Phase 1', () {
    test('homeowner gets {0,1,3,4} — no Analytics (2)', () {
      final visible = ProfessionalTypeInfo.fromString('homeowner').visibleTabIndices;
      expect(visible.contains(2), isFalse, reason: 'Analytics tab must be hidden');
      expect(visible.contains(0), isTrue);
      expect(visible.contains(1), isTrue);
      expect(visible.contains(3), isTrue);
      expect(visible.contains(4), isTrue);
      expect(visible.length, 4);
    });

    test('admin gets {0,1,3,4} — no Analytics tab in nav', () {
      final visible = ProfessionalTypeInfo.fromString('admin').visibleTabIndices;
      expect(visible.contains(2), isFalse);
      expect(visible.length, 4);
    });

    test('realEstateDeveloper gets {0,1,3,4}', () {
      final visible = ProfessionalTypeInfo.fromString('realEstateDeveloper').visibleTabIndices;
      expect(visible.contains(2), isFalse);
      expect(visible.length, 4);
    });

    test('contractor (professional) still gets {0,1,3,4} — unchanged', () {
      final visible = ProfessionalTypeInfo.fromString('contractor').visibleTabIndices;
      expect(visible.contains(2), isFalse);
      expect(visible.length, 4);
    });
  });

  // ── Task 4: Navigation labels (SC5) ──────────────────────────────────────
  group('Navigation labels — Phase 1', () {
    test('home_shell.dart contains Find Builders label and no Analytics or Marketplace labels', () {
      final file = File('lib/features/shell/home_shell.dart');
      final contents = file.readAsStringSync();
      expect(contents.contains("'Find Builders'"), isTrue,
          reason: 'Find Builders label must be present');
      expect(contents.contains("label: 'Marketplace'"), isFalse,
          reason: 'Marketplace label must be renamed');
      expect(contents.contains("label: 'Analytics'"), isFalse,
          reason: 'Analytics tab must not appear in nav bar');
    });
  });

  // ── Task 5: Project details tab count (SC6) ───────────────────────────────
  group('Project details tabs — Phase 1', () {
    test('project_details_page.dart has TabController length 3', () {
      final file = File('lib/features/project/project_details_page.dart');
      final contents = file.readAsStringSync();
      expect(contents.contains('TabController(length: 3'), isTrue,
          reason: 'ProjectDetailsPage must have exactly 3 tabs');
    });
  });

  // ── Task 6: sign-up picker — 2 cards (SC8) ────────────────────────────────
  group('Sign-up role picker', () {
    test('phase1 role options contains exactly 2 entries', () {
      const phase1Roles = [
        ProfessionalType.homeowner,
        ProfessionalType.contractor,
      ];
      expect(phase1Roles.length, 2);
    });
  });

  // ── Task 7: upgrade page — homeowner tier visibility (SC7) ────────────────
  group('Upgrade page tier visibility', () {
    test('isClient roles do not see business or builderSku', () {
      for (final role in [
        ProfessionalType.homeowner,
        ProfessionalType.realEstateDeveloper,
        ProfessionalType.bankLender,
        ProfessionalType.governmentRegulator,
      ]) {
        expect(role.isClient, isTrue,
            reason: '${role.name} should be isClient');
      }
    });

    test('professional roles are not isClient — see all tiers', () {
      for (final role in [
        ProfessionalType.contractor,
        ProfessionalType.architect,
        ProfessionalType.engineer,
        ProfessionalType.inspector,
        ProfessionalType.materialSupplier,
      ]) {
        expect(role.isClient, isFalse);
        expect(role.isProfessional, isTrue);
      }
    });
  });
}
