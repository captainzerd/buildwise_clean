const mockSet = jest.fn().mockResolvedValue(undefined);
const mockRef: any = {};
mockRef.collection = jest.fn().mockReturnValue(mockRef);
mockRef.doc        = jest.fn().mockReturnValue(mockRef);
mockRef.set        = mockSet;

jest.mock('firebase-admin', () => {
  const fsModule: any = jest.fn().mockReturnValue(mockRef);
  fsModule.FieldValue = { serverTimestamp: jest.fn().mockReturnValue('SERVER_TS') };
  return { firestore: fsModule, initializeApp: jest.fn(), apps: ['app'] };
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

import '../../src/marketPricesUpdater';

describe('refreshMarketPrices', () => {
  beforeEach(() => {
    mockSet.mockClear();
    mockRef.collection = jest.fn().mockReturnValue(mockRef);
    mockRef.doc        = jest.fn().mockReturnValue(mockRef);
    mockRef.set        = mockSet;
  });

  it('writes to market_prices/ghana_current', async () => {
    await capturedHandler();
    expect(mockRef.collection).toHaveBeenCalledWith('market_prices');
    expect(mockRef.doc).toHaveBeenCalledWith('ghana_current');
    expect(mockSet).toHaveBeenCalledTimes(1);
  });

  it('written document has updatedAt, currency, and items fields', async () => {
    await capturedHandler();
    const written = mockSet.mock.calls[0][0] as Record<string, unknown>;
    expect(written).toHaveProperty('updatedAt');
    expect(written).toHaveProperty('currency', 'GHS');
    expect(written).toHaveProperty('items');
    expect(Array.isArray(written.items)).toBe(true);
    expect((written.items as unknown[]).length).toBeGreaterThan(0);
  });

  it('each item has name, unit, and priceGhs fields', async () => {
    await capturedHandler();
    const written = mockSet.mock.calls[0][0] as Record<string, unknown>;
    const items = written.items as Array<Record<string, unknown>>;
    for (const item of items) {
      expect(item).toHaveProperty('name');
      expect(item).toHaveProperty('unit');
      expect(item).toHaveProperty('priceGhs');
    }
  });

  it('is idempotent — calling twice uses set() (overwrite, not append)', async () => {
    await capturedHandler();
    await capturedHandler();
    // Both calls write to the same doc — each is a full set(), not add()
    expect(mockSet).toHaveBeenCalledTimes(2);
  });
});
