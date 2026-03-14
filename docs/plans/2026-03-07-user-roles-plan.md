# User Roles Streamlining Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current dual-role system (`UserRole` enum + `ProfessionalType` enum) with a single 10-value `ProfessionalType` as the canonical role, deleting `UserRole` entirely.

**Architecture:** `ProfessionalType` already exists with all 10 correct values and is set at sign-up — it just wasn't wired as the access-control role. The plan collapses the two systems: `AppUser.role` becomes `ProfessionalType`, access-control predicates (`isClient`, `isProfessional`, `isAdmin`) replace the old `UserRole.owner / pm / admin` enum comparisons everywhere, and a legacy Firestore parser maps `'owner'`→`homeowner`, `'pm'`→`contractor` so existing accounts upgrade silently on first load.

**Tech Stack:** Flutter 3.x, Dart, Firebase Firestore, Provider (`AuthService` is a `ChangeNotifier` provided via `MultiProvider` in `lib/main.dart`). No test runner is wired — verification is `flutter analyze lib/` + manual smoke test.

---

## Current-state summary (read this before touching code)

### What exists now

```
lib/core/models/app_user.dart
  enum UserRole { owner, pm, admin }          ← DELETE this
  enum ProfessionalType { homeowner, contractor, architect, engineer,
      inspector, materialSupplier, realEstateDeveloper, bankLender,
      governmentRegulator, admin }             ← KEEP, promote to role
  class AppUser {
    final UserRole role;                       ← change to ProfessionalType
    final ProfessionalType? professionalType;  ← DELETE (merge into role)
  }
```

### Access-control pattern used everywhere

| Old expression | New expression |
|---|---|
| `auth.role == UserRole.pm` | `auth.role.isProfessional` |
| `auth.role == UserRole.owner` | `auth.role.isClient` |
| `user.role == UserRole.admin` | `user.role.isAdmin` |
| `auth.currentUser?.role == UserRole.pm` | `auth.role.isProfessional` |
| `auth.currentUser?.role == UserRole.owner` | `auth.role.isClient` |

### Firestore `role` field values today → after migration

| Old stored string | New stored string |
|---|---|
| `'owner'` | `'homeowner'` |
| `'pm'` | `'contractor'` |
| `'admin'` | `'admin'` |

All other `ProfessionalType.name` values are already correct (they were already stored as `professionalType`).

### Files that reference `UserRole` (all must be updated)

1. `lib/core/models/app_user.dart`
2. `lib/core/services/auth_service.dart`
3. `lib/features/auth/sign_in_page.dart`
4. `lib/features/account/account_page.dart`
5. `lib/features/shell/home_shell.dart`
6. `lib/features/project/projects_page.dart`
7. `lib/features/project/project_details_page.dart`
8. `lib/features/project/variation_orders_page.dart`
9. `lib/features/project/tabs/overview_tab.dart`
10. `lib/features/admin/users_admin_page.dart`

---

## Task 1: Update `app_user.dart` — collapse roles, add access predicates

**Files:**
- Modify: `lib/core/models/app_user.dart`

This is the core change. Everything else flows from here.

**Step 1: Add `isProfessional`, `isClient`, `isAdmin` getters to `ProfessionalTypeInfo`**

In the `ProfessionalTypeInfo` extension (after the existing `defaultUserRole` getter which you are about to delete), add:

```dart
  /// Professionals offer services and appear in the builder/PM marketplace.
  bool get isProfessional => switch (this) {
        ProfessionalType.contractor ||
        ProfessionalType.architect ||
        ProfessionalType.engineer ||
        ProfessionalType.inspector ||
        ProfessionalType.materialSupplier =>
          true,
        _ => false,
      };

  /// Clients primarily create projects and hire professionals.
  /// Covers: homeowner, realEstateDeveloper, bankLender, governmentRegulator.
  bool get isClient => !isProfessional && !isAdmin;

  bool get isAdmin => this == ProfessionalType.admin;
```

**Step 2: Remove `defaultUserRole` getter from `ProfessionalTypeInfo`**

Delete lines 65–73:
```dart
  UserRole get defaultUserRole => switch (this) {
        ProfessionalType.contractor => UserRole.pm,
        ...
      };
```

**Step 3: Delete `enum UserRole` and `extension UserRoleLabel`**

Delete lines 4 and 184–190 (the enum and its extension).

**Step 4: Update `AppUser` — change `role` field type, remove `professionalType` field**

Change:
```dart
  final UserRole role;
  ...
  final ProfessionalType? professionalType;
```

To:
```dart
  final ProfessionalType role;
  // professionalType field removed — role IS the professional type
```

Remove `professionalType` from: constructor params, field declarations, `fromDoc`, `toMap`, `copyWith`.

**Step 5: Update `fromDoc` parser with legacy migration**

Replace the old `_roleFromString`:
```dart
  // OLD (delete this):
  static UserRole _roleFromString(String? s) => switch (s) {
        'pm' => UserRole.pm,
        'admin' => UserRole.admin,
        _ => UserRole.owner,
      };
```

With:
```dart
  // NEW — reads new ProfessionalType values AND migrates legacy 'owner'/'pm' strings
  static ProfessionalType _professionalTypeFromString(String? s) => switch (s) {
        'owner' => ProfessionalType.homeowner,      // legacy migration
        'pm' => ProfessionalType.contractor,        // legacy migration
        _ => ProfessionalTypeInfo.fromString(s),    // handles all 10 new values + null
      };
```

Update `fromDoc` to call `_professionalTypeFromString` instead of `_roleFromString`:
```dart
      role: _professionalTypeFromString(d['role'] as String?),
```

Remove the separate `professionalType` line from `fromDoc` entirely (field is gone).

**Step 6: Update `toMap` — write `role.name` (ProfessionalType name)**

The existing line `'role': role.name` is already correct (was writing `UserRole.name` before — now writes `ProfessionalType.name`). Remove the `'professionalType': professionalType!.name` entry.

**Step 7: Update `copyWith` — change `UserRole? role` → `ProfessionalType? role`, remove `professionalType`**

**Step 8: Verify the file compiles**

```bash
cd /Users/donaldduodu/wysebrix
flutter analyze lib/core/models/app_user.dart
```

Expected: errors in other files (they still import `UserRole`), but `app_user.dart` itself should be clean.

**Step 9: Commit**

```bash
git add lib/core/models/app_user.dart
git commit -m "refactor: collapse UserRole into ProfessionalType — single role system"
```

---

## Task 2: Update `auth_service.dart`

**Files:**
- Modify: `lib/core/services/auth_service.dart:20-30, 106-160, 280-300, 405-415`

**Step 1: Update the `role` getter**

Change:
```dart
UserRole get role => _currentUser?.role ?? UserRole.owner;
```
To:
```dart
ProfessionalType get role => _currentUser?.role ?? ProfessionalType.homeowner;
```

**Step 2: Update `_profileFromFirebaseUser` default**

Change:
```dart
role: UserRole.owner,
```
To:
```dart
role: ProfessionalType.homeowner,
```

This is the temporary `AppUser` created while Firestore profile loads. It only shows momentarily.

**Step 3: Update `signUp` signature — remove separate `role` param, use `professionalType` directly**

Old signature:
```dart
Future<void> signUp({
  required String email,
  required String password,
  required String displayName,
  required UserRole role,
  String? firstName,
  String? lastName,
  String? phone,
  ProfessionalType? professionalType,
})
```

New signature:
```dart
Future<void> signUp({
  required String email,
  required String password,
  required String displayName,
  required ProfessionalType role,
  String? firstName,
  String? lastName,
  String? phone,
})
```

Inside `signUp`, update the `AppUser(...)` constructor call:
- Change `role: role` to `role: role` (same param name, now `ProfessionalType`)
- Remove `professionalType: professionalType` line (field is gone)

**Step 4: Update `updateRole` method signature**

Find the `updateRole` method. Change its parameter type from `UserRole` to `ProfessionalType`:
```dart
Future<void> updateRole(ProfessionalType role) async {
  ...
  .update({'role': role.name});
  _currentUser = _currentUser?.copyWith(role: role);
  notifyListeners();
}
```

**Step 5: Find and fix the Google sign-in `AppUser` constructor (if any)**

Search for any other `role: UserRole.owner` references in the file and change to `role: ProfessionalType.homeowner`.

**Step 6: Verify**

```bash
flutter analyze lib/core/services/auth_service.dart
```

Expected: still errors in UI files, but this file clean.

**Step 7: Commit**

```bash
git add lib/core/services/auth_service.dart
git commit -m "refactor: update AuthService role getter and signUp to use ProfessionalType"
```

---

## Task 3: Update `sign_in_page.dart`

**Files:**
- Modify: `lib/features/auth/sign_in_page.dart:310-330`

The sign-up form already uses `_ProfessionalTypePicker` and stores `ProfessionalType _professionalType`. The only change needed is the `signUp` call.

**Step 1: Find the `signUp` call in `_SignUpFormState._submit()`**

Currently:
```dart
final role = _professionalType.defaultUserRole;

await context.read<AuthService>().signUp(
  email: _emailCtrl.text.trim(),
  ...
  role: role,
  professionalType: _professionalType,
);
```

Change to:
```dart
await context.read<AuthService>().signUp(
  email: _emailCtrl.text.trim(),
  ...
  role: _professionalType,
);
```

Remove the `final role = _professionalType.defaultUserRole;` line.

**Step 2: Verify**

```bash
flutter analyze lib/features/auth/sign_in_page.dart
```

Expected: no errors in this file.

**Step 3: Commit**

```bash
git add lib/features/auth/sign_in_page.dart
git commit -m "refactor: sign-up passes ProfessionalType directly as role"
```

---

## Task 4: Update `account_page.dart`

**Files:**
- Modify: `lib/features/account/account_page.dart`

This file has the most `UserRole` references. Changes:
1. `_roleIcon` — replace 3-case switch with `user.role.icon` (already on `ProfessionalType`)
2. Role chip tooltip — change copy (users can now switch themselves)
3. `_SwitchRoleTile` — update subtitle text and `isAdmin` check
4. `_RoleSwitchSheet` — replace 2-card layout with full `ProfessionalType.values` picker
5. Admin check — `UserRole.admin` → `role.isAdmin`
6. PM checks — `UserRole.pm` → `role.isProfessional`

**Step 1: Fix `_roleIcon` (around line 317)**

Delete the entire `_roleIcon` method:
```dart
IconData _roleIcon(UserRole role) => switch (role) {
      UserRole.owner => Icons.home_outlined,
      UserRole.pm => Icons.engineering_outlined,
      UserRole.admin => Icons.admin_panel_settings_outlined,
    };
```

Where it is called (role chip, around line 264), replace:
```dart
avatar: Icon(_roleIcon(user.role), size: 16),
```
With:
```dart
avatar: Icon(user.role.icon, size: 16),
```

**Step 2: Update role chip tooltip copy (around line 261)**

Change:
```dart
message: 'Contact support to change your role',
```
To:
```dart
message: 'Tap "Switch role" below to change',
```

**Step 3: Update three `UserRole.pm` checks that gate sections (lines 56, 70)**

Change:
```dart
if (user.role == UserRole.pm) ...
```
To:
```dart
if (user.role.isProfessional) ...
```

(Both occurrences — the profile section and the pending contracts tile.)

**Step 4: Update admin check (line 83)**

Change:
```dart
if (user.role == UserRole.admin) ...
```
To:
```dart
if (user.role.isAdmin) ...
```

**Step 5: Update `_SwitchRoleTile` (around line 1199–1232)**

Change the admin guard:
```dart
if (currentRole == UserRole.admin) return const SizedBox.shrink();
```
To:
```dart
if (currentRole.isAdmin) return const SizedBox.shrink();
```

Change the subtitle text:
```dart
subtitle: Text(
  currentRole == UserRole.owner
      ? 'Current: Property Owner — switch to Builder / PM'
      : 'Current: Builder / PM — switch to Property Owner',
),
```
To:
```dart
subtitle: Text('Current: ${currentRole.label}'),
```

**Step 6: Rewrite `_RoleSwitchSheetState.build()` to show all 10 types**

The current sheet shows 2 hardcoded `_RoleCard` widgets. Replace the body with a scrollable list of all `ProfessionalType.values` (excluding `admin`, which is not self-selectable):

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final current = widget.auth.currentUser?.role ?? ProfessionalType.homeowner;

  return Padding(
    padding: EdgeInsets.fromLTRB(
      24, 20, 24,
      MediaQuery.of(context).viewInsets.bottom + 40,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Switch role', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Your role determines which features are available to you.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final type in ProfessionalType.values)
                if (!type.isAdmin) ...[
                  _RoleCard(
                    title: type.label,
                    subtitle: type.subtitle,
                    icon: type.icon,
                    selected: _selected == type,
                    isCurrent: current == type,
                    onTap: () => setState(() => _selected = type),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _confirm,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirm'),
        ),
      ],
    ),
  );
}
```

**Step 7: Update `_RoleSwitchSheetState` field type**

Change:
```dart
UserRole? _selected;
```
To:
```dart
ProfessionalType? _selected;
```

And in `initState`:
```dart
_selected = widget.auth.currentUser?.role ?? ProfessionalType.homeowner;
```

**Step 8: Update `_confirm` dialog text**

Change the old binary reference to use `.label`:
```dart
'Your account will be switched to ${_selected!.label}. '
'You can switch back at any time.',
```
(This text was already generic — just ensure it uses `.label` not `.name`.)

**Step 9: Remove the old hardcoded role cards**

Delete the two `_RoleCard(title: 'Property Owner', ...)` and `_RoleCard(title: 'Builder / PM / Architect', ...)` entries — they are replaced by the loop above.

**Step 10: Verify**

```bash
flutter analyze lib/features/account/account_page.dart
```

**Step 11: Commit**

```bash
git add lib/features/account/account_page.dart
git commit -m "feat: role switch sheet shows all 10 professional types"
```

---

## Task 5: Update `home_shell.dart` and `projects_page.dart`

**Files:**
- Modify: `lib/features/shell/home_shell.dart:53,66`
- Modify: `lib/features/project/projects_page.dart:26-31`

**Step 1: Fix `home_shell.dart`**

Change (line 53):
```dart
final isOwner = auth.isSignedIn && auth.role == UserRole.owner;
```
To:
```dart
final isOwner = auth.isSignedIn && auth.role.isClient;
```

Change (line 66):
```dart
auth.isSignedIn && auth.role == UserRole.pm ? 'My Work' : 'Projects';
```
To:
```dart
auth.isSignedIn && auth.role.isProfessional ? 'My Work' : 'Projects';
```

**Step 2: Fix `projects_page.dart`**

Change:
```dart
final role = auth.role;
if (role == UserRole.pm) {
  return const _BuilderProjectsView();
}
return const _OwnerProjectsView();
```
To:
```dart
if (auth.role.isProfessional) {
  return const _BuilderProjectsView();
}
return const _OwnerProjectsView();
```

Remove the `final role = auth.role;` line (no longer needed).

**Step 3: Verify both files**

```bash
flutter analyze lib/features/shell/home_shell.dart lib/features/project/projects_page.dart
```

**Step 4: Commit**

```bash
git add lib/features/shell/home_shell.dart lib/features/project/projects_page.dart
git commit -m "refactor: replace UserRole.pm/owner checks with isProfessional/isClient"
```

---

## Task 6: Update `project_details_page.dart`, `variation_orders_page.dart`, `overview_tab.dart`

**Files:**
- Modify: `lib/features/project/project_details_page.dart:214,685`
- Modify: `lib/features/project/variation_orders_page.dart:28-29`
- Modify: `lib/features/project/tabs/overview_tab.dart:497`

**Step 1: Fix `project_details_page.dart` (two occurrences)**

Both at lines 214 and 685, change:
```dart
final isBuilder = auth.role == UserRole.pm;
```
To:
```dart
final isBuilder = auth.role.isProfessional;
```

**Step 2: Fix `variation_orders_page.dart` (lines 28–29)**

Change:
```dart
final isOwner = auth.currentUser?.role == UserRole.owner;
final isPm = auth.currentUser?.role == UserRole.pm;
```
To:
```dart
final isOwner = auth.role.isClient;
final isPm = auth.role.isProfessional;
```

**Step 3: Fix `overview_tab.dart` (line 497)**

Change:
```dart
final isBuilderLocal = auth.role == UserRole.pm;
```
To:
```dart
final isBuilderLocal = auth.role.isProfessional;
```

**Step 4: Verify all three**

```bash
flutter analyze lib/features/project/project_details_page.dart lib/features/project/variation_orders_page.dart lib/features/project/tabs/overview_tab.dart
```

**Step 5: Commit**

```bash
git add lib/features/project/project_details_page.dart lib/features/project/variation_orders_page.dart lib/features/project/tabs/overview_tab.dart
git commit -m "refactor: update project pages to use isProfessional/isClient predicates"
```

---

## Task 7: Update `users_admin_page.dart`

**Files:**
- Modify: `lib/features/admin/users_admin_page.dart`

This file shows a `_RoleBadge` and lets admins change user roles. It currently has 3-colour role badge and a role picker with all `UserRole.values`.

**Step 1: Update `_RoleBadge` colours**

The badge currently uses a 3-case switch on `UserRole`. Replace with one based on `ProfessionalType`:

```dart
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final ProfessionalType role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (role) {
      _ when role.isAdmin => (cs.errorContainer, cs.onErrorContainer),
      _ when role.isProfessional =>
        (cs.secondaryContainer, cs.onSecondaryContainer),
      _ => (cs.primaryContainer, cs.onPrimaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
```

**Step 2: Update the role picker dialog**

Currently iterates `UserRole.values`. Change to iterate `ProfessionalType.values`:

```dart
for (final r in ProfessionalType.values)
  RadioListTile<ProfessionalType>(
    value: r,
    groupValue: user.role,      // user.role is now ProfessionalType
    onChanged: (v) => Navigator.pop(context, v),
    title: Row(
      children: [
        if (r == user.role)
          const Icon(Icons.check, size: 18)
        else
          const SizedBox(width: 18),
        const SizedBox(width: 8),
        Text(r.label),
      ],
    ),
  ),
```

**Step 3: Update the `picked` variable type and Firestore write**

Change:
```dart
UserRole? picked = await showDialog<UserRole>(...)
if (picked != null && picked != user.role) {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .update({'role': picked.name});
```
To:
```dart
ProfessionalType? picked = await showDialog<ProfessionalType>(...)
if (picked != null && picked != user.role) {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .update({'role': picked.name});
```

**Step 4: Update the `_RoleBadge` call site**

The call that passes `user.role` to `_RoleBadge` should already work since `user.role` is now `ProfessionalType`.

**Step 5: Verify**

```bash
flutter analyze lib/features/admin/users_admin_page.dart
```

**Step 6: Commit**

```bash
git add lib/features/admin/users_admin_page.dart
git commit -m "feat: admin role management supports all 10 professional types"
```

---

## Task 8: Full analyze + final verification

**Step 1: Run full analyze**

```bash
flutter analyze lib/
```

Expected: `No issues found.`

If there are errors, they will indicate any remaining `UserRole` references. Fix each one by applying the patterns from tasks 1–7.

**Step 2: Search for any stray `UserRole` references**

```bash
grep -r "UserRole" lib/
```

Expected: no output. If any files appear, fix them.

**Step 3: Search for stray `defaultUserRole` references**

```bash
grep -r "defaultUserRole" lib/
```

Expected: no output.

**Step 4: Search for stray `professionalType` field references** (the field that was removed from AppUser)

```bash
grep -r "\.professionalType" lib/
```

Expected: no output referencing the removed field (the `ProfessionalType` type itself is fine, just the `.professionalType` field on `AppUser` is gone).

**Step 5: Smoke test — sign-up flow**
1. Create a new account, pick any professional type (e.g. Architect)
2. Verify account page shows "Architect" as role with the correct icon
3. Verify nav tab says "My Work" (professional role)
4. Switch role to "Homeowner" via Switch Role in account
5. Verify nav tab changes to "Projects"
6. Verify Projects page shows owner view

**Step 6: Smoke test — existing account migration**
1. Sign in with an existing account that had `role: 'pm'` in Firestore
2. Verify it loads as `Contractor` (the legacy migration fallback)
3. Verify it loads as `Homeowner` for `role: 'owner'`

**Step 7: Final commit**

```bash
git add -p  # review any remaining unstaged changes
git commit -m "fix: final cleanup — zero UserRole references, full analyze clean"
```

---

## Reference: complete access-control predicate table

| Who | `role.isClient` | `role.isProfessional` | `role.isAdmin` |
|---|---|---|---|
| Homeowner | ✓ | | |
| Real Estate Developer | ✓ | | |
| Bank / Mortgage Lender | ✓ | | |
| Government Regulator | ✓ | | |
| Contractor | | ✓ | |
| Architect | | ✓ | |
| Engineer | | ✓ | |
| Inspector | | ✓ | |
| Material Supplier | | ✓ | |
| Admin | | | ✓ |

**What `isProfessional` gates:**
- Shows "My Work" instead of "Projects" in nav
- Routes to `_BuilderProjectsView` (contracted projects they work on)
- Shows Profile section and Pending Contracts tile in Account
- `isBuilder` flag in project details / snag list / variation orders

**What `isClient` gates:**
- Routes to `_OwnerProjectsView` (their own projects)
- Can create new projects
- `isOwner` flag in project details / variation orders (project creator check is separate — `project.ownerUid == auth.uid`)

**What `isAdmin` gates:**
- Admin tile in Account page
- Admin section in router
- Cannot self-switch role (admin role only set by other admins)
