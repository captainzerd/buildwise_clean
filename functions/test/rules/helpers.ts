import * as fs from 'fs';
import * as path from 'path';
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';

export { assertFails, assertSucceeds, RulesTestEnvironment };

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
    let ref: any = ctx.firestore().collection(parts[0]).doc(parts[1]);
    for (let i = 2; i < parts.length; i += 2) {
      ref = ref.collection(parts[i]).doc(parts[i + 1]);
    }
    await ref.set(data);
  });
}

// Clear all Firestore data (for use in afterEach hooks)
export async function clearFirestore(testEnv: RulesTestEnvironment): Promise<void> {
  await testEnv.clearFirestore();
}
