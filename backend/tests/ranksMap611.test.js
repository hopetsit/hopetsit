// 611 (PAM, 04/10/2026) — RANGS sur les couches de la PawMap : chaque
// personne porte `rank {key, level, pointsEarned, nextAt, nextKey}` calculé sur
// ses PawPoints gagnés depuis toujours (jamais le solde). Zone fictive (-35 / -30).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const LAT = -35.2;
const LNG = -30.4;
const loc = (dx) => ({ type: 'Point', coordinates: [LNG + dx, LAT] });
const DOCS = {
  Owner: [
    { _id: 'cam', email: 'cam@example.com', name: 'Cam Normale', mapBoostExpiry: new Date(Date.now() + 864e5), pawPoints: 820, pawPointsSpendable: 5, location: loc(0.006), preferences: {} },
    { _id: 'vieux', email: 'vieux@example.com', name: 'Vieux Compte', location: loc(0.007), preferences: {} },
    { _id: 'testAcc', email: 'dadaciao84+testx@gmail.com', name: 'Test', pawPoints: 50000, location: loc(0.004), preferences: { mapVisibility: 'all' } },
  ],
  Sitter: [
    { _id: 'lea', email: 'lea@example.com', name: 'Lea Gardienne', mapBoostExpiry: new Date(Date.now() + 864e5), pawPoints: 12000, location: loc(0.008), preferences: {}, dailyRate: 20 },
  ],
  Walker: [
    { _id: 'stranger1', email: 'stranger@example.com', name: 'Lecteur', location: loc(-0.01), preferences: {} },
  ],
};
const SELECTS = [];

function get(doc, path) {
  return path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), doc);
}
function matches(doc, q) {
  if (!q) return true;
  for (const [k, v] of Object.entries(q)) {
    if (k === '$or') { if (!v.some((c) => matches(doc, c))) return false; continue; }
    if (k === 'location') continue; // $near ignoré
    if (k === 'location.coordinates.1') { if (!Array.isArray(get(doc, 'location.coordinates'))) return false; continue; }
    const val = k === '_id' ? String(doc._id) : get(doc, k);
    if (v && typeof v === 'object' && '$ne' in v) { if (val === v.$ne) return false; continue; }
    if (v && typeof v === 'object' && '$in' in v) { if (!v.$in.map(String).includes(String(val))) return false; continue; }
    if (v && typeof v === 'object' && '$exists' in v) continue;
    if (String(val) !== String(v)) return false;
  }
  return true;
}
const chain = (result) => {
  const c = {
    select: (s) => { SELECTS.push(String(s || '')); return c; }, limit: () => c, sort: () => c,
    lean: () => Promise.resolve(result),
    then: (ok, ko) => Promise.resolve(result).then(ok, ko),
    catch: () => c,
  };
  return c;
};
const mockModel = (name) => ({
  find: jest.fn((q) => chain(DOCS[name].filter((d) => matches(d, q)).map((d) => ({ ...d })))),
  findById: jest.fn((id) => chain(DOCS[name].find((d) => String(d._id) === String(id)) || null)),
  exists: jest.fn(() => Promise.resolve(false)),
  updateOne: jest.fn((q, u) => {
    const d = DOCS[name].find((x) => String(x._id) === String(q._id));
    if (d && u.$set) {
      for (const [k, val] of Object.entries(u.$set)) {
        const parts = k.split('.');
        let o = d;
        for (const p of parts.slice(0, -1)) { o[p] = o[p] || {}; o = o[p]; }
        o[parts[parts.length - 1]] = val;
      }
    }
    return Promise.resolve({ acknowledged: true });
  }),
});

jest.mock('../src/models/Owner', () => mockModel('Owner'));
jest.mock('../src/models/Sitter', () => mockModel('Sitter'));
jest.mock('../src/models/Walker', () => mockModel('Walker'));
jest.mock('../src/models/UserSubscription', () => ({
  find: jest.fn(() => chain([])),
  findOne: jest.fn(() => chain(null)),
  hasActivePawFollow: jest.fn(() => Promise.resolve(false)),
  isInSameFamily: jest.fn(() => Promise.resolve(false)),
  familyActiveMatch: jest.fn(() => ({})),
}));
jest.mock('../src/models/Friendship', () => ({ find: jest.fn(() => chain([])) }));
jest.mock('../src/sockets/emitter', () => ({
  buildPresenceIndex: jest.fn(() => Promise.resolve(null)),
  isIdentityOnline: jest.fn(() => false),
  emitToUser: jest.fn(),
}));
jest.mock('../src/utils/personScope', () => ({
  personIds: jest.fn((id) => Promise.resolve([String(id)])),
  personIndex: jest.fn((ids) => Promise.resolve(new Map(ids.map((i) => [String(i), {
    ids: [String(i)], set: new Set([String(i)]),
    docs: [{ id: String(i), model: String(i) === 'friend1' ? 'Owner' : (String(i) === 'stranger1' ? 'Walker' : 'Sitter') }],
  }])))),
}));
jest.mock('../src/utils/identityGroup', () => ({
  identityGroup: jest.fn((id) => {
    const s = String(id);
    const model = s === 'friend1' ? 'Owner' : (s === 'stranger1' ? 'Walker' : 'Sitter');
    return Promise.resolve({ ids: [s], set: new Set([s]), docs: [{ id: s, model }] });
  }),
}));

const router = require('../src/routes/friendRoutes');
const mv = require('../src/utils/mapVisibility');

function handler(path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path);
  if (!layer) throw new Error(`route ${path} introuvable`);
  return layer.route.stack[layer.route.stack.length - 1].handle;
}
function call(fn, user, query = {}, body = undefined) {
  return new Promise((resolve, reject) => {
    const req = { user, query, body, headers: {} };
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(b) { resolve({ status: this.statusCode, body: b }); },
    };
    Promise.resolve(fn(req, res)).catch(reject);
  });
}

describe('611 — rang sur la couche monde', () => {
  test('GET /friends/members/world : rang par personne, champ lu en base', async () => {
    SELECTS.length = 0;
    const r = await call(handler('/members/world'), { id: 'stranger1', role: 'walker' });
    expect(r.status).toBe(200);
    const by = (id) => r.body.members.find((m) => m.id === id);
    expect(by('cam').rank).toEqual({ key: 'adult_dog', level: 3, pointsEarned: 820, nextAt: 3000, nextKey: 'pack_leader' });
    expect(by('lea').rank).toMatchObject({ key: 'legend', level: 5, nextAt: null });
    expect(by('vieux').rank).toMatchObject({ key: 'puppy', pointsEarned: 0 });
    expect(by('testAcc')).toBeUndefined(); // compte +test : hors couche publique
    // le solde dépensable ne sort jamais sur la carte
    expect(JSON.stringify(r.body)).not.toMatch(/pawPointsSpendable/);
    // la requête demande bien le total gagné (sinon tout le monde serait Chiot en prod)
    expect(SELECTS.filter((s) => s.includes('mapBoostExpiry')).every((s) => /\bpawPoints\b/.test(s))).toBe(true);
  });
});

describe('611 — rang sur la couche « proches »', () => {
  // la couche « proches » ne montre que les membres actifs (PawSpot / abonnés / staff)
  test('GET /friends/members/nearby : rang par personne', async () => {
    SELECTS.length = 0;
    const r = await call(handler('/members/nearby'), { id: 'stranger1', role: 'walker' },
      { lat: String(LAT), lng: String(LNG), radiusInMeters: '5000' });
    expect(r.status).toBe(200);
    const list = r.body.members || r.body.users || [];
    const cam = list.find((m) => String(m.id || m._id) === 'cam');
    expect(cam).toBeDefined();
    expect(cam.rank).toMatchObject({ key: 'adult_dog', pointsEarned: 820 });
    const lea = list.find((m) => String(m.id || m._id) === 'lea');
    expect(lea.rank.key).toBe('legend');
    expect(JSON.stringify(r.body)).not.toMatch(/pawPointsSpendable/);
    expect(SELECTS.some((s) => s.includes('walkRates') && /\bpawPoints\b/.test(s))).toBe(true);
  });
});
