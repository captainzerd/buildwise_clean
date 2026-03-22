# WyseBrix P0–P3 Implementation Design
Date: 2026-03-07
Status: Approved

---

## P0 — Critical Fixes

### P0.1 — Fix Multi-Contractor Project Query
**File:** `lib/core/services/project_service.dart`

Current `fetchBuilderProjectsPage` only queries `assignedPmUid`. Builders added via team invitation with `teamMemberUids` membership are invisible.

Fix: run two parallel Firestore queries via `Future.wait`:
1. `where('assignedPmUid', isEqualTo: uid)`
2. `where('teamMemberUids', arrayContains: uid)`

Merge and deduplicate by `project.id`. Apply to both `fetchBuilderProjectsPage` and `projectsForBuilder` stream.

### P0.2 — Server-Side Subscription Enforcement
**Files:** `firestore.rules`, `functions/src/index.ts`

- Firestore rules: add `hasActiveTier(minTier)` helper that checks `request.auth.token.subscriptionTier` custom claim. Gate project creation: free users blocked after 1 project.
- Cloud Function: extend user document trigger to sync `subscriptionTier` into custom claims on every users/{uid} write.
- Cloud Function: scheduled daily `checkExpiredProjectPasses` demotes expired Project Pass users back to `free` in Firestore + custom claims.

### P0.3 — Update Cost Catalog Rates (2024/25)
**File:** `assets/data/cost_catalog_gh.json`

Updated base rates per m²:
- Basic residential: GH₵3,800
- Standard residential: GH₵5,500
- Premium residential: GH₵9,500
- Commercial: +25% on all tiers
- Coastal/pile-foundation areas: +20% substructure weight

### P0.4 — CI/CD Pipeline
**Files:** `.github/workflows/ci.yml`, `.github/workflows/deploy.yml`

- `ci.yml`: triggers on PR to main — runs `flutter analyze`, `flutter test`, builds APK
- `deploy.yml`: triggers on push to main — deploys Firestore rules + Cloud Functions via Firebase CLI

---

## P1 — Architecture & Features

### P1.1 — God File Decomposition (Full Tab Split)
**Current:** `project_details_page.dart` at 9,300+ lines

**Target structure:**
```
lib/features/project/
  project_details_page.dart          ← shell ~200 lines: AppBar, TabBar, TabController
  tabs/
    overview_tab.dart                ← quick actions, summary cards, chat
    work_tab.dart                    ← phases, monitor, tasks, site log (sub-tabs)
    finance_tab.dart                 ← costs, payments, estimates (sub-tabs)
    documents_tab.dart               ← uploads, architecture plan, BOQ
    risk_tab.dart                    ← risk register
    team_tab.dart                    ← members, invitations, contracts
  widgets/
    cost_entry_card.dart
    payment_record_card.dart
    task_card.dart
    snag_card.dart
    chat_message_bubble.dart
    quick_action_card.dart
    invite_member_sheet.dart
    add_task_sheet.dart
    add_risk_sheet.dart
```

Shell passes `projectId` + `Project` down. All business logic and service calls move into tab files.

### P1.2 — Pagination on Sub-Collection Streams
**File:** `lib/core/services/project_service.dart`

Add `limit` parameter (default 50) to `phasesStream()`, `costsStream()`, `documentsStream()`, `updatesStream()`. Each tab that owns a list shows a "Load more" button when `items.length >= limit`.

### P1.3 — Search & Filter on Projects List
**File:** `lib/features/project/projects_page.dart`

- Material 3 `SearchBar` at top filters in-memory by title, location
- `FilterChip` row for status: Planning / Active / Paused / Completed
- Client-side filtering, no new Firestore queries

### P1.4 — Ghana Labour Rate Reference Table
**Files:** `lib/core/data/ghana_labour_rates.dart`, `lib/features/project/labor_tracking_page.dart`

New `GhanaLabourRates` constants class with 2024 standard daily rates by trade. Info icon on labor tracking page opens `_RateReferenceSheet` bottom sheet with a `DataTable`. Rates: Mason GH₵150, Steel Fixer GH₵175, Carpenter GH₵155, Electrician GH₵200, Plumber GH₵190, Painter GH₵130, Unskilled GH₵90.

### P1.5 — Foundation Type Input for Estimate
**Files:** `lib/features/estimate/widgets/step2_building.dart`, `lib/features/estimate/state/estimate_controller.dart`

New `FoundationType` enum: `strip`, `pad`, `raft`, `pile`. Added to Step 2 (Building) dropdown. Substructure cost multipliers: Strip 1.0×, Pad 1.1×, Raft 1.25×, Pile 1.6×. Coastal regions (Greater Accra, Western, Central) default to `raft`.

---

## P2 — UX & Domain Quality

### P2.1 — Post-Onboarding Coach Mark Tour
**File:** `lib/features/shell/home_shell.dart`, new `lib/core/widgets/coach_mark_overlay.dart`

4-step overlay sequence after first sign-in, gated by `SharedPreferences` key `coach_done`. Custom `CustomPainter` with semi-transparent scrim + `RRect` cutout over each nav tab. Steps cover: Estimate, Projects, People, Account tabs. No third-party package.

### P2.2 — Accessibility Pass
**Files:** multiple (shell, widgets, account, estimate)

- `Semantics` on all `NavigationDestination` icons with role labels
- `Badge` announces count (e.g. "3 unread notifications")
- `LoadingButton` announces loading state
- `ShimmerBox` excluded from semantics tree
- All `IconButton` widgets get explicit `tooltip`
- `ExcludeSemantics` on decorative images
- Minimum 44×44 touch targets on all interactive elements

### P2.3 — Formal Variation Order Certification
**Files:** `lib/core/models/variation_order.dart`, `lib/features/project/variation_orders_page.dart`, `firestore.rules`

New fields on `VariationOrder`: `certifiedByUid`, `certifiedByName`, `certifiedAt`, `requiresCertification` (true when amount > 5% of project budget). PM role can "Certify" a VO. Owner approve button disabled until certified when `requiresCertification`. Firestore rule enforces `certifiedByUid` non-null before owner approval.

### P2.4 — Snag List Defect Categories
**Files:** `lib/core/models/snag_item.dart`, `lib/features/project/snag_list_page.dart`

New `SnagCategory` enum: `structural`, `weatherproofing`, `finishes`, `services`, `externalWorks`, `other`. Category dropdown in add-snag sheet. `FilterChip` row on list. Section headers group by category. Existing snags default to `other`.

---

## P3 — Advanced Features

### P3.1 — GRA Stamp Duty Calculator
**Files:** `lib/core/use_cases/calculate_stamp_duty.dart`, embedded in `LandOwnershipPage` + `CreateContractPage`

GRA 2024 schedule:
- Stamp Duty: 3% residential / 5% commercial
- Transfer Tax: 0.5%
- CGT placeholder: 15% (requires cost basis input)

Pure use-case class (testable). `StampDutyCalculator` widget shows itemised `Card`. Disclaimer: "These are estimates — consult a licensed solicitor."

### P3.2 — Staging Firebase Scaffold
**Files:** `lib/core/config/flavors.dart`, main entry points, Android/iOS config, CI update

Three flavors: `dev`, `staging`, `prod`. Entry points `main_dev.dart`, `main_staging.dart`, `main_prod.dart`. Android `src/{dev,staging,prod}/google-services.json` with `TODO` placeholders. iOS `Firebase/{Dev,Staging}/GoogleService-Info.plist` with `TODO` placeholders. `README.md` updated with flavor setup guide.

### P3.3 — FIDIC/GhBC Contract Template Scaffold
**Files:** `lib/core/models/builder_contract.dart` (extend), `lib/features/project/create_contract_page.dart`

`ContractTemplateType` enum: `custom`, `ghbcResidential`, `fidicShortForm`, `necEngineering`. Template selector step added before the contract form. Each template pre-populates clause list. Legal text placeholders with `// TODO: Insert licensed clause text` for `ghbcResidential` and `fidicShortForm`. `custom` remains fully functional.

---

## Decisions
- Twi localization: deferred — English only for now
- God File: Option B (full tab split), not incremental extract
- Staging: scaffold with TODO placeholders for Firebase credentials
- FIDIC: scaffold with TODO placeholders for licensed clause text
