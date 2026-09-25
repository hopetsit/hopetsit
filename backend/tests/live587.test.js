// v587 (25/09/2026) — le direct « suspendu » et le frère « dans l'eau ».
// Deux personnes à plusieurs rôles (zone fictive lat -35 / lng -30) :
//   · S (diffuseur) : gardien sS qui PARTAGE (position exacte), propriétaire
//     sO dont la position de profil (centre-ville) est PLUS RÉCENTE ;
//   · V (ami qui regarde) : amitié faite depuis son profil propriétaire vO,
//     mais il regarde depuis son profil gardien vS.
// Attendus : (1) la position part aussi dans le salon du rôle COURANT de V ;
// (2) un ami avec son PawFollow reçoit le direct comme sur la route HTTP ;
// (3) /friends/live-positions renvoie la position du document QUI PARTAGE,
// jamais le point de profil, et l'âge mesuré par le serveur (`ageMs`).
// Modèles simulés : aucune base, aucun réseau.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mockLIVE = [-30.4012, -35.2034];   // [lng, lat] GPS réel du partage
const mockPROFILE = [-30.39, -35.19];    // point de profil flouté / centre-ville
const mockDOCS = {
  Owner: [
    { _id: 'sO', email: 's@example.test', location: { type: 'Point', coordinates: mockPROFILE, updatedAt: new Date() }, preferences: {} },
    { _id: 'vO', email: 'v@example.test', location: { type: 'Point', coordinates: [-30.5, -35.3] }, preferences: {} },
  ],
  Sitter: [
    { _id: 'sS', email: 's@example.test', location: { type: 'Point', coordinates: mockLIVE, liveShareActive: true, updatedAt: new Date(Date.now() - 20000) }, preferences: {} },
    { _id: 'vS', email: 'v@example.test', location: { type: 'Point', coordinates: [-30.5, -35.3] }, preferences: {} },
  ],
  Walker: [],
};
const mockGROUPS = { s: ['sO', 'sS'], v: ['vO', 'vS'] };
const mockModelOf = (id) => (id.endsWith('O') ? 'Owner' : 'Sitter');
const mockGroupOf = (id) => {
  const g = Object.values(mockGROUPS).find((ids) => ids.includes(String(id))) || [String(id)];
  return { ids: g, set: new Set(g), docs: g.map((x) => ({ id: x, model: mockModelOf(x) })) };
};

const mockChain = (result) => {
  const c = { select: () => c, limit: () => c, sort: () => c, lean: () => Promise.resolve(result),
    then: (ok, ko) => Promise.resolve(result).then(ok, ko), catch: () => c };
  return c;
};
const mockModel = (name) => ({
  find: jest.fn(() => mockChain([])),
  findById: jest.fn((id) => mockChain(mockDOCS[name].find((d) => String(d._id) === String(id)) || null)),
  updateOne: jest.fn(() => Promise.resolve({})),
});
jest.mock('../src/models/Owner', () => mockModel('Owner'));
jest.mock('../src/models/Sitter', () => mockModel('Sitter'));
jest.mock('../src/models/Walker', () => mockModel('Walker'));
const mockPawFollow = new Set();
jest.mock('../src/models/UserSubscription', () => ({
  find: jest.fn(() => mockChain([])),
  findOne: jest.fn(() => mockChain(null)),
  hasActivePawFollow: jest.fn((id) => Promise.resolve(mockPawFollow.has(String(id)))),
  isInSameFamily: jest.fn(() => Promise.resolve(false)),
  listFamilyMembers: jest.fn(() => Promise.resolve([])),
  familyActiveMatch: jest.fn(() => ({})),
}));
let mockShareFlag = true;
jest.mock('../src/models/Friendship', () => ({
  find: jest.fn(() => mockChain([{
    requesterId: 'vO', requesterModel: 'Owner', addresseeId: 'sO', addresseeModel: 'Owner',
    status: 'accepted', requesterSharesPosition: true, addresseeSharesPosition: mockShareFlag,
  }])),
}));
jest.mock('../src/sockets/emitter', () => ({
  userRoom: (role, id) => `user:${String(role).toLowerCase()}:${id}`,
  emitToUser: jest.fn(),
  buildPresenceIndex: jest.fn(() => Promise.resolve(null)),
  isIdentityOnline: jest.fn(() => false),
}));
jest.mock('../src/utils/identityGroup', () => ({ identityGroup: jest.fn((id) => Promise.resolve(mockGroupOf(id))) }));
jest.mock('../src/utils/personScope', () => ({
  personIds: jest.fn((id) => Promise.resolve(mockGroupOf(id).ids)),
  personIndex: jest.fn((ids) => Promise.resolve(new Map(ids.map((i) => [String(i), mockGroupOf(i)])))),
}));
jest.mock('../src/utils/mapVisibility', () => ({
  ...jest.requireActual('../src/utils/mapVisibility'),
  personMapVisibility: jest.fn(() => Promise.resolve('all')),
}));

const mapSocket = require('../src/sockets/mapSocket');
const router = require('../src/routes/friendRoutes');

function handler(path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path && l.route.methods.get);
  return layer.route.stack[layer.route.stack.length - 1].handle;
}
function call(fn, user) {
  return new Promise((resolve, reject) => {
    const res = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json(b) { resolve({ status: this.statusCode, body: b }); } };
    Promise.resolve(fn({ user, query: {}, headers: {} }, res)).catch(reject);
  });
}

beforeEach(() => { mockShareFlag = true; mockPawFollow.clear(); mapSocket.clearLiveSession('sS'); });

test('la position part aussi vers le salon du rôle COURANT de l\'ami (gardien), avec l\'id qu\'il connaît', async () => {
  const ls = await mapSocket.listPositionListeners('sS', 'sitter');
  const rooms = ls.map((l) => `${l.role}:${l.userId}`).sort();
  expect(rooms).toEqual(['owner:vO', 'sitter:vS']);
  for (const l of ls) expect(l.viewAsId).toBe('sO');
});

test('ami sans drapeau de partage mais avec son PawFollow : reçoit le direct (même règle que la route HTTP)', async () => {
  mockShareFlag = undefined;
  expect(await mapSocket.listPositionListeners('sS', 'sitter')).toEqual([]);
  mockPawFollow.add('vO');
  const ls = await mapSocket.listPositionListeners('sS', 'sitter');
  expect(ls.length).toBe(2);
});

test('opt-out explicite : rien, même avec PawFollow', async () => {
  mockShareFlag = false;
  mockPawFollow.add('vO');
  expect(await mapSocket.listPositionListeners('sS', 'sitter')).toEqual([]);
});

test('live-positions : position GPS du document qui partage, jamais le point de profil plus récent ; ageMs serveur', async () => {
  const r = await call(handler('/live-positions'), { id: 'vS', role: 'sitter', model: 'Sitter' });
  expect(r.status).toBe(200);
  expect(r.body.positions).toHaveLength(1);
  const p = r.body.positions[0];
  expect([p.lng, p.lat]).toEqual(mockLIVE);
  expect(p.state).toBe('live');
  expect(p.sharing).toBe(true);
  expect(p.ageMs).toBeGreaterThanOrEqual(15000);
  expect(p.ageMs).toBeLessThan(60000);
});

test('session RAM plus fraîche : elle prime (position exacte envoyée par le téléphone)', async () => {
  mapSocket.touchLiveSession({ userId: 'sS', role: 'sitter', lat: -35.2041, lng: -30.4003 });
  const r = await call(handler('/live-positions'), { id: 'vO', role: 'owner', model: 'Owner' });
  const p = r.body.positions[0];
  expect([p.lng, p.lat]).toEqual([-30.4003, -35.2041]);
  expect(p.ageMs).toBeLessThan(2000);
});

describe('point 3 — barres repliables retenues sur le compte', () => {
  const { normalizeMapPrefs } = jest.requireActual('../src/controllers/mapPrefsController');
  test('railCollapsed / capsuleCollapsed : booléens gardés, fusion partielle, rien d\'autre', () => {
    const a = normalizeMapPrefs({ rail: ['sos'] }, { railCollapsed: true });
    expect(a.railCollapsed).toBe(true);
    expect(a.rail).toEqual(['sos']);
    const b = normalizeMapPrefs(a, { capsuleCollapsed: true });
    expect(b.railCollapsed).toBe(true);
    expect(b.capsuleCollapsed).toBe(true);
    const c = normalizeMapPrefs(b, { railCollapsed: 'oui', capsuleCollapsed: false });
    expect(c.railCollapsed).toBe(true);
    expect(c.capsuleCollapsed).toBe(false);
  });
});
