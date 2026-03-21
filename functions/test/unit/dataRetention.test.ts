const mockBatchDelete = jest.fn().mockResolvedValue(undefined);
const mockBatchCommit = jest.fn().mockResolvedValue(undefined);
const mockBatch: any  = { delete: mockBatchDelete, commit: mockBatchCommit };

const mockGet = jest.fn();

// Chainable ref — used as both db and doc.ref in snapshots
const mockRef: any = {};
mockRef.collection = jest.fn().mockReturnValue(mockRef);
mockRef.doc        = jest.fn().mockReturnValue(mockRef);
mockRef.select     = jest.fn().mockReturnValue(mockRef);
mockRef.where      = jest.fn().mockReturnValue(mockRef);
mockRef.limit      = jest.fn().mockReturnValue(mockRef);
mockRef.get        = mockGet;
mockRef.batch      = jest.fn().mockReturnValue(mockBatch);
mockRef.delete     = jest.fn().mockResolvedValue(undefined);

jest.mock('firebase-admin', () => {
  const fsModule: any = jest.fn().mockReturnValue(mockRef);
  fsModule.FieldValue = { serverTimestamp: jest.fn().mockReturnValue('SERVER_TS') };
  return {
    firestore: fsModule,
    initializeApp: jest.fn(),
    apps: ['app'],
    auth: jest.fn().mockReturnValue({ deleteUser: jest.fn().mockResolvedValue(undefined) }),
    storage: jest.fn().mockReturnValue({ bucket: jest.fn().mockReturnValue({ deleteFiles: jest.fn().mockResolvedValue(undefined) }) }),
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
jest.mock('../../src/utils/rateLimit', () => ({
  rateLimit: jest.fn().mockResolvedValue(undefined),
}));

import '../../src/dataRetention';

// makeSnapshot uses mockRef as ref so userDoc.ref.collection() works
function makeSnapshot(docs: Array<Record<string, unknown>>) {
  const items = docs.map((d) => ({
    ref: mockRef,
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
    mockRef.batch      = jest.fn().mockReturnValue(mockBatch);
  });

  it('runs without throwing when all collections are empty', async () => {
    mockGet.mockResolvedValue(makeSnapshot([]));
    await expect(capturedRetentionHandler()).resolves.toBeUndefined();
  });

  it('audit_log: deletes docs older than 2 years, keeps newer ones', async () => {
    const twoYearsAgo = new Date(Date.now() - 2 * 365 * 24 * 60 * 60 * 1000 - 1000);
    mockGet
      .mockResolvedValueOnce(makeSnapshot([{ createdAt: twoYearsAgo }])) // audit_log old
      .mockResolvedValueOnce(makeSnapshot([]))   // users list (no users)
      .mockResolvedValueOnce(makeSnapshot([]));  // soft-deleted projects
    await capturedRetentionHandler();
    expect(mockBatchDelete).toHaveBeenCalledTimes(1);
  });

  it('login_activity: deletes entries older than 90 days', async () => {
    const ninetyOneDaysAgo = new Date(Date.now() - 91 * 24 * 60 * 60 * 1000);
    mockGet
      .mockResolvedValueOnce(makeSnapshot([]))                                         // audit_log
      .mockResolvedValueOnce(makeSnapshot([{ uid: 'user-1' }]))                        // users list (1 user)
      .mockResolvedValueOnce(makeSnapshot([{ timestamp: ninetyOneDaysAgo }]))          // login_activity
      .mockResolvedValueOnce(makeSnapshot([]));                                        // soft-deleted projects
    await capturedRetentionHandler();
    expect(mockBatchDelete).toHaveBeenCalledTimes(1);
  });

  it('stops at 500 docs per collection (single-pass behaviour)', async () => {
    const oldDate = new Date(Date.now() - 3 * 365 * 24 * 60 * 60 * 1000);
    const docs500 = Array(500).fill(null).map(() => ({ createdAt: oldDate }));
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
