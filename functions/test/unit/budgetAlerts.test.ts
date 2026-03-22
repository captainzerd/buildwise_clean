// Mocks must be declared before importing the module under test.
// Variables prefixed with 'mock' are hoisted by babel-jest with jest.mock().

const mockAdd    = jest.fn().mockResolvedValue({ id: 'notif-1' });
const mockGet    = jest.fn();
const mockUpdate = jest.fn().mockResolvedValue(undefined);

// Chainable Firestore ref mock — every collection/doc call returns the same ref
const mockRef: any = { add: mockAdd, get: mockGet, update: mockUpdate };
mockRef.collection = jest.fn().mockReturnValue(mockRef);
mockRef.doc        = jest.fn().mockReturnValue(mockRef);

jest.mock('firebase-admin', () => {
  const fsModule: any = jest.fn().mockReturnValue(mockRef);
  fsModule.FieldValue = { serverTimestamp: jest.fn().mockReturnValue('SERVER_TS') };
  return { firestore: fsModule, initializeApp: jest.fn(), apps: ['app'] };
});

jest.mock('firebase-functions', () => ({
  logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

// Capture the handler registered with onDocumentUpdated
let capturedHandler: Function;
jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentUpdated: jest.fn((_opts: unknown, handler: Function) => {
    capturedHandler = handler;
    return { run: handler };
  }),
}));

// Now import the module — handler is registered during import
import '../../src/budgetAlerts';

// Helper to build a minimal trigger event
function makeEvent(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
  projectId = 'proj-1',
) {
  return {
    params: { projectId },
    data: {
      before: { data: () => before },
      after:  { data: () => after  },
    },
  };
}

// Helper to mock phase snapshot
function mockPhaseSnap(total: number, completed: number) {
  const docs = Array.from({ length: total }, (_, i) => ({
    data: () => ({ status: i < completed ? 'completed' : 'pending' }),
  }));
  mockGet.mockResolvedValue({ size: total, empty: total === 0, docs });
}

describe('budgetAlerts', () => {
  beforeEach(() => {
    mockAdd.mockClear();
    mockGet.mockClear();
    jest.clearAllMocks();
    // Re-apply the mockRef circular references after clearAllMocks resets them
    mockRef.collection = jest.fn().mockReturnValue(mockRef);
    mockRef.doc        = jest.fn().mockReturnValue(mockRef);
    mockRef.add        = mockAdd;
    mockRef.get        = mockGet;
  });

  it('no notification when amountSpent did not change', async () => {
    await capturedHandler(makeEvent(
      { amountSpent: 5000 },
      { amountSpent: 5000, budget: 10000, ownerUid: 'uid-1', title: 'T' },
    ));
    expect(mockAdd).not.toHaveBeenCalled();
  });

  it('no notification when budget is missing', async () => {
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 9000, ownerUid: 'uid-1', title: 'T' }, // no budget field
    ));
    expect(mockAdd).not.toHaveBeenCalled();
  });

  it('no notification when ownerUid is missing', async () => {
    mockPhaseSnap(0, 0);
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 9500, budget: 10000, title: 'T' }, // no ownerUid
    ));
    expect(mockAdd).not.toHaveBeenCalled();
  });

  it('critical alert when spendPct >= 90', async () => {
    mockPhaseSnap(4, 2); // 50% completion — irrelevant for critical
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 9200, budget: 10000, ownerUid: 'uid-1', title: 'Proj' },
    ));
    expect(mockAdd).toHaveBeenCalledWith(
      expect.objectContaining({ severity: 'critical' }),
    );
  });

  it('high alert when spendPct=75 and completionPct<50', async () => {
    mockPhaseSnap(10, 3); // 30% completion < 50
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 7500, budget: 10000, ownerUid: 'uid-1', title: 'Proj' },
    ));
    expect(mockAdd).toHaveBeenCalledWith(
      expect.objectContaining({ severity: 'high' }),
    );
  });

  it('no alert when spendPct=75 and completionPct>=50', async () => {
    mockPhaseSnap(10, 6); // 60% completion >= 50
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 7500, budget: 10000, ownerUid: 'uid-1', title: 'Proj' },
    ));
    expect(mockAdd).not.toHaveBeenCalled();
  });

  it('medium alert when spendPct=50 and completionPct<30', async () => {
    mockPhaseSnap(10, 2); // 20% completion < 30
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 5000, budget: 10000, ownerUid: 'uid-1', title: 'Proj' },
    ));
    expect(mockAdd).toHaveBeenCalledWith(
      expect.objectContaining({ severity: 'medium' }),
    );
  });

  it('no alert when spendPct=50 and completionPct>=30', async () => {
    mockPhaseSnap(10, 4); // 40% completion >= 30
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 5000, budget: 10000, ownerUid: 'uid-1', title: 'Proj' },
    ));
    expect(mockAdd).not.toHaveBeenCalled();
  });

  it('no alert when spendPct=40', async () => {
    mockPhaseSnap(10, 0);
    await capturedHandler(makeEvent(
      { amountSpent: 0 },
      { amountSpent: 4000, budget: 10000, ownerUid: 'uid-1', title: 'Proj' },
    ));
    expect(mockAdd).not.toHaveBeenCalled();
  });
});
