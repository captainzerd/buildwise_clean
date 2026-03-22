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
