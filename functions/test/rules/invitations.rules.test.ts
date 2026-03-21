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

  it('unverified user cannot create invitation', async () => {
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
