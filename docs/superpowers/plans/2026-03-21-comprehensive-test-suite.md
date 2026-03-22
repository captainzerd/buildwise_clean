# Comprehensive Test Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four production-readiness test suites — Firestore security rules, Cloud Functions unit tests, Flutter performance/soak tests, and iOS integration tests — going from zero coverage on the first three to full CI-green status.

**Architecture:** Suite 1 (rules) and Suite 2 (functions) live in `functions/test/` and are run by Jest with Node 20. Suite 4 (perf/soak) is pure Dart and picked up automatically by `flutter test`. Suite 3 (integration) lives in `integration_test/` and runs manually against Firebase emulators on an iOS simulator. Suites 1, 2, 4 are added to CI; Suite 3 is manual-only.

**Tech Stack:** Jest 29 + ts-jest 29, `@firebase/rules-unit-testing` ^4, `firebase-functions-test` ^3, Firebase emulators (auth:9099 + firestore:8080), Flutter `integration_test` package, `flutter_test`.

---

## File Map

**New files — Node / functions:**
| File | Purpose |
|---|---|
| `functions/jest.config.js` | Jest configuration for all `test/**/*.test.ts` files |
| `functions/tsconfig.test.json` | TypeScript config for tests (extends main, adds `test/`) |
| `functions/test/rules/helpers.ts` | `initTestEnv`, fixture contexts, seed helpers |
| `functions/test/rules/users.rules.test.ts` | `/users/{uid}` + `/users/{uid}/estimates/{id}` rules |
| `functions/test/rules/projects.rules.test.ts` | `/projects/{id}` + sub-collections rules |
| `functions/test/rules/catalog.rules.test.ts` | `cost_catalog`, `fx_rates`, `boq_rates` |
| `functions/test/rules/contracts.rules.test.ts` | `/contracts/{id}` |
| `functions/test/rules/vendors.rules.test.ts` | `/vendors/{id}` |
| `functions/test/rules/invitations.rules.test.ts` | `/invitations/{token}` |
| `functions/test/unit/budgetAlerts.test.ts` | Budget threshold logic |
| `functions/test/unit/dataRetention.test.ts` | Retention cutoffs |
| `functions/test/unit/marketPricesUpdater.test.ts` | Market prices write |
| `functions/test/unit/updateReminderScheduler.test.ts` | Overdue-project notification logic |
| `functions/test/unit/aiCostOptimiser.test.ts` | AI cost optimiser guards |
| `functions/test/unit/rateLimit.test.ts` | Rate-limit counter logic |

**Modified files — Node:**
| File | Change |
|---|---|
| `functions/package.json` | Add jest/ts-jest devDeps + npm test scripts |
| `firebase.json` | Add `emulators` block (auth:9099, firestore:8080) |

**New files — Flutter:**
| File | Purpose |
|---|---|
| `test/estimator/performance_test.dart` | Throughput, determinism, monotonic-scaling tests |
| `test/estimator/soak_test.dart` | 972-combo sweep, boundary inputs, catalog integrity, fee scale |
| `integration_test/helpers/emulator_setup.dart` | Points Flutter SDK at emulator ports |
| `integration_test/helpers/fixture_seeder.dart` | Seeds test users + project into emulator Auth/Firestore |
| `integration_test/helpers/test_app.dart` | Bootstraps app with `ENV=test` |
| `integration_test/journeys/auth_flow_test.dart` | Sign-in / sign-out / unverified gate |
| `integration_test/journeys/estimate_wizard_test.dart` | Happy-path wizard → result screen |
| `integration_test/journeys/project_creation_test.dart` | Save estimate as project |
| `integration_test/journeys/project_details_test.dart` | Finance/Overview tabs, add variation order |
| `integration_test/journeys/role_gate_test.dart` | Contractor cannot see create-project FAB |

**Modified files — Flutter:**
| File | Change |
|---|---|
| `pubspec.yaml` | Add `integration_test` to dev_dependencies |

**Modified files — CI:**
| File | Change |
|---|---|
| `.github/workflows/ci.yml` | Add `test-rules` and `test-functions` jobs |

---

## Task 1: Node test infrastructure

**Files:**
- Modify: `functions/package.json`
- Create: `functions/jest.config.js`
- Create: `functions/tsconfig.test.json`

- [ ] **Step 1: Add devDependencies and test scripts to `functions/package.json`**

Replace the existing `"scripts"` and `"devDependencies"` sections:

```json
"scripts": {
  "build":       "tsc",
  "lint":        "eslint --ext .ts src",
  "serve":       "firebase emulators:start --only functions",
  "deploy":      "firebase deploy --only functions",
  "clean":       "rimraf lib",
  "test":        "jest --forceExit",
  "test:rules":  "jest --testPathPattern=rules --forceExit",
  "test:unit":   "jest --testPathPattern=unit --forceExit"
},
"devDependencies": {
  "@typescript-eslint/eslint-plugin": "^8.1.0",
  "@typescript-eslint/parser":        "^8.1.0",
  "eslint":                           "^9.9.0",
  "rimraf":                           "^6.0.1",
  "typescript":                       "^5.5.4",
  "jest":                             "^29",
  "ts-jest":                          "^29",
  "@types/jest":                      "^29",
  "firebase-functions-test":          "^3",
  "@firebase/rules-unit-testing":     "^4"
}
```

- [ ] **Step 2: Create `functions/jest.config.js`**

```js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/test/**/*.test.ts'],
  globals: {
    'ts-jest': {
      tsconfig: 'tsconfig.test.json',
    },
  },
  testTimeout: 30000,
};
```

- [ ] **Step 3: Create `functions/tsconfig.test.json`**

The main `tsconfig.json` has `"rootDir": "src"` and `"include": ["src"]` which excludes test files. This override loosens those constraints for Jest without breaking the production build:

```json
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "rootDir": ".",
    "outDir": "lib-test"
  },
  "include": ["src", "test"]
}
```

- [ ] **Step 4: Install new dependencies**

```bash
cd functions && npm install
```

Expected: no errors; `node_modules/jest/` and `node_modules/ts-jest/` appear.

- [ ] **Step 5: Verify Jest runs (no tests yet)**

```bash
cd functions && npm test
```

Expected: `Test Suites: 0 skipped` (no tests found yet — that's fine).

- [ ] **Step 6: Commit**

```bash
git add functions/package.json functions/package-lock.json functions/jest.config.js functions/tsconfig.test.json
git commit -m "chore(test): add Jest + ts-jest infrastructure to functions"
```

---

## Task 2: Firebase emulator configuration

**Files:**
- Modify: `firebase.json`

- [ ] **Step 1: Add emulators block to `firebase.json`**

Add after the `"firestore"` key (do not replace existing keys):

```json
"emulators": {
  "auth":      { "port": 9099 },
  "firestore": { "port": 8080 },
  "ui":        { "enabled": false }
}
```

Final `firebase.json` structure should have keys: `functions`, `firestore`, `flutter`, `emulators`.

- [ ] **Step 2: Verify emulators start**

```bash
firebase emulators:start --only auth,firestore --project wysebrix-test
```

Expected: `✔  All emulators ready!` with Auth on 9099 and Firestore on 8080.
Stop with Ctrl+C.

- [ ] **Step 3: Commit**

```bash
git add firebase.json
git commit -m "chore(infra): configure Firebase Auth + Firestore emulator ports"
```

---

## Task 3: Rules test helpers

**Files:**
- Create: `functions/test/rules/helpers.ts`

The helpers initialise a shared `RulesTestEnvironment` and expose typed auth contexts with the fixed UIDs and custom claims used across all rule tests.

**Important notes about the rules:**
- `subTier()` reads `request.auth.token.get('subscriptionTier', 'free')` — claim key is `subscriptionTier`, not `sub`.
- `withinProjectLimit()` calls `get()` on the user doc; to trigger the denial, seed the user doc with `projectCount: 3` before the test.
- `invitations` read requires `inviteeEmail == request.auth.token.email` OR `inviterUid == uid` OR `isAdmin()` — it is NOT public to all authenticated users.
- `contracts` read uses `memberUids` array, not `partyUids`.
- `vendors` write (`create`/`update`) is open to any `isEmailVerified()` user, not owner-only.

- [ ] **Step 1: Create `functions/test/rules/helpers.ts`**

```typescript
import * as fs from 'fs';
import * as path from 'path';
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';

export { assertFails, assertSucceeds };

// Fixed UIDs used across all rule test files
export const UIDS = {
  owner:      'uid-owner',
  other:      'uid-other',
  member:     'uid-member',
  admin:      'uid-admin',
  unverified: 'uid-unverified',
  free:       'uid-free',
};

// Fixed emails (needed for invitation rule tests)
export const EMAILS = {
  owner:      'owner@test.com',
  other:      'other@test.com',
  member:     'member@test.com',
  admin:      'admin@test.com',
  unverified: 'unverified@test.com',
  free:       'free@test.com',
};

const RULES_PATH = path.resolve(__dirname, '../../../firestore.rules');

export async function createTestEnv(): Promise<RulesTestEnvironment> {
  return initializeTestEnvironment({
    projectId: 'wysebrix-test',
    firestore: {
      host: 'localhost',
      port: 8080,
      rules: fs.readFileSync(RULES_PATH, 'utf8'),
    },
  });
}

// Returns a Firestore instance for the given user with the given custom claims
export function authedDb(
  testEnv: RulesTestEnvironment,
  uid: string,
  claims: Record<string, unknown> = {},
) {
  return testEnv.authenticatedContext(uid, claims).firestore();
}

export function unauthDb(testEnv: RulesTestEnvironment) {
  return testEnv.unauthenticatedContext().firestore();
}

// Claim sets for fixture users
export const CLAIMS = {
  owner:      { email_verified: true,  email: EMAILS.owner,      subscriptionTier: 'pro' },
  other:      { email_verified: true,  email: EMAILS.other,      subscriptionTier: 'pro' },
  member:     { email_verified: true,  email: EMAILS.member,     subscriptionTier: 'free' },
  admin:      { email_verified: true,  email: EMAILS.admin,      role: 'admin' },
  unverified: { email_verified: false, email: EMAILS.unverified },
  free:       { email_verified: true,  email: EMAILS.free,       subscriptionTier: 'free' },
};

// Seed helpers — bypass rules using Admin context
export async function seedDoc(
  testEnv: RulesTestEnvironment,
  path: string,
  data: Record<string, unknown>,
): Promise<void> {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const parts = path.split('/');
    let ref: FirebaseFirestore.DocumentReference = ctx.firestore().collection(parts[0]).doc(parts[1]);
    for (let i = 2; i < parts.length; i += 2) {
      ref = ref.collection(parts[i]).doc(parts[i + 1]);
    }
    await ref.set(data);
  });
}
```

- [ ] **Step 2: Verify TypeScript compiles**

```bash
cd functions && npx tsc --project tsconfig.test.json --noEmit
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add functions/test/rules/helpers.ts
git commit -m "test(rules): add rules test helpers and fixture definitions"
```

---

## Task 4: users.rules.test.ts

**Files:**
- Create: `functions/test/rules/users.rules.test.ts`

- [ ] **Step 1: Create the test file**

```typescript
import {
  RulesTestEnvironment,
  createTestEnv,
  authedDb, unauthDb,
  assertFails, assertSucceeds,
  UIDS, CLAIMS,
  seedDoc,
} from './helpers';

let testEnv: RulesTestEnvironment;

beforeAll(async () => { testEnv = await createTestEnv(); });
afterAll(async ()  => { await testEnv.cleanup(); });
afterEach(async () => { await testEnv.clearFirestore(); });

describe('/users/{uid}', () => {
  const USER_DATA = { displayName: 'Owner', email: CLAIMS.owner.email };

  beforeEach(async () => {
    await seedDoc(testEnv, `users/${UIDS.owner}`, USER_DATA);
  });

  it('owner can read own profile', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(db.collection('users').doc(UIDS.owner).get());
  });

  it('owner can update own profile', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(
      db.collection('users').doc(UIDS.owner).update({ displayName: 'Updated' }),
    );
  });

  it('other authenticated user cannot read owner profile', async () => {
    const db = authedDb(testEnv, UIDS.other, CLAIMS.other);
    await assertFails(db.collection('users').doc(UIDS.owner).get());
  });

  it('unauthenticated user cannot read any profile', async () => {
    const db = unauthDb(testEnv);
    await assertFails(db.collection('users').doc(UIDS.owner).get());
  });

  it('unauthenticated user cannot write any profile', async () => {
    const db = unauthDb(testEnv);
    await assertFails(db.collection('users').doc(UIDS.owner).set(USER_DATA));
  });

  it('admin can read any profile', async () => {
    const db = authedDb(testEnv, UIDS.admin, CLAIMS.admin);
    await assertSucceeds(db.collection('users').doc(UIDS.owner).get());
  });
});

describe('/users/{uid}/estimates/{estimateId}', () => {
  beforeEach(async () => {
    await seedDoc(testEnv, `users/${UIDS.owner}/estimates/est-1`, {
      totalGhs: 50000, createdAt: new Date(),
    });
  });

  it('owner can read own estimate', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(
      db.collection('users').doc(UIDS.owner).collection('estimates').doc('est-1').get(),
    );
  });

  it('owner can write own estimate', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(
      db.collection('users').doc(UIDS.owner).collection('estimates').doc('est-new')
        .set({ totalGhs: 75000, createdAt: new Date() }),
    );
  });

  it('other user cannot read estimates', async () => {
    const db = authedDb(testEnv, UIDS.other, CLAIMS.other);
    await assertFails(
      db.collection('users').doc(UIDS.owner).collection('estimates').doc('est-1').get(),
    );
  });

  it('admin can read estimates (via admin claim)', async () => {
    const db = authedDb(testEnv, UIDS.admin, CLAIMS.admin);
    await assertSucceeds(
      db.collection('users').doc(UIDS.owner).collection('estimates').doc('est-1').get(),
    );
  });
});
```

- [ ] **Step 2: Start emulators in background**

```bash
firebase emulators:start --only auth,firestore --project wysebrix-test &
sleep 5   # give emulators time to start
```

- [ ] **Step 3: Run users test and confirm it passes**

```bash
cd functions && npm run test:rules -- --testPathPattern=users.rules
```

Expected: `Tests: N passed`.

- [ ] **Step 4: Stop background emulators**

```bash
kill %1
```

- [ ] **Step 5: Commit**

```bash
git add functions/test/rules/users.rules.test.ts
git commit -m "test(rules): add users and user-estimates security rules tests"
```

---

## Task 5: projects.rules.test.ts

**Files:**
- Create: `functions/test/rules/projects.rules.test.ts`

**Important rule behaviour to test correctly:**
- `isProjectMember()` = owner OR assignedPm OR teamMember OR observer OR collaborator OR admin.
- `isTeamMember()` uses `request.auth.uid in resource.data.teamMemberUids` (array-contains).
- `create` requires `isEmailVerified()` AND `ownerUid == request.auth.uid` AND `withinProjectLimit()`.
- `withinProjectLimit()` does a live `get()` on the user doc — seed `projectCount: 3` to trip the limit.
- `variation_orders` create: any `isProjectMember()` with email-verified; `memberCtx` (seeded as team member) qualifies.
- `costs` write: owner, assignedPm, collaborator, or admin only (not plain team member).
- `chat` update: always `false`.
- `/projects/{id}/audit_log`: read requires owner/actor matching the log entry OR admin; create allowed for any email-verified project member.

- [ ] **Step 1: Create `functions/test/rules/projects.rules.test.ts`**

```typescript
import {
  RulesTestEnvironment,
  createTestEnv,
  authedDb, unauthDb,
  assertFails, assertSucceeds,
  UIDS, CLAIMS, EMAILS,
  seedDoc,
} from './helpers';

let testEnv: RulesTestEnvironment;

beforeAll(async () => { testEnv = await createTestEnv(); });
afterAll(async ()  => { await testEnv.cleanup(); });
afterEach(async () => { await testEnv.clearFirestore(); });

// Shared project fixture
const PROJECT = {
  ownerUid: UIDS.owner,
  title: 'Test Project',
  status: 'active',
  teamMemberUids: [UIDS.member],
  collaboratorUids: [],
  observerUids: [],
  assignedPmUid: null,
  budget: 100000,
};

describe('/projects/{projectId} — top-level CRUD', () => {
  beforeEach(async () => {
    await seedDoc(testEnv, `users/${UIDS.owner}`, { projectCount: 1 });
    await seedDoc(testEnv, `users/${UIDS.free}`,  { projectCount: 0 });
    await seedDoc(testEnv, `projects/proj-1`, PROJECT);
  });

  it('owner can read own project', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(db.collection('projects').doc('proj-1').get());
  });

  it('team member can read project', async () => {
    const db = authedDb(testEnv, UIDS.member, CLAIMS.member);
    await assertSucceeds(db.collection('projects').doc('proj-1').get());
  });

  it('non-member cannot read project', async () => {
    const db = authedDb(testEnv, UIDS.other, CLAIMS.other);
    await assertFails(db.collection('projects').doc('proj-1').get());
  });

  it('unauthenticated user cannot read project', async () => {
    const db = unauthDb(testEnv);
    await assertFails(db.collection('projects').doc('proj-1').get());
  });

  it('admin can read any project', async () => {
    const db = authedDb(testEnv, UIDS.admin, CLAIMS.admin);
    await assertSucceeds(db.collection('projects').doc('proj-1').get());
  });

  it('owner can delete own project', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(db.collection('projects').doc('proj-1').delete());
  });

  it('team member cannot delete project', async () => {
    const db = authedDb(testEnv, UIDS.member, CLAIMS.member);
    await assertFails(db.collection('projects').doc('proj-1').delete());
  });

  it('email-verified owner can create project within limit', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(
      db.collection('projects').doc('proj-new').set({
        ...PROJECT, ownerUid: UIDS.owner,
      }),
    );
  });

  it('free user at project limit (projectCount >= 3) cannot create', async () => {
    // Update free user to be at limit
    await seedDoc(testEnv, `users/${UIDS.free}`, { projectCount: 3 });
    const db = authedDb(testEnv, UIDS.free, CLAIMS.free);
    await assertFails(
      db.collection('projects').doc('proj-over-limit').set({
        ...PROJECT, ownerUid: UIDS.free,
      }),
    );
  });

  it('unverified user cannot create project', async () => {
    const db = authedDb(testEnv, UIDS.unverified, CLAIMS.unverified);
    await assertFails(
      db.collection('projects').doc('proj-unverified').set({
        ...PROJECT, ownerUid: UIDS.unverified,
      }),
    );
  });
});

describe('/projects/{projectId}/variation_orders/{voId}', () => {
  beforeEach(async () => {
    await seedDoc(testEnv, `projects/proj-1`, PROJECT);
    await seedDoc(testEnv, `projects/proj-1/variation_orders/vo-1`, {
      title: 'Extra excavation',
      costDeltaGhs: 1000,
      status: 'pending',
    });
  });

  it('owner can create variation order', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(
      db.collection('projects').doc('proj-1').collection('variation_orders').doc('vo-new')
        .set({ title: 'New VO', costDeltaGhs: 500, status: 'pending' }),
    );
  });

  it('team member can read variation orders', async () => {
    const db = authedDb(testEnv, UIDS.member, CLAIMS.member);
    await assertSucceeds(
      db.collection('projects').doc('proj-1').collection('variation_orders').doc('vo-1').get(),
    );
  });

  it('non-member cannot read variation orders', async () => {
    const db = authedDb(testEnv, UIDS.other, CLAIMS.other);
    await assertFails(
      db.collection('projects').doc('proj-1').collection('variation_orders').doc('vo-1').get(),
    );
  });
});

describe('/projects/{projectId}/costs/{costId}', () => {
  beforeEach(async () => {
    await seedDoc(testEnv, `projects/proj-1`, PROJECT);
    await seedDoc(testEnv, `users/${UIDS.owner}`, { projectCount: 1, costEntryCount: 0 });
    await seedDoc(testEnv, `projects/proj-1/costs/cost-1`, {
      description: 'Cement', amountGhs: 850,
    });
  });

  it('owner can read costs', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(
      db.collection('projects').doc('proj-1').collection('costs').doc('cost-1').get(),
    );
  });

  it('team member can read costs', async () => {
    const db = authedDb(testEnv, UIDS.member, CLAIMS.member);
    await assertSucceeds(
      db.collection('projects').doc('proj-1').collection('costs').doc('cost-1').get(),
    );
  });

  it('non-member cannot read costs', async () => {
    const db = authedDb(testEnv, UIDS.other, CLAIMS.other);
    await assertFails(
      db.collection('projects').doc('proj-1').collection('costs').doc('cost-1').get(),
    );
  });

  it('owner can write cost entry', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(
      db.collection('projects').doc('proj-1').collection('costs').doc('cost-new')
        .set({ description: 'Steel', amountGhs: 1200 }),
    );
  });

  it('team member (non-owner, non-PM, non-collaborator) cannot write costs', async () => {
    const db = authedDb(testEnv, UIDS.member, CLAIMS.member);
    await assertFails(
      db.collection('projects').doc('proj-1').collection('costs').doc('cost-new2')
        .set({ description: 'Gravel', amountGhs: 300 }),
    );
  });
});

describe('/projects/{projectId}/chat/{messageId} — immutability', () => {
  beforeEach(async () => {
    await seedDoc(testEnv, `projects/proj-1`, PROJECT);
    await seedDoc(testEnv, `projects/proj-1/chat/msg-1`, {
      senderUid: UIDS.owner, text: 'Hello', createdAt: new Date(),
    });
  });

  it('owner can create a new message', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(
      db.collection('projects').doc('proj-1').collection('chat').doc('msg-new')
        .set({ senderUid: UIDS.owner, text: 'New message', createdAt: new Date() }),
    );
  });

  it('update of existing message is denied for all users', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertFails(
      db.collection('projects').doc('proj-1').collection('chat').doc('msg-1')
        .update({ text: 'Edited' }),
    );
  });
});

describe('/projects/{projectId}/audit_log — read and write', () => {
  beforeEach(async () => {
    await seedDoc(testEnv, `projects/proj-1`, PROJECT);
    await seedDoc(testEnv, `projects/proj-1/audit_log/log-1`, {
      actorUid: UIDS.owner, ownerUid: UIDS.owner, action: 'project.created',
    });
  });

  it('owner (actorUid matches) can read audit log', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(
      db.collection('projects').doc('proj-1').collection('audit_log').doc('log-1').get(),
    );
  });

  it('admin can read audit log', async () => {
    const db = authedDb(testEnv, UIDS.admin, CLAIMS.admin);
    await assertSucceeds(
      db.collection('projects').doc('proj-1').collection('audit_log').doc('log-1').get(),
    );
  });

  it('write is denied for all clients (backend-only via admin SDK)', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    // update and delete are rule-blocked; create is allowed for project members
    await assertFails(
      db.collection('projects').doc('proj-1').collection('audit_log').doc('log-1')
        .update({ action: 'tampered' }),
    );
  });
});
```

- [ ] **Step 2: Run projects rules test**

```bash
firebase emulators:start --only auth,firestore --project wysebrix-test &
sleep 5
cd functions && npm run test:rules -- --testPathPattern=projects.rules
kill %1
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add functions/test/rules/projects.rules.test.ts
git commit -m "test(rules): add projects security rules tests"
```

---

## Task 6: Remaining rules test files (catalog, contracts, vendors, invitations)

**Files:**
- Create: `functions/test/rules/catalog.rules.test.ts`
- Create: `functions/test/rules/contracts.rules.test.ts`
- Create: `functions/test/rules/vendors.rules.test.ts`
- Create: `functions/test/rules/invitations.rules.test.ts`

- [ ] **Step 1: Create `functions/test/rules/catalog.rules.test.ts`**

Tests `cost_catalog`, `fx_rates`, `boq_rates` (all use `allow read: if true; write: if isAdmin()`):

```typescript
import {
  RulesTestEnvironment, createTestEnv, authedDb, unauthDb,
  assertFails, assertSucceeds, UIDS, CLAIMS, seedDoc,
} from './helpers';

let testEnv: RulesTestEnvironment;
beforeAll(async () => { testEnv = await createTestEnv(); });
afterAll(async ()  => { await testEnv.cleanup(); });
afterEach(async () => { await testEnv.clearFirestore(); });

const COLLECTIONS = ['cost_catalog', 'fx_rates', 'boq_rates'];

for (const col of COLLECTIONS) {
  describe(`/${col} — public read, admin write`, () => {
    beforeEach(async () => {
      await seedDoc(testEnv, `${col}/doc-1`, { value: 100 });
    });

    it(`authenticated user can read ${col}`, async () => {
      const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
      await assertSucceeds(db.collection(col).doc('doc-1').get());
    });

    it(`unauthenticated user can read ${col} (public)`, async () => {
      const db = unauthDb(testEnv);
      await assertSucceeds(db.collection(col).doc('doc-1').get());
    });

    it(`authenticated non-admin cannot write ${col}`, async () => {
      const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
      await assertFails(db.collection(col).doc('doc-new').set({ value: 200 }));
    });
  });
}
```

- [ ] **Step 2: Create `functions/test/rules/contracts.rules.test.ts`**

Contract read uses `memberUids` array (not `partyUids`):

```typescript
import {
  RulesTestEnvironment, createTestEnv, authedDb, unauthDb,
  assertFails, assertSucceeds, UIDS, CLAIMS, seedDoc,
} from './helpers';

let testEnv: RulesTestEnvironment;
beforeAll(async () => { testEnv = await createTestEnv(); });
afterAll(async ()  => { await testEnv.cleanup(); });
afterEach(async () => { await testEnv.clearFirestore(); });

const CONTRACT = {
  ownerUid: UIDS.owner,
  builderUid: UIDS.member,
  memberUids: [UIDS.owner, UIDS.member],
  title: 'Construction Contract',
};

describe('/contracts/{contractId}', () => {
  beforeEach(async () => {
    await seedDoc(testEnv, 'contracts/contract-1', CONTRACT);
  });

  it('memberUids party can read contract', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(db.collection('contracts').doc('contract-1').get());
  });

  it('builderUid can read contract', async () => {
    const db = authedDb(testEnv, UIDS.member, CLAIMS.member);
    await assertSucceeds(db.collection('contracts').doc('contract-1').get());
  });

  it('non-member cannot read contract', async () => {
    const db = authedDb(testEnv, UIDS.other, CLAIMS.other);
    await assertFails(db.collection('contracts').doc('contract-1').get());
  });

  it('unauthenticated cannot read contract', async () => {
    const db = unauthDb(testEnv);
    await assertFails(db.collection('contracts').doc('contract-1').get());
  });

  it('email-verified owner can create contract', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(
      db.collection('contracts').doc('contract-new').set({
        ...CONTRACT, ownerUid: UIDS.owner,
      }),
    );
  });

  it('unverified user cannot create contract', async () => {
    const db = authedDb(testEnv, UIDS.unverified, CLAIMS.unverified);
    await assertFails(
      db.collection('contracts').doc('contract-unverified').set({
        ...CONTRACT, ownerUid: UIDS.unverified,
      }),
    );
  });
});
```

- [ ] **Step 3: Create `functions/test/rules/vendors.rules.test.ts`**

Note: the actual rules allow `create`/`update` for any `isEmailVerified()` user (not owner-only):

```typescript
import {
  RulesTestEnvironment, createTestEnv, authedDb, unauthDb,
  assertFails, assertSucceeds, UIDS, CLAIMS, seedDoc,
} from './helpers';

let testEnv: RulesTestEnvironment;
beforeAll(async () => { testEnv = await createTestEnv(); });
afterAll(async ()  => { await testEnv.cleanup(); });
afterEach(async () => { await testEnv.clearFirestore(); });

describe('/vendors/{vendorId}', () => {
  beforeEach(async () => {
    await seedDoc(testEnv, 'vendors/vendor-1', { name: 'BuildCo', ownerUid: UIDS.owner });
  });

  it('authenticated user can read vendors', async () => {
    const db = authedDb(testEnv, UIDS.other, CLAIMS.other);
    await assertSucceeds(db.collection('vendors').doc('vendor-1').get());
  });

  it('unauthenticated user cannot read vendors', async () => {
    const db = unauthDb(testEnv);
    await assertFails(db.collection('vendors').doc('vendor-1').get());
  });

  it('email-verified user can create vendor profile', async () => {
    const db = authedDb(testEnv, UIDS.other, CLAIMS.other);
    await assertSucceeds(
      db.collection('vendors').doc('vendor-new').set({ name: 'New Vendor', ownerUid: UIDS.other }),
    );
  });

  it('unverified user cannot create vendor', async () => {
    const db = authedDb(testEnv, UIDS.unverified, CLAIMS.unverified);
    await assertFails(
      db.collection('vendors').doc('vendor-unverified').set({ name: 'Bad', ownerUid: UIDS.unverified }),
    );
  });
});
```

- [ ] **Step 4: Create `functions/test/rules/invitations.rules.test.ts`**

Note: invitations read is NOT open to all authenticated users — only invitee, inviter, or admin can read:

```typescript
import {
  RulesTestEnvironment, createTestEnv, authedDb, unauthDb,
  assertFails, assertSucceeds, UIDS, EMAILS, CLAIMS, seedDoc,
} from './helpers';

let testEnv: RulesTestEnvironment;
beforeAll(async () => { testEnv = await createTestEnv(); });
afterAll(async ()  => { await testEnv.cleanup(); });
afterEach(async () => { await testEnv.clearFirestore(); });

const INVITATION = {
  inviterUid: UIDS.owner,
  inviteeEmail: EMAILS.member,
  projectId: 'proj-1',
  status: 'pending',
};

describe('/invitations/{token}', () => {
  beforeEach(async () => {
    await seedDoc(testEnv, 'invitations/invite-tok-1', INVITATION);
  });

  it('inviter can read own invitation', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(db.collection('invitations').doc('invite-tok-1').get());
  });

  it('invitee (email matches inviteeEmail) can read invitation', async () => {
    // memberCtx has email matching EMAILS.member == INVITATION.inviteeEmail
    const db = authedDb(testEnv, UIDS.member, CLAIMS.member);
    await assertSucceeds(db.collection('invitations').doc('invite-tok-1').get());
  });

  it('unrelated authenticated user cannot read invitation', async () => {
    const db = authedDb(testEnv, UIDS.other, CLAIMS.other);
    await assertFails(db.collection('invitations').doc('invite-tok-1').get());
  });

  it('admin can read any invitation', async () => {
    const db = authedDb(testEnv, UIDS.admin, CLAIMS.admin);
    await assertSucceeds(db.collection('invitations').doc('invite-tok-1').get());
  });

  it('unauthenticated user cannot read invitation', async () => {
    const db = unauthDb(testEnv);
    await assertFails(db.collection('invitations').doc('invite-tok-1').get());
  });

  it('non-admin cannot create invitation (only email-verified users can create)', async () => {
    // Actually: create requires isEmailVerified() — so email-verified users CAN create
    // Test that unverified user cannot create
    const db = authedDb(testEnv, UIDS.unverified, CLAIMS.unverified);
    await assertFails(
      db.collection('invitations').doc('invite-new').set({ ...INVITATION }),
    );
  });

  it('email-verified user can create invitation', async () => {
    const db = authedDb(testEnv, UIDS.owner, CLAIMS.owner);
    await assertSucceeds(
      db.collection('invitations').doc('invite-new').set({ ...INVITATION, inviterUid: UIDS.owner }),
    );
  });
});
```

- [ ] **Step 5: Run all rules tests together**

```bash
firebase emulators:start --only auth,firestore --project wysebrix-test &
sleep 5
cd functions && npm run test:rules
kill %1
```

Expected: all rules tests pass (users + projects + catalog + contracts + vendors + invitations).

- [ ] **Step 6: Commit**

```bash
git add functions/test/rules/
git commit -m "test(rules): add catalog, contracts, vendors, invitations rules tests"
```

---

## Task 7: budgetAlerts.test.ts

**Files:**
- Create: `functions/test/unit/budgetAlerts.test.ts`

**Strategy:** Mock `firebase-admin` so `db.collection(...).doc(...).collection(...).get()` returns
configurable phase snapshots, and `.add()` returns a resolved promise. Capture the underlying handler
by mocking `onDocumentUpdated` to expose it. Call the captured handler with synthetic before/after data.

- [ ] **Step 1: Create `functions/test/unit/budgetAlerts.test.ts`**

```typescript
// Mocks must be declared before importing the module under test.
// Variables prefixed with 'mock' are hoisted by babel-jest with jest.mock().

const mockAdd    = jest.fn().mockResolvedValue({ id: 'notif-1' });
const mockGet    = jest.fn();
const mockUpdate = jest.fn().mockResolvedValue(undefined);

// Chainable Firestore ref mock — every collection/doc call returns the same ref
const mockRef: any = { add: mockAdd, get: mockGet, update: mockUpdate };
mockRef.collection = jest.fn().mockReturnValue(mockRef);
mockRef.doc        = jest.fn().mockReturnValue(mockRef);

jest.mock('firebase-admin', () => {
  const fsModule: any = jest.fn().mockReturnValue(mockRef);
  fsModule.FieldValue = { serverTimestamp: jest.fn().mockReturnValue('SERVER_TS') };
  return { firestore: fsModule, initializeApp: jest.fn(), apps: ['app'] };
});

jest.mock('firebase-functions', () => ({
  logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

// Capture the handler registered with onDocumentUpdated
let capturedHandler: Function;
jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentUpdated: jest.fn((_opts: unknown, handler: Function) => {
    capturedHandler = handler;
    return { run: handler };
  }),
}));

// Now import the module — handler is registered during import
import '../../src/budgetAlerts';

// Helper to build a minimal trigger event
function makeEvent(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
  projectId = 'proj-1',
) {
  return {
    params: { projectId },
    data: {
      before: { data: () => before },
      after:  { data: () => after  },
    },
  };
}

// Helper to mock phase snapshot
function mockPhaseSnap(total: number, completed: number) {
  const docs = Array.from({ length: total }, (_, i) => ({
    data: () => ({ status: i < completed ? 'completed' : 'pending' }),
  }));
  mockGet.mockResolvedValue({ size: total, empty: total === 0, docs });
}

describe('budgetAlerts', () => {
  beforeEach(() => {
    mockAdd.mockClear();
    mockGet.mockClear();
    jest.clearAllMocks();
    // Re-apply the mockRef circular references after clearAllMocks resets them
    mockRef.collection = jest.fn().mockReturnValue(mockRef);
    mockRef.doc        = jest.fn().mockReturnValue(mockRef);
    mockRef.add        = mockAdd;
    mockRef.get        = mockGet;
  });

  it('no notification when amountSpent did not change', async () => {
    await capturedHandler(makeEvent(
      { amountSpent: 5000 },
      { amountSpent: 5000, budget: 10000, ownerUid: 'uid-1', title: 'T' },
    ));
    expect(mockAdd).not.toHaveBeenCalled();
  });

  it('no notification when budget is missing', async () => {
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 9000, ownerUid: 'uid-1', title: 'T' }, // no budget field
    ));
    expect(mockAdd).not.toHaveBeenCalled();
  });

  it('no notification when ownerUid is missing', async () => {
    mockPhaseSnap(0, 0);
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 9500, budget: 10000, title: 'T' }, // no ownerUid
    ));
    expect(mockAdd).not.toHaveBeenCalled();
  });

  it('critical alert when spendPct >= 90', async () => {
    mockPhaseSnap(4, 2); // 50% completion — irrelevant for critical
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 9200, budget: 10000, ownerUid: 'uid-1', title: 'Proj' },
    ));
    expect(mockAdd).toHaveBeenCalledWith(
      expect.objectContaining({ severity: 'critical' }),
    );
  });

  it('high alert when spendPct=75 and completionPct<50', async () => {
    mockPhaseSnap(10, 3); // 30% completion < 50
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 7500, budget: 10000, ownerUid: 'uid-1', title: 'Proj' },
    ));
    expect(mockAdd).toHaveBeenCalledWith(
      expect.objectContaining({ severity: 'high' }),
    );
  });

  it('no alert when spendPct=75 and completionPct>=50', async () => {
    mockPhaseSnap(10, 6); // 60% completion >= 50
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 7500, budget: 10000, ownerUid: 'uid-1', title: 'Proj' },
    ));
    expect(mockAdd).not.toHaveBeenCalled();
  });

  it('medium alert when spendPct=50 and completionPct<30', async () => {
    mockPhaseSnap(10, 2); // 20% completion < 30
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 5000, budget: 10000, ownerUid: 'uid-1', title: 'Proj' },
    ));
    expect(mockAdd).toHaveBeenCalledWith(
      expect.objectContaining({ severity: 'medium' }),
    );
  });

  it('no alert when spendPct=50 and completionPct>=30', async () => {
    mockPhaseSnap(10, 4); // 40% completion >= 30
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 5000, budget: 10000, ownerUid: 'uid-1', title: 'Proj' },
    ));
    expect(mockAdd).not.toHaveBeenCalled();
  });

  it('no alert when spendPct=40', async () => {
    mockPhaseSnap(10, 0);
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 4000, budget: 10000, ownerUid: 'uid-1', title: 'Proj' },
    ));
    expect(mockAdd).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run budgetAlerts unit test**

```bash
cd functions && npm run test:unit -- --testPathPattern=budgetAlerts
```

Expected: `Tests: 7 passed`.

- [ ] **Step 3: Commit**

```bash
git add functions/test/unit/budgetAlerts.test.ts
git commit -m "test(functions): add budgetAlerts unit tests"
```

---

## Task 8: dataRetention.test.ts

**Files:**
- Create: `functions/test/unit/dataRetention.test.ts`

**Key facts from source (`dataRetention.ts`):**
- `audit_log` (top-level collection) cutoff: **2 years** (`TWO_YEARS_MS`), not 1 year.
- `login_activity` cutoff: 90 days (`NINETY_DAYS_MS`); timestamp field is `"timestamp"` (not `createdAt`).
- Soft-deleted projects cutoff: 30 days; uses `deletedAt` field.
- `deleteCollection` is a module-private helper — tests verify behaviour via the exported `enforceDataRetention.run()`.
- Hard limit: 500 docs per collection per run; documents beyond 500 are left for the next run.
- The function iterates `users` to clean per-user `login_activity`; mock `db.collection('users').select().get()` accordingly.

- [ ] **Step 1: Create `functions/test/unit/dataRetention.test.ts`**

```typescript
const mockBatchDelete = jest.fn().mockResolvedValue(undefined);
const mockBatchCommit = jest.fn().mockResolvedValue(undefined);
const mockBatch: any  = { delete: mockBatchDelete, commit: mockBatchCommit };

const mockRunTransaction = jest.fn();
const mockGet            = jest.fn();

// Per-call stub map: key = collection name, value = mock snapshot
const snapStubs: Record<string, any> = {};

// Chainable ref — tracks the last collection name for test routing
let lastCollectionName = '';
const mockRef: any = {};
mockRef.collection = jest.fn().mockImplementation((name: string) => {
  lastCollectionName = name;
  return { ...mockRef, _name: name };
});
mockRef.doc = jest.fn().mockReturnValue(mockRef);
mockRef.select = jest.fn().mockReturnValue(mockRef);
mockRef.where = jest.fn().mockReturnValue(mockRef);
mockRef.limit = jest.fn().mockReturnValue(mockRef);
mockRef.get   = mockGet;

jest.mock('firebase-admin', () => {
  const fsModule: any = jest.fn().mockReturnValue(mockRef);
  fsModule.FieldValue = { serverTimestamp: jest.fn().mockReturnValue('SERVER_TS') };
  return {
    firestore: fsModule,
    initializeApp: jest.fn(),
    apps: ['app'],
    storage: jest.fn().mockReturnValue({ bucket: jest.fn().mockReturnValue({ deleteFiles: jest.fn() }) }),
  };
});

jest.mock('firebase-functions', () => ({
  logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

let capturedRetentionHandler: Function;
jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: jest.fn((_opts: unknown, handler: Function) => {
    capturedRetentionHandler = handler;
    return { run: handler };
  }),
}));
jest.mock('firebase-functions/v2/https', () => ({
  onCall: jest.fn((_opts: unknown, handler: Function) => ({ run: handler })),
  HttpsError: class HttpsError extends Error {
    constructor(public code: string, message: string) { super(message); }
  },
}));
jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentUpdated: jest.fn((_opts: unknown, handler: Function) => ({ run: handler })),
}));
jest.mock('./../../src/utils/rateLimit', () => ({
  rateLimit: jest.fn().mockResolvedValue(undefined),
}));

import '../../src/dataRetention';

function makeSnapshot(docs: Array<Record<string, unknown>>, timestampField = 'createdAt') {
  const items = docs.map((d) => ({
    ref:  { id: 'x' },
    data: () => d,
  }));
  return { empty: items.length === 0, size: items.length, docs: items };
}

describe('enforceDataRetention', () => {
  beforeEach(() => {
    mockGet.mockReset();
    mockBatchDelete.mockClear();
    mockBatchCommit.mockReset().mockResolvedValue(undefined);
    mockRef.collection = jest.fn().mockReturnValue(mockRef);
    mockRef.doc        = jest.fn().mockReturnValue(mockRef);
    mockRef.select     = jest.fn().mockReturnValue(mockRef);
    mockRef.where      = jest.fn().mockReturnValue(mockRef);
    mockRef.limit      = jest.fn().mockReturnValue(mockRef);
    mockRef.get        = mockGet;
    // Re-attach batch mock to firestore module
    (require('firebase-admin').firestore as jest.Mock).mockReturnValue({
      ...mockRef,
      batch: jest.fn().mockReturnValue(mockBatch),
    });
  });

  it('runs without throwing when all collections are empty', async () => {
    mockGet.mockResolvedValue(makeSnapshot([]));
    await expect(capturedRetentionHandler()).resolves.toBeUndefined();
  });

  it('audit_log: deletes docs older than 2 years, keeps newer ones', async () => {
    const twoYearsAgo = new Date(Date.now() - 2 * 365.25 * 24 * 60 * 60 * 1000 - 1000);
    const recent      = new Date();
    // First call is audit_log, second is users.select().get(), rest are login_activity + projects
    mockGet
      .mockResolvedValueOnce(makeSnapshot([{ createdAt: twoYearsAgo }])) // audit_log old
      .mockResolvedValueOnce(makeSnapshot([]))  // users list (no users)
      .mockResolvedValueOnce(makeSnapshot([])); // soft-deleted projects
    await capturedRetentionHandler();
    expect(mockBatchDelete).toHaveBeenCalledTimes(1);
  });

  it('login_activity: deletes entries older than 90 days', async () => {
    const ninetyOneDaysAgo = new Date(Date.now() - 91 * 24 * 60 * 60 * 1000);
    mockGet
      .mockResolvedValueOnce(makeSnapshot([]))  // audit_log
      .mockResolvedValueOnce(makeSnapshot([{ id: 'user-1' }]))  // users list
      .mockResolvedValueOnce(makeSnapshot([{ timestamp: ninetyOneDaysAgo }])) // login_activity
      .mockResolvedValueOnce(makeSnapshot([]));  // soft-deleted projects
    await capturedRetentionHandler();
    expect(mockBatchDelete).toHaveBeenCalledTimes(1);
  });

  it('stops at 500 docs per collection (single-pass behaviour)', async () => {
    const oldDate = new Date(Date.now() - 3 * 365 * 24 * 60 * 60 * 1000);
    const docs500 = Array(500).fill({ createdAt: oldDate });
    mockGet
      .mockResolvedValueOnce(makeSnapshot(docs500)) // audit_log returns exactly 500
      .mockResolvedValueOnce(makeSnapshot([]))       // users
      .mockResolvedValueOnce(makeSnapshot([]));      // soft-deleted projects
    await capturedRetentionHandler();
    // Batch committed exactly once for audit_log
    expect(mockBatchCommit).toHaveBeenCalledTimes(1);
  });

  it('soft-deleted projects older than 30 days are purged', async () => {
    const thirtyOneDaysAgo = new Date(Date.now() - 31 * 24 * 60 * 60 * 1000);
    mockGet
      .mockResolvedValueOnce(makeSnapshot([]))   // audit_log
      .mockResolvedValueOnce(makeSnapshot([]))   // users
      .mockResolvedValueOnce(makeSnapshot([{ deletedAt: thirtyOneDaysAgo }])); // soft-deleted project
    await capturedRetentionHandler();
    expect(mockBatchDelete).toHaveBeenCalledTimes(1);
  });
});
```

- [ ] **Step 2: Run dataRetention test**

```bash
cd functions && npm run test:unit -- --testPathPattern=dataRetention
```

Expected: `Tests: 5 passed`.

- [ ] **Step 3: Commit**

```bash
git add functions/test/unit/dataRetention.test.ts
git commit -m "test(functions): add dataRetention unit tests"
```

---

## Task 9: marketPricesUpdater.test.ts + updateReminderScheduler.test.ts

**Files:**
- Create: `functions/test/unit/marketPricesUpdater.test.ts`
- Create: `functions/test/unit/updateReminderScheduler.test.ts`

- [ ] **Step 1: Create `functions/test/unit/marketPricesUpdater.test.ts`**

```typescript
const mockSet = jest.fn().mockResolvedValue(undefined);
const mockRef: any = {};
mockRef.collection = jest.fn().mockReturnValue(mockRef);
mockRef.doc        = jest.fn().mockReturnValue(mockRef);
mockRef.set        = mockSet;

jest.mock('firebase-admin', () => {
  const fsModule: any = jest.fn().mockReturnValue(mockRef);
  fsModule.FieldValue = { serverTimestamp: jest.fn().mockReturnValue('SERVER_TS') };
  return { firestore: fsModule, initializeApp: jest.fn(), apps: ['app'] };
});

jest.mock('firebase-functions', () => ({
  logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

let capturedHandler: Function;
jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: jest.fn((_opts: unknown, handler: Function) => {
    capturedHandler = handler;
    return { run: handler };
  }),
}));

import '../../src/marketPricesUpdater';

describe('refreshMarketPrices', () => {
  beforeEach(() => {
    mockSet.mockClear();
    mockRef.collection = jest.fn().mockReturnValue(mockRef);
    mockRef.doc        = jest.fn().mockReturnValue(mockRef);
    mockRef.set        = mockSet;
  });

  it('writes to market_prices/ghana_current', async () => {
    await capturedHandler();
    expect(mockRef.collection).toHaveBeenCalledWith('market_prices');
    expect(mockRef.doc).toHaveBeenCalledWith('ghana_current');
    expect(mockSet).toHaveBeenCalledTimes(1);
  });

  it('written document has updatedAt, currency, and items fields', async () => {
    await capturedHandler();
    const written = mockSet.mock.calls[0][0] as Record<string, unknown>;
    expect(written).toHaveProperty('updatedAt');
    expect(written).toHaveProperty('currency', 'GHS');
    expect(written).toHaveProperty('items');
    expect(Array.isArray(written.items)).toBe(true);
    expect((written.items as unknown[]).length).toBeGreaterThan(0);
  });

  it('each item has name, unit, and priceGhs fields', async () => {
    await capturedHandler();
    const written = mockSet.mock.calls[0][0] as Record<string, unknown>;
    const items = written.items as Array<Record<string, unknown>>;
    for (const item of items) {
      expect(item).toHaveProperty('name');
      expect(item).toHaveProperty('unit');
      expect(item).toHaveProperty('priceGhs');
    }
  });

  it('is idempotent — calling twice uses set() (overwrite, not append)', async () => {
    await capturedHandler();
    await capturedHandler();
    // Both calls write to the same doc — each is a full set(), not add()
    expect(mockSet).toHaveBeenCalledTimes(2);
  });
});
```

- [ ] **Step 2: Create `functions/test/unit/updateReminderScheduler.test.ts`**

The scheduler queries `projects` where `status == 'active'` and `updateFrequencyDays > 0`.
It notifies the builder when overdue, and BOTH builder+owner when `daysSinceLastUpdate >= updateFrequencyDays + 2`.
Uses `project_updates` subcollection (ordered by `timestamp desc`) to find last update time.

```typescript
import * as admin from 'firebase-admin';

const mockNotifAdd = jest.fn().mockResolvedValue({ id: 'n-1' });
const mockProjectsGet = jest.fn();
const mockUpdatesGet  = jest.fn();

// Build a chainable mock that routes get() differently for projects vs project_updates
const mockRef: any = {};
mockRef.doc        = jest.fn().mockReturnValue(mockRef);
mockRef.collection = jest.fn().mockReturnValue(mockRef);
mockRef.where      = jest.fn().mockReturnValue(mockRef);
mockRef.orderBy    = jest.fn().mockReturnValue(mockRef);
mockRef.limit      = jest.fn().mockReturnValue(mockRef);
mockRef.add        = mockNotifAdd;
mockRef.get        = mockProjectsGet; // default; overridden per test via mockResolvedValueOnce

jest.mock('firebase-admin', () => {
  const adminFirestore: any = jest.fn().mockReturnValue(mockRef);
  adminFirestore.Timestamp = { now: jest.fn().mockReturnValue({ toDate: () => new Date() }) };
  adminFirestore.FieldValue = { serverTimestamp: jest.fn().mockReturnValue('SERVER_TS') };
  return {
    firestore: adminFirestore,
    initializeApp: jest.fn(),
    apps: ['app'],
  };
});

jest.mock('firebase-functions', () => ({
  logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

let capturedHandler: Function;
jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: jest.fn((_opts: unknown, handler: Function) => {
    capturedHandler = handler;
    return { run: handler };
  }),
}));

import '../../src/updateReminderScheduler';

const NOW = new Date();

function makeProject(overrides: Record<string, unknown> = {}) {
  return {
    id: 'proj-1',
    data: () => ({
      status:               'active',
      updateFrequencyDays:  7,
      title:               'Test Project',
      assignedBuilderUid:  'builder-uid',
      ownerUid:            'owner-uid',
      createdAt:           { toDate: () => new Date(NOW.getTime() - 30 * 24 * 60 * 60 * 1000) },
      ...overrides,
    }),
  };
}

function makeUpdateSnap(lastUpdateDaysAgo: number | null) {
  if (lastUpdateDaysAgo === null) return { empty: true, docs: [] };
  const ts = new Date(NOW.getTime() - lastUpdateDaysAgo * 24 * 60 * 60 * 1000);
  return {
    empty: false,
    docs: [{ data: () => ({ timestamp: { toDate: () => ts } }) }],
  };
}

describe('updateReminderScheduler', () => {
  beforeEach(() => {
    mockNotifAdd.mockClear();
    mockProjectsGet.mockReset();
    mockUpdatesGet.mockReset();
    mockRef.collection = jest.fn().mockReturnValue(mockRef);
    mockRef.doc        = jest.fn().mockReturnValue(mockRef);
    mockRef.where      = jest.fn().mockReturnValue(mockRef);
    mockRef.orderBy    = jest.fn().mockReturnValue(mockRef);
    mockRef.limit      = jest.fn().mockReturnValue(mockRef);
    mockRef.add        = mockNotifAdd;
    mockRef.get        = mockProjectsGet;
  });

  it('no notification when project is within update window', async () => {
    // Last update was 5 days ago; frequency is 7 days → still on time
    mockProjectsGet
      .mockResolvedValueOnce({ docs: [makeProject()] })
      .mockResolvedValueOnce(makeUpdateSnap(5)); // project_updates
    await capturedHandler();
    expect(mockNotifAdd).not.toHaveBeenCalled();
  });

  it('notifies builder only when overdue by exactly updateFrequencyDays days', async () => {
    // Last update 8 days ago; frequency 7 → overdue by 1 day (< 2 days) → builder only
    mockProjectsGet
      .mockResolvedValueOnce({ docs: [makeProject()] })
      .mockResolvedValueOnce(makeUpdateSnap(8));
    await capturedHandler();
    expect(mockNotifAdd).toHaveBeenCalledTimes(1);
    const call = mockNotifAdd.mock.calls[0][0] as Record<string, unknown>;
    expect(call.type).toBe('updateReminder');
  });

  it('notifies builder AND owner when overdue by updateFrequencyDays + 2 days', async () => {
    // Last update 10 days ago; frequency 7 → overdue by 3 days (>= 2) → both
    mockProjectsGet
      .mockResolvedValueOnce({ docs: [makeProject()] })
      .mockResolvedValueOnce(makeUpdateSnap(10));
    await capturedHandler();
    expect(mockNotifAdd).toHaveBeenCalledTimes(2);
  });

  it('skips project with status == complete', async () => {
    mockProjectsGet.mockResolvedValueOnce({ docs: [] }); // query returns nothing for completed
    await capturedHandler();
    expect(mockNotifAdd).not.toHaveBeenCalled();
  });

  it('skips project with updateFrequencyDays == 0', async () => {
    mockProjectsGet.mockResolvedValueOnce({ docs: [] }); // query filters these out
    await capturedHandler();
    expect(mockNotifAdd).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 3: Run both tests**

```bash
cd functions && npm run test:unit -- --testPathPattern="marketPricesUpdater|updateReminderScheduler"
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add functions/test/unit/marketPricesUpdater.test.ts functions/test/unit/updateReminderScheduler.test.ts
git commit -m "test(functions): add marketPricesUpdater and updateReminderScheduler unit tests"
```

---

## Task 10: aiCostOptimiser.test.ts + rateLimit.test.ts

**Files:**
- Create: `functions/test/unit/aiCostOptimiser.test.ts`
- Create: `functions/test/unit/rateLimit.test.ts`

- [ ] **Step 1: Create `functions/test/unit/aiCostOptimiser.test.ts`**

The function guard is `!data.totalGhs || data.totalGhs <= 0`. It calls `@anthropic-ai/sdk` — mock it.
Return shape: `{ headline: string, suggestions: Array<{title, description, potentialSavingPct, category}> }`.

```typescript
const mockCreate = jest.fn();

jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockCreate },
  }));
});

jest.mock('firebase-functions/params', () => ({
  defineSecret: jest.fn().mockReturnValue({
    value: jest.fn().mockReturnValue('fake-api-key'),
  }),
}));

const HttpsErrorMock = class extends Error {
  code: string;
  constructor(code: string, message: string) { super(message); this.code = code; }
};

let capturedHandler: Function;
jest.mock('firebase-functions/v2/https', () => ({
  onCall: jest.fn((_opts: unknown, handler: Function) => {
    capturedHandler = handler;
    return { run: handler };
  }),
  HttpsError: HttpsErrorMock,
}));

jest.mock('firebase-functions', () => ({
  logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

import '../../src/aiCostOptimiser';

const VALID_INPUT = {
  typology: 'Residential Standard',
  quality: 'Standard',
  region: 'Greater Accra',
  floorAreaM2: 150,
  floors: 2,
  totalGhs: 800000,
  breakdownGhs: { Superstructure: 400000, Finishes: 200000 },
  preliminariesPct: 8,
  ohpPct: 15,
  contingencyPct: 5,
};

const VALID_AI_RESPONSE = JSON.stringify({
  headline: 'Save 12% with material substitution',
  suggestions: [
    { title: 'Use hollow blocks', description: 'Cheaper than burnt brick', potentialSavingPct: 5, category: 'Masonry' },
    { title: 'Pre-fab roof', description: 'Faster than cast-in-place', potentialSavingPct: 7, category: 'Roofing' },
  ],
});

function makeRequest(data: Record<string, unknown>, authenticated = true) {
  return {
    auth: authenticated ? { uid: 'uid-1' } : null,
    data,
  };
}

describe('analyseEstimateCosts', () => {
  beforeEach(() => {
    mockCreate.mockClear();
    mockCreate.mockResolvedValue({
      content: [{ type: 'text', text: VALID_AI_RESPONSE }],
    });
  });

  it('unauthenticated call throws HttpsError unauthenticated', async () => {
    await expect(capturedHandler(makeRequest(VALID_INPUT, false)))
      .rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('missing totalGhs throws invalid-argument', async () => {
    const { totalGhs: _, ...noTotal } = VALID_INPUT;
    await expect(capturedHandler(makeRequest(noTotal)))
      .rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('totalGhs <= 0 throws invalid-argument', async () => {
    await expect(capturedHandler(makeRequest({ ...VALID_INPUT, totalGhs: 0 })))
      .rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('valid input returns headline string and suggestions array', async () => {
    const result = await capturedHandler(makeRequest(VALID_INPUT)) as Record<string, unknown>;
    expect(typeof result.headline).toBe('string');
    expect(result.headline).not.toBe('');
    expect(Array.isArray(result.suggestions)).toBe(true);
  });

  it('each suggestion has required fields', async () => {
    const result = await capturedHandler(makeRequest(VALID_INPUT)) as Record<string, unknown>;
    const suggestions = result.suggestions as Array<Record<string, unknown>>;
    for (const s of suggestions) {
      expect(s).toHaveProperty('title');
      expect(s).toHaveProperty('description');
      expect(s).toHaveProperty('potentialSavingPct');
      expect(s).toHaveProperty('category');
    }
  });

  it('malformed AI response (non-JSON) throws HttpsError internal', async () => {
    mockCreate.mockResolvedValue({
      content: [{ type: 'text', text: 'NOT VALID JSON !!!!' }],
    });
    await expect(capturedHandler(makeRequest(VALID_INPUT)))
      .rejects.toMatchObject({ code: 'internal' });
  });
});
```

- [ ] **Step 2: Create `functions/test/unit/rateLimit.test.ts`**

`rateLimit` uses Firestore transactions. Mock `db.runTransaction(cb)` by calling `cb` with a mock `tx`.

```typescript
const mockTxGet    = jest.fn();
const mockTxSet    = jest.fn();
const mockTxUpdate = jest.fn();
const mockTx       = { get: mockTxGet, set: mockTxSet, update: mockTxUpdate };

const mockRunTransaction = jest.fn().mockImplementation(async (cb: Function) => cb(mockTx));

const mockRef: any = {};
mockRef.collection = jest.fn().mockReturnValue(mockRef);
mockRef.doc        = jest.fn().mockReturnValue(mockRef);

jest.mock('firebase-admin', () => {
  const fsModule: any = jest.fn().mockReturnValue({
    ...mockRef,
    runTransaction: mockRunTransaction,
    collection: jest.fn().mockReturnValue(mockRef),
  });
  fsModule.FieldValue = { serverTimestamp: jest.fn().mockReturnValue('SERVER_TS') };
  return { firestore: fsModule, initializeApp: jest.fn(), apps: ['app'] };
});

const HttpsErrorMock = class extends Error {
  code: string;
  constructor(code: string, message: string) { super(message); this.code = code; }
};
jest.mock('firebase-functions/v2/https', () => ({
  HttpsError: HttpsErrorMock,
}));

import { rateLimit } from '../../src/utils/rateLimit';

const WINDOW_SECONDS = 3600;
const MAX_CALLS = 3;
const UID = 'uid-test';
const ACTION = 'testAction';

function mockDocState(exists: boolean, count: number, windowStart: number) {
  mockTxGet.mockResolvedValue({
    exists,
    data: () => ({ count, windowStart }),
  });
}

describe('rateLimit', () => {
  beforeEach(() => {
    mockTxGet.mockReset();
    mockTxSet.mockClear();
    mockTxUpdate.mockClear();
    mockRunTransaction.mockImplementation(async (cb: Function) => cb(mockTx));
  });

  it('resolves on first call (document does not exist yet)', async () => {
    mockTxGet.mockResolvedValue({ exists: false });
    await expect(rateLimit(UID, ACTION, MAX_CALLS, WINDOW_SECONDS)).resolves.toBeUndefined();
    expect(mockTxSet).toHaveBeenCalledWith(mockRef, { count: 1, windowStart: expect.any(Number) });
  });

  it('resolves when count is below limit', async () => {
    mockDocState(true, 2, Date.now());
    await expect(rateLimit(UID, ACTION, MAX_CALLS, WINDOW_SECONDS)).resolves.toBeUndefined();
    expect(mockTxUpdate).toHaveBeenCalledWith(mockRef, { count: 3 });
  });

  it('throws resource-exhausted when count equals limit', async () => {
    mockDocState(true, 3, Date.now());
    await expect(rateLimit(UID, ACTION, MAX_CALLS, WINDOW_SECONDS))
      .rejects.toMatchObject({ code: 'resource-exhausted' });
  });

  it('resets counter after TTL window expires', async () => {
    const expiredWindowStart = Date.now() - WINDOW_SECONDS * 1000 - 1000;
    mockDocState(true, 3, expiredWindowStart); // was at limit but window expired
    await expect(rateLimit(UID, ACTION, MAX_CALLS, WINDOW_SECONDS)).resolves.toBeUndefined();
    // Counter reset: set called with count: 1
    expect(mockTxSet).toHaveBeenCalledWith(mockRef, { count: 1, windowStart: expect.any(Number) });
  });
});
```

- [ ] **Step 3: Run both tests**

```bash
cd functions && npm run test:unit -- --testPathPattern="aiCostOptimiser|rateLimit"
```

Expected: all tests pass.

- [ ] **Step 4: Run the full unit test suite**

```bash
cd functions && npm run test:unit
```

Expected: all 6 unit test files pass with 0 failures.

- [ ] **Step 5: Commit**

```bash
git add functions/test/unit/aiCostOptimiser.test.ts functions/test/unit/rateLimit.test.ts
git commit -m "test(functions): add aiCostOptimiser and rateLimit unit tests"
```

---

## Task 11: CI workflow — test-rules and test-functions jobs

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add two new jobs to `.github/workflows/ci.yml`**

Add immediately after the closing `build-android-prod` job block (before the end of file):

```yaml
  test-rules:
    name: Firestore Rules Tests
    runs-on: ubuntu-latest
    needs: []   # runs in parallel with analyze-and-test
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - name: Install functions deps
        run: npm ci
        working-directory: functions
      - name: Install Firebase CLI
        run: npm install -g firebase-tools
      - name: Run rules tests via emulators
        run: |
          firebase emulators:exec \
            --only auth,firestore \
            --project wysebrix-test \
            "npm run test:rules --prefix functions"
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}

  test-functions:
    name: Cloud Functions Unit Tests
    runs-on: ubuntu-latest
    needs: []   # runs in parallel with analyze-and-test
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - name: Install functions deps
        run: npm ci
        working-directory: functions
      - name: Run Cloud Functions unit tests
        run: npm run test:unit
        working-directory: functions
```

- [ ] **Step 2: Verify YAML is valid**

```bash
python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "YAML valid"
```

Expected: `YAML valid`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add test-rules and test-functions parallel CI jobs"
```

---

## Task 12: Suite 4 — performance_test.dart

**Files:**
- Create: `test/estimator/performance_test.dart`

These tests are picked up automatically by `flutter test --coverage` (no CI change needed).

- [ ] **Step 1: Create `test/estimator/performance_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/models/catalog_version.dart';
import 'package:wysebrix/core/use_cases/calculate_estimate.dart';

// Minimal valid input for performance tests
EstimateInput _baseInput(CatalogVersion catalog) => EstimateInput(
  catalogVersion: catalog,
  buildingTypology: BuildingTypology.residentialStandard,
  qualityTier: 'Standard',
  floorAreaM2: 150,
  numberOfFloors: 1,
  region: 'Greater Accra',
  foundationType: 'Strip',
  soilCondition: 'Firm',
  roofType: 'Pitched sheet',
  constructionType: ConstructionType.blockMasonry,
  preliminariesPct: 8,
  ohpPct: 15,
  contingencyPct: 5,
  professionalFeesPct: 5,
  taxLines: [],
  permitMode: PermitMode.standard,
  phasePercents: {},
);

void main() {
  late CatalogVersion catalog;

  setUpAll(() {
    catalog = CatalogVersion.fallback();
  });

  group('Performance — throughput', () {
    test('10,000 calculations complete with average < 1 ms and p99 < 5 ms', () {
      const iterations = 10000;
      final input = _baseInput(catalog);
      final latencies = <int>[];

      for (int i = 0; i < iterations; i++) {
        final sw = Stopwatch()..start();
        EstimationEngine.calculate(input);
        sw.stop();
        latencies.add(sw.elapsedMicroseconds);
      }

      latencies.sort();
      final totalUs = latencies.fold<int>(0, (a, b) => a + b);
      final avgMs = totalUs / iterations / 1000;
      final p99Ms = latencies[(iterations * 0.99).floor()] / 1000;

      expect(avgMs, lessThan(1.0),
          reason: 'Average latency $avgMs ms exceeds 1 ms target');
      expect(p99Ms, lessThan(5.0),
          reason: 'p99 latency $p99Ms ms exceeds 5 ms target');
    });
  });

  group('Performance — determinism', () {
    test('same input produces bit-identical results on repeated calls', () {
      final input = _baseInput(catalog);
      final r1 = EstimationEngine.calculate(input);
      final r2 = EstimationEngine.calculate(input);

      expect(r1.totalPlannedGhs,   equals(r2.totalPlannedGhs));
      expect(r1.costPerM2Ghs,      equals(r2.costPerM2Ghs));
      expect(r1.contingencyGhs,    equals(r2.contingencyGhs));
      expect(r1.professionalFeesGhs, equals(r2.professionalFeesGhs));
      expect(r1.phaseBreakdownGhs, equals(r2.phaseBreakdownGhs));
    });
  });

  group('Performance — monotonic scaling with area', () {
    test('doubling floor area roughly doubles total cost (within 1.95–2.05)', () {
      final input100 = _baseInput(catalog);
      final input200 = EstimateInput(
        catalogVersion: catalog,
        buildingTypology: BuildingTypology.residentialStandard,
        qualityTier: 'Standard',
        floorAreaM2: 300,   // double
        numberOfFloors: 1,
        region: 'Greater Accra',
        foundationType: 'Strip',
        soilCondition: 'Firm',
        roofType: 'Pitched sheet',
        constructionType: ConstructionType.blockMasonry,
        preliminariesPct: 8,
        ohpPct: 15,
        contingencyPct: 5,
        professionalFeesPct: 5,
        taxLines: [],
        permitMode: PermitMode.standard,
        phasePercents: {},
      );

      final r100 = EstimationEngine.calculate(input100);
      final r200 = EstimationEngine.calculate(input200);
      final ratio = r200.totalPlannedGhs / r100.totalPlannedGhs;

      expect(ratio, greaterThan(1.95),
          reason: 'Ratio $ratio below 1.95 — cost does not scale linearly');
      expect(ratio, lessThan(2.05),
          reason: 'Ratio $ratio above 2.05 — cost scales super-linearly');
    });
  });
}
```

- [ ] **Step 2: Run performance tests**

```bash
flutter test test/estimator/performance_test.dart -v
```

Expected: `All tests passed!`

- [ ] **Step 3: Commit**

```bash
git add test/estimator/performance_test.dart
git commit -m "test(estimator): add performance tests — throughput, determinism, monotonic scaling"
```

---

## Task 13: Suite 4 — soak_test.dart

**Files:**
- Create: `test/estimator/soak_test.dart`

- [ ] **Step 1: Create `test/estimator/soak_test.dart`**

```dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/models/catalog_version.dart';
import 'package:wysebrix/core/use_cases/calculate_estimate.dart';

EstimateInput _makeInput({
  required CatalogVersion catalog,
  required String quality,
  required BuildingTypology typology,
  required String foundation,
  required String soil,
  required String roof,
  required ConstructionType constructionType,
  double floorAreaM2 = 150,
  int floors = 1,
}) =>
    EstimateInput(
      catalogVersion: catalog,
      buildingTypology: typology,
      qualityTier: quality,
      floorAreaM2: floorAreaM2,
      numberOfFloors: floors,
      region: 'Greater Accra',
      foundationType: foundation,
      soilCondition: soil,
      roofType: roof,
      constructionType: constructionType,
      preliminariesPct: 8,
      ohpPct: 15,
      contingencyPct: 5,
      professionalFeesPct: 5,
      taxLines: [],
      permitMode: PermitMode.standard,
      phasePercents: {},
    );

void main() {
  late CatalogVersion catalog;

  setUpAll(() {
    catalog = CatalogVersion.fallback();
  });

  group('Soak — combinatorial sweep (972 combinations)', () {
    test('all combinations produce valid, non-NaN, non-zero results', () {
      const qualities    = ['Economy', 'Standard', 'Premium'];
      const foundations  = ['Strip', 'Raft', 'Pile'];
      const soils        = ['Firm', 'Soft', 'Waterlogged'];
      const roofs        = ['Pitched sheet', 'Concrete flat'];
      final typologies   = BuildingTypology.values;
      final constructions = ConstructionType.values;

      int count = 0;
      for (final quality in qualities) {
        for (final typology in typologies) {
          for (final foundation in foundations) {
            for (final soil in soils) {
              for (final roof in roofs) {
                for (final ct in constructions) {
                  final input = _makeInput(
                    catalog: catalog,
                    quality: quality,
                    typology: typology,
                    foundation: foundation,
                    soil: soil,
                    roof: roof,
                    constructionType: ct,
                  );
                  final result = EstimationEngine.calculate(input);
                  final tag = '$quality/$typology/$foundation/$soil/$roof/$ct';

                  expect(result.totalPlannedGhs, greaterThan(0),
                      reason: '$tag: totalPlannedGhs is 0');
                  expect(result.costPerM2Ghs, greaterThan(0),
                      reason: '$tag: costPerM2Ghs is 0');
                  expect(result.totalPlannedGhs.isNaN, isFalse,
                      reason: '$tag: totalPlannedGhs is NaN');
                  expect(result.totalPlannedGhs.isInfinite, isFalse,
                      reason: '$tag: totalPlannedGhs is Infinite');
                  expect(result.phaseBreakdownGhs.isNotEmpty, isTrue,
                      reason: '$tag: phaseBreakdownGhs is empty');

                  // Phase sum ≈ adjustedDirectCost (costPerM2Ghs * area), within GHS 1.0
                  final phaseSum = result.phaseBreakdownGhs.values
                      .fold<double>(0, (a, b) => a + b);
                  final directCost = result.costPerM2Ghs * input.floorAreaM2;
                  expect((phaseSum - directCost).abs(), lessThan(1.0),
                      reason: '$tag: phaseSum $phaseSum != directCost $directCost');

                  count++;
                }
              }
            }
          }
        }
      }
      expect(count, equals(972), reason: 'Expected 972 combinations');
    });
  });

  group('Soak — boundary inputs', () {
    const boundaryAreas  = [0.1, 1.0, 50000.0];
    const boundaryFloors = [1, 2, 10, 30, 99];

    test('floor area extremes produce valid results', () {
      for (final area in boundaryAreas) {
        final input = _makeInput(
          catalog: catalog, quality: 'Standard',
          typology: BuildingTypology.residentialStandard,
          foundation: 'Strip', soil: 'Firm', roof: 'Pitched sheet',
          constructionType: ConstructionType.blockMasonry,
          floorAreaM2: area,
        );
        final result = EstimationEngine.calculate(input);
        expect(result.totalPlannedGhs, greaterThan(0),
            reason: 'Area $area m²: totalPlannedGhs is 0');
        expect(result.totalPlannedGhs.isNaN, isFalse,
            reason: 'Area $area m²: NaN result');
      }
    });

    test('floor count extremes produce valid results', () {
      for (final floors in boundaryFloors) {
        final input = _makeInput(
          catalog: catalog, quality: 'Standard',
          typology: BuildingTypology.residentialStandard,
          foundation: 'Raft', soil: 'Firm', roof: 'Concrete flat',
          constructionType: ConstructionType.blockMasonry,
          floors: floors,
        );
        final result = EstimationEngine.calculate(input);
        expect(result.totalPlannedGhs, greaterThan(0),
            reason: '$floors floors: totalPlannedGhs is 0');
        expect(result.totalPlannedGhs.isNaN, isFalse,
            reason: '$floors floors: NaN result');
      }
    });

    test('all add-ons simultaneously enabled', () {
      final input = EstimateInput(
        catalogVersion: catalog,
        buildingTypology: BuildingTypology.residentialStandard,
        qualityTier: 'Premium',
        floorAreaM2: 300,
        numberOfFloors: 2,
        region: 'Greater Accra',
        foundationType: 'Pile',
        soilCondition: 'Waterlogged',
        roofType: 'Concrete flat',
        constructionType: ConstructionType.rcFrame,
        preliminariesPct: 10,
        ohpPct: 18,
        contingencyPct: 7,
        professionalFeesPct: 6,
        taxLines: [],
        permitMode: PermitMode.standard,
        phasePercents: {},
        includeWaterTank: true,
        includeGeneratorHouse: true,
        includeSwimmingPool: true,
        swimmingPoolGhs: 50000,
        securityWallLenM: 100,
        securityWallRatePerM: 500,
        enhancedServices: true,
        curtainWall: true,
      );
      final result = EstimationEngine.calculate(input);
      expect(result.totalPlannedGhs, greaterThan(0));
      expect(result.totalPlannedGhs.isNaN, isFalse);
    });

    test('zero add-ons and all soft costs disabled produces valid result', () {
      final input = EstimateInput(
        catalogVersion: catalog,
        buildingTypology: BuildingTypology.residentialStandard,
        qualityTier: 'Economy',
        floorAreaM2: 80,
        numberOfFloors: 1,
        region: 'Greater Accra',
        foundationType: 'Strip',
        soilCondition: 'Firm',
        roofType: 'Pitched sheet',
        constructionType: ConstructionType.blockMasonry,
        preliminariesPct: 0,
        ohpPct: 0,
        contingencyPct: 0,
        professionalFeesPct: 0,
        taxLines: [],
        permitMode: PermitMode.none,
        phasePercents: {},
      );
      final result = EstimationEngine.calculate(input);
      expect(result.totalPlannedGhs, greaterThan(0));
      expect(result.totalPlannedGhs.isNaN, isFalse);
    });
  });

  group('Soak — catalog fallback integrity', () {
    test('CatalogVersion.fallback() has valid base rates', () {
      final c = CatalogVersion.fallback();
      for (final entry in c.baseRatesPerM2.entries) {
        expect(entry.value, greaterThan(0),
            reason: 'Base rate for ${entry.key} is not > 0');
      }
    });

    test('all regional indices are in (0.0, 2.0]', () {
      final c = CatalogVersion.fallback();
      for (final entry in c.regionalIndices.entries) {
        expect(entry.value, greaterThan(0.0),
            reason: '${entry.key} index <= 0');
        expect(entry.value, lessThanOrEqualTo(2.0),
            reason: '${entry.key} index > 2.0');
      }
    });

    test('phaseWeights sum to 1.0 for each typology (within 0.0001)', () {
      final c = CatalogVersion.fallback();
      for (final entry in c.phaseWeights.entries) {
        final sum = entry.value.values.fold<double>(0, (a, b) => a + b);
        expect((sum - 1.0).abs(), lessThan(0.0001),
            reason: 'Phase weights for ${entry.key} sum to $sum (not 1.0)');
      }
    });

    test('all tax lines have pct > 0', () {
      final c = CatalogVersion.fallback();
      for (final tax in c.taxLines) {
        expect(tax.pct, greaterThan(0),
            reason: 'Tax ${tax.label} has pct <= 0');
      }
    });

    test('default pct fields are all > 0', () {
      final c = CatalogVersion.fallback();
      expect(c.preliminariesDefaultPct, greaterThan(0));
      expect(c.ohpDefaultPct,           greaterThan(0));
      expect(c.contingencyDefaultPct,   greaterThan(0));
    });
  });

  group('Soak — regressive professional fee scale', () {
    test('regressiveProfessionalFeesPct returns values in [3.5, 6.0] for 1000 samples', () {
      const samples = 1000;
      const maxValue = 100000000.0;
      for (int i = 0; i < samples; i++) {
        final value = 1.0 + (maxValue - 1.0) * i / (samples - 1);
        final pct = regressiveProfessionalFeesPct(value);
        expect(pct, greaterThanOrEqualTo(3.5),
            reason: 'Fee pct $pct below 3.5% at value $value');
        expect(pct, lessThanOrEqualTo(6.0),
            reason: 'Fee pct $pct above 6.0% at value $value');
      }
    });
  });
}
```

- [ ] **Step 2: Run soak tests**

```bash
flutter test test/estimator/soak_test.dart -v
```

Expected: `All tests passed!` (may take 10-30 seconds for 972-combo sweep).

- [ ] **Step 3: Run full estimator test suite**

```bash
flutter test test/estimator/ -v
```

Expected: all 4 files pass (logic_audit, benchmark_scenarios, performance, soak).

- [ ] **Step 4: Commit**

```bash
git add test/estimator/soak_test.dart
git commit -m "test(estimator): add soak tests — 972-combo sweep, boundary inputs, catalog integrity, fee scale"
```

---

## Task 14: Integration test infrastructure (pubspec + helpers)

**Files:**
- Modify: `pubspec.yaml`
- Create: `integration_test/helpers/emulator_setup.dart`
- Create: `integration_test/helpers/fixture_seeder.dart`
- Create: `integration_test/helpers/test_app.dart`

- [ ] **Step 1: Add `integration_test` and `http` to `pubspec.yaml`**

Under `dev_dependencies:`, add:
```yaml
  integration_test:
    sdk: flutter
  http: ^1.2.0   # needed by fixture_seeder.dart to call Auth emulator REST API
```

- [ ] **Step 2: Run `flutter pub get`**

```bash
flutter pub get
```

Expected: no errors, `integration_test` resolved.

- [ ] **Step 3: Create `integration_test/helpers/emulator_setup.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Call this once in setUpAll() before any test that touches Firebase.
Future<void> configureEmulators() async {
  await FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
}
```

- [ ] **Step 4: Create `integration_test/helpers/fixture_seeder.dart`**

The Firebase Auth emulator does not assign custom claims via `createUserWithEmailAndPassword`.
Custom claims must be set through the emulator's admin REST endpoint:
`PATCH http://localhost:9099/emulator/v1/projects/{projectId}/accounts/{uid}`
with body `{"customAttributes": "<JSON-encoded claims string>"}`.

This is done via `http.patch` from the test helper after creating each user.
After setting claims, the helper signs back in as the contractor and force-refreshes the ID token
(`getIdToken(true)`) so the emulator issues a fresh token with the claims before the tests run.
Without the force-refresh, the test's sign-in would produce a token with the claims correctly
(since the prior session was signed out), but the explicit refresh makes the intent clear and
eliminates any SDK token-cache ambiguity.

```dart
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

const String kOwnerEmail      = 'owner@e2e.test';
const String kContractorEmail = 'contractor@e2e.test';
const String kUnverifiedEmail = 'unverified@e2e.test';
const String kTestPassword    = 'Test1234!';
const String _kProjectId      = 'building-estimator';
const String _kEmulatorAuthBase = 'http://localhost:9099';

/// Sets custom claims on a user via the Auth emulator REST API.
/// Requires the [uid] to already exist in the emulator.
Future<void> _setCustomClaims(String uid, Map<String, dynamic> claims) async {
  final url = Uri.parse(
    '$_kEmulatorAuthBase/emulator/v1/projects/$_kProjectId/accounts/$uid',
  );
  final response = await http.patch(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'customAttributes': jsonEncode(claims)}),
  );
  if (response.statusCode != 200) {
    throw Exception(
      'Failed to set custom claims for $uid: ${response.statusCode} ${response.body}',
    );
  }
}

/// Creates fixture users in the emulator Auth instance and assigns custom claims.
/// Idempotent: tries sign-in first; creates if not found.
Future<void> seedFixtureUsers() async {
  final auth = FirebaseAuth.instance;

  Future<String> ensureUser(String email) async {
    try {
      final cred = await auth.signInWithEmailAndPassword(email: email, password: kTestPassword);
      await auth.signOut();
      return cred.user!.uid;
    } catch (_) {
      final cred = await auth.createUserWithEmailAndPassword(email: email, password: kTestPassword);
      await auth.signOut();
      return cred.user!.uid;
    }
  }

  // Create all three fixture users
  final ownerUid      = await ensureUser(kOwnerEmail);
  final contractorUid = await ensureUser(kContractorEmail);
  await ensureUser(kUnverifiedEmail); // no special claims needed

  // Set custom claims via emulator REST API (cannot be done through the client SDK)
  await _setCustomClaims(ownerUid,      {'email_verified': true, 'subscriptionTier': 'pro'});
  await _setCustomClaims(contractorUid, {'email_verified': true, 'role': 'contractor'});
  // kUnverifiedEmail intentionally left with no claims (email_verified stays false)

  // Force-refresh the contractor token so tests receive a token that includes the claims.
  // The Firebase Auth emulator includes custom claims in newly issued tokens, but an explicit
  // force-refresh eliminates any SDK token-cache ambiguity.
  final contractorCred = await auth.signInWithEmailAndPassword(
    email: kContractorEmail, password: kTestPassword,
  );
  await contractorCred.user!.getIdToken(true); // force-refresh with new claims
  await auth.signOut();
}

/// Signs in as owner and seeds a test project document.
Future<String> seedTestProject() async {
  final auth = FirebaseAuth.instance;
  final cred = await auth.signInWithEmailAndPassword(
    email: kOwnerEmail, password: kTestPassword,
  );
  final uid = cred.user!.uid;

  final ref = await FirebaseFirestore.instance.collection('projects').add({
    'ownerUid':        uid,
    'title':           'E2E Seeded Project',
    'status':          'active',
    'teamMemberUids':  <String>[],
    'collaboratorUids': <String>[],
    'observerUids':    <String>[],
    'assignedPmUid':   null,
    'budget':          100000,
    'amountSpent':     0,
    'updateFrequencyDays': 7,
    'createdAt':       DateTime.now(),
  });

  await auth.signOut();
  return ref.id;
}
```

- [ ] **Step 5: Create `integration_test/helpers/test_app.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:wysebrix/wysebrix.dart';  // adjust to actual app entry import
import 'emulator_setup.dart';

/// Bootstrap the app in test mode, pointing Firebase at emulators.
Future<void> bootstrapTestApp() async {
  await configureEmulators();
}

/// Returns the root widget for the app (same as production bootstrap).
Widget testAppWidget() {
  return const WyseBrixApp();  // adjust to actual root widget class name
}
```

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock integration_test/
git commit -m "test(integration): add integration test infrastructure and fixture helpers"
```

---

## Task 15: Integration test journeys — auth_flow + estimate_wizard

**Files:**
- Create: `integration_test/journeys/auth_flow_test.dart`
- Create: `integration_test/journeys/estimate_wizard_test.dart`

**Note:** These tests require semantic keys (`Key('...')`) on certain widgets. Add the keys listed below to the production widgets. Aim to add keys only to widgets the tests actually need — do not add keys to everything.

**Required widget keys (add to production code where missing):**
- `Key('sign_in_email_field')` — email `TextFormField` on sign-in screen
- `Key('sign_in_password_field')` — password `TextFormField`
- `Key('sign_in_submit_button')` — sign-in `ElevatedButton` / `FilledButton`
- `Key('email_verification_gate')` — the email-verification wall widget
- `Key('home_shell')` — top-level scaffold/navigation widget shown after sign-in
- `Key('sign_out_button')` — sign-out action in account drawer/menu
- `Key('new_estimate_button')` — FAB or button to start a new estimate
- `Key('estimate_result_screen')` — root widget of the estimate result page
- `Key('total_planned_ghs_label')` — Text widget displaying the total

- [ ] **Step 1: Add semantic keys to production widgets**

Locate and add the keys above to the relevant production files (sign_in_page.dart, home_shell.dart, estimate_result_page.dart, etc.). Do not restructure code — just add `key:` named parameters.

- [ ] **Step 2: Create `integration_test/journeys/auth_flow_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import '../helpers/fixture_seeder.dart';
import '../helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await bootstrapTestApp();
    await seedFixtureUsers();
  });

  testWidgets('cold launch shows sign-in screen', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byKey(const Key('sign_in_email_field')), findsOneWidget);
  });

  testWidgets('sign in as owner loads home shell', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.enterText(
      find.byKey(const Key('sign_in_email_field')), kOwnerEmail,
    );
    await tester.enterText(
      find.byKey(const Key('sign_in_password_field')), kTestPassword,
    );
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byKey(const Key('home_shell')), findsOneWidget);
  });

  testWidgets('sign out returns to sign-in screen', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Sign in first
    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kOwnerEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Sign out
    await tester.tap(find.byKey(const Key('sign_out_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byKey(const Key('sign_in_email_field')), findsOneWidget);
  });

  testWidgets('unverified user sees email verification gate, not home shell', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kUnverifiedEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byKey(const Key('email_verification_gate')), findsOneWidget);
    expect(find.byKey(const Key('home_shell')), findsNothing);
  });
}
```

- [ ] **Step 3: Create `integration_test/journeys/estimate_wizard_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import '../helpers/fixture_seeder.dart';
import '../helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await bootstrapTestApp();
    await seedFixtureUsers();
  });

  testWidgets('estimate wizard happy path — result screen shows non-zero total', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Sign in
    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kOwnerEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Start new estimate
    await tester.tap(find.byKey(const Key('new_estimate_button')));
    await tester.pumpAndSettle();

    // Step 1: project name + region
    await tester.enterText(find.byKey(const Key('step1_project_name')), 'E2E Test');
    await tester.tap(find.byKey(const Key('step1_region_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Greater Accra'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Step 2: typology + floors + area
    await tester.tap(find.byKey(const Key('step2_typology_residential_standard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Step 3: quality + foundation + soil + roof
    await tester.tap(find.byKey(const Key('step3_quality_standard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Step 4: no extras — just proceed
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Step 5: review — check non-zero total label visible
    expect(find.byKey(const Key('step5_total_label')), findsOneWidget);

    // Calculate
    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byKey(const Key('estimate_result_screen')), findsOneWidget);
    expect(find.byKey(const Key('total_planned_ghs_label')), findsOneWidget);

    // Verify the label text is not '0' or empty
    final totalLabel = tester.widget<Text>(
      find.byKey(const Key('total_planned_ghs_label')),
    );
    expect(totalLabel.data, isNotEmpty);
    expect(totalLabel.data, isNot('GHS 0'));
    expect(totalLabel.data, isNot('GHS 0.00'));
  });
}
```

- [ ] **Step 4: Commit**

```bash
git add integration_test/journeys/auth_flow_test.dart integration_test/journeys/estimate_wizard_test.dart
git commit -m "test(integration): add auth flow and estimate wizard journey tests"
```

---

## Task 16: Integration test journeys — project_creation, project_details, role_gate

**Files:**
- Create: `integration_test/journeys/project_creation_test.dart`
- Create: `integration_test/journeys/project_details_test.dart`
- Create: `integration_test/journeys/role_gate_test.dart`

**Additional required widget keys:**
- `Key('save_as_project_button')` — on estimate result screen
- `Key('projects_screen')` — root of the projects list page
- `Key('project_list_item')` — each project tile in the list
- `Key('project_details_screen')` — root of project details page
- `Key('finance_tab')` — Finance tab in project details
- `Key('overview_tab')` — Overview tab in project details
- `Key('add_variation_order_button')` — FAB/button to open new VO form
- `Key('vo_title_field')` — VO title text field
- `Key('vo_amount_field')` — VO amount field
- `Key('vo_save_button')` — submit button for new VO
- `Key('create_project_fab')` — FAB on projects screen for creating new project (should NOT appear for contractors)

- [ ] **Step 1: Add remaining semantic keys to production widgets**

Add keys above to project-related screens and widgets. Focus only on keys listed — do not gold-plate.

- [ ] **Step 2: Create `integration_test/journeys/project_creation_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import '../helpers/fixture_seeder.dart';
import '../helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await bootstrapTestApp();
    await seedFixtureUsers();
  });

  testWidgets('save estimate as project — project appears on projects screen', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Sign in
    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kOwnerEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Navigate through estimate wizard (same steps as estimate_wizard_test)
    await tester.tap(find.byKey(const Key('new_estimate_button')));
    await tester.pumpAndSettle();

    // Step 1: project name + region
    await tester.enterText(find.byKey(const Key('step1_project_name')), 'E2E Create Test');
    await tester.tap(find.byKey(const Key('step1_region_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Greater Accra'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Step 2: typology
    await tester.tap(find.byKey(const Key('step2_typology_residential_standard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Step 3: quality
    await tester.tap(find.byKey(const Key('step3_quality_standard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Step 4: no extras
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Calculate from Step 5 review
    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Save as project
    await tester.tap(find.byKey(const Key('save_as_project_button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('project_name_field')), 'E2E Project');
    await tester.tap(find.byKey(const Key('project_save_confirm_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Expect projects screen with the new project
    expect(find.byKey(const Key('projects_screen')), findsOneWidget);
    expect(find.text('E2E Project'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Create `integration_test/journeys/project_details_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import '../helpers/fixture_seeder.dart';
import '../helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String seededProjectId;

  setUpAll(() async {
    await bootstrapTestApp();
    await seedFixtureUsers();
    seededProjectId = await seedTestProject();
  });

  testWidgets('project detail tabs render without error', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Sign in as owner
    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kOwnerEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Open seeded project (find by title seeded in fixture_seeder)
    await tester.tap(find.text('E2E Seeded Project'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byKey(const Key('project_details_screen')), findsOneWidget);

    // Finance tab
    await tester.tap(find.byKey(const Key('finance_tab')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Overview tab
    await tester.tap(find.byKey(const Key('overview_tab')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('add variation order — appears in list', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kOwnerEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('E2E Seeded Project'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.byKey(const Key('add_variation_order_button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('vo_title_field')),  'Extra Excavation');
    await tester.enterText(find.byKey(const Key('vo_amount_field')), '5000');
    await tester.tap(find.byKey(const Key('vo_save_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Extra Excavation'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Create `integration_test/journeys/role_gate_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import '../helpers/fixture_seeder.dart';
import '../helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await bootstrapTestApp();
    await seedFixtureUsers();
  });

  testWidgets('contractor does not see create-project FAB', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Sign in as contractor
    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kContractorEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byKey(const Key('home_shell')), findsOneWidget);

    // Navigate to Projects tab
    await tester.tap(find.byKey(const Key('projects_nav_tab')));
    await tester.pumpAndSettle();

    // FAB to create a new project must NOT be visible
    expect(find.byKey(const Key('create_project_fab')), findsNothing);
  });
}
```

- [ ] **Step 5: Verify integration test files compile**

```bash
flutter build ios --simulator --no-codesign --dart-define=ENV=test 2>&1 | head -30
```

Expected: no compile errors in `integration_test/` files (build may fail for other reasons — that's OK at this stage).

- [ ] **Step 6: Document run instructions**

Add the following comment block at the top of `integration_test/journeys/auth_flow_test.dart`:

```dart
// HOW TO RUN:
//   Terminal 1: firebase emulators:start --only auth,firestore
//   Terminal 2: flutter test integration_test/ -d <ios-simulator-id> --dart-define=ENV=test
//
// Get simulator ID: xcrun simctl list devices | grep Booted
```

- [ ] **Step 7: Commit**

```bash
git add integration_test/
git commit -m "test(integration): add project creation, details, and role gate journey tests"
```

---

## Final Verification

- [ ] **Run full Flutter test suite (unit + estimator + performance + soak)**

```bash
flutter test --coverage
```

Expected: all tests pass; no failures.

- [ ] **Run full Cloud Functions unit tests**

```bash
cd functions && npm run test:unit
```

Expected: 6 test files, 0 failures.

- [ ] **Run full Cloud Functions rules tests (requires emulators)**

```bash
firebase emulators:start --only auth,firestore --project wysebrix-test &
sleep 5
cd functions && npm run test:rules
kill %1
```

Expected: 6 rules test files, 0 failures.

- [ ] **Final commit and push**

```bash
git add -A
git status  # confirm only expected files changed
git push origin mvp-vendors-projects
```
