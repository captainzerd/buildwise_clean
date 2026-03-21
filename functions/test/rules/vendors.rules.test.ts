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
