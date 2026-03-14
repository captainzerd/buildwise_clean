# UX/UI Sprint 2 — P1 Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 4 UX/UI P1 issues surfaced in the full-app audit: retry buttons on load failures, consistent empty states, notification routing safety, and one missing loading indicator.

**Architecture:** All fixes are isolated to existing pages — no new routes, services, or models. Two shared widgets (`EmptyState`, `LoadingButton`) already exist and should be used instead of ad-hoc inline patterns. Test coverage uses widget tests only (no Firebase init required).

**Tech Stack:** Flutter, StreamBuilder/FutureBuilder, `EmptyState` widget at `lib/core/widgets/empty_state.dart`, `LoadingButton` at `lib/core/widgets/loading_button.dart`, `AppException.from(e).message` for error strings.

---

## Task 1: Retry buttons on failed load states (5 pages)

**Files:**
- Modify: `lib/features/project/projects_page.dart:185-191`
- Modify: `lib/features/account/pending_contracts_page.dart:28-30`
- Modify: `lib/features/notifications/notification_centre_page.dart:30-56`
- Modify: `lib/features/project/snag_list_page.dart:58-64`
- Modify: `lib/features/saved/saved_estimates_page.dart:68-75`
- Test: `test/ux/retry_on_error_test.dart`

**Context:**
Each page loads data via `StreamBuilder` or `FutureBuilder`. On error, they either show raw error text with no action, or swallow the error silently. The fix is to show `EmptyState` with `icon: Icons.cloud_off_outlined`, `title: 'Could not load data'`, `message: AppException.from(snap.error!).message`, `actionLabel: 'Retry'`, `onAction: _reload` for FutureBuilders or a setState that triggers stream re-subscription for StreamBuilders.

**Standard error pattern to apply:**

For StreamBuilder (`snap.hasError`):
```dart
if (snap.hasError) {
  return EmptyState(
    icon: Icons.cloud_off_outlined,
    title: 'Could not load',
    message: AppException.from(snap.error!).message,
    actionLabel: 'Retry',
    onAction: () => setState(() {}),
  );
}
```

For FutureBuilder (`snap.hasError`):
```dart
if (snap.hasError) {
  return EmptyState(
    icon: Icons.cloud_off_outlined,
    title: 'Could not load',
    message: AppException.from(snap.error!).message,
    actionLabel: 'Retry',
    onAction: () => setState(() { _futureSnaps = _load(); }),
  );
}
```

**Specific changes per file:**

1. **`projects_page.dart` line 185**: Replace `Center(child: Padding(child: Text('Error loading projects: $_error', ...)))` with `EmptyState(icon: Icons.cloud_off_outlined, title: 'Could not load projects', message: AppException.from(_error!).message, actionLabel: 'Retry', onAction: _loadProjects)`.

2. **`pending_contracts_page.dart` line 29**: Change `Center(child: Text('Error: ${snap.error}'))` to `EmptyState(icon: Icons.cloud_off_outlined, title: 'Could not load contracts', message: AppException.from(snap.error!).message, actionLabel: 'Retry', onAction: () => setState(() {}))`.
   **Note:** `PendingContractsPage` is currently a `StatelessWidget`. It must be converted to `StatefulWidget` to use `setState`. The `StreamBuilder` already rebuilds the stream, so `setState(() {})` simply triggers rebuild which re-subscribes.

3. **`notification_centre_page.dart` line 34**: After `if (snap.connectionState == ConnectionState.waiting) { ... }` add `if (snap.hasError) { return EmptyState(icon: Icons.cloud_off_outlined, title: 'Could not load notifications', message: AppException.from(snap.error!).message, actionLabel: 'Retry', onAction: () => setState(() {})); }`.
   **Note:** `NotificationCentrePage` is currently a `StatelessWidget`. Convert to `StatefulWidget`.

4. **`snag_list_page.dart` line 63**: After `if (snap.connectionState == ConnectionState.waiting) { ... }` add `if (snap.hasError) { return EmptyState(icon: Icons.cloud_off_outlined, title: 'Could not load issues', message: AppException.from(snap.error!).message, actionLabel: 'Retry', onAction: () => setState(() {})); }`.

5. **`saved_estimates_page.dart` line 71**: Change `if (!snap.hasData) { return const Center(child: CircularProgressIndicator()); }` to: `if (snap.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); } if (snap.hasError) { return EmptyState(icon: Icons.cloud_off_outlined, title: 'Could not load estimates', message: AppException.from(snap.error!).message, actionLabel: 'Retry', onAction: () => setState(() { _futureSnaps = _load(); })); }`.
   **Note:** `_load()` is the existing private method that runs the future. Check the actual method name in `saved_estimates_page.dart`.

**Imports needed:** Add `import '../../core/widgets/empty_state.dart';` and `import '../../core/errors/app_exception.dart';` to each file that doesn't already have them.

**Step 1: Write the failing test**

```dart
// test/ux/retry_on_error_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState shows retry button and fires onAction', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load',
            message: 'Check your connection.',
            actionLabel: 'Retry',
            onAction: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('Could not load'), findsOneWidget);
    expect(find.text('Check your connection.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(taps, 1);
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/ux/retry_on_error_test.dart -v`
Expected: PASS (EmptyState widget already exists and supports onAction — this test validates the contract before we wire it up to pages)

**Step 3: Apply changes to all 5 pages**

Apply the patterns described above to each file. Keep `AppException.from(snap.error!)` to ensure user-friendly messages.

**Step 4: Run all tests**

Run: `flutter test test/ux/ -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/project/projects_page.dart \
        lib/features/account/pending_contracts_page.dart \
        lib/features/notifications/notification_centre_page.dart \
        lib/features/project/snag_list_page.dart \
        lib/features/saved/saved_estimates_page.dart \
        test/ux/retry_on_error_test.dart
git commit -m "fix: add retry buttons to all failed-load error states"
```

---

## Task 2: Standardise empty states (3 pages)

**Files:**
- Modify: `lib/features/project/projects_page.dart:228-229` (search filter empty state)
- Modify: `lib/features/notifications/notification_centre_page.dart:35-45` (inline Column → EmptyState)
- Modify: `lib/features/account/pending_contracts_page.dart:33-60` (inline Column → EmptyState)
- Test: `test/ux/empty_state_standard_test.dart`

**Context:**
`EmptyState` widget already exists at `lib/core/widgets/empty_state.dart`. Three pages either use an ad-hoc inline Column with Icon, or use bare `Center(child: Text(...))` for filter/search empty results. All should use `EmptyState`.

**Specific changes:**

1. **`projects_page.dart` line 228-229**: Change `const Center(child: Text('No projects match your search.'))` to:
```dart
const EmptyState(
  icon: Icons.search_off_outlined,
  title: 'No matches',
  message: 'Try a different search term.',
)
```

2. **`notification_centre_page.dart` lines 36-45**: Replace the inline `Center(child: Column(children: [Icon(Icons.notifications_none_outlined, ...), ...]))` with:
```dart
const EmptyState(
  icon: Icons.notifications_none_outlined,
  title: 'No notifications yet',
  message: 'You\'ll see alerts for contracts, approvals, and updates here.',
)
```

3. **`pending_contracts_page.dart` lines 33-60**: Replace the inline `Center(child: Padding(child: Column(children: [Icon(...), Text(...), ...])))` with:
```dart
const EmptyState(
  icon: Icons.description_outlined,
  title: 'No pending contracts',
  message: 'Contracts sent to you by project owners will appear here.',
)
```

**Step 1: Write the failing test**

```dart
// test/ux/empty_state_standard_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState renders icon, title, and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.notifications_none_outlined,
            title: 'No notifications yet',
            message: 'You\'ll see alerts here.',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
    expect(find.text('No notifications yet'), findsOneWidget);
    expect(find.text('You\'ll see alerts here.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('EmptyState shows no button when actionLabel is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.search_off_outlined,
            title: 'No matches',
          ),
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
  });
}
```

**Step 2: Run test to verify it passes**

Run: `flutter test test/ux/empty_state_standard_test.dart -v`
Expected: PASS (testing existing widget)

**Step 3: Apply changes to 3 pages**

**Step 4: Run all tests**

Run: `flutter test -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/project/projects_page.dart \
        lib/features/notifications/notification_centre_page.dart \
        lib/features/account/pending_contracts_page.dart \
        test/ux/empty_state_standard_test.dart
git commit -m "fix: standardise empty states to use EmptyState widget"
```

---

## Task 3: Notification routing error handling

**Files:**
- Modify: `lib/core/services/notification_service.dart:298-309`
- Modify: `lib/features/notifications/notification_centre_page.dart` (onTap handler)
- Test: `test/ux/notification_routing_test.dart`

**Context:**
`routeFromData()` in `notification_service.dart` silently returns if `navigatorKey.currentContext` is null, and routes to `/projects/$projectId` without any validation. If the project was deleted between when the notification was sent and when the user taps it, the app navigates to a non-existent project. In `notification_centre_page.dart`, the `onTap` handler calls `svc.routeFromData(notif.data)` with no try-catch.

**Changes to `notification_service.dart`:**

Wrap `routeFromData` body in a try-catch and show a SnackBar if context is available:

```dart
void routeFromData(Map<String, dynamic> data) {
  final type = data['type'] as String? ?? '';
  final projectId = data['projectId'] as String? ?? '';
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;

  try {
    if (type == 'contract_new') {
      GoRouter.of(ctx).push('/account/contracts/pending');
    } else if (projectId.isNotEmpty) {
      GoRouter.of(ctx).push('/projects/$projectId');
    }
  } catch (_) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Could not open this notification.')),
    );
  }
}
```

**Changes to `notification_centre_page.dart` onTap:**

Read the `_NotifTile` widget's `onTap` (around line 105-115) and wrap the `routeFromData` call:

```dart
onTap: () {
  if (unread) svc.markRead(uid, notif.id);
  try {
    svc.routeFromData(notif.data);
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this notification.')),
    );
  }
},
```

**Step 1: Write the failing test**

```dart
// test/ux/notification_routing_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('notification tile renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListTile(
            title: const Text('New contract received'),
            subtitle: const Text('2 minutes ago'),
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('New contract received'), findsOneWidget);
    expect(find.text('2 minutes ago'), findsOneWidget);
  });

  testWidgets('snackbar shows on routing error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                try {
                  throw Exception('route error');
                } catch (_) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open this notification.'),
                    ),
                  );
                }
              },
              child: const Text('tap'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('tap'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open this notification.'), findsOneWidget);
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/ux/notification_routing_test.dart -v`
Expected: PASS (widget-level test only, not testing the actual service)

**Step 3: Apply changes to both files**

**Step 4: Run all tests**

Run: `flutter test -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/core/services/notification_service.dart \
        lib/features/notifications/notification_centre_page.dart \
        test/ux/notification_routing_test.dart
git commit -m "fix: add error handling to notification routing to prevent silent failures"
```

---

## Task 4: Loading spinner on id_verification submit button

**Files:**
- Modify: `lib/features/account/id_verification_page.dart:73-94`
- Test: `test/ux/id_verification_submit_test.dart`

**Context:**
`id_verification_page.dart` has a Submit button that sets `_busy = true` and disables the button during submission, but the button text and icon don't change — the user sees no visual feedback that work is happening. The `LoadingButton` widget at `lib/core/widgets/loading_button.dart` handles this automatically.

**Current code (approximate):**
```dart
FilledButton.icon(
  onPressed: _busy ? null : _submit,
  icon: const Icon(Icons.upload_outlined),
  label: const Text('Submit for Verification'),
)
```

**Target code:**
```dart
LoadingButton(
  label: 'Submit for Verification',
  icon: Icons.upload_outlined,
  onPressed: _submit,
)
```

Remove the `_busy` state variable if it is only used to control this button (check if it's used elsewhere first). `LoadingButton` manages its own loading state.

**If `_busy` is used elsewhere** (e.g., to disable other UI), keep `_busy` and keep the existing `onPressed: _busy ? null : _submit` pattern on the button, but add a `CircularProgressIndicator` next to the button label:

```dart
FilledButton.icon(
  onPressed: _busy ? null : _submit,
  icon: _busy
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
      : const Icon(Icons.upload_outlined),
  label: Text(_busy ? 'Please wait…' : 'Submit for Verification'),
)
```

Read the file before deciding which approach to use.

**Step 1: Write the failing test**

```dart
// test/ux/id_verification_submit_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/widgets/loading_button.dart';

void main() {
  testWidgets('LoadingButton shows spinner when tapped', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadingButton(
            label: 'Submit for Verification',
            icon: Icons.upload_outlined,
            onPressed: () async {
              await Future.delayed(const Duration(milliseconds: 100));
              completed = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Submit for Verification'), findsOneWidget);
    expect(find.byIcon(Icons.upload_outlined), findsOneWidget);

    await tester.tap(find.text('Submit for Verification'));
    await tester.pump();

    // During loading: spinner visible, label changed
    expect(find.text('Please wait…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(find.text('Submit for Verification'), findsOneWidget);
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/ux/id_verification_submit_test.dart -v`
Expected: PASS (testing the LoadingButton widget directly)

**Step 3: Apply changes to id_verification_page.dart**

Read the file, locate the submit button, apply the fix (LoadingButton or inline spinner pattern as appropriate).

**Step 4: Run all tests**

Run: `flutter test -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/account/id_verification_page.dart \
        test/ux/id_verification_submit_test.dart
git commit -m "fix: add loading spinner to id_verification submit button"
```

---

## Final verification

Run full test suite:

```bash
flutter test -v
```

Expected: All tests pass, no regressions.
