# Phase 1 Scope Reduction — Design Spec

> **Status:** Approved by product owner 2026-03-22
> **Approach:** UI-layer pruning — remove Phase 2 entry points from the visible UI. Underlying screens and routes remain in code but unreachable. No feature flags, no hard deletes of Phase 2 screens.

---

## Goal

Reduce WyseBrix to a focused, intuitive homeowner-first experience for Phase 1 launch. Remove every screen, field, and option that is not needed by a Ghanaian homeowner planning or managing a residential build. Defer professional and developer tools to Phase 2.

## Primary Customer

**Homeowner** — someone planning or actively building a house or apartment in Ghana. They want to know what their build will cost and track spending as the build progresses.

## Core Loop

```
Estimate → Save as Project / Export PDF → Track spend → Come back weekly
```

## Architecture

No existing screens deleted. Routes stay registered in `router.dart`. Changes are confined to:
- Filtering display lists (building types, role cards, pricing tiers, nav tabs, project tabs, overflow menu items)
- Removing specific widget fields (toggles, sliders, checkboxes) from wizard steps
- Hiding role-conditional sections in Account page
- Renaming one nav tab label
- One new lightweight tab widget (`ChangesTab`) wrapping existing variation-order data

---

## Section 1 — Estimate Wizard

### Step 2: Building (`lib/features/estimate/widgets/step2_building.dart`)

**Building type list — reduce to 2 cards:**

| Keep | Enum value | Display label |
|---|---|---|
| ✅ | `residentialStandard` | House / Bungalow |
| ✅ | `residentialMediumRise` | Apartment / Compound House |
| ❌ removed from list | `residentialHighRise` | Residential High-rise |
| ❌ removed from list | `commercialOffice` | Commercial Office |
| ❌ removed from list | `commercialRetail` | Commercial Retail / Mixed Use |
| ❌ removed from list | `commercialWarehouse` | Commercial Warehouse / Factory |

Implementation: filter the list of `BuildingTypology` values rendered as cards. The `BuildingTypology` enum in `lib/core/use_cases/calculate_estimate.dart` and the `EstimationEngine` are **unchanged**.

**Remove from Step 2 widget (fields only — model unchanged):**
- "Enhanced M&E services" toggle (`enhancedME`) — remove the `SwitchListTile` widget only
- "Curtain wall / large glazing" toggle (`curtainWall`) — remove the `SwitchListTile` widget only

Both fields remain on `EstimateInput` with their default values (`false`).

### Step 4: Extras (`lib/features/estimate/widgets/step4_extras.dart`)

**Remove these widgets only — no model changes:**
- Swimming pool toggle + `RangeSlider`
- Generator house `CheckboxListTile`
- Security wall `TextFormField` + length field

**Remove from Commercials expansion tile:**
- Professional fees `SwitchListTile` + percentage `Slider` (GIQS scale)
- OHP (Overhead & Profit) percentage `Slider`

**Keep in Step 4:**
- External works section (compound wall length, driveway area)
- Septic / soakaway checkbox
- Water storage tank checkbox
- Preliminaries % slider
- Contingency toggle + % slider
- Permit cost (percent or manual)
- Budget comparison field

### Result Screen (`lib/features/estimate/estimate_result_page.dart`)

Two equally-weighted full-width action buttons, stacked vertically, below the computed breakdown:
1. **Save as Project** — `FilledButton` (primary)
2. **Export PDF** — `OutlinedButton` (secondary, same width)

No change to the computed result display (cost breakdown, phase chart, totals).

---

## Section 2 — Navigation (`lib/features/shell/home_shell.dart`)

**Reduce from 5 tabs to 4 by dropping Analytics (logical index 2).**

Keep the existing logical index constants. Do not renumber them. Update only:

1. **`visibleTabIndices` in `ProfessionalTypeInfo` (`lib/core/models/app_user.dart`)**:
   - Professional roles (`contractor`, `architect`, `engineer`, `inspector`, `materialSupplier`) → `const {0, 1, 3, 4}` (already correct — no change needed)
   - Client roles (`homeowner`, `realEstateDeveloper`, `bankLender`, `governmentRegulator`) → change from `{0, 1, 2, 3, 4}` to `const {0, 1, 3, 4}`
   - `admin` → change from `{0, 1, 2, 3, 4}` to `const {0, 1, 3, 4}` (Analytics still accessible via direct route `/analytics` for admin)
   - Update the doc-comment on line ~98 to: `/// 0=Estimate, 1=Projects, 3=Find Builders, 4=Account`

2. **Unauthenticated fallback in `HomeShell`** (line ~77):
   - Change `const {0, 1, 2, 3, 4}` → `const {0, 1, 3, 4}` so signed-out users also see 4 tabs

3. **`_buildBody` in `HomeShell`**: No logical changes needed — `_kPeople = 3` and `_kAccount = 4` remain. `_kAnalytics = 2` simply never appears in `visibleTabIndices` so it is never rendered.

4. **`_NavBar._destination(int logicalI)` for case `3`**:
   - Change label from `'Marketplace'` → `'Find Builders'`
   - Keep icon `Icons.storefront_outlined` / `Icons.storefront`

5. **`_buildBody` case `_kPeople` (logical 3)**:
   - Replace `const PeoplePage()` with `const BuilderMarketplacePage()`
   - Add import for `BuilderMarketplacePage` (find its file path with a search for `class BuilderMarketplacePage`)
   - Remove unused `PeoplePage` import if nothing else references it in this file

The `AnalyticsPage` route stays registered in `router.dart`. Its tab constant `_kAnalytics = 2` stays in `HomeShell` but is unreachable from the nav bar.

---

## Section 3 — Project Details (`lib/features/project/project_details_page.dart`)

**Current tabs (length: 5):** Overview (0), Progress/Work (1), Finance (2), Documents (3), Risks (4)

**Phase 1 tabs (length: 3):**

| Index | Tab | Source |
|---|---|---|
| 0 | **Overview** | Existing `OverviewTab` — keeps `PhotoEvidenceSection` widget inside it |
| 1 | **Finance** | Existing `FinanceTab` |
| 2 | **Changes** | New `ChangesTab` widget (see below) |

**Implementation:**
- Set `TabController(length: 3, ...)`
- Remove `WorkTab`, `DocsTab`, `RisksTab` from `TabBarView` (keep their file imports and source files intact)
- Update `TabBar` to 3 tabs: Overview, Finance, Changes
- Replace tab index constants with:
  ```dart
  static const _kOverview  = 0;
  static const _kFinance   = 1;
  static const _kChanges   = 2;
  ```
  Remove `_kWork = 1`, `_kDocuments = 3`, `_kRisk = 4` constants entirely (they become dead code)
- Update `_buildFab` switch: `_kOverview → null`, `_kFinance → existing finance FAB`, `_kChanges → FAB that pushes '/projects/$id/variation-orders'`, `_ → null`
- Update `_buildAppBarTitle` (or equivalent title switch) to use new constants
- Update `_helpContent` map to 3 entries keyed 0, 1, 2 with help text matching Overview, Finance, Changes respectively. Remove old entries for keys 1–4.

**`ChangesTab` widget** (`lib/features/project/tabs/changes_tab.dart` — new file):
A lightweight `StatelessWidget` that renders the variation orders list for the given `projectId`. Reuse the existing `VariationOrderService` stream and the list-tile widget already used in `VariationOrdersPage`. Read-only list. The "Add change" FAB (defined in `_buildFab` above) pushes the full-screen route `context.push('/projects/$projectId/variation-orders')` — do **not** use a bottom sheet (no bottom-sheet constructor exists on `VariationOrdersPage`). This is the only new file in Phase 1.

**Overflow menu (`PopupMenuButton<_MenuAction>`) — prune to Phase 1 entries only:**

| Keep | Menu item |
|---|---|
| ✅ | Edit project |
| ✅ | Edit status |
| ✅ | Export (PDF/CSV) |
| ❌ remove | Build timeline |
| ❌ remove | View analytics (standalone) |
| ❌ remove | Mortgage calculator |
| ❌ remove | Generate invoice |
| ❌ remove | View audit log |
| ❌ remove | Manage tasks |
| ❌ remove | Any other Phase 2 entries |

Remove both the `PopupMenuItem` widget and the corresponding `_MenuAction` enum value and `switch` case for each removed item.

**`cash_flow_tab.dart`** — currently untracked and uncommitted. Leave as-is (do not commit). No action required.

---

## Section 4 — Sign-up Role Selection (`lib/features/auth/sign_in_page.dart`)

Role selection lives in **`_ProfessionalTypePicker`** (line ~511) inside `sign_in_page.dart`, rendered during the sign-up flow.

**Replace `_ProfessionalTypePicker` with two full-width tappable cards:**

| Card | Icon | Sub-label | `ProfessionalType` value |
|---|---|---|---|
| I'm building a home | `Icons.home_outlined` | Planning or managing a residential build | `homeowner` |
| I'm a professional | `Icons.construction` | Contractor, architect, engineer or surveyor | `contractor` |

Implementation:
- Replace the `ListView` of `_ProfessionalTypeCard` widgets (iterating `ProfessionalType.values`) with two hardcoded `InkWell` / `Card` widgets
- Each card calls `onChanged(ProfessionalType.homeowner)` or `onChanged(ProfessionalType.contractor)` respectively — only when `enabled == true`. When `enabled == false` (i.e. `_busy` is true during form submission), set `onTap: null` on both `InkWell` widgets to disable interaction and prevent role changes mid-flight
- The `_professionalType` state field, `signUp()` call with `role: _professionalType`, and the underlying `ProfessionalType` enum all remain unchanged
- Keep `_ProfessionalTypeCard` class in the file — just stop using it in the picker for now

**Onboarding carousel** (`lib/features/onboarding/onboarding_page.dart`) — no changes.

---

## Section 5 — Pricing & Upgrade Page (`lib/features/account/upgrade_page.dart`)

**Tier visibility by role:**

| Role | Sees |
|---|---|
| `isClient` roles (`homeowner`, `realEstateDeveloper`, `bankLender`, `governmentRegulator`) | Free, Builder Pass, Pro only |
| `isProfessional` roles (`contractor`, `architect`, `engineer`, `inspector`, `materialSupplier`) | All 5 tiers |
| `admin` | All 5 tiers |

Implementation: Wrap the **Business** and **Builder SKU** tier card widgets with:
```dart
if (!auth.role.isClient) ...[
  // Business tier card
  // Builder SKU tier card
],
```

`isClient` is defined in `app_user.dart` as `!isProfessional && !isAdmin`. It covers all four client role types listed above. This is intentional — none of those client roles need a marketplace listing or builder-supply tier in Phase 1.

No changes to payment flow, Paystack/Stripe integration, or subscription activation Cloud Function.

---

## Section 6 — Account Page (`lib/features/account/account_page.dart`)

Verify and enforce that professional-only sections are correctly gated with `if (auth.role.isProfessional)` or equivalent. These sections must **not** be visible to homeowners:
- Builder Profile card / link
- PM Profile card / link
- Work History
- Certifications
- Portfolio
- RFQ Inbox link

Most of these are already conditionally rendered. Audit each one and fix any that render unconditionally.

**Homeowners always see:**
- Profile (display name, photo, phone)
- Subscription & upgrade
- Security (password change, 2FA, phone verification, email verification)
- Login activity
- Sign out / delete account

No structural changes to the page — visibility gates only.

---

## Section 7 — Find Builders Tab

Covered by Section 2: tab index 3 renders `BuilderMarketplacePage` directly.

`VendorsPage` and `PmMarketplacePage` routes remain registered and their files remain intact — they simply have no navigation entry point in Phase 1.

---

## What Does NOT Change

- `EstimationEngine` logic — all multipliers, phase weights, formulas
- `BuildingTypology` enum — all 6 values remain; display list is filtered
- `EstimateInput` model — `enhancedME`, `curtainWall`, and all removed-field values remain with defaults
- `ProfessionalType` enum — all 9 values remain; sign-up picker shows 2
- All Phase 2 routes in `router.dart` — registered but unreachable
- Firebase security rules, Cloud Functions, Firestore schema
- Admin panel (`/admin/*`) — unchanged
- Payment integration (Paystack, Stripe)
- All existing test files
- `VariationOrdersPage` full route — reused by `ChangesTab`

---

## Files Changed

| File | Change type |
|---|---|
| `lib/features/estimate/widgets/step2_building.dart` | Remove 4 typology cards, 2 toggle widgets |
| `lib/features/estimate/widgets/step4_extras.dart` | Remove 5 field widgets |
| `lib/features/estimate/estimate_result_page.dart` | Equalise Save/Export button weights |
| `lib/features/shell/home_shell.dart` | Drop Analytics tab, rename People→Find Builders, render BuilderMarketplacePage |
| `lib/core/models/app_user.dart` | Update `visibleTabIndices` return value + doc-comment |
| `lib/features/project/project_details_page.dart` | Reduce to 3 tabs, prune overflow menu |
| `lib/features/project/tabs/changes_tab.dart` | **New file** — lightweight variation orders tab |
| `lib/features/auth/sign_in_page.dart` | Replace 9-card picker with 2-card picker |
| `lib/features/account/upgrade_page.dart` | Hide Business + Builder SKU for `isClient` roles |
| `lib/features/account/account_page.dart` | Verify/fix professional-section visibility gates |

---

## Success Criteria

### Automated (widget or integration tests)
1. Estimate wizard Step 2 renders exactly 2 building type cards
2. Estimate wizard Step 2 contains no widget with text matching `'M&E'`, `'curtain'`, or `'glazing'`
3. Estimate wizard Step 4 contains no widget with text matching `'swimming pool'`, `'generator'`, `'security wall'`, `'OHP'`, or `'professional fees'`
4. `HomeShell` renders exactly 4 `NavigationDestination` widgets for a signed-in homeowner
5. The "Find Builders" `NavigationDestination` label is present; the "Analytics" and "Marketplace" labels are absent
6. `ProjectDetailsPage` renders exactly 3 tabs: Overview, Finance, Changes
7. Upgrade page for a homeowner role renders exactly 3 tier cards (not 5)
8. Sign-up role picker renders exactly 2 cards

### Manual QA
- A first-time user can complete an estimate without asking what any field means
- The result screen makes "Save as Project" and "Export PDF" equally obvious choices
- A homeowner opening their project immediately understands all 3 tabs without explanation

---

## Phase 2 Additions (not in scope)

- High-rise, office, warehouse, factory building types
- Enhanced M&E and curtain wall cost toggles
- Professional fees / GIQS scale in wizard
- Swimming pool, generator house, security wall add-ons
- Progress/Work tab, Documents tab, Risks tab in project details
- Invoices, labor tracking, snag list, site visits, drawings, permits, contracts inside projects
- Analytics tab (standalone)
- Vendors directory and PM marketplace in Find Builders tab
- Professional sub-type selection at sign-up (architect, engineer, inspector, etc.)
- Business and Builder SKU tiers shown to client roles
- Cash flow tab, quote comparison, project templates, audit trail
- Mortgage calculator, build timeline, audit log in project overflow menu
