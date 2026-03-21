const mockCreate = jest.fn();

jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockCreate },
  }));
});

jest.mock('firebase-functions/params', () => ({
  defineSecret: jest.fn().mockReturnValue({
    value: jest.fn().mockReturnValue('fake-api-key'),
  }),
}));

const HttpsErrorMock = class extends Error {
  code: string;
  constructor(code: string, message: string) { super(message); this.code = code; }
};

let capturedHandler: Function;
jest.mock('firebase-functions/v2/https', () => ({
  onCall: jest.fn((_opts: unknown, handler: Function) => {
    capturedHandler = handler;
    return { run: handler };
  }),
  HttpsError: HttpsErrorMock,
}));

jest.mock('firebase-functions', () => ({
  logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

import '../../src/aiCostOptimiser';

const VALID_INPUT = {
  typology: 'Residential Standard',
  quality: 'Standard',
  region: 'Greater Accra',
  floorAreaM2: 150,
  floors: 2,
  totalGhs: 800000,
  breakdownGhs: { Superstructure: 400000, Finishes: 200000 },
  preliminariesPct: 8,
  ohpPct: 15,
  contingencyPct: 5,
};

const VALID_AI_RESPONSE = JSON.stringify({
  headline: 'Save 12% with material substitution',
  suggestions: [
    { title: 'Use hollow blocks', description: 'Cheaper than burnt brick', potentialSavingPct: 5, category: 'Masonry' },
    { title: 'Pre-fab roof', description: 'Faster than cast-in-place', potentialSavingPct: 7, category: 'Roofing' },
  ],
});

function makeRequest(data: Record<string, unknown>, authenticated = true) {
  return {
    auth: authenticated ? { uid: 'uid-1' } : null,
    data,
  };
}

describe('analyseEstimateCosts', () => {
  beforeEach(() => {
    mockCreate.mockClear();
    mockCreate.mockResolvedValue({
      content: [{ type: 'text', text: VALID_AI_RESPONSE }],
    });
  });

  it('unauthenticated call throws HttpsError unauthenticated', async () => {
    await expect(capturedHandler(makeRequest(VALID_INPUT, false)))
      .rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('missing totalGhs throws invalid-argument', async () => {
    const { totalGhs: _, ...noTotal } = VALID_INPUT;
    await expect(capturedHandler(makeRequest(noTotal)))
      .rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('totalGhs <= 0 throws invalid-argument', async () => {
    await expect(capturedHandler(makeRequest({ ...VALID_INPUT, totalGhs: 0 })))
      .rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('valid input returns headline string and suggestions array', async () => {
    const result = await capturedHandler(makeRequest(VALID_INPUT)) as Record<string, unknown>;
    expect(typeof result.headline).toBe('string');
    expect(result.headline).not.toBe('');
    expect(Array.isArray(result.suggestions)).toBe(true);
  });

  it('each suggestion has required fields', async () => {
    const result = await capturedHandler(makeRequest(VALID_INPUT)) as Record<string, unknown>;
    const suggestions = result.suggestions as Array<Record<string, unknown>>;
    for (const s of suggestions) {
      expect(s).toHaveProperty('title');
      expect(s).toHaveProperty('description');
      expect(s).toHaveProperty('potentialSavingPct');
      expect(s).toHaveProperty('category');
    }
  });

  it('malformed AI response (non-JSON) throws HttpsError internal', async () => {
    mockCreate.mockResolvedValue({
      content: [{ type: 'text', text: 'NOT VALID JSON !!!!' }],
    });
    await expect(capturedHandler(makeRequest(VALID_INPUT)))
      .rejects.toMatchObject({ code: 'internal' });
  });
});
