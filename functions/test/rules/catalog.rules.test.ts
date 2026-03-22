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
