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

No new screens created. No screens deleted. Changes are confined to:
- Filtering display lists (building types, role cards, pricing tiers, project tabs, nav tabs)
- Removing specific widget fields (toggles, sliders, checkboxes) from wizard steps
- Hiding role-conditional sections in Account page
- Renaming one nav tab label

---

## Section 1 — Estimate Wizard

### Step 2: Building

**Building type list — reduce to 2 cards:**

| Keep | Enum value | Display label |
|---|---|---|
| ✅ | `residentialStandard` | House / Bungalow |
| ✅ | `residentialMediumRise` | Apartment / Compound House |
| ❌ removed | `residentialHighRise` | Residential High-rise |
| ❌ removed | `commercialOffice` | Commercial Office |
| ❌ removed | `commercialRetail` | Commercial Retail / Mixed Use |
| ❌ removed | `commercialWarehouse` | Commercial Warehouse / Factory |

Implementation: filter the displayed list in `step2_building.dart` — the `BuildingTypology` enum and `EstimationEngine` are unchanged.

**Remove from Step 2:**
- "Enhanced M&E services" toggle (`enhancedME` field) — remove widget only; calculation field stays in model for Phase 2
- "Curtain wall / large glazing" toggle (`curtainWall` field) — same

### Step 4: Extras

**Remove from Step 4:**
- Swimming pool toggle + range slider
- Generator house checkbox
- Security wall length field
- Professional fees toggle + percentage slider (GIQS scale)
- OHP (Overhead & Profit) percentage slider

**Keep in Step 4:**
- External works section (compound wall, driveway)
- Septic / soakaway checkbox
- Water storage tank checkbox
- Preliminaries % slider
- Contingency toggle + % slider
- Permit cost (percent or manual)
- Budget comparison field

### Result Screen

Two equally-weighted full-width action buttons stacked vertically:
1. **Save as Project** (primary filled button)
2. **Export PDF** (secondary outlined button)

No change to the computed result display (cost breakdown, phase chart, etc.).

---

## Section 2 — Navigation (HomeShell)

**Reduce from 5 tabs to 4:**

| Index | Label | Icon | Change |
|---|---|---|---|
| 0 | Estimate | `Icons.calculate_outlined` | unchanged |
| 1 | Projects | `Icons.work_outline` | unchanged |
| 2 | **Find Builders** | `Icons.storefront_outlined` | renamed from "Marketplace/People" |
| 3 | Account | `Icons.person_outline` | unchanged |

**Analytics tab (index 2) removed.** The `AnalyticsPage` route remains in the router but is not linked from any tab.

**`visibleTabIndices` in `ProfessionalTypeInfo`:**
Update all roles to use indices `{0, 1, 2, 3}` (4-tab set). Professional roles keep "My Work" label on tab 1.

**`_buildBody` in `HomeShell`:**
Update switch to map new indices:
- 0 → `EstimatePage`
- 1 → `ProjectsPage` (auth-guarded)
- 2 → `BuilderMarketplacePage` (public, no auth required)
- 3 → `AccountPage`

---

## Section 3 — Project Details Page

**Reduce to 4 tabs inside `ProjectDetailsPage`:**

| Tab | Content |
|---|---|
| **Overview** | Budget snapshot cards (spent / total / % used), current phase label, phase progress bar, basic spend-by-phase breakdown. Replaces standalone Analytics tab content for single project. |
| **Finance** | Cost entries list grouped by phase + "Add cost entry" FAB |
| **Photos** | Photo grid with upload button, one section per build phase |
| **Changes** | Simplified variation orders — title, amount, reason, status chip |

**Remove from project UI (no navigation path):**
- Invoices (`/projects/:id/invoice`)
- Labor tracking (`/projects/:id/labor`)
- Snag list (`/projects/:id/snag`)
- Site visits (`/projects/:id/site-visits`)
- Land ownership / due diligence (`/projects/:id/due-diligence`)
- Quotes / RFQ (`/projects/:id/quotes`)
- Quote comparison (`/projects/:id/quote-comparison`)
- Project templates (`/projects/:id/templates`)
- Audit trail (`/projects/:id/audit`)
- Drawings (`/projects/:id/contract/create`, `/contract/view`)
- Progress timeline
- Cash flow tab

Routes remain registered in `router.dart` — they simply have no UI entry points in Phase 1.

**Project list page** — no changes.

---

## Section 4 — Sign-up Role Selection

**Replace 9 role cards with 2 large tappable cards** in the onboarding/sign-up role step:

| Card | Icon | Sub-label | Maps to `ProfessionalType` |
|---|---|---|---|
| I'm building a home | 🏠 | Planning or managing a residential build | `homeowner` |
| I'm a professional | 🔨 | Contractor, architect, engineer or surveyor | `contractor` |

Implementation: Replace the `ListView` of 9 `RoleCard` widgets in `onboarding_page.dart` (or wherever role selection is rendered) with two full-width `InkWell` cards. The underlying `ProfessionalType` values and `AuthService.signUp()` call are unchanged.

Professional sub-type (architect vs engineer vs inspector) deferred to Phase 2 profile setup.

**Onboarding carousel** (3-screen feature intro) — no changes.

---

## Section 5 — Pricing & Upgrade Page

**Homeowners (`homeowner` role) see 3 tiers only:**

| Tier | Price | Highlight |
|---|---|---|
| Free | GH₵0 | Default |
| Builder Pass | GH₵349 one-time | "Most Popular" badge, highlighted border |
| Pro | GH₵99/mo | — |

**Business and Builder SKU tiers hidden** when `auth.role == ProfessionalType.homeowner`.

**Professionals** (all non-homeowner roles) see all 5 tiers as currently built.

Implementation: Wrap the Business and Builder SKU tier cards in a conditional `if (!auth.role.isClient)` in `upgrade_page.dart`. No changes to payment flow, Paystack/Stripe integration, or subscription activation logic.

---

## Section 6 — Account Page

**For homeowner role — hide professional-only sections:**
- Builder Profile card / link
- PM Profile card / link
- Work History
- Certifications
- Portfolio
- RFQ Inbox

**Condition:** `if (auth.role.isProfessional)` already wraps most of these sections. Verify all professional sections are correctly gated and not visible to homeowners.

**Homeowners see:**
- Profile (display name, photo, phone)
- Subscription & upgrade
- Security (password change, 2FA, phone verification, email verification status)
- Login activity
- Sign out
- Delete account

No structural changes — only verify the existing role-conditional visibility is correct.

---

## Section 7 — Find Builders Tab

**Content of tab index 2:** Render `BuilderMarketplacePage` directly.

**Remove from this tab's UI:**
- Vendors directory entry point (`VendorsPage`)
- PM marketplace entry point (`PmMarketplacePage`)

`VendorsPage` and `PmMarketplacePage` routes remain registered. `BuilderProfileDetailPage` remains reachable from builder cards.

---

## What Does NOT Change

- `EstimationEngine` calculation logic — all multipliers, phase weights, and formula stay intact
- `BuildingTypology` enum — all 6 values stay; only the display list is filtered
- `EstimateInput` model — `enhancedME` and `curtainWall` fields stay; just not shown in UI
- All Phase 2 routes in `router.dart` — registered but unreachable from Phase 1 UI
- Firebase security rules, Cloud Functions, Firestore schema
- Admin panel — unchanged
- Payment integration (Paystack, Stripe)
- All test files

---

## Success Criteria

1. A new homeowner can complete an estimate in under 3 minutes without confusion
2. The wizard has no field a homeowner cannot understand without construction knowledge
3. The result screen offers both "Save as Project" and "Export PDF" with equal prominence
4. A new user sees exactly 4 tabs — each with a self-explanatory label
5. Sign-up role selection takes under 5 seconds — 2 cards, obvious choice
6. Homeowners never see "Builder SKU", "OHP", "Curtain wall", "Enhanced M&E", or "Government Regulator"
7. Opening a project shows 4 tabs — every tab's purpose is clear without explanation

---

## Phase 2 Additions (not in scope now)

- High-rise, office, warehouse, factory building types
- Enhanced M&E and curtain wall cost toggles
- Professional fees / GIQS scale in wizard
- Swimming pool, generator house, security wall add-ons
- Invoices, labor tracking, snag list, site visits, drawings, permits, contracts inside projects
- Analytics tab (standalone)
- Vendors directory and PM marketplace
- Professional sub-type selection at sign-up (architect, engineer, inspector, etc.)
- Business and Builder SKU subscription tiers shown to homeowners
- Cash flow tab, quote comparison, project templates, audit trail
