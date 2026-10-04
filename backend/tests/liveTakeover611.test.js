// 611 (PAM, 04/10/2026) — REPRISE DU DIRECT SUR UN AUTRE TÉLÉPHONE.
// Cam (capture du 04/10, 17 h 30) : « En direct de mon autre iPhone resté à la
// maison. Du coup je ne peux pas être en direct avec cet iPhone. »
// Règle : « Passer en direct sur ce téléphone » = UN appel. L'ancien appareil
// est prévenu (map:self-live reason device_takeover), ses positions tardives
// sont ignorées, la Balade garde son heure de départ, ses suiveurs et ses
// demandes de suivi. Un appareil immobile resté à la maison ne bloque jamais.
// Modèles simulés, aucune base, aucun réseau (même montage que liveDevices589).
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
const IPHONE = { user: { id: 'dS', role: 'sitter' }, headers: { 'x-app-version': '23.1.583+611' } };
// 611 — l'iPhone resté à la maison, app 611 au premier plan, même profil que l'iPhone en main.
const HOME_611 = { user: { id: 'dS', role: 'sitter' }, headers: { 'x-app-version': '23.1.583+611' } };
const post = (who, body) => call(route('post', '/live-position'), { ...who, body });
const liveState = (who) => call(route('get', '/live-state'), who);
const selfLiveEvents = () => emitToUser.mock.calls.filter((c) => c[2] === 'map:self-live');

const takeover = (who, deviceId) => call(route('post', '/live-takeover'), { ...who, body: { deviceId } });
const followers = require('../src/utils/followers589');

beforeEach(() => {
  emitToUser.mockClear();
  mapSocket.clearLiveSession('dO');
  mapSocket.clearLiveSession('dS');
  followers._resetForTests();
  for (const d of [...mockDOCS.Owner, ...mockDOCS.Sitter]) {
    d.location = { type: 'Point', coordinates: [-30.4, -35.2] };
  }
});

// Une socket simulée : on récupère les gestionnaires enregistrés par mapSocket.
function fakeSocket(identity) {
  const handlers = {};
  const socket = { data: { mapIdentity: identity }, on: (ev, fn) => { handlers[ev] = fn; }, emit: () => {}, join: () => {} };
  mapSocket(null, socket);
  return handlers;
}

describe('611 — reprise du direct sur ce téléphone', () => {
  test('A (ancienne app, service de fond) diffuse ; B reprend : même Balade, A prévenu, B garde la main', async () => {
    await post(ANDROID_BG, { lat: -35.21, lng: -30.41 });
    const before = mapSocket.getLiveSession('dO');
    expect(before).toBeTruthy();
    const startedAt = before.startedAt;
    const fk = followers.personKey(['dO', 'dS']);
    followers.touch(fk, 'cam-friend', true, Date.now(), 'friend1');
    expect(followers.count(fk)).toBe(1);

    const r = await takeover(IPHONE, 'B-iphone');
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ ok: true, takenOver: true });
    // la Balade passe sur le profil de B, même heure de départ, même tracé
    expect(mapSocket.getLiveSession('dO')).toBeNull();
    const s = mapSocket.getLiveSession('dS');
    expect(s.startedAt).toBe(startedAt);
    expect(s.deviceId).toBe('B-iphone');
    // suiveurs conservés, aucune fin de suivi annoncée aux amis
    expect(followers.count(fk)).toBe(1);
    expect(emitToUser.mock.calls.some((c) => c[2] === 'map:friend-offline')).toBe(false);
    // A reçoit l'ordre d'arrêter (B l'ignore grâce à keepDeviceId), puis « direct ailleurs »
    const ev = selfLiveEvents().map((c) => c[3]);
    expect(ev.some((e) => e.active === false && e.reason === 'device_takeover' && e.keepDeviceId === 'B-iphone')).toBe(true);
    expect(ev.some((e) => e.active === true && e.reason === 'device_takeover' && e.deviceId === 'B-iphone')).toBe(true);
    // l'arrêt n'est PAS noté : ce n'est pas un arrêt voulu
    expect(mockDOCS.Owner[0].location.liveShareStoppedAt || null).toBeNull();
  });

  test('positions tardives de A ignorées (HTTP, battement) ; celles de B passent', async () => {
    await post(ANDROID_BG, { lat: -35.21, lng: -30.41 });
    await takeover(IPHONE, 'B-iphone');
    const late = await post(ANDROID_BG, { lat: -35.99, lng: -30.99 });
    expect(late.body).toMatchObject({ ok: true, ignored: true, stopped: true, takenOver: true });
    const hb = await post(ANDROID_BG, { heartbeat: true });
    expect(hb.body.ignored).toBe(true);
    expect(mapSocket.getLiveSession('dO')).toBeNull(); // A ne recrée pas de session
    const ok = await post(IPHONE, { lat: -35.3, lng: -30.5, deviceId: 'B-iphone' });
    expect(ok.body.ignored).toBeUndefined();
    expect(mapSocket.getLiveSession('dS').lat).toBe(-35.3);
  });

  test('deux apps 611 sur le MÊME profil : A ignoré après reprise par B (corps et en-tête)', async () => {
    await post(HOME_611, { lat: -35.21, lng: -30.41, deviceId: 'A-home' });
    expect(mapSocket.getLiveSession('dS').deviceId).toBe('A-home');
    const r = await takeover(IPHONE, 'B-iphone');
    expect(r.body.takenOver).toBe(true);
    const lateBody = await post(HOME_611, { lat: -35.9, lng: -30.9, deviceId: 'A-home' });
    expect(lateBody.body.ignored).toBe(true);
    const lateHeader = await call(route('post', '/live-position'), { ...HOME_611, headers: { ...HOME_611.headers, 'x-live-device': 'A-home' }, body: { lat: -35.9, lng: -30.9 } });
    expect(lateHeader.body.ignored).toBe(true);
    expect(mapSocket.getLiveSession('dS').lat).toBe(-35.21);
  });

  test('socket : la position tardive de A est ignorée, celle de B passe', async () => {
    await post(HOME_611, { lat: -35.21, lng: -30.41, deviceId: 'A-home' });
    await takeover(IPHONE, 'B-iphone');
    const h = fakeSocket({ userId: 'dS', role: 'sitter' });
    await h['map:position-update']({ lat: -35.8, lng: -30.8, deviceId: 'A-home' });
    expect(mapSocket.getLiveSession('dS').lat).toBe(-35.21);
    const h2 = fakeSocket({ userId: 'dS', role: 'sitter' });
    await h2['map:position-update']({ lat: -35.4, lng: -30.6, deviceId: 'B-iphone' });
    expect(mapSocket.getLiveSession('dS').lat).toBe(-35.4);
  });

  test('après un arrêt voulu, l\'ancien téléphone peut de nouveau lancer SA Balade', async () => {
    await post(HOME_611, { lat: -35.21, lng: -30.41, deviceId: 'A-home' });
    await takeover(IPHONE, 'B-iphone');
    await post(IPHONE, { offline: true });
    const again = await post(HOME_611, { lat: -35.5, lng: -30.5, deviceId: 'A-home' });
    expect(again.body.ignored).toBeUndefined();
    expect(mapSocket.getLiveSession('dS').deviceId).toBe('A-home');
  });

  test('reprise sans direct en cours : rien à reprendre, rien de cassé', async () => {
    const r = await takeover(IPHONE, 'B-iphone');
    expect(r.body).toMatchObject({ ok: true, takenOver: false });
    const p = await post(IPHONE, { lat: -35.3, lng: -30.5, deviceId: 'B-iphone' });
    expect(p.body.ignored).toBeUndefined();
  });

  test('identifiant d\'appareil absent ou invalide : 400', async () => {
    const r = await takeover(IPHONE, '');
    expect(r.status).toBe(400);
  });
});
