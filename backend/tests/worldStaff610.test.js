// 610 (PAM, 04/10/2026) — Daniel (staff) se met « visible par tous » à La
// Isla : Cam, à 2 m de lui, ne le voyait pas. La couche MONDE excluait le
// staff d'office. Règle : un staff qui CHOISIT « visible par tous » apparaît
// comme tout le monde ; staff sans choix / « amis » / « masqué », comptes
// +test et modération restent exclus. Zone fictive (-35 / -30), aucune base.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const LAT = -35.2;
const LNG = -30.4;
const loc = (dx) => ({ type: 'Point', coordinates: [LNG + dx, LAT] });
const DOCS = {
  Owner: [
    { _id: 'staffAll', email: 'boss@example.com', name: 'John Staff', isStaff: true, location: loc(0.001), preferences: { mapVisibility: 'all', hideFromMap: false } },
    { _id: 'staffDefault', email: 'ops@example.com', name: 'Ops Staff', isStaff: true, location: loc(0.002), preferences: {} },
    { _id: 'staffFriends', email: 'friends@example.com', name: 'Amis Staff', isStaff: true, location: loc(0.003), preferences: { mapVisibility: 'friends', hideFromMap: true } },
    { _id: 'testAcc', email: 'dadaciao84+testx@gmail.com', name: 'Test', location: loc(0.004), preferences: { mapVisibility: 'all' } },
    { _id: 'moderated', email: 'mod@example.com', name: 'Modere', hiddenFromPublic: true, location: loc(0.005), preferences: { mapVisibility: 'all' } },
    { _id: 'cam', email: 'cam@example.com', name: 'Cam Normale', location: loc(0.006), preferences: {} },
  ],
  Sitter: [],
  Walker: [
    { _id: 'stranger1', email: 'stranger@example.com', name: 'Lecteur', location: loc(-0.01), preferences: {} },
  ],
};

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
    select: () => c, limit: () => c, sort: () => c,
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

describe('610 — staff « visible par tous » dans la couche monde', () => {
  test('règle pure excludedFromWorld', () => {
    const by = (id) => DOCS.Owner.find((d) => d._id === id);
    expect(mv.excludedFromWorld(by('staffAll'))).toBe(false);
    expect(mv.excludedFromWorld(by('staffDefault'))).toBe(true);
    expect(mv.excludedFromWorld(by('staffFriends'))).toBe(true);
    expect(mv.excludedFromWorld(by('testAcc'))).toBe(true);
    expect(mv.excludedFromWorld(by('moderated'))).toBe(true);
    expect(mv.excludedFromWorld(by('cam'))).toBe(false);
    expect(mv.excludedFromWorld({ email: 'probe-565@invalid.example' })).toBe(true);
    expect(mv.excludedFromWorld(null)).toBe(true);
  });

  test('GET /friends/members/world vu par un membre quelconque', async () => {
    const r = await call(handler('/members/world'), { id: 'stranger1', role: 'walker' });
    expect(r.status).toBe(200);
    const got = (r.body.members || []).map((m) => m.id);
    expect(got).toContain('staffAll');
    expect(got).toContain('cam');
    expect(got).not.toContain('staffDefault');
    expect(got).not.toContain('staffFriends');
    expect(got).not.toContain('testAcc');
    expect(got).not.toContain('moderated');
    const john = r.body.members.find((m) => m.id === 'staffAll');
    expect(john.isPremium).toBe(true); // couronne staff conservée
    expect(john.approx).toBe(true); // position floutée comme tout le monde
  });
});
