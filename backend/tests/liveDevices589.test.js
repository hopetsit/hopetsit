// v589 (26/09/2026) — le direct suit la PERSONNE, pas le téléphone.
// Daniel : « si je me connecte sur un Android puis sur un Apple, la
// géolocalisation est synchronisée ? ». Une personne D, deux profils :
//   · dO (propriétaire) = son Android, qui partage par le SERVICE DE FOND
//     (requêtes SANS en-tête X-App-Version) ;
//   · dS (gardien) = son iPhone, app ouverte (en-tête présent).
// Attendus : l'arrêt sur l'iPhone coupe AUSSI le profil de l'Android, le
// service de fond ne peut plus le rallumer, l'état est lisible par
// /friends/live-state et annoncé aux autres appareils (map:self-live) ; un
// nouveau démarrage depuis l'app ouverte lève l'arrêt.
// Modèles simulés, écriture réelle en mémoire : aucune base, aucun réseau.

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
jest.mock('../src/models/Friendship', () => ({ find: jest.fn(() => mockChain([])) }));
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
const ANDROID_BG = { user: { id: 'dO', role: 'owner' }, headers: {} };
const IPHONE = { user: { id: 'dS', role: 'sitter' }, headers: { 'x-app-version': '23.1.578+589' } };
const post = (who, body) => call(route('post', '/live-position'), { ...who, body });
const liveState = (who) => call(route('get', '/live-state'), who);
const selfLiveEvents = () => emitToUser.mock.calls.filter((c) => c[2] === 'map:self-live');

beforeEach(() => {
  emitToUser.mockClear();
  mapSocket.clearLiveSession('dO');
  mapSocket.clearLiveSession('dS');
  for (const d of [...mockDOCS.Owner, ...mockDOCS.Sitter]) {
    d.location = { type: 'Point', coordinates: [-30.4, -35.2] };
  }
});

test('Android en arrière-plan partage : l\'iPhone lit « en direct » via /live-state', async () => {
  const r = await post(ANDROID_BG, { lat: -35.21, lng: -30.41 });
  expect(r.body.ok).toBe(true);
  expect(r.body.ignored).toBeUndefined();
  const s = await liveState(IPHONE);
  expect(s.status).toBe(200);
  expect(s.body.active).toBe(true);
  expect(s.body.role).toBe('owner');
  expect(s.body.fromId).toBe('dO');
});

test('arrêt sur l\'iPhone (autre profil) : coupe aussi le profil de l\'Android et prévient ses 2 salons', async () => {
  await post(ANDROID_BG, { lat: -35.21, lng: -30.41 });
  const r = await post(IPHONE, { offline: true });
  expect(r.body.offline).toBe(true);
  expect(mapSocket.getLiveSession('dO')).toBeNull();
  expect(mockDOCS.Owner[0].location.liveShareActive).toBe(false);
  expect(mockDOCS.Owner[0].location.liveShareStoppedAt).toBeInstanceOf(Date);
  expect(mockDOCS.Sitter[0].location.liveShareStoppedAt).toBeInstanceOf(Date);
  const rooms = selfLiveEvents().map((c) => `${c[0]}:${c[1]}:${c[3].active}`).sort();
  expect(rooms).toEqual(['owner:dO:false', 'sitter:dS:false']);
});

test('après l\'arrêt, le service de fond Android ne peut plus rallumer le direct (position ni battement)', async () => {
  await post(ANDROID_BG, { lat: -35.21, lng: -30.41 });
  await post(IPHONE, { offline: true });
  const r1 = await post(ANDROID_BG, { lat: -35.22, lng: -30.42 });
  const r2 = await post(ANDROID_BG, { heartbeat: true });
  expect(r1.body).toEqual({ ok: true, ignored: true, stopped: true });
  expect(r2.body.ignored).toBe(true);
  expect(mapSocket.getLiveSession('dO')).toBeNull();
  const s = await liveState(IPHONE);
  expect(s.body.active).toBe(false);
  expect(s.body.stopped).toBe(true);
});

test('redémarrage depuis l\'app ouverte : l\'arrêt est levé sur les 3 profils et annoncé aux autres appareils', async () => {
  await post(IPHONE, { offline: true });
  emitToUser.mockClear();
  const r = await post(IPHONE, { lat: -35.23, lng: -30.43 });
  expect(r.body.ok).toBe(true);
  expect(mockDOCS.Owner[0].location.liveShareStoppedAt).toBeNull();
  expect(mockDOCS.Sitter[0].location.liveShareStoppedAt).toBeNull();
  expect(selfLiveEvents().map((c) => c[3].active)).toEqual([true, true]);
  // … et le service de fond Android est de nouveau accepté.
  const bg = await post(ANDROID_BG, { lat: -35.24, lng: -30.44 });
  expect(bg.body.ignored).toBeUndefined();
  expect((await liveState(IPHONE)).body.active).toBe(true);
});

test('une position de plus en cours de direct ne ré-annonce pas le démarrage', async () => {
  await post(IPHONE, { lat: -35.23, lng: -30.43 });
  emitToUser.mockClear();
  await post(IPHONE, { lat: -35.231, lng: -30.431 });
  expect(selfLiveEvents()).toHaveLength(0);
});

test('socket map:go-offline : même arrêt sur les 3 profils', async () => {
  await post(ANDROID_BG, { lat: -35.21, lng: -30.41 });
  const handlers = {};
  const socket = { data: { mapIdentity: { userId: 'dS', role: 'sitter' } }, on: (ev, fn) => { handlers[ev] = fn; }, join: () => {} };
  mapSocket({}, socket);
  await handlers['map:go-offline']();
  expect(mapSocket.getLiveSession('dO')).toBeNull();
  expect(mockDOCS.Owner[0].location.liveShareStoppedAt).toBeInstanceOf(Date);
  expect((await post(ANDROID_BG, { lat: -35.22, lng: -30.42 })).body.ignored).toBe(true);
});
