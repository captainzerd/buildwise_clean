# MVP Market-Ready Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix five critical/high-priority issues blocking market launch: project creation failure, estimate duplicate saves, unformatted currency, commercial building types showing in residential-only MVP, and missing Firestore composite index.

**Architecture:** Each task is a targeted surgical fix in existing files. No new abstractions. The estimate controller's `money()` helper needs `NumberFormat`, estimate saving needs an idempotent ID, the create/edit/estimate UIs need commercial types removed, and project creation needs email-verification pre-flight UI feedback.

**Tech Stack:** Flutter 3.x, Dart, Firebase Firestore, `intl` (already imported), `uuid` (already in pubspec), Provider/GetIt service locator.

---

## Context for all tasks

- **Working directory:** `/Users/donaldduodu/wysebrix`
- **Run `flutter analyze`** after each task. Zero new warnings expected.
- **Run app** on iPhone simulator to verify visually (`flutter run -d <device-id>`).
- The app uses `GetIt` (`sl<>()`) for services and `Provider` for state.
- All monetary values are in GHS (Ghanaian Cedi, symbol `GH₵`).

---

### Task 1: Email verification pre-flight check in project creation

**Problem:** When a user tries to create a project without a verified email, Firestore silently returns `permission-denied`, which appears as a cryptic error string in the UI.

**Files:**
- Modify: `lib/features/project/create_project_page.dart` (lines 292–417, the `_save()` method)

**Step 1: Read the file to understand the `_save()` method**

Read `lib/features/project/create_project_page.dart` lines 292–420.

**Step 2: Add email verification pre-flight at the top of `_save()`**

In `_CreateProjectPageState._save()`, immediately after `if (!_formKey.currentState!.validate()) return;`, insert this block **before** the `setState(() { _saving = true; ... })`:

```dart
// Email verification gate — Firestore rules require emailVerified.
final auth = context.read<AuthService>();
final user = auth.currentUser;
if (user == null) {
  setState(() => _error = 'You must be signed in to create a project.');
  return;
}
if (!(user.emailVerified)) {
  if (!mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Verify your email first'),
      content: const Text(
        'Please check your inbox and tap the verification link we sent you. '
        'Once verified, reload the app and try again.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  return;
}
```

**IMPORTANT:** The `auth` variable is already declared later in the method (line ~301: `final auth = context.read<AuthService>();`). After inserting the pre-flight check, **remove** the duplicate `auth` declaration from the method body (keep only the one in the pre-flight block).

The final `_save()` opening should look like:

```dart
Future<void> _save() async {
  if (!_formKey.currentState!.validate()) return;

  // Email verification gate — Firestore rules require emailVerified.
  final auth = context.read<AuthService>();
  final user = auth.currentUser;
  if (user == null) {
    setState(() => _error = 'You must be signed in to create a project.');
    return;
  }
  if (!(user.emailVerified)) {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify your email first'),
        content: const Text(
          'Please check your inbox and tap the verification link we sent you. '
          'Once verified, reload the app and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  setState(() {
    _saving = true;
    _error = null;
  });

  try {
    // Remove the duplicate: final auth = context.read<AuthService>(); line here
    final projectService = sl<ProjectService>();
    final uid = user.uid;   // use `user` not `auth.currentUser!`
    ...
```

**Step 3: Run flutter analyze**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/features/project/create_project_page.dart
```

Expected: No new errors.

**Step 4: Commit**

```bash
cd /Users/donaldduodu/wysebrix && git add lib/features/project/create_project_page.dart && git commit -m "fix: show email verification dialog before project creation"
```

---

### Task 2: Fix estimate saving — prevent duplicate saves with idempotent ID

**Problem:** `estimate_result_page.dart` line 300 uses `.add(data)` which auto-generates a new Firestore document ID on every tap, creating duplicate saves.

**Files:**
- Modify: `lib/features/estimate/estimate_result_page.dart` (lines 272–309, the `_save()` method)

**Step 1: Read the file**

Read `lib/features/estimate/estimate_result_page.dart` lines 272–310.

Current code at lines 297–301:
```dart
await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .collection('estimates')
    .add(data);
```

**Step 2: Add uuid import and change .add() to .doc().set()**

First, add the uuid import at the top of the file (with the other imports):
```dart
import 'package:uuid/uuid.dart';
```

Then change the `.add(data)` call to use an explicit document ID:

```dart
final docId = const Uuid().v4();
await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .collection('estimates')
    .doc(docId)
    .set(data);
```

This means if the user taps Save twice (network hiccup), the second write is idempotent — it just overwrites the same document.

**Step 3: Run flutter analyze**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/features/estimate/estimate_result_page.dart
```

Expected: No errors.

**Step 4: Commit**

```bash
cd /Users/donaldduodu/wysebrix && git add lib/features/estimate/estimate_result_page.dart && git commit -m "fix: use idempotent document ID for estimate saves to prevent duplicates"
```

---

### Task 3: Currency formatting — add thousand separators

**Problem:** The `money()` helper in `estimate_controller.dart` uses `toStringAsFixed(0)` which produces `450000` instead of `GH₵ 450,000`. Ghana users expect comma-separated thousands.

**Files:**
- Modify: `lib/features/estimate/state/estimate_controller.dart` (around lines 479–495)

**Step 1: Read the file**

Read `lib/features/estimate/state/estimate_controller.dart` lines 479–496.

Current code:
```dart
String money(double ghs) {
  final sym = currency.symbol;
  if (currency.code == 'GHS') {
    return '$sym${_fmt(ghs)}';
  }
  final converted = fxService.convertFromGhs(
    amountGhs: ghs,
    to: currency.code,
  );
  return '$sym${_fmt(converted)}';
}

String _fmt(double v) =>
    v >= 1000 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
```

**Step 2: Check existing imports in estimate_controller.dart**

Read the top ~15 lines of the file. The file already imports `package:flutter/material.dart` indirectly. Check if `intl` is already imported. Look for `import 'package:intl/intl.dart';`.

If not present, add:
```dart
import 'package:intl/intl.dart';
```

**Step 3: Replace `_fmt()` with NumberFormat**

Replace the `_fmt()` method with:

```dart
static final _nfGhs = NumberFormat('#,##0.##', 'en_US');

String _fmt(double v) => _nfGhs.format(v);
```

The pattern `'#,##0.##'` means:
- Comma-separated thousands
- No decimal places for whole numbers
- Up to 2 decimal places when there are cents

This gives:
- `450000` → `450,000`
- `1234567.5` → `1,234,567.5`
- `1500.25` → `1,500.25`

The `money()` method stays unchanged — it calls `_fmt()` internally.

**Step 4: Run flutter analyze**

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/features/estimate/state/estimate_controller.dart
```

Expected: No errors.

**Step 5: Commit**

```bash
cd /Users/donaldduodu/wysebrix && git add lib/features/estimate/state/estimate_controller.dart && git commit -m "fix: currency formatting with thousand separators using NumberFormat"
```

---

### Task 4: Residential-only building types in 3 files

**Problem:** For MVP, only residential building types should appear. Currently:
- `step2_building.dart`: shows all 6 `BuildingTypology.values` including 3 commercial
- `create_project_page.dart`: shows 3 residential + 3 commercial in the building type dropdown + 4 project types
- `edit_project_page.dart`: shows 8 old-style building types with mismatched key values

**Files:**
- Modify: `lib/features/estimate/widgets/step2_building.dart`
- Modify: `lib/features/project/create_project_page.dart`
- Modify: `lib/features/project/edit_project_page.dart`

#### 4a: Filter step2_building.dart to residential only

**Step 1:** Read `lib/features/estimate/widgets/step2_building.dart` lines 60–122.

The current code at line 65:
```dart
for (final t in BuildingTypology.values)
```

**Step 2:** Change to iterate only the 3 residential types:

```dart
for (final t in const [
  BuildingTypology.residentialStandard,
  BuildingTypology.residentialMediumRise,
  BuildingTypology.residentialHighRise,
])
```

This is a one-line change on line 65.

**Step 3:** Run flutter analyze on the file.

#### 4b: Update create_project_page.dart building types

**Step 1:** Read `lib/features/project/create_project_page.dart` lines 91–96 (project types) and lines 527–562 (building type dropdown).

**Step 2:** Remove the `_projectTypes` list entirely (lines 91–96) or simplify. Since project type is now always 'residential', the simplest MVP approach is to remove the project type dropdown from the form entirely and hard-code `projectType: 'residential'` in the `_save()` method.

Change line ~332 in `_save()` from:
```dart
projectType: _projectType,
```
to:
```dart
projectType: 'residential',
```

Then remove the entire project type dropdown section from the `build()` method (lines 511–523):
```dart
// Project type   — REMOVE THIS BLOCK
DropdownButtonFormField<String>(
  decoration: const InputDecoration(
    labelText: 'Project type (optional)',
    border: OutlineInputBorder(),
  ),
  initialValue: _projectType,
  items: [
    const DropdownMenuItem(value: null, child: Text('— Select —')),
    for (final t in _projectTypes)
      DropdownMenuItem(value: t.$1, child: Text(t.$2)),
  ],
  onChanged: (v) => setState(() => _projectType = v),
),
const SizedBox(height: 14),    // also remove this SizedBox
```

Also remove `String? _projectType;` state variable declaration and the `_projectTypes` constant.

**Step 3:** In the building type dropdown (lines 527–562), remove the 3 commercial items:

```dart
// REMOVE THESE 3 items:
DropdownMenuItem(
  value: 'commercialOffice',
  child: Text('Commercial — Office / Bank'),
),
DropdownMenuItem(
  value: 'commercialRetail',
  child: Text('Commercial — Retail / Mixed Use'),
),
DropdownMenuItem(
  value: 'commercialWarehouse',
  child: Text('Commercial — Warehouse / Factory'),
),
```

After removal, the building type dropdown should only have:
```dart
items: const [
  DropdownMenuItem(value: null, child: Text('— Select —')),
  DropdownMenuItem(
    value: 'residentialStandard',
    child: Text('Residential — Bungalow / Duplex'),
  ),
  DropdownMenuItem(
    value: 'residentialMediumRise',
    child: Text('Residential — Medium-rise (3–6 floors)'),
  ),
  DropdownMenuItem(
    value: 'residentialHighRise',
    child: Text('Residential — High-rise (7+ floors)'),
  ),
],
```

#### 4c: Update edit_project_page.dart building types

**Step 1:** Read `lib/features/project/edit_project_page.dart` lines 40–56 (`_projectTypes` and `_buildingTypes`) and the full build() method to see where the dropdowns are rendered.

**Step 2:** Replace the `_buildingTypes` constant (lines 47–56) with the same 3 residential values used in create_project_page:

```dart
static const _buildingTypes = [
  ('residentialStandard', 'Residential — Bungalow / Duplex'),
  ('residentialMediumRise', 'Residential — Medium-rise (3–6 floors)'),
  ('residentialHighRise', 'Residential — High-rise (7+ floors)'),
];
```

**Step 3:** In the `_save()` method of edit_project_page, change the `projectType` field to always save 'residential':
```dart
'projectType': 'residential',
```
(Remove `if (_projectType != null) 'projectType': _projectType,`)

**Step 4:** Remove the `_projectTypes` constant and the project type dropdown from edit_project_page's build() entirely. Remove `String? _projectType;` state variable. Keep `String? _buildingType;`.

**Step 5:** Run flutter analyze on all 3 files:

```bash
cd /Users/donaldduodu/wysebrix && flutter analyze lib/features/estimate/widgets/step2_building.dart lib/features/project/create_project_page.dart lib/features/project/edit_project_page.dart
```

Expected: Zero errors.

**Step 6:** Commit:

```bash
cd /Users/donaldduodu/wysebrix && git add lib/features/estimate/widgets/step2_building.dart lib/features/project/create_project_page.dart lib/features/project/edit_project_page.dart && git commit -m "feat: limit building types to residential-only for MVP"
```

---

### Task 5: Firestore composite index + deploy instructions

**Problem:** `project_service.dart` queries `projects` where `teamMemberUids arrayContains builderUid` ordered by `createdAt DESC`. This query requires a composite index that does not exist in `firestore.indexes.json`.

**Files:**
- Modify: `firestore.indexes.json`

**Step 1:** Read `firestore.indexes.json` to see current content.

**Step 2:** Add the missing index. Insert this JSON object into the `"indexes"` array (after the existing `assignedPmUid + createdAt` entry):

```json
{
  "collectionGroup": "projects",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "teamMemberUids", "arrayConfig": "CONTAINS" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

**Step 3:** Verify the file is valid JSON:

```bash
cd /Users/donaldduodu/wysebrix && python3 -c "import json; json.load(open('firestore.indexes.json')); print('Valid JSON')"
```

Expected output: `Valid JSON`

**Step 4:** Commit:

```bash
cd /Users/donaldduodu/wysebrix && git add firestore.indexes.json && git commit -m "fix: add missing teamMemberUids composite index for builder projects query"
```

**Step 5: Manual deploy steps for the user**

Document in the commit body or in a comment that the user must run:

```bash
# Deploy Firestore indexes (requires Firebase CLI installed and logged in)
firebase deploy --only firestore:indexes

# Optionally also deploy rules if rules were updated
firebase deploy --only firestore:rules
```

The index deployment takes 2–10 minutes to build in Firebase console. Until it builds, builder project queries will return an error in production — but the app handles this gracefully (empty list).

---

## Final verification

After all 5 tasks:

**Step 1:** Run full flutter analyze:
```bash
cd /Users/donaldduodu/wysebrix && flutter analyze
```
Expected: 0 errors, 0 warnings (or same as before).

**Step 2:** Run on iPhone simulator and verify:
1. Create account → try creating project WITHOUT verifying email → expect dialog "Verify your email first"
2. Verify email → create project → succeeds
3. Run estimate → see result with proper formatting like `GH₵ 450,000` not `GH₵450000`
4. Save estimate → tap Save twice → only 1 document created in Firestore
5. Building type dropdown shows only 3 residential options (no Commercial items)
6. Estimate step 2 shows only 3 residential building type cards

**Manual Firestore steps for the project owner:**

```bash
# From the project root directory (requires firebase-tools installed):
firebase login    # if not already logged in
firebase use <your-project-id>   # e.g. firebase use wysebrix-prod

# Deploy indexes (needed for teamMemberUids query):
firebase deploy --only firestore:indexes

# Deploy security rules:
firebase deploy --only firestore:rules
```

Check Firebase Console → Firestore → Indexes tab to confirm the new `teamMemberUids` index status changes from "Building" to "Enabled" (usually 2–5 minutes).
