// 607 (ZOE) — Balade terminée par l'API REST (POST /friends/live-position puis offline) :
// mesuré en ligne, aucun +15 crédité. Rejoue le même chemin avec une vraie base.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_'.padEnd(64, 'x');
jest.mock('../src/services/notificationSender', () => new Proxy({}, { get: () => jest.fn(async () => ({})) }));
jest.mock('../src/sockets/emitter', () => ({
  buildPresenceIndex: jest.fn(() => Promise.resolve(null)), isIdentityOnline: jest.fn(() => false),
  emitToUser: jest.fn(), emitToConversation: jest.fn(), userRoom: (r, id) => `user:${r}:${id}`,
}));
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
let mongo; let Walker; let router;
beforeAll(async () => {
  mongo = await MongoMemoryServer.create(); await mongoose.connect(mongo.getUri());
  Walker = require('../src/models/Walker'); router = require('../src/routes/friendRoutes');
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
test('11 min, ~700 m puis arrêt → +15 une fois', async () => {
  const w = await Walker.create({ name: 'Walt Test', email: 'walt607@example.test', password: 'MotDePasse607!' });
  const user = { id: String(w._id), role: 'walker' };
  for (let i = 0; i < 12; i += 1) {
    const r = await post(user, { lat: -35.2 + i * 0.0006, lng: -30.4 });
    expect(r.status).toBe(200);
  }
  // 11 minutes « écoulées » : on recule le début de la session en mémoire.
  const s = require('../src/sockets/mapSocket').getLiveSession(String(w._id));
  s.startedAt -= 11 * 60000;
  await post(user, { offline: true });
  // Le gain est crédité sans bloquer la réponse : on attend qu'il arrive (5 s max).
  let pts = 0;
  for (let i = 0; i < 50 && pts === 0; i += 1) {
    await new Promise((r) => setTimeout(r, 100));
    pts = (await Walker.findById(w._id).lean()).pawPoints || 0;
  }
  expect(pts).toBe(15);
});
