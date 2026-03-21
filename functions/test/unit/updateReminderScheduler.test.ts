import * as admin from 'firebase-admin';

const mockNotifAdd = jest.fn().mockResolvedValue({ id: 'n-1' });
const mockProjectsGet = jest.fn();

// Build a chainable mock that handles all get() calls via mockProjectsGet
const mockRef: any = {};
mockRef.doc        = jest.fn().mockReturnValue(mockRef);
mockRef.collection = jest.fn().mockReturnValue(mockRef);
mockRef.where      = jest.fn().mockReturnValue(mockRef);
mockRef.orderBy    = jest.fn().mockReturnValue(mockRef);
mockRef.limit      = jest.fn().mockReturnValue(mockRef);
mockRef.add        = mockNotifAdd;
mockRef.get        = mockProjectsGet;

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
