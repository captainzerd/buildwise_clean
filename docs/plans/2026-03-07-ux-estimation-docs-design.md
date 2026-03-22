# WyseBrix UX, Estimation & Document Management Design
Date: 2026-03-07
Status: Approved

---

## Scope

Four interconnected improvements:
1. Estimation logic redesign (Ghana QS/Architect perspective)
2. Document management system — architectural drawings integration
3. Project creation ↔ Estimate field alignment
4. Full UX/UI review — all screens

---

## Section 1: Estimation Logic Redesign

### 1.1 Building Typology (replaces binary Residential/Commercial)

New `BuildingTypology` enum with 6 values replacing the current binary:

| Enum value | Display label | Cost multiplier |
|---|---|---|
| `residentialStandard` | Residential Standard (Bungalow / Duplex / Terraced) | 1.00× |
| `residentialMediumRise` | Residential Medium-rise (Apt Block 3–6 storeys) | 1.18× |
| `residentialHighRise` | Residential High-rise (Apt Block 7+ storeys) | 1.40× |
| `commercialOffice` | Commercial Office / Bank / Institution | 1.22× |
| `commercialRetail` | Commercial Retail / Mixed Use | 1.28× |
| `commercialWarehouse` | Commercial Warehouse / Factory / Store | 0.88× |

Rationale:
- `residentialStandard`: single storey or split-level, simple structure, baseline cost
- `residentialMediumRise`: stair cores, structural columns, longer M&E runs (+18%)
- `residentialHighRise`: lift shaft, advanced fire egress, post-tensioned slab (+40%)
- `commercialOffice`: false ceiling, raised floor, AC ducting (+22%)
- `commercialRetail`: high floor-to-floor, shopfront glazing, loading bay (+28%)
- `commercialWarehouse`: portal frame, minimal finishes, wide-span roof (−12%)

Floor count in Step 3 handles repetition cost. Typology handles structural system complexity. No double-counting.

### 1.2 New Inputs to Expose

**Services tier** (Step 2 — M&E sub-option, replaces hardcoded 8%):
- Basic (1.00×) — standard plumbing, single-phase power, basic lighting
- Enhanced (1.18×) — AC, solar-ready, smart wiring, 3-phase power

**Curtain wall / Large glazing** (Step 4 toggle):
- Off: openings allocation remains 4% of base
- On: openings allocation raised to 8% of base

**Additional external works** (Step 4):
- Water storage tank: GH₵5,000 (fixed, checkbox)
- Generator house: GH₵12,000 (fixed, checkbox)
- Swimming pool: GH₵45,000–80,000 (slider, toggle to enable)
- Perimeter security wall with barbed wire: GH₵1,400/lm (linear metre input)

### 1.3 Multiplier Corrections (GhBC 2024 practice)

| Factor | Old multiplier | New multiplier | Reason |
|---|---|---|---|
| Raft foundation | 1.25× | 1.22× | Actual BQ data closer to 22% premium |
| Pile foundation | 1.65× | 1.55× | Pile driving in GH cheaper than model assumed |
| Waterlogged soil | 1.30× | 1.25× | Realistic for most coastal sites |
| Concrete flat roof | 1.45× | 1.38× | RC roof slab now mainstream, not luxury premium |

### 1.4 Result Page — Specification Cost Breakdown

Add expandable "Cost by Specification" card to result page showing:
- Baseline (Standard Residential Strip Foundation, Firm Soil, Pitched Sheet Roof): GH₵X
- Building typology premium/discount: ±GH₵X
- Foundation uplift: +GH₵X
- Soil condition uplift: +GH₵X
- Roof type uplift: +GH₵X
- Services tier uplift: +GH₵X
- External works: +GH₵X

Tab toggle on result: Phase Breakdown | Specification Breakdown

### 1.5 Step 2 UI — Illustrated ChoiceChip Cards

Replace radio buttons with 2-column illustrated ChoiceChip cards. Each card: icon + label + subtitle (e.g. "Bungalow, duplex or terraced house"). Tapping selects and scrolls to next section.

### 1.6 Step 4 UI — ExpansionTile Sections

Wrap each logical group in `ExpansionTile`:
- External Works (compound wall, driveway, septic, water tank, generator, pool, security wall)
- Services & Openings (M&E tier, curtain wall toggle)
- Commercials (prelims, OHP, professional fees)
- Contingency
- Permit
- Budget Comparison

### 1.7 Step 5 Review — Edit-in-place

Reformat Step 5 as grouped summary cards (one per step). Each card has an Edit icon that navigates back to that step. Fixes: users currently cannot go back without losing state.

---

## Section 2: Document Management System

### 2.1 DocumentCategory Enum — New Values

```dart
enum DocumentCategory {
  architecturalDrawing,  // NEW
  structuralDrawing,     // NEW
  landTitle,
  indenture,
  permit,
  boq,                   // NEW
  receipt,
  contract,              // NEW
  other,
}
```

Display labels and icons:
- `architecturalDrawing` → "Architectural Drawing", `Icons.architecture`
- `structuralDrawing` → "Structural Drawing", `Icons.engineering`
- `landTitle` → "Land Title", `Icons.landscape`
- `indenture` → "Indenture / Deed", `Icons.gavel`
- `permit` → "Building Permit", `Icons.approval`
- `boq` → "Bill of Quantities", `Icons.format_list_numbered`
- `receipt` → "Receipt / Invoice", `Icons.receipt_long`
- `contract` → "Contract", `Icons.handshake`
- `other` → "Other", `Icons.attach_file`

### 2.2 Architecture Plan — Unified Storage

Current: arch plan stored as `Project.architecturePlanUrl` (single URL on Project model).

New: arch plan uploaded during project creation creates a `ProjectDocument` with:
- `category: architecturalDrawing`
- `visibility: all`
- Storage path: `project_uploads/{projectId}/documents/{fileName}` (same as all docs)

`Project.architecturePlanUrl` field is deprecated — it becomes a derived getter that queries the documents subcollection for the first `architecturalDrawing` doc. Existing data migrated on read (if `architecturePlanUrl` is non-null and no `architecturalDrawing` doc exists, create one).

### 2.3 Documents Tab Improvements

- `FloatingActionButton.extended('Upload Document')` — clearly visible upload trigger
- Category filter chips row: All · Drawings · Land · Permits · BOQ · Contracts · Other
- Drawings section pinned at top when architectural/structural docs exist
- Thumbnail preview for image files; PDF page-count badge for PDF files
- Empty state: "No documents yet. Upload land title, permits, drawings or contracts."
- `showDragHandle: true` on upload bottom sheet

### 2.4 Overview Tab — "View Drawings" Quick Action

Quick action card on Overview tab: "Architecture Plan" → opens Documents tab filtered to `architecturalDrawing` + `structuralDrawing` categories.

### 2.5 BOQ Export → Auto-save as Document

When BOQ PDF is exported from Finance tab, it is automatically saved as a `ProjectDocument` with `category: boq`. User sees a snackbar: "BOQ saved to Documents."

---

## Section 3: Project Creation ↔ Estimate Alignment

### 3.1 Unified Building Typology

Project creation "Building Type" dropdown adopts the same 6 options from Section 1.1.
Old granular list (bungalow/duplex/terraced/…) retired.
"Project Type" (residential/commercial/industrial/infrastructure) kept as a high-level category tag for filtering only.

### 3.2 Optional QS Specification Fields in Project Creation

Collapsible "Specification Details" card below existing fields:
- Quality / Finish Level (Economy / Standard / Premium)
- Foundation Type (Strip / Raft / Pad / Pile)
- Soil Condition (Firm / Soft / Waterlogged / Laterite)
- Roof Type (Pitched sheet / Concrete flat / Tile)
- M&E Services Tier (Basic / Enhanced)

When filled: unlocks "Quick Re-estimate" button in Finance tab that recomputes budget using current catalog rates.

### 3.3 Pre-fill from Estimate → Project Creation

When "Create Project from Estimate" tapped on result page:

| Estimate field | Project field |
|---|---|
| Project name | Title |
| Region | Region |
| Building typology | Building type |
| Quality | Quality (spec details) |
| Foundation | Foundation (spec details) |
| Soil | Soil (spec details) |
| Roof | Roof (spec details) |
| M&E tier | M&E tier (spec details) |
| Estimate total (GHS) | Budget |
| Contingency GHS (computed) | Contingency reserve |
| Architecture plan (if attached) | Creates ProjectDocument (architecturalDrawing) |

### 3.4 Contingency Reconciliation

Project `contingencyGhs` receives the computed contingency GHS from the estimate result directly. No more percent vs. GHS mismatch.

### 3.5 Permit Linkage

Project creation retains: Permit Number + Approval Date (metadata).
Saved estimate retains: computed permit cost.
Finance tab: shows "Estimated permit cost: GH₵X · Actual permit: GH₵Y" when both are available.

---

## Section 4: UX/UI Fixes

### 4.1 Estimate Wizard

- Step 2: illustrated 2-column ChoiceChip grid for typology
- Step 4: `ExpansionTile` sections for each logical group
- Step 5: grouped summary cards with per-step Edit icons
- Result page: Phase Breakdown / Specification Breakdown tab toggle

### 4.2 Projects List

- Empty state: "Start with an estimate → create your first project" + "Get Estimate" CTA button
- Project cards: add subtitle `{region} · {buildingType}`

### 4.3 Project Details Tabs

- Rename "Work" tab to "Progress"
- Move chat to FAB overlay on Overview tab; free the 6th tab slot
- Overview quick-action cards: primary actions use `FilledButton`, secondary use `OutlinedButton`

### 4.4 Documents Tab

- `FloatingActionButton.extended` for upload (see Section 2.3)
- Category filter chips

### 4.5 Finance Tab

- Consolidate Costs + Payments into single scrollable page with labelled sections
- "Load more" TextButton with subtle divider — no layout-breaking standalone widget

### 4.6 Account Page

- Role chip: add tooltip "Contact support to change your role"
- Trust score: add `?` info button → bottom sheet explaining 5 scoring dimensions
- Subscription badge: show days remaining for Project Pass ("Project Pass · 23 days left")

### 4.7 Auth Pages

- Sign-in: add "Continue without account" TextButton → Estimate tab only
- Email verification: show Resend button immediately with countdown timer (not after 30s)

### 4.8 Onboarding

- Add "Skip" TextButton top-right on all 4 onboarding pages

### 4.9 Cross-cutting

- Loading states: replace `CircularProgressIndicator` on blank screens with `ShimmerBox` skeleton layouts
- Error states: replace raw exception text with friendly messages + Retry button
- Keyboard avoidance: `SingleChildScrollView` + `resizeToAvoidBottomInset: true` on all form Scaffolds
- Bottom sheets: `showDragHandle: true` on all `showModalBottomSheet` calls
- Snackbar duration: error snackbars use `SnackBarDuration.long` (10 seconds)

---

## Decisions

- Building typology: Option B (6 grouped types, not full granular list)
- Architecture plans: unified into ProjectDocument system, architecturePlanUrl deprecated
- Contingency: stored as GHS on both project and estimate result
- Chat tab: moved to FAB overlay on Overview, not a standalone tab
- Industrial/infrastructure estimate: deferred — current catalog covers residential/commercial only
