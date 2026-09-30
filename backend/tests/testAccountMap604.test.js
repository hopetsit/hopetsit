// v604 (ZOE, 30/09/2026) — les comptes `+test` ne sortent JAMAIS en public.
// BOB : +testsitter et +testwalker, posés au centre de Paris, apparaissaient
// comme gardien et promeneur aux vrais utilisateurs parisiens.
// VRAIE base Mongo en mémoire, VRAIS gestionnaires : /sitters/nearby,
// /walkers/nearby, /sitters, /walkers, /friends/members/nearby,
// /friends/search, /supply/city et /supply/city/faces. Un compte de test
// dont l'e-mail est stocké CHIFFRÉ est couvert aussi (aucune regex Mongo).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'ab'.repeat(32);

jest.mock('../src/services/notificationSender', () => new Proxy({}, {
  get: () => jest.fn(async () => ({})),
}));
jest.mock('../src/sockets/emitter', () => ({
  buildPresenceIndex: jest.fn(() => Promise.resolve(null)),
  isIdentityOnline: jest.fn(() => false),
  emitToUser: jest.fn(),
  emitToUsersAllRoles: jest.fn(),
  emitChatMessage: jest.fn(),
  userRoom: (role, id) => `user:${role}:${id}`,
}));
jest.mock('../src/utils/geocodeCity', () => ({
  ...jest.requireActual('../src/utils/geocodeCity'),
  geocodeCity: jest.fn(async () => ({ lat: 48.8566, lng: 2.3522 })),
  peekCity: jest.fn(() => null),
  warmCities: jest.fn(),
}));

const mongoose = require('mongoose');
const _lg = require('../src/utils/logger'); const _orig = _lg.error; _lg.error = (...a) => { if (process.env.PF_DEBUG) console.log('LOGERR', ...a.map((x) => (x && x.stack) || x)); return _orig.apply(_lg, a); };
const { MongoMemoryServer } = require('mongodb-memory-server');
const { encrypt } = require('../src/utils/encryption');
const { isTestAccountDoc, testAccountVisibleTo, hideTestAccounts } = require('../src/utils/testAccountMap604');

let mongo;
let Owner; let Sitter; let Walker; let Friendship;
let sitterCtl; let walkerCtl; let friendRouter; let supplyRouter;

const oid = () => new mongoose.Types.ObjectId();
const PARIS = [2.3522, 48.8566];
const near = (dx) => [PARIS[0] + dx, PARIS[1]];
const FUTURE = new Date(Date.now() + 7 * 864e5);

const TEST_SITTER = { _id: oid(), email: 'dadaciao84+testsitter604@gmail.com', firstName: 'Test', lastName: 'Sitter' };
const TEST_WALKER = { _id: oid(), email: 'dadaciao84+testwalker604@gmail.com', firstName: 'Test', lastName: 'Walker' };
// Compte de test dont l'e-mail est stocké chiffré.
const TEST_ENC = { _id: oid(), email: encrypt('someone+testenc604@example.test'), firstName: 'Test', lastName: 'Chiffre' };
const REAL_SITTER = { _id: oid(), email: 'lea604@example.test', firstName: 'Léa', lastName: 'Martin' };
const REAL_WALKER = { _id: oid(), email: 'hugo604@example.test', firstName: 'Hugo', lastName: 'Petit' };
const STRANGER = { _id: oid(), email: 'inconnu604@example.test', firstName: 'Inconnu', lastName: 'X' };
const FRIEND = { _id: oid(), email: 'ami604@example.test', firstName: 'Ami', lastName: 'Y' };

function provider(p, coords) {
  return {
    ...p,
    name: `${p.firstName} ${p.lastName}`,
    password: 'x'.repeat(60),
    avatar: { url: 'https://example.test/a.jpg', publicId: '' },
    location: { type: 'Point', coordinates: coords, city: 'Paris' },
    city: 'Paris',
    // Membre « actif » de la PawMap (PawSpot) pour /friends/members/nearby.
    mapBoostExpiry: FUTURE,
    basePrice: 10,
    hourlyRate: 12,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
}

function run(fn, { user = null, query = {} } = {}) {
  return new Promise((resolve, reject) => {
    const req = { user, query, params: {}, body: {}, headers: {} };
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      set() { return this; },
      json(b) { resolve({ status: this.statusCode, body: JSON.parse(JSON.stringify(b)) }); },
    };
    Promise.resolve(fn(req, res)).catch(reject);
  });
}
function handlerOf(router, method, p) {
  const layer = router.stack.find((l) => l.route && l.route.path === p && l.route.methods[method]);
  if (!layer) throw new Error(`route ${method} ${p} introuvable`);
  return layer.route.stack[layer.route.stack.length - 1].handle;
}
const asOwner = (p) => ({ id: String(p._id), role: 'owner' });
const ids = (list, key = 'id') => (list || []).map((x) => String(x[key] || x._id || x.id));
const TEST_IDS = [TEST_SITTER, TEST_WALKER, TEST_ENC].map((p) => String(p._id));
const hasTest = (list, key) => ids(list, key).some((i) => TEST_IDS.includes(i));

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Friendship = require('../src/models/Friendship');
  sitterCtl = require('../src/controllers/sitterController');
  walkerCtl = require('../src/controllers/walkerController');
  friendRouter = require('../src/routes/friendRoutes');
  supplyRouter = require('../src/routes/supplyRoutes');
  await Promise.all([Sitter.init(), Walker.init(), Owner.init()]);

  await Sitter.collection.insertMany([
    provider(TEST_SITTER, near(0.001)), provider(TEST_ENC, near(0.002)), provider(REAL_SITTER, near(0.003)),
  ]);
  await Walker.collection.insertMany([provider(TEST_WALKER, near(0.001)), provider(REAL_WALKER, near(0.004))]);
  await Owner.collection.insertMany([
    { ...STRANGER, name: 'Inconnu X', password: 'x'.repeat(60), location: { type: 'Point', coordinates: near(0.01), city: 'Paris' } },
    { ...FRIEND, name: 'Ami Y', password: 'x'.repeat(60), location: { type: 'Point', coordinates: near(0.01), city: 'Paris' } },
  ]);
  // FRIEND est ami des deux comptes de test (gardien et promeneur).
  for (const [t, model] of [[TEST_SITTER, 'Sitter'], [TEST_WALKER, 'Walker']]) {
    // eslint-disable-next-line no-await-in-loop
    await Friendship.collection.insertOne({
      requesterId: FRIEND._id, requesterModel: 'Owner', addresseeId: t._id, addresseeModel: model,
      status: 'accepted', acceptedAt: new Date(), createdAt: new Date(), updatedAt: new Date(),
      requesterSharesPosition: true, addresseeSharesPosition: true,
    });
  }
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

describe('règle pure', () => {
  test('e-mail en clair ou chiffré contenant « +test » = compte de test', () => {
    expect(isTestAccountDoc(TEST_SITTER)).toBe(true);
    expect(isTestAccountDoc(TEST_ENC)).toBe(true);
    expect(isTestAccountDoc(REAL_SITTER)).toBe(false);
    expect(isTestAccountDoc({ email: 'dadaciao84@gmail.com' })).toBe(false);
  });
  test('visible de lui-même et de ses amis seulement', () => {
    const id = String(TEST_SITTER._id);
    expect(testAccountVisibleTo(TEST_SITTER, {})).toBe(false);
    expect(testAccountVisibleTo(TEST_SITTER, { viewerIds: new Set([id]) })).toBe(true);
    expect(testAccountVisibleTo(TEST_SITTER, { friendIds: new Set([id]) })).toBe(true);
    expect(hideTestAccounts([TEST_SITTER, REAL_SITTER])).toEqual([REAL_SITTER]);
  });
});

const Q = { lat: String(PARIS[1]), lng: String(PARIS[0]), radiusInMeters: '5000' };

describe('/sitters/nearby et /walkers/nearby (Paris)', () => {
  test('un anonyme ne voit aucun compte de test', async () => {
    const s = await run(sitterCtl.findNearbySitters, { query: Q });
    const w = await run(walkerCtl.findNearbyWalkers, { query: Q });
    expect(s.status).toBe(200);
    expect(w.status).toBe(200);
    const sl = s.body.sitters || s.body;
    const wl = w.body.walkers || w.body;
    expect(ids(sl)).toContain(String(REAL_SITTER._id));
    expect(ids(wl)).toContain(String(REAL_WALKER._id));
    expect(hasTest(sl)).toBe(false);
    expect(hasTest(wl)).toBe(false);
  });
  test('un inconnu connecté ne voit aucun compte de test', async () => {
    const s = await run(sitterCtl.findNearbySitters, { user: asOwner(STRANGER), query: Q });
    expect(hasTest(s.body.sitters || s.body)).toBe(false);
  });
  test('leur ami les voit (et pas le compte de test chiffré, qui n\'est pas son ami)', async () => {
    const s = await run(sitterCtl.findNearbySitters, { user: asOwner(FRIEND), query: Q });
    const w = await run(walkerCtl.findNearbyWalkers, { user: asOwner(FRIEND), query: Q });
    const sl = ids(s.body.sitters || s.body);
    expect(sl).toContain(String(TEST_SITTER._id));
    expect(sl).not.toContain(String(TEST_ENC._id));
    expect(ids(w.body.walkers || w.body)).toContain(String(TEST_WALKER._id));
  });
});

describe('listes publiques /sitters et /walkers', () => {
  test('aucun compte de test', async () => {
    const s = await run(sitterCtl.listSitters, {});
    const w = await run(walkerCtl.listWalkers, {});
    expect(ids(s.body.sitters)).toContain(String(REAL_SITTER._id));
    expect(hasTest(s.body.sitters)).toBe(false);
    expect(hasTest(w.body.walkers)).toBe(false);
  });
});

describe('PawMap : /friends/members/nearby', () => {
  const nearbyQ = { lat: String(PARIS[1]), lng: String(PARIS[0]), radiusInMeters: '5000' };
  const flat = (members) => (members || []).flatMap((m) => [m.id, ...(m.personIds || [])]).map(String);
  test('inconnu : aucun compte de test sur la carte', async () => {
    const r = await run(handlerOf(friendRouter, 'get', '/members/nearby'), { user: asOwner(STRANGER), query: nearbyQ });
    expect(r.status).toBe(200);
    const got = flat(r.body.members);
    expect(got).toContain(String(REAL_SITTER._id));
    expect(got.some((i) => TEST_IDS.includes(i))).toBe(false);
  });
  test('ami : ses amis de test apparaissent', async () => {
    const r = await run(handlerOf(friendRouter, 'get', '/members/nearby'), { user: asOwner(FRIEND), query: nearbyQ });
    const got = flat(r.body.members);
    expect(got).toContain(String(TEST_SITTER._id));
    expect(got).not.toContain(String(TEST_ENC._id));
  });
});

describe('recherche /friends/search', () => {
  test('inconnu : « test » ne propose aucun compte de test', async () => {
    const r = await run(handlerOf(friendRouter, 'get', '/search'), { user: asOwner(STRANGER), query: { q: 'test' } });
    expect(r.status).toBe(200);
    expect(hasTest(r.body.users)).toBe(false);
  });
  test('ami : il retrouve ses amis de test', async () => {
    const r = await run(handlerOf(friendRouter, 'get', '/search'), { user: asOwner(FRIEND), query: { q: 'test' } });
    expect(ids(r.body.users)).toEqual(expect.arrayContaining([String(TEST_SITTER._id), String(TEST_WALKER._id)]));
  });
});

describe('offre publique /supply', () => {
  test('« N gardiens / promeneurs à Paris » ne compte pas les comptes de test', async () => {
    const r = await run(handlerOf(supplyRouter, 'get', '/city'), { query: { city: 'Paris', lat: String(PARIS[1]), lng: String(PARIS[0]) } });
    expect(r.status).toBe(200);
    expect(r.body.sitters).toBe(1);
    expect(r.body.walkers).toBe(1);
  });
  test('visages de l\'offre : aucun compte de test', async () => {
    const r = await run(handlerOf(supplyRouter, 'get', '/city/faces'), { query: { city: 'Paris', limit: '6' } });
    expect(r.status).toBe(200);
    const list = r.body.faces || r.body.providers || r.body.items || [];
    expect(hasTest(list)).toBe(false);
    expect(JSON.stringify(r.body)).not.toMatch(/Chiffre|testsitter|testwalker/i);
  });
});
