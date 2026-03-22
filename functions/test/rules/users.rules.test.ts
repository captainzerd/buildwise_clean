import {
  RulesTestEnvironment,
  createTestEnv,
  authedDb, unauthDb,
  assertFails, assertSucceeds,
  UIDS, CLAIMS,
  seedDoc,
  clearFirestore,
} from './helpers';

let testEnv: RulesTestEnvironment;

beforeAll(async () => { testEnv = await createTestEnv(); });
afterAll(async ()  => { await testEnv.cleanup(); });
afterEach(async () => { await clearFirestore(testEnv); });

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
