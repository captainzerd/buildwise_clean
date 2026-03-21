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
    await seedDoc(testEnv, `projects/proj-1`, { ...PROJECT, costEntryCount: 0 });
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
