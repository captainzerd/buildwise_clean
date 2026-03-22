# WyseBrix Product Roadmap — Full Phased Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform WyseBrix into the leading construction project management platform for Ghanaian diaspora and local clients — built on a trust-first narrative with transparent cost management, phase approval, fraud prevention, and contractor verification.

**Architecture:** Firebase/Firestore backend with Flutter frontend. Estimation engine is pure Dart (portable, testable). Provider + GetIt for state management. Paystack (Ghana) + Stripe (diaspora) for payments.

**Tech Stack:** Flutter, Firebase (Auth, Firestore, Storage, Functions, App Check, Crashlytics), Paystack, Stripe, GoRouter, Provider, GetIt, fl_chart, pdf, share_plus.

**Market:** Diaspora Ghanaians (primary), local Ghanaian middle-class (secondary), small property developers (tertiary).

---

## OVERVIEW OF PHASES

| Phase | Name | Timeline | Goal |
|---|---|---|---|
| 0 | Quick Wins | Week 1 | Fix critical issues, add trust signals |
| 1 | MVP Hardening | Month 1 | Mandatory photos, receipt upload, payment-approval link |
| 2 | Trust & Verification | Month 2–3 | Contractor verification story, weekly cadence, builder UX |
| 3 | Marketplace & Growth | Month 4–6 | Builder marketplace, materials price index, escrow-lite |
| 4 | Scale & AI | Month 7–12 | Commercial types, AI optimiser, API integrations |

---

## PHASE 0 — QUICK WINS (Week 1)

> These are 1–4 hour tasks. High impact, minimal risk. Ship all of these before any marketing.

---

### Task 0.1: Stamp Catalog Version Date on Every Estimate

**Why:** Clients must know if rates are current. A stale estimate causes project over-runs and destroys trust.

**Files:**
- Modify: `lib/features/estimate/estimate_result_page.dart`
- Modify: `lib/core/services/catalog_service.dart`
- Modify: `lib/core/models/catalog_version.dart`

**Step 1: Expose `publishedAt` from CatalogVersion**

In `catalog_version.dart`, ensure `publishedAt` (DateTime?) is serialised from Firestore. If missing, fall back to a hardcoded Q1 2026 date.

```dart
// In CatalogVersion.fromMap():
publishedAt: (map['publishedAt'] as Timestamp?)?.toDate() ?? DateTime(2026, 1, 1),
```

**Step 2: Expose date through CatalogService**

```dart
// In catalog_service.dart
DateTime? get ratesPublishedAt => _active?.publishedAt;
String get ratesVersionLabel {
  final d = ratesPublishedAt;
  if (d == null) return 'Q1 2026 (estimated)';
  return DateFormat('MMM yyyy').format(d);
}
```

**Step 3: Show rate freshness on estimate result page**

In `estimate_result_page.dart`, add below the total card:

```dart
Consumer<CatalogService>(
  builder: (_, catalog, __) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        Icon(Icons.info_outline, size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Rates current as of ${catalog.ratesVersionLabel}. '
            'Actual costs may vary. Obtain a professional QS estimate before tendering.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  ),
),
```

**Step 4: Commit**
```bash
git add lib/features/estimate/estimate_result_page.dart \
        lib/core/services/catalog_service.dart \
        lib/core/models/catalog_version.dart
git commit -m "feat: show catalog version date and rate disclaimer on estimate result"
```

---

### Task 0.2: BOQ Disclaimer & Watermark

**Why:** The auto-generated BOQ creates legal and reputational risk if clients present it as a professional document.

**Files:**
- Modify: `lib/features/estimate/boq_page.dart`
- Modify: `lib/core/services/pdf_service.dart`

**Step 1: Rename "Bill of Quantities" to "Indicative Quantity Schedule" everywhere**

Search and replace in boq_page.dart, pdf_service.dart, and any export strings:
```
"Bill of Quantities" → "Indicative Quantity Schedule"
"BOQ" in display labels → "IQS"
```

**Step 2: Add banner to BoqPage**

At the top of the BOQ page body, before the list:

```dart
Container(
  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3)),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.warning_amber_rounded,
        color: Theme.of(context).colorScheme.error, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'INDICATIVE ONLY — Quantities are estimated from floor area geometry, '
          'not measured from drawings. This schedule is NOT a substitute for a '
          'Bill of Quantities prepared by a Licensed Quantity Surveyor.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    ],
  ),
),
```

**Step 3: Add watermark text to PDF header in pdf_service.dart**

Add to every PDF page header:
```
"INDICATIVE QUANTITY SCHEDULE — NOT A CONTRACT DOCUMENT"
```

**Step 4: Commit**
```bash
git commit -m "feat: rebrand BOQ as Indicative Quantity Schedule with disclaimer watermark"
```

---

### Task 0.3: Analytics Basic Access for Project Pass Holders

**Why:** A Project Pass holder who can't see budget utilisation will churn. Only multi-project portfolio view should be Pro-gated.

**Files:**
- Modify: `lib/core/models/app_user.dart`
- Modify: `lib/features/analytics/analytics_page.dart`

**Step 1: Add `canAccessBasicAnalytics` to AppUser**

```dart
bool get canAccessBasicAnalytics =>
    subscriptionTier == SubscriptionTier.projectPass ||
    subscriptionTier == SubscriptionTier.pro ||
    subscriptionTier == SubscriptionTier.business;

bool get canAccessPortfolioAnalytics =>
    subscriptionTier == SubscriptionTier.pro ||
    subscriptionTier == SubscriptionTier.business;
```

**Step 2: Split AnalyticsPage into basic and portfolio sections**

Wrap the single-project budget card + phase progress in a section accessible to `canAccessBasicAnalytics`. Wrap the multi-project portfolio section in `SubscriptionGate` requiring `canAccessPortfolioAnalytics`.

**Step 3: Commit**
```bash
git commit -m "feat: allow Project Pass holders access to basic single-project analytics"
```

---

### Task 0.4: Replace In-App Chat with WhatsApp Deeplink

**Why:** In-app chat is expensive to build well and hard to moderate. WhatsApp is how Ghanaians communicate. This reduces Firebase costs and support overhead.

**Files:**
- Modify: `lib/features/project/project_details_page.dart`
- Delete or hide: chat tab integration
- Add: `lib/features/project/widgets/whatsapp_contact_button.dart`

**Step 1: Create WhatsApp deeplink button widget**

```dart
// lib/features/project/widgets/whatsapp_contact_button.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppContactButton extends StatelessWidget {
  const WhatsAppContactButton({
    super.key,
    required this.phone,
    required this.label,
    this.message,
  });

  final String phone;
  final String label;
  final String? message;

  Future<void> _launch() async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final encoded = Uri.encodeComponent(message ?? 'Hello, I am contacting you via WyseBrix.');
    final uri = Uri.parse('https://wa.me/$cleaned?text=$encoded');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _launch,
      icon: const Icon(Icons.chat_outlined),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF25D366), // WhatsApp green
      ),
    );
  }
}
```

**Step 2: Add to project overview tab**

In the project overview/team section, replace chat tab button with:
```dart
WhatsAppContactButton(
  phone: builderPhone,
  label: 'Message Builder on WhatsApp',
  message: 'Hi, I am contacting you about project: ${project.title}',
),
```

**Step 3: Hide chat tab from navigation in project details page**

Remove or comment out the Chat tab from the TabBar. Add a note: `// Chat: deferred to Phase 2 — using WhatsApp deeplink for MVP`

**Step 4: Commit**
```bash
git commit -m "feat: replace in-app chat with WhatsApp deeplink for MVP"
```

---

### Task 0.5: Simplify Onboarding to 3 Screens

**Why:** Diaspora users want to estimate within 60 seconds. 4+ onboarding screens with role selection causes drop-off.

**Files:**
- Modify: `lib/features/onboarding/onboarding_page.dart`

**New 3-screen structure:**

| Screen | Headline | Subtext | Visual |
|---|---|---|---|
| 1 | "Know your build cost before you break ground" | "Instant estimates based on Ghana market rates — in GHS, GBP, USD or EUR." | Calculator / house icon |
| 2 | "See every phase. Approve before paying." | "Your builder can't move to the next phase without your sign-off. Every payment is tracked." | Checklist / shield icon |
| 3 | "Your build. Your control." | "Whether you're in Accra or London, WyseBrix puts you in charge." | Globe / phone icon |

Remove the role-selection slide — role is captured during sign-up, not onboarding.

**Step 1: Update `_OnboardPage` data list to 3 items**
**Step 2: Remove role selection slide and its state**
**Step 3: Update page indicator dots (3 instead of 4)**
**Step 4: Commit**

```bash
git commit -m "feat: simplify onboarding to 3 screens focused on diaspora trust narrative"
```

---

### Task 0.6: Prominently Show Diaspora Currency on Estimate

**Why:** The #1 question a diaspora client has is "what does this cost in pounds/dollars?" The currency picker is currently buried.

**Files:**
- Modify: `lib/features/estimate/estimate_result_page.dart`
- Modify: `lib/features/estimate/widgets/step1_project.dart`

**Step 1: Auto-detect locale and pre-select currency**

In `EstimateController.init()`, check device locale:
```dart
final locale = PlatformDispatcher.instance.locale.countryCode;
if (locale == 'GB') setCurrency(CurrencyInfo.gbp);
else if (locale == 'US') setCurrency(CurrencyInfo.usd);
else if (locale == 'CA') setCurrency(CurrencyInfo.cad);
// etc.
```

**Step 2: Show dual-currency total on result page**

On the main total card, show GHS total prominently with diaspora currency below:
```dart
Text(ghsFormatted, style: displayLarge),  // primary
if (currency != CurrencyInfo.ghs)
  Text(localCurrencyFormatted, style: titleMedium.onSurfaceVariant), // secondary
```

**Step 3: Commit**
```bash
git commit -m "feat: auto-detect locale currency and show dual-currency total on estimate result"
```

---

## PHASE 1 — MVP HARDENING (Month 1)

> These features are the core trust narrative. Non-negotiable for diaspora market adoption.

---

### Task 1.1: Mandatory Phase Photos

**Why:** Phase completion without photo evidence is the primary fraud vector. No photos = no submission.

**Files:**
- Modify: `lib/features/project/tabs/work_tab.dart`
- Modify: `lib/core/services/snapshot.dart` (or phase submission service)
- Create: `lib/features/project/widgets/photo_evidence_section.dart`

**Acceptance criteria:**
- Builder cannot submit phase for approval if `completionPhotoUrls` has fewer than 2 photos
- If photos < 2, submit button is disabled with tooltip "Add at least 2 progress photos"
- Photos are geotagged (lat/lng stored in Firestore alongside URL)
- Owner sees photo count badge on each phase card: "3 photos"

**Step 1: Create PhotoEvidenceSection widget**

Handles: image picker → Firebase Storage upload → Firestore update → display grid.

Enforces minimum 2 photos before allowing submission.

**Step 2: Add minimum photo guard to phase submission**

```dart
bool get canSubmitForApproval =>
    phase.completionPhotoUrls.length >= 2;
```

Display guard on submit button:
```dart
FilledButton(
  onPressed: canSubmitForApproval ? onSubmit : null,
  child: const Text('Submit for Approval'),
),
if (!canSubmitForApproval)
  Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      'Add at least 2 progress photos to submit',
      style: TextStyle(color: cs.error, fontSize: 12),
    ),
  ),
```

**Step 3: Allow free-tier builders to upload photos within a project**

In `AppUser.canUploadPhotos`, change to:
```dart
// Photos within projects are always allowed — gating on Project Pass caused
// anti-fraud features to be bypassed. Gate export/download behind paid tier.
bool get canUploadPhotos => true;
bool get canDownloadPhotos =>
    subscriptionTier != SubscriptionTier.free;
```

**Step 4: Add geotag capture**

Use `geolocator` package. On photo capture:
```dart
final position = await Geolocator.getCurrentPosition();
// Store alongside photo URL in Firestore: { url: "...", lat: x, lng: y, capturedAt: timestamp }
```

**Step 5: Commit**
```bash
git commit -m "feat: enforce minimum 2 geotagged photos before phase approval submission"
```

---

### Task 1.2: Material Receipt Upload

**Why:** Inflated material costs are the #1 fraud vector in Ghanaian construction. Receipt transparency destroys this vector.

**Files:**
- Create: `lib/features/project/widgets/receipt_upload_section.dart`
- Create: `lib/core/models/material_receipt.dart`
- Create: `lib/core/services/receipt_service.dart`
- Modify: `lib/features/project/tabs/work_tab.dart`
- Modify: `firestore.rules` (add receipts subcollection)

**Step 1: Create MaterialReceipt model**

```dart
// lib/core/models/material_receipt.dart
@immutable
class MaterialReceipt {
  const MaterialReceipt({
    required this.id,
    required this.projectId,
    required this.phaseId,
    required this.description,     // "50 bags Portland cement - Ghacem"
    required this.supplierName,    // "Ghacem Depot, Tema"
    required this.amountGhs,
    required this.receiptUrl,      // Firebase Storage URL
    required this.purchaseDate,
    required this.uploadedByUid,
    required this.uploadedAt,
  });
  // ... fromMap/toMap
}
```

**Step 2: Create ReceiptService (CRUD)**

Firestore path: `projects/{projectId}/receipts/{receiptId}`

**Step 3: Add ReceiptUploadSection to phase detail view**

- File picker (photo or PDF)
- Description field ("What did you buy?")
- Supplier name field
- Amount field
- Date picker
- Upload progress indicator

**Step 4: Show receipt total per phase**

On phase card: "Receipts: GHS 12,450 submitted" — helps owner cross-reference against phase payment

**Step 5: Add Firestore rule for receipts**

```
match /projects/{projectId}/receipts/{receiptId} {
  allow read: if isSignedIn() && isProjectMember();
  allow create: if isEmailVerified() && isProjectMember();
  allow delete: if isSignedIn() && isProjectOwner();
  allow update: if false; // receipts are immutable
}
```

**Step 6: Commit**
```bash
git commit -m "feat: add material receipt upload to phases for transparent cost tracking"
```

---

### Task 1.3: Phase-Approval Payment Prompt

**Why:** The diaspora workflow is: see photos → approve phase → pay builder. The app tracks these separately today. Linking them creates the "smart payment" narrative.

**Files:**
- Modify: `lib/features/project/tabs/work_tab.dart`
- Modify: `lib/core/services/snapshot.dart` (phase approval flow)

**Step 1: After owner approves a phase, show payment prompt**

```dart
// After successful phase approval API call:
await showModalBottomSheet(
  context: context,
  builder: (_) => _PhasePaymentPrompt(
    phase: approvedPhase,
    projectId: projectId,
  ),
);
```

**Step 2: Create `_PhasePaymentPrompt` widget**

```dart
// Shows:
// "Phase approved! Ready to release payment?"
// Phase name: Superstructure
// Estimated cost: GHS 145,000
// [Record Payment]  [Skip for now]
```

Tapping "Record Payment" pre-fills the payment form with phase name and estimated cost, navigating to the add-payment sheet.

**Step 3: Commit**
```bash
git commit -m "feat: prompt owner to record payment immediately after phase approval"
```

---

### Task 1.4: Required Update Cadence

**Why:** Without enforced cadence, builders go silent. Diaspora clients need predictable updates.

**Files:**
- Modify: `lib/core/models/project.dart` (add `updateFrequencyDays` field)
- Modify: `lib/features/project/create_project_page.dart`
- Modify: `lib/features/project/edit_project_page.dart`
- Create: `functions/src/updateReminderScheduler.ts` (Cloud Function)

**Step 1: Add `updateFrequencyDays` to Project model**

```dart
final int updateFrequencyDays; // 7 = weekly, 14 = fortnightly, 0 = not required
```

Default: 7 (weekly) for active projects.

**Step 2: Add cadence selector to project creation/edit**

```dart
DropdownButtonFormField<int>(
  label: 'Required update frequency',
  items: [
    DropdownMenuItem(value: 0, child: Text('Not required')),
    DropdownMenuItem(value: 7, child: Text('Weekly')),
    DropdownMenuItem(value: 14, child: Text('Fortnightly')),
  ],
  ...
)
```

**Step 3: Cloud Function — daily scheduler**

`functions/src/updateReminderScheduler.ts`:
- Runs daily at 08:00 GMT
- Queries active projects where `updateFrequencyDays > 0`
- For each: checks `lastUpdateAt` timestamp on project updates subcollection
- If `now - lastUpdateAt > updateFrequencyDays`, sends push notification to assigned builder: *"Your client is waiting for a project update on [Project Name]"*
- If 48h past due, sends notification to owner: *"No update received for [Project Name] in X days"*

**Step 4: Commit**
```bash
git commit -m "feat: add configurable update cadence with automated reminders via Cloud Function"
```

---

### Task 1.5: Simplify Variation Orders to Change Requests

**Why:** The current VO workflow has PM certification and complex approval states that are too heavy for MVP users.

**Files:**
- Modify: `lib/features/project/variation_orders_page.dart`
- Modify: `lib/core/models/variation_order.dart` (if exists)
- Simplify: remove PM certification requirement from UI

**New simplified flow:**
1. Builder submits: Title, Description, Cost Impact (GHS), Reason
2. Owner sees: pending change requests
3. Owner action: Approve or Reject (with optional comment)
4. Approved: cost delta added to `amountSpent` tracking

Remove: PM certification, `voRequiresCertification` logic from UI (keep in rules for future).

**Step 1: Rebuild VariationOrdersPage as simple list + form**
**Step 2: Submit form: title, description, costDeltaGhs, reason, attached photo (optional)**
**Step 3: Owner approval: two-button row (Approve / Reject)**
**Step 4: Commit**
```bash
git commit -m "refactor: simplify variation orders to basic change request flow for MVP"
```

---

### Task 1.6: Fix Estimation Base Rates

**Why:** Stale rates cause client trust failures faster than any UX issue.

**Files:**
- Modify: `lib/core/models/catalog_version.dart` (fallback rates)
- Modify: Firebase admin: `cost_catalog` Firestore document

**Step 1: Validate current rates against Ghana market**

Engage a licensed Ghanaian QS (or use current tender data) to verify:
- Economy: GHS 4,500/m² — is this current?
- Standard: GHS 6,200/m² — is this current?
- Premium: GHS 10,500/m² — is this current?

Note: With Ghana's construction inflation 2023–2025, these may need revision upward.

**Step 2: Update admin Firestore catalog document with validated rates and `publishedAt` timestamp**

**Step 3: Update fallback rates in `catalog_version.dart`**

**Step 4: Add typology-adjusted phase weights**

Current: flat weights for all typologies. Update to:

```dart
// Phase weights by typology
static const _phaseWeightsByTypology = {
  'residentialStandard': {
    'Substructure': 0.15, 'Superstructure': 0.30,
    'Roofing': 0.12, 'Finishes': 0.28, 'MEP': 0.15,
  },
  'residentialMediumRise': {
    'Substructure': 0.16, 'Superstructure': 0.32,
    'Roofing': 0.08, 'Finishes': 0.22, 'MEP': 0.22,
  },
  'residentialHighRise': {
    'Substructure': 0.17, 'Superstructure': 0.33,
    'Roofing': 0.06, 'Finishes': 0.20, 'MEP': 0.24,
  },
};
```

**Step 5: Update storey premium formula**

```dart
// Replace: 10% per floor (linear)
// With: first floor +16%, subsequent +10%
double _storeyPremium(int floors) {
  if (floors <= 1) return 0.0;
  return 0.16 + (floors - 2).clamp(0, 99) * 0.10;
}
```

**Step 6: Add missing cost line items to catalog**

Add to `CatalogVersion`:
- `electricityConnectionGhs`: 15000.0 (default, visible as optional add-on)
- `boreholeCostGhs`: 20000.0 (optional)
- `soilTestGhs`: 5000.0 (optional, shown as advisory)

**Step 7: Commit**
```bash
git commit -m "feat: update estimation rates, typology-adjusted phase weights, corrected storey premium"
```

---

## PHASE 2 — TRUST & VERIFICATION (Month 2–3)

---

### Task 2.1: Contractor Verification Badge & Story

**Why:** "Every builder on WyseBrix has submitted proof of NCA licence, ID, and insurance" is your trust moat.

**Files:**
- Modify: `lib/features/project/builder_profile_detail_page.dart`
- Modify: `lib/features/people/people_page.dart`
- Create: `lib/core/widgets/verification_badge.dart`
- Modify: `lib/features/admin/licence_verification_admin_page.dart`

**Step 1: Create VerificationBadge widget**

Tiered badges:
- **ID Verified** (green shield) — Ghana Card verified
- **NCA Licensed** (blue badge) — NCA class shown (e.g. "D2 Contractor")
- **Insured** (gold badge) — PLI verified and not expired
- **Business Registered** (grey badge) — REGISTRAR GENERAL verified

```dart
// lib/core/widgets/verification_badge.dart
class VerificationBadge extends StatelessWidget {
  // Displays appropriate badge row for a BuilderProfile
}
```

**Step 2: Show verification badges on builder profile detail and people list cards**

**Step 3: Add "Verification required to appear in marketplace" prompt in BuilderProfilePage**

If key verifications are missing, show a card: *"Complete your verification to unlock marketplace visibility and earn client trust."* List missing verifications with action tiles.

**Step 4: Admin tool: licence verification admin page must show photo ID + licence doc side by side for verification**

**Step 5: Commit**
```bash
git commit -m "feat: contractor verification badges with NCA, ID, insurance, and business registration tiers"
```

---

### Task 2.2: Build Progress Timeline (Photo Feed)

**Why:** A chronological photo feed showing the build progressing over time is your viral/sharing feature. Diaspora clients will share it with family.

**Files:**
- Create: `lib/features/project/progress_timeline_page.dart`
- Create: `lib/core/models/progress_entry.dart`
- Modify: `lib/features/project/project_details_page.dart` (add tab or menu entry)

**ProgressEntry model:**
```dart
class ProgressEntry {
  final String id, projectId, phaseId, phaseName;
  final List<String> photoUrls;
  final String caption;
  final double? lat, lng;
  final DateTime capturedAt;
  final String uploadedByName;
}
```

**UI:** Reverse-chronological scrollable feed. Each entry shows: date, phase name, photos (horizontal scroll if multiple), caption, uploader name. Pinch-to-zoom on photos.

**Share button:** Generates a PDF or image collage of all progress photos for sharing.

**Step: Commit**
```bash
git commit -m "feat: build progress timeline as chronological photo feed with sharing"
```

---

### Task 2.3: Smart Budget Alerts

**Why:** "You've committed 65% of budget but only completed 40% of phases" is the most actionable insight for a project owner.

**Files:**
- Create: `functions/src/budgetAlerts.ts`
- Modify: `lib/features/project/project_details_page.dart`
- Create: `lib/features/project/widgets/budget_health_card.dart`

**Alert thresholds:**
- 50% budget spent but <30% phases complete → amber warning
- 75% budget spent but <50% phases complete → red alert + push notification
- 90% budget spent, any phase % → critical + push to owner

**BudgetHealthCard widget:**
```dart
// Shows traffic-light indicator:
// GREEN: spend % <= phase completion % + 10%
// AMBER: spend % > phase completion % + 10%
// RED: spend % > phase completion % + 25%
```

**Step: Commit**
```bash
git commit -m "feat: smart budget health alerts with traffic-light indicator and push notifications"
```

---

### Task 2.4: Builder-Focused UX (My Work View)

**Why:** Builders are time-poor, less tech-savvy, and often on-site. Their view needs to be radically simpler.

**Files:**
- Create: `lib/features/project/builder_dashboard_page.dart`
- Modify: `lib/features/project/projects_page.dart` (role-based routing)

**Builder dashboard shows (for their active project):**
- "What's due today" (phases pending submission, tasks due)
- "Awaiting your action" (owner feedback on rejected phases)
- "Upload progress photos" — big prominent CTA
- "Submit for approval" — when photos > 2 minimum
- "Record materials purchased" — receipt upload shortcut
- Payment history (what they've received)

**Step: Commit**
```bash
git commit -m "feat: builder-focused dashboard with simplified task-first UX"
```

---

### Task 2.5: Professional PDF Progress Report

**Why:** Diaspora clients want to show family/bank a professional one-page progress report.

**Files:**
- Modify: `lib/core/services/pdf_service.dart`
- Create: `lib/features/project/widgets/report_bottom_sheet.dart`

**Report content:**
1. Project summary (name, location, builder, start date)
2. Budget status (total, spent, %, traffic light)
3. Phase summary table (phase name, status, % complete, cost)
4. Progress photos (up to 6, latest from each completed phase)
5. Next milestone
6. Generated by WyseBrix with timestamp and version

**Export options:** Share PDF via email/WhatsApp.

**Step: Commit**
```bash
git commit -m "feat: one-page professional PDF progress report for sharing with family/bank"
```

---

### Task 2.6: Ghana Materials Price Index

**Why:** Transparent material pricing destroys the inflation fraud vector.

**Files:**
- Create: `lib/core/services/materials_price_service.dart`
- Create: `lib/features/estimate/widgets/market_prices_card.dart`
- Create: `functions/src/scrapeMaterialPrices.ts` (or use Ghana Build Exchange API if available)

**Key materials to track:**
- Portland cement (50kg bag) — Ghacem, Diamond
- Steel rebar (Y12, Y16 per tonne)
- Concrete blocks (6" sandcrete, per block)
- Sand (tipper load)
- Granite aggregates (tipper load)
- Aluminium windows (sliding, per m²)

**Data source options:**
1. Partner with a Ghanaian building merchant for live prices
2. Community-reported prices (crowdsourced with admin verification)
3. Web scrape from Tonaton/Jiji building materials listings

**Step: Commit**
```bash
git commit -m "feat: Ghana materials price index with weekly updated market rates"
```

---

## PHASE 3 — MARKETPLACE & GROWTH (Month 4–6)

---

### Task 3.1: Verified Builder Marketplace

**Why:** After Phase 2 verification infrastructure, surface it as a searchable marketplace.

**Files:**
- Modify: `lib/features/people/people_page.dart`
- Create: `lib/features/people/builder_search_page.dart`
- Modify: `lib/core/models/builder_profile.dart`

**Search filters:**
- Region (16 Ghana regions)
- Specialty (residential, commercial, renovation, etc.)
- NCA class (D1–D8, G1–G8)
- Verified only toggle
- Budget range (minimumBudgetGhs)
- Rating (4+ stars)

**Builder card shows:**
- Name + verification badges
- NCA class
- Average rating + review count
- Region + specializations
- Min project budget
- Portfolio thumbnail
- "Contact on WhatsApp" + "Request Quote" CTAs

**Step: Commit**
```bash
git commit -m "feat: searchable verified builder marketplace with filter by region, NCA class, specialty"
```

---

### Task 3.2: Escrow-Lite Payment Release

**Why:** Milestone-payment linkage is the logical next step after Phase 1.3. Full escrow is complex — "escrow-lite" is a UX promise, not a financial product.

**Files:**
- Create: `lib/features/project/widgets/milestone_payment_card.dart`
- Modify: `lib/core/services/payment_service.dart`
- Create: `functions/src/paymentRelease.ts`

**Flow:**
1. Owner sets phase payment amount at phase creation (% of budget or fixed GHS)
2. When phase approved, Paystack/Stripe transaction initiated from owner → to WyseBrix holding reference
3. WyseBrix releases to builder via mobile money within 24h
4. 2% platform fee retained

**Note:** This requires a Ghanaian Payment Service Provider (PSP) licence or partnership with a licensed entity. Explore: Ghana Interbank Payment and Settlement Systems (GHIPSS) API, Express Pay, or sub-merchant arrangement with Paystack.

**Step: Commit after PSP partnership confirmed**
```bash
git commit -m "feat: milestone payment release linked to phase approval"
```

---

### Task 3.3: PM Marketplace (Full)

**Why:** With Phase 1–2 done, the trust infrastructure supports a 3-way PM relationship.

**Files:**
- Modify: `lib/features/project/pm_marketplace_page.dart`
- Create: `lib/features/project/hire_pm_flow.dart`

**PM profile shows:**
- PM specialty (residential, infrastructure, commercial)
- Certifications (CIQS, PMP)
- Current project load (how many active projects)
- Daily/weekly rate in GHS
- Verified via ID + certification upload

**Hiring flow:**
1. Owner browses → selects PM → sends project invite
2. PM accepts → assigned to project
3. PM can now approve phases (becomes second layer of oversight)
4. PM receives 5–10% of project budget (managed outside app, payment tracked inside)

**Step: Commit**
```bash
git commit -m "feat: PM marketplace with hire flow and project assignment"
```

---

### Task 3.4: Mortgage Calculator Integration

**Why:** Many clients building in Ghana are using UK mortgage equity release or local bank financing.

**Files:**
- Create: `lib/features/estimate/widgets/mortgage_calculator_card.dart`

**Calculator inputs:**
- Build cost (auto-filled from estimate)
- Deposit %
- Loan term (years)
- Interest rate (pre-filled with Stanbic/Absa/Republic current rates)
- Currency (GHS/GBP/USD)

**Output:** Monthly repayment, total interest, LTV ratio.

**Show contact CTA:** "Speak to a mortgage advisor" → partner bank WhatsApp/link.

**Step: Commit**
```bash
git commit -m "feat: mortgage calculator with Ghana bank rates pre-filled from estimate"
```

---

## PHASE 4 — SCALE & AI (Month 7–12)

---

### Task 4.1: Commercial Building Types

**Files:**
- Modify: `lib/features/estimate/widgets/step2_building.dart` (un-reserve commercial types)
- Modify: `lib/core/use_cases/calculate_estimate.dart` (add commercial phase weights)
- Modify: `lib/core/models/catalog_version.dart` (add commercial base rates)

**Commercial types to add:**
- Office/Institution (1.35x base)
- Retail/Mixed Use (1.25x base)
- Warehouse/Factory (0.85x base — simpler finishes)

**Different phase weights for commercial:**
- Superstructure: 35% (more structural steel)
- MEP: 20–28% depending on type
- Finishes: 15–20% (warehouse) to 25% (office)

---

### Task 4.2: AI Cost Optimiser

**Files:**
- Create: `lib/features/estimate/widgets/ai_optimiser_card.dart`
- Create: `functions/src/optimiseEstimate.ts` (calls Claude API)

**Optimiser prompt:** Given the estimate parameters, suggest 3 specific changes that would reduce total cost by 10–20% while maintaining structural integrity and Ghana Building Code compliance.

**Example output:**
- "Switch from Pile to Raft foundation (soil condition: Soft) → saves GHS 45,000"
- "Use pitched sheet roof instead of concrete flat → saves GHS 28,000"
- "Economy MEP tier for budget build → saves GHS 18,000"

---

### Task 4.3: Drawing Viewer & Annotation

**Files:**
- Create: `lib/features/project/drawing_viewer_page.dart`

**Features:**
- PDF architectural plan viewer (full-screen)
- Pinch to zoom, pan
- Annotation layer: add comments with pin markers
- Share annotated PDF

---

### Task 4.4: NHBRC & Building Permit Tracker

**Files:**
- Create: `lib/features/project/permit_tracker_page.dart`

**Features:**
- Record permit application date, reference number, expected approval date
- Reminder when permit is approaching expiry
- Document upload (permit certificate)
- DA contact directory (Ghana's 261 District Assemblies) for follow-up

---

## MONETISATION ADJUSTMENTS

### Revised Tier Pricing

| Tier | GHS Price | GBP/USD equiv | What changes |
|---|---|---|---|
| **Free** | Free | Free | Estimate + 1 project read-only (no phase submission) |
| **Builder Pass** | GHS 349 one-time | ~£17 | Full 1 project, phase submission, photos, receipts, 24 months |
| **Pro** | GHS 99/month | ~£5.99/mo | Unlimited projects, analytics, PDF report, materials tracker |
| **Business** | GHS 249/month | ~£15/mo | All Pro + marketplace listing, escrow-lite, API access |
| **Builder SKU** | GHS 30/month | ~£1.80/mo | For professionals: marketplace visibility, verified badge, client project access |

**Key changes from current:**
- Add Builder SKU (supply-side subscription — builders pay to be visible)
- Show GBP/USD price prominently for diaspora on upgrade page
- Project Pass: emphasise "per house" positioning for diaspora self-builders
- Remove Pro analytics gate for single-project view

---

## MARKETING STRATEGY (Integrated with Product)

### In-app referral (Phase 1)
After first estimate: *"Share your WyseBrix estimate with your builder — they'll get a free builder account."* → WhatsApp share of PDF estimate → builder downloads app → supply-side growth.

### Diaspora community groups (Phase 1)
Target Facebook groups: "UK Ghanaians", "Ghana Real Estate Investors", "Building in Ghana" etc. Paid + organic. Key message: *"Your builder can't ghost you. Every payment is tracked. Every phase needs your approval."*

### Builder adoption (Phase 2)
Builders refer themselves when clients tell them "my owner uses WyseBrix." Reduce friction: builder onboarding in 5 minutes, WhatsApp-first communication, simple task view.

---

## SUCCESS METRICS BY PHASE

| Phase | Key Metric | Target |
|---|---|---|
| 0 | Estimate completions/week | +20% vs baseline |
| 1 | Project Pass conversions | 50 paying users |
| 1 | Photo upload rate per phase | >80% phases have photos |
| 2 | Verified builder profiles | 100 verified builders |
| 2 | Weekly active owners | 200 |
| 3 | Builder marketplace hires | 20/month |
| 3 | Revenue MRR | GHS 50,000 (~£3,000) |
| 4 | Commercial projects | 10% of all projects |
| 4 | Escrow volume | GHS 500,000/month |
