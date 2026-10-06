// 607 (PAM, 02/10/2026) — « redémarrage du serveur pendant une Balade ».
// Mesuré par ZOE : chaque publication Render effaçait les Balades en cours
// (mémoire vive seulement). Ce test rejoue : Balade de 11 min et ~700 m →
// la mémoire est vidée (redémarrage) → reprise depuis la base → arrêt par
// l'utilisateur → +15 « Balade terminée » crédité une fois.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_'.padEnd(64, 'x');
jest.mock('../src/services/notificationSender', () => new Proxy({}, { get: () => jest.fn(async () => ({})) }));
jest.mock('../src/sockets/emitter', () => ({
  buildPresenceIndex: jest.fn(() => Promise.resolve(null)), isIdentityOnline: jest.fn(() => false),
  emitToUser: jest.fn(), emitToConversation: jest.fn(), userRoom: (r, id) => `user:${r}:${id}`,
}));
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Walker; let router; let map; let store; let LiveSession;
beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Walker = require('../src/models/Walker');
  router = require('../src/routes/friendRoutes');
  map = require('../src/sockets/mapSocket');
  store = require('../src/utils/liveSessionStore607');
  LiveSession = require('../src/models/LiveSession607');
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

function post(user, body) {
  const layer = router.stack.find((l) => l.route && l.route.path === '/live-position' && l.route.methods.post);
  const h = layer.route.stack[layer.route.stack.length - 1].handle;
  return new Promise((resolve, reject) => {
    const req = { user, body, headers: { 'x-app-version': '23.1.580+607' }, query: {} };
    const res = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json(b) { resolve({ status: this.statusCode, body: b }); } };
    Promise.resolve(h(req, res)).catch(reject);
  });
}

test('Balade en cours : un redémarrage du serveur ne la perd plus, +15 à la fin', async () => {
  const w = await Walker.create({ name: 'Walt Restart', email: 'walt607r@example.test', password: 'MotDePasse607!' });
  const user = { id: String(w._id), role: 'walker' };
  // 612 (PAM) — 67 m entre deux points : il faut le temps de les marcher
  // (15 s), sinon le filtre anti-saut GPS du tracé les écarte.
  let fakeNow = Date.now();
  const nowSpy = jest.spyOn(Date, 'now').mockImplementation(() => fakeNow);
  for (let i = 0; i < 12; i += 1) {
    fakeNow += 15000;
    const r = await post(user, { lat: -35.2 + i * 0.0006, lng: -30.4, duration: '4h' });
    expect(r.status).toBe(200);
  }
  nowSpy.mockRestore();
  const s = map.getLiveSession(String(w._id));
  s.startedAt -= 11 * 60000; // 11 minutes « écoulées »
  s.expiresAt = s.startedAt + 4 * 3600000;
  store.save(s);
  await store.flushAllForTests();
  const doc = await LiveSession.findOne({ userId: String(w._id) }).lean();
  expect(doc).toBeTruthy();
  expect(doc.trail.length).toBeGreaterThanOrEqual(10);

  // ── redémarrage : la mémoire vive est vide ──
  map._liveSessionsForTests.clear();
  expect(map.getLiveSession(String(w._id))).toBeNull();
  const n = await map.restoreLiveSessions();
  expect(n).toBe(1);
  const back = map.getLiveSession(String(w._id));
  expect(back).toBeTruthy();
  expect(back.startedAt).toBe(s.startedAt); // la durée affichée ne repart pas de zéro
  expect(back.duration).toBe('4h');
  expect(back.expiresAt).toBe(s.expiresAt);
  expect(back.trail.length).toBe(s.trail.length);

  // ── la Balade continue, puis l'utilisateur l'arrête ──
  const r = await post(user, { lat: -35.2 + 12 * 0.0006, lng: -30.4 });
  expect(r.status).toBe(200);
  expect(map.getLiveSession(String(w._id)).startedAt).toBe(s.startedAt);
  await post(user, { offline: true });
  let pts = 0;
  for (let i = 0; i < 50 && pts === 0; i += 1) {
    await new Promise((res) => setTimeout(res, 100));
    pts = (await Walker.findById(w._id).lean()).pawPoints || 0;
  }
  expect(pts).toBe(15);
  // arrêt = ligne effacée : rien ne revient au prochain redémarrage
  await store.flushAllForTests();
  let left = 1;
  for (let i = 0; i < 20 && left; i += 1) {
    await new Promise((res) => setTimeout(res, 50));
    left = await LiveSession.countDocuments({ userId: String(w._id) });
  }
  expect(left).toBe(0);
  map._liveSessionsForTests.clear();
  expect(await map.restoreLiveSessions()).toBe(0);
});

test('une session déjà revenue en mémoire n\'est pas écrasée par la base', async () => {
  const id = new mongoose.Types.ObjectId().toString();
  await LiveSession.create(store.toDoc({ userId: id, role: 'owner', lat: 1, lng: 2, lastSeenAt: Date.now() - 1000, startedAt: Date.now() - 60000 }));
  map._liveSessionsForTests.set(id, { userId: id, role: 'owner', lat: 3, lng: 4, lastSeenAt: Date.now(), startedAt: Date.now() });
  await map.restoreLiveSessions();
  expect(map.getLiveSession(id).lat).toBe(3);
  map.clearLiveSession(id);
});

test('une session de plus de 24 h sans signal n\'est pas reprise', async () => {
  const id = new mongoose.Types.ObjectId().toString();
  const old = Date.now() - 25 * 3600000;
  await LiveSession.create({ ...store.toDoc({ userId: id, role: 'owner', lat: 1, lng: 2, lastSeenAt: old, startedAt: old }), purgeAt: new Date(Date.now() + 60000) });
  map._liveSessionsForTests.clear();
  expect(await map.restoreLiveSessions()).toBe(0);
});
