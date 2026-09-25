// v584 (révision PawMap du 25/09) — ÉTAT VRAI du suivi en direct.
// Daniel : des positions d'amis vieilles d'une semaine s'affichaient « en
// direct ». Règle : « en direct » = partage ACTIF et signe de vie < 2 min ;
// « signal perdu » = partage actif, 2 à 10 min ; sinon « vu il y a X ».
//   1. la règle pure (utils/liveState) ;
//   2. le VRAI gestionnaire GET /friends/live-positions (modèles simulés,
//      zone fictive lat -35 / lng -30) : un ami qui partage depuis 30 s est
//      `live`, un ami qui partage mais muet depuis 5 min est `lost`, un ami
//      dont la position date d'une semaine sans partage n'est PAS renvoyé,
//      un ami dont le profil a bougé il y a 1 h SANS partage n'est PAS
//      renvoyé (sa position de profil floutée suffit), un ami qui a coupé
//      son partage non plus (Daniel, 25/09 : « on ne peut pas garder la
//      vieille position »).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const { liveState, LIVE_FRESH_MS, LIVE_LOST_MS } = require('../src/utils/liveState');

const mockNow = Date.parse('2026-09-25T08:00:00Z');
const NOW = mockNow;
const ago = (ms) => new Date(NOW - ms);
const LAT = -35.2;
const LNG = -30.4;

describe('liveState — règle pure', () => {
  test('partage actif et < 2 min → live', () => {
    expect(liveState({ sharing: true, lastSeenAt: ago(30 * 1000), now: NOW })).toBe('live');
    expect(liveState({ sharing: true, lastSeenAt: ago(LIVE_FRESH_MS), now: NOW })).toBe('live');
  });
  test('partage actif, 2 à 10 min → lost (signal perdu)', () => {
    expect(liveState({ sharing: true, lastSeenAt: ago(LIVE_FRESH_MS + 1), now: NOW })).toBe('lost');
    expect(liveState({ sharing: true, lastSeenAt: ago(5 * 60 * 1000), now: NOW })).toBe('lost');
    expect(liveState({ sharing: true, lastSeenAt: ago(LIVE_LOST_MS), now: NOW })).toBe('lost');
  });
  test('plus de 10 min, ou pas de partage → seen (rien de « direct »)', () => {
    expect(liveState({ sharing: true, lastSeenAt: ago(LIVE_LOST_MS + 1), now: NOW })).toBe('seen');
    expect(liveState({ sharing: false, lastSeenAt: ago(10 * 1000), now: NOW })).toBe('seen');
    expect(liveState({ sharing: true, lastSeenAt: null, now: NOW })).toBe('seen');
    expect(liveState({ sharing: false, lastSeenAt: ago(7 * 24 * 3600 * 1000), now: NOW })).toBe('seen');
  });
});

// ── la vraie route ────────────────────────────────────────────────────────
const DOCS = {
  Owner: [
    { _id: 'me1', email: 'me@example.test', name: 'Moi', location: { type: 'Point', coordinates: [LNG, LAT] } },
  ],
  Walker: [
    // partage actif (session RAM) — position à l'instant
    { _id: 'walkLive', email: 'live@example.test', name: 'Live', location: { type: 'Point', coordinates: [LNG + 0.01, LAT], updatedAt: ago(30 * 1000), liveShareActive: true } },
    // partage actif mais muet depuis 5 min
    { _id: 'walkLost', email: 'lost@example.test', name: 'Perdu', location: { type: 'Point', coordinates: [LNG + 0.02, LAT], updatedAt: ago(5 * 60 * 1000), liveShareActive: true } },
    // profil rafraîchi il y a 1 h, AUCUN partage
    { _id: 'walkSeen', email: 'seen@example.test', name: 'Vu', location: { type: 'Point', coordinates: [LNG + 0.03, LAT], updatedAt: ago(60 * 60 * 1000) } },
    // partage coupé (drapeau false), position d'il y a 20 min
    { _id: 'walkOff', email: 'off@example.test', name: 'Coupé', location: { type: 'Point', coordinates: [LNG + 0.04, LAT], updatedAt: ago(20 * 60 * 1000), liveShareActive: false } },
    // position d'il y a une semaine, aucun partage
    { _id: 'walkOld', email: 'old@example.test', name: 'Vieux', location: { type: 'Point', coordinates: [LNG + 0.05, LAT], updatedAt: ago(6 * 24 * 3600 * 1000) } },
  ],
  Sitter: [],
};
const chain = (result) => {
  const c = { select: () => c, limit: () => c, sort: () => c, lean: () => Promise.resolve(result), then: (ok, ko) => Promise.resolve(result).then(ok, ko), catch: () => c };
  return c;
};
const mockModel = (name) => ({
  find: jest.fn(() => chain(DOCS[name].map((d) => ({ ...d })))),
  findById: jest.fn((id) => chain(DOCS[name].find((d) => String(d._id) === String(id)) || null)),
  exists: jest.fn(() => Promise.resolve(false)),
});
jest.mock('../src/models/Owner', () => mockModel('Owner'));
jest.mock('../src/models/Sitter', () => mockModel('Sitter'));
jest.mock('../src/models/Walker', () => mockModel('Walker'));
jest.mock('../src/models/UserSubscription', () => ({
  find: jest.fn(() => chain([])),
  findOne: jest.fn(() => chain(null)),
  hasActivePawFollow: jest.fn(() => Promise.resolve(false)),
}));
jest.mock('../src/models/Friendship', () => ({
  find: jest.fn(() => chain([
    { requesterId: 'me1', requesterModel: 'Owner', addresseeId: 'walkLive', addresseeModel: 'Walker', status: 'accepted', addresseeSharesPosition: true },
    { requesterId: 'me1', requesterModel: 'Owner', addresseeId: 'walkLost', addresseeModel: 'Walker', status: 'accepted', addresseeSharesPosition: true },
    { requesterId: 'me1', requesterModel: 'Owner', addresseeId: 'walkSeen', addresseeModel: 'Walker', status: 'accepted', addresseeSharesPosition: true },
    { requesterId: 'me1', requesterModel: 'Owner', addresseeId: 'walkOff', addresseeModel: 'Walker', status: 'accepted', addresseeSharesPosition: true },
    { requesterId: 'me1', requesterModel: 'Owner', addresseeId: 'walkOld', addresseeModel: 'Walker', status: 'accepted', addresseeSharesPosition: true },
  ])),
}));
jest.mock('../src/utils/identityGroup', () => ({
  identityGroup: jest.fn((id) => Promise.resolve({ ids: [String(id)], set: new Set([String(id)]), docs: [] })),
}));
jest.mock('../src/utils/personScope', () => ({
  personIds: jest.fn((id) => Promise.resolve([String(id)])),
  personIndex: jest.fn((ids) => Promise.resolve(new Map(ids.map((i) => [String(i), { ids: [String(i)], set: new Set([String(i)]), docs: [{ id: String(i), model: 'Walker' }] }])))),
}));
// Sessions RAM : seuls « Live » et « Perdu » ont une session (ils partagent).
jest.mock('../src/sockets/mapSocket', () => ({
  LIVE_STALE_MS: 3 * 60 * 1000,
  getLiveSessionForIds: jest.fn((ids) => {
    const S = {
      walkLive: { userId: 'walkLive', lat: -35.2, lng: -30.39, city: '', at: mockNow - 30 * 1000, lastSeenAt: mockNow - 30 * 1000 },
      walkLost: { userId: 'walkLost', lat: -35.2, lng: -30.38, city: '', at: mockNow - 5 * 60 * 1000, lastSeenAt: mockNow - 5 * 60 * 1000 },
    };
    for (const id of ids) if (S[id]) return S[id];
    return null;
  }),
  getLiveSession: jest.fn(() => null),
  describeLiveSession: jest.fn(() => null),
  relayLivePosition: jest.fn(() => Promise.resolve(0)),
}));

const router = require('../src/routes/friendRoutes');
function handler(path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path);
  if (!layer) throw new Error(`route ${path} introuvable`);
  return layer.route.stack[layer.route.stack.length - 1].handle;
}
function call(fn, user, query = {}) {
  return new Promise((resolve, reject) => {
    const req = { user, query, headers: {} };
    const res = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json(body) { resolve({ status: this.statusCode, body }); } };
    fn(req, res).catch(reject);
  });
}

describe('GET /friends/live-positions — états vrais', () => {
  let byId;
  beforeAll(async () => {
    jest.spyOn(Date, 'now').mockReturnValue(NOW);
    const r = await call(handler('/live-positions'), { id: 'me1', role: 'owner' });
    expect(r.status).toBe(200);
    byId = Object.fromEntries(r.body.positions.map((p) => [p.userId, p]));
  });
  afterAll(() => { Date.now.mockRestore(); });

  test('ami qui partage depuis 30 s → live', () => {
    expect(byId.walkLive).toBeDefined();
    expect(byId.walkLive.sharing).toBe(true);
    expect(byId.walkLive.state).toBe('live');
    expect(byId.walkLive.live).toBe(true);
    expect(byId.walkLive.stale).toBe(false);
  });
  test('ami qui partage mais muet depuis 5 min → lost, jamais live', () => {
    expect(byId.walkLost.sharing).toBe(true);
    expect(byId.walkLost.state).toBe('lost');
    expect(byId.walkLost.live).toBe(false);
    expect(byId.walkLost.stale).toBe(true);
  });
  test('profil rafraîchi il y a 1 h SANS partage → ABSENT (la vieille position ne reste pas sur la carte)', () => {
    expect(byId.walkSeen).toBeUndefined();
  });
  test('partage coupé (drapeau false) → absent', () => {
    expect(byId.walkOff).toBeUndefined();
  });
  test('position de 6 jours sans partage → absente', () => {
    expect(byId.walkOld).toBeUndefined();
  });
  test('seuls les partages actifs et récents sortent (live + lost)', () => {
    expect(Object.keys(byId).sort()).toEqual(['walkLive', 'walkLost']);
  });
});
