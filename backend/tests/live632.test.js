// 632 (PAM, 01/11/2026) — vidéos de Daniel (Condado de Alhama) : pilule
// « Connexion… » > 1 min puis retombée en pleine balade ; « En direct · autre
// téléphone » alors qu'aucun autre téléphone ne diffusait.
//   1. POST /friends/live-position confirme la Balade SANS attendre la base ni
//      la liste des amis (mesuré en prod : 2,1-2,6 s avec 5 amis).
//   2. Une panne du relais aux amis ne fait ni 500, ni chute du processus.
//   3. GET /friends/live-state dit QUEL appareil tient la session (deviceId),
//      et `map:self-live` aussi : l'app ne prend plus sa propre balade pour
//      un autre téléphone.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mockDOCS = {
  Owner: [{ _id: 'dO', email: 'd@example.test', location: { type: 'Point', coordinates: [-30.4, -35.2] }, preferences: {} }],
  Sitter: [{ _id: 'dS', email: 'd@example.test', location: { type: 'Point', coordinates: [-30.4, -35.2] }, preferences: {} }],
  Walker: [],
};
const mockGroupOf = (id) => {
  const g = ['dO', 'dS'].includes(String(id)) ? ['dO', 'dS'] : [String(id)];
  return { ids: g, set: new Set(g), docs: g.map((x) => ({ id: x, model: x.endsWith('O') ? 'Owner' : 'Sitter' })) };
};
const mockChain = (result) => {
  const c = { select: () => c, limit: () => c, sort: () => c, lean: () => Promise.resolve(result),
    then: (ok, ko) => Promise.resolve(result).then(ok, ko), catch: () => c };
  return c;
};
const mockSetPath = (obj, path, val) => {
  const parts = path.split('.');
  let o = obj;
  for (const p of parts.slice(0, -1)) { o[p] = o[p] || {}; o = o[p]; }
  o[parts[parts.length - 1]] = val;
};
const mockGetPath = (obj, path) => path.split('.').reduce((o, p) => (o == null ? o : o[p]), obj);
const mockModel = (name) => ({
  find: jest.fn(() => mockChain([])),
  findById: jest.fn((id) => mockChain(mockDOCS[name].find((d) => String(d._id) === String(id)) || null)),
  updateOne: jest.fn((filter, update) => {
    const doc = mockDOCS[name].find((d) => String(d._id) === String(filter._id));
    if (!doc) return Promise.resolve({ modifiedCount: 0 });
    for (const [k, cond] of Object.entries(filter)) {
      if (k === '_id' || k === '$or') continue;
      if (cond && typeof cond === 'object' && '$ne' in cond) {
        const v = mockGetPath(doc, k);
        if ((v == null ? null : v) === cond.$ne) return Promise.resolve({ modifiedCount: 0 });
      }
    }
    for (const [k, v] of Object.entries((update && update.$set) || {})) mockSetPath(doc, k, v);
    return Promise.resolve({ modifiedCount: 1 });
  }),
});
jest.mock('../src/models/Owner', () => mockModel('Owner'));
jest.mock('../src/models/Sitter', () => mockModel('Sitter'));
jest.mock('../src/models/Walker', () => mockModel('Walker'));
jest.mock('../src/models/UserSubscription', () => ({
  find: jest.fn(() => mockChain([])),
  findOne: jest.fn(() => mockChain(null)),
  hasActivePawFollow: jest.fn(() => Promise.resolve(false)),
  isInSameFamily: jest.fn(() => Promise.resolve(false)),
  listFamilyMembers: jest.fn(() => Promise.resolve([])),
  familyActiveMatch: jest.fn(() => ({})),
}));
let mockSlowMs = 0;
let mockFriendFail = false;
jest.mock('../src/models/Friendship', () => ({
  find: jest.fn(() => {
    const c = { select: () => c, limit: () => c, sort: () => c,
      lean: () => new Promise((ok, ko) => setTimeout(() => (mockFriendFail ? ko(new Error('base indisponible')) : ok([])), mockSlowMs)) };
    return c;
  }),
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

const { emitToUser } = require('../src/sockets/emitter');
const mapSocket = require('../src/sockets/mapSocket');
const router = require('../src/routes/friendRoutes');

function route(method, path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path && l.route.methods[method]);
  return layer.route.stack[layer.route.stack.length - 1].handle;
}
function call(fn, { user, body = {}, headers = {} }) {
  return new Promise((resolve, reject) => {
    const res = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json(b) { resolve({ status: this.statusCode, body: b }); } };
    Promise.resolve(fn({ user, body, headers, query: {} }, res)).catch(reject);
  });
}
const IPHONE = { user: { id: 'dS', role: 'sitter' }, headers: { 'x-app-version': '23.1.599+632' } };
const settle = (ms = 25) => new Promise((r) => setTimeout(r, ms));

beforeEach(() => {
  emitToUser.mockClear();
  mapSocket.clearLiveSession('dO');
  mapSocket.clearLiveSession('dS');
  mockSlowMs = 0;
  mockFriendFail = false;
});

test('la Balade est confirmée avant la fin du relais aux amis (base lente)', async () => {
  mockSlowMs = 1500;
  const t0 = Date.now();
  const r = await call(route('post', '/live-position'), { ...IPHONE, body: { lat: -35.2, lng: -30.4, deviceId: 'IPH-1', duration: 'until_stop' } });
  const dt = Date.now() - t0;
  expect(r.status).toBe(200);
  expect(r.body.ok).toBe(true);
  expect(r.body.session).toEqual(expect.objectContaining({ lat: -35.2, lng: -30.4 }));
  expect(dt).toBeLessThan(500);
  await settle(1700);
});

test('battement sans position : confirmé tout de suite si la session existe', async () => {
  await call(route('post', '/live-position'), { ...IPHONE, body: { lat: -35.2, lng: -30.4, deviceId: 'IPH-1' } });
  mockSlowMs = 1500;
  const t0 = Date.now();
  const r = await call(route('post', '/live-position'), { ...IPHONE, body: { heartbeat: true, deviceId: 'IPH-1' } });
  expect(Date.now() - t0).toBeLessThan(500);
  expect(r.body.heartbeat).toBe(true);
  expect(r.body.session).toBeTruthy();
  await settle(1700);
});

test('relais aux amis en panne : réponse 200 avec session, pas de rejet orphelin', async () => {
  mockFriendFail = true;
  const seen = [];
  const onRej = (e) => seen.push(e);
  process.on('unhandledRejection', onRej);
  const r = await call(route('post', '/live-position'), { ...IPHONE, body: { lat: -35.2, lng: -30.4, deviceId: 'IPH-1' } });
  expect(r.status).toBe(200);
  expect(r.body.session).toBeTruthy();
  await settle(60);
  process.off('unhandledRejection', onRej);
  expect(seen).toEqual([]);
});

test('sans position ni battement : 400 (inchangé)', async () => {
  const r = await call(route('post', '/live-position'), { ...IPHONE, body: { deviceId: 'IPH-1' } });
  expect(r.status).toBe(400);
});

test('live-state renvoie l\'appareil qui tient la session ; self-live aussi', async () => {
  await call(route('post', '/live-position'), { ...IPHONE, body: { lat: -35.2, lng: -30.4, deviceId: 'IPH-1' } });
  await settle();
  const st = await call(route('get', '/live-state'), IPHONE);
  expect(st.body.active).toBe(true);
  expect(st.body.deviceId).toBe('IPH-1');
  const started = emitToUser.mock.calls.filter((c) => c[2] === 'map:self-live' && c[3].active === true);
  expect(started.length).toBeGreaterThan(0);
  expect(started.every((c) => c[3].deviceId === 'IPH-1')).toBe(true);
});

test('live-state sans session : deviceId vide', async () => {
  const st = await call(route('get', '/live-state'), IPHONE);
  expect(st.body.active).toBe(false);
  expect(st.body.deviceId).toBe('');
});

// Contrôle ZOE (01/11) — deux vrais téléphones du même compte : A a perdu
// son arrêt, B relance une vraie balade (même session RAM). A ne doit ni se
// croire maître de la session, ni couper la balade de B.
const IPHONE_B = { user: { id: 'dO', role: 'owner' }, headers: { 'x-app-version': '23.1.599+632' } };

test('A orphelin puis B diffuse : live-state désigne B (le dernier qui diffuse)', async () => {
  await call(route('post', '/live-position'), { ...IPHONE, body: { lat: -35.2, lng: -30.4, deviceId: 'IPH-A' } });
  await settle();
  await call(route('post', '/live-position'), { ...IPHONE, body: { lat: -35.21, lng: -30.41, deviceId: 'IPH-B' } });
  await settle();
  const st = await call(route('get', '/live-state'), IPHONE);
  expect(st.body.active).toBe(true);
  expect(st.body.deviceId).toBe('IPH-B');
});

test('arrêt conditionnel de A pendant la balade de B : ignoré, B continue', async () => {
  await call(route('post', '/live-position'), { ...IPHONE, body: { lat: -35.2, lng: -30.4, deviceId: 'IPH-A' } });
  await call(route('post', '/live-position'), { ...IPHONE, body: { lat: -35.21, lng: -30.41, deviceId: 'IPH-B' } });
  await settle();
  const r = await call(route('post', '/live-position'), { ...IPHONE_B, body: { offline: true, onlyIfMine: true, deviceId: 'IPH-A' } });
  expect(r.body).toEqual(expect.objectContaining({ ok: true, ignored: true, heldElsewhere: true }));
  const st = await call(route('get', '/live-state'), IPHONE);
  expect(st.body.active).toBe(true);
  expect(st.body.deviceId).toBe('IPH-B');
});

test('arrêt conditionnel du téléphone qui tient la balade : il l\'arrête', async () => {
  await call(route('post', '/live-position'), { ...IPHONE, body: { lat: -35.2, lng: -30.4, deviceId: 'IPH-A' } });
  await settle();
  const r = await call(route('post', '/live-position'), { ...IPHONE, body: { offline: true, onlyIfMine: true, deviceId: 'IPH-A' } });
  expect(r.body.offline).toBe(true);
  const st = await call(route('get', '/live-state'), IPHONE);
  expect(st.body.active).toBe(false);
});

test('arrêt voulu (sans condition) depuis A : coupe la balade de B (inchangé, « arrêter partout »)', async () => {
  await call(route('post', '/live-position'), { ...IPHONE, body: { lat: -35.2, lng: -30.4, deviceId: 'IPH-B' } });
  await settle();
  const r = await call(route('post', '/live-position'), { ...IPHONE_B, body: { offline: true, deviceId: 'IPH-A' } });
  expect(r.body.offline).toBe(true);
  const st = await call(route('get', '/live-state'), IPHONE);
  expect(st.body.active).toBe(false);
});

test('ancienne app : arrêt sans appareil ni condition = arrêt (inchangé)', async () => {
  await call(route('post', '/live-position'), { ...IPHONE, body: { lat: -35.2, lng: -30.4, deviceId: 'IPH-B' } });
  await settle();
  const r = await call(route('post', '/live-position'), { ...IPHONE, body: { offline: true } });
  expect(r.body.offline).toBe(true);
});

test('lastDeviceId survit à un redémarrage (toDoc / fromDoc)', () => {
  const store = require('../src/utils/liveSessionStore607');
  const lt = require('../src/utils/liveTakeover611');
  const s = { userId: 'dS', role: 'sitter', lat: 1, lng: 2, lastSeenAt: Date.now(), startedAt: Date.now() };
  lt.noteDevice(s, 'IPH-A');
  lt.noteDevice(s, 'IPH-B');
  expect(lt.holderDevice(s)).toBe('IPH-B');
  const back = store.fromDoc(store.toDoc(s));
  expect(lt.holderDevice(back)).toBe('IPH-B');
});

test('reprise 611 par B puis arrêt conditionnel de A : ignoré, B garde la balade', async () => {
  await call(route('post', '/live-position'), { ...IPHONE, body: { lat: -35.2, lng: -30.4, deviceId: 'IPH-A' } });
  await settle();
  const tk = await call(route('post', '/live-takeover'), { ...IPHONE, body: { deviceId: 'IPH-B' } });
  expect(tk.status).toBe(200);
  const st = await call(route('get', '/live-state'), IPHONE);
  expect(st.body.deviceId).toBe('IPH-B');
  const r = await call(route('post', '/live-position'), { ...IPHONE, body: { offline: true, onlyIfMine: true, deviceId: 'IPH-A' } });
  expect(r.body).toEqual(expect.objectContaining({ ignored: true, heldElsewhere: true }));
  const st2 = await call(route('get', '/live-state'), IPHONE);
  expect(st2.body.active).toBe(true);
});
