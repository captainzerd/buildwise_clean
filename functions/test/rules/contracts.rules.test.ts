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
