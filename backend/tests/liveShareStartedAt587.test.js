// v587 — heure de départ du direct (`location.liveShareStartedAt`), sur une
// VRAIE base Mongo en mémoire et le vrai relais de position (mapSocket) :
//   · posée au premier point du partage ;
//   · INCHANGÉE aux points suivants (le site compte « En direct · X min ») ;
//   · effacée à l'arrêt ; reposée au partage suivant ;
//   · renvoyée par GET /users/me/profile.
// Aucun réseau, aucune production.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_'.padEnd(64, 'x');

// Pas de Firebase en test : les notifications sont neutralisées.
jest.mock('../src/services/notificationSender', () => new Proxy({}, {
  get: () => jest.fn(async () => ({})),
}));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo;
let Sitter;
let relayLivePosition;
let getOwnerProfile;
const ID = new mongoose.Types.ObjectId();

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Sitter = require('../src/models/Sitter');
  ({ relayLivePosition } = require('../src/sockets/mapSocket'));
  ({ getOwnerProfile } = require('../src/controllers/userController'));
  // Insertion brute : on ne teste pas la validation d'inscription ici.
  await Sitter.collection.insertOne({
    _id: ID,
    name: 'Gardien direct',
    email: 'direct587@example.test',
    location: { type: 'Point', coordinates: [2.35, 48.85], city: 'Paris' },
  });
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

const loc = async () => (await Sitter.findById(ID).lean()).location;
const tick = (ms) => new Promise((r) => setTimeout(r, ms));

test('premier point du partage → heure de départ posée', async () => {
  expect((await loc()).liveShareStartedAt ?? null).toBeNull();
  const before = Date.now();
  await relayLivePosition({ userId: String(ID), role: 'sitter', lat: 48.86, lng: 2.36 });
  const l = await loc();
  expect(l.liveShareActive).toBe(true);
  expect(l.liveShareStartedAt).toBeInstanceOf(Date);
  expect(l.liveShareStartedAt.getTime()).toBeGreaterThanOrEqual(before - 5);
});

test('points suivants → heure de départ INCHANGÉE', async () => {
  const first = (await loc()).liveShareStartedAt.getTime();
  await tick(30);
  await relayLivePosition({ userId: String(ID), role: 'sitter', lat: 48.87, lng: 2.37 });
  const l = await loc();
  expect(l.coordinates).toEqual([2.37, 48.87]);
  expect(l.liveShareStartedAt.getTime()).toBe(first);
});

test('GET /users/me/profile renvoie l\'heure de départ', async () => {
  const started = (await loc()).liveShareStartedAt.toISOString();
  const body = await new Promise((resolve, reject) => {
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(b) { resolve({ status: this.statusCode, b }); },
    };
    getOwnerProfile({ user: { id: String(ID), role: 'sitter' } }, res).catch(reject);
  });
  expect(body.status).toBe(200);
  expect(new Date(body.b.profile.liveShareStartedAt).toISOString()).toBe(started);
  expect(new Date(body.b.profile.location.liveShareStartedAt).toISOString()).toBe(started);
});

test('arrêt du partage → heure effacée, direct éteint, coordonnées gardées', async () => {
  await relayLivePosition({ userId: String(ID), role: 'sitter', offline: true });
  const l = await loc();
  expect(l.liveShareActive).toBe(false);
  expect(l.liveShareStartedAt).toBeNull();
  expect(l.coordinates).toEqual([2.37, 48.87]);
});

test('nouveau partage → nouvelle heure de départ', async () => {
  const before = Date.now();
  await relayLivePosition({ userId: String(ID), role: 'sitter', lat: 48.88, lng: 2.38 });
  const l = await loc();
  expect(l.liveShareStartedAt.getTime()).toBeGreaterThanOrEqual(before - 5);
});

test('session précédente jamais arrêtée (> 10 min sans point) → repart de zéro', async () => {
  const old = new Date(Date.now() - 60 * 60 * 1000);
  await Sitter.updateOne({ _id: ID }, {
    $set: { 'location.liveShareActive': true, 'location.liveShareStartedAt': old, 'location.updatedAt': old },
  });
  await relayLivePosition({ userId: String(ID), role: 'sitter', lat: 48.89, lng: 2.39 });
  const l = await loc();
  expect(l.liveShareStartedAt.getTime()).toBeGreaterThan(old.getTime() + 30 * 60 * 1000);
});
