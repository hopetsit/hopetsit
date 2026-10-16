// 1617 (LEO, 16/10/2026, §B.5) — « N propriétaires cherchent un gardien à Paris
// cette semaine » : GET /api/v1/posts/requests/public-stats (vraie route, sans
// compte), base Mongo en mémoire. Propriétaires réels seulement, positions
// floutées, jamais de nom.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({ sendEachForMulticast: jest.fn(async (m) => ({ successCount: m.tokens.length, failureCount: 0, responses: [] })) }),
}));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async () => ({ messageId: 'capté' })) };
});

const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { haversineKm } = require('../src/utils/searchRadius');

const H = 3600000; const NOW = Date.now();
let mongo; let app; let Post; let Owner;
let real; let real2; let testAcc; let staff; let probe;
const PARIS = { lat: 48.8566, lng: 2.3522 };

const mk = async (ownerId, extra = {}) => String((await Post.collection.insertOne({
  ownerId, postType: 'request', status: 'open', hidden: false, body: 'Garde de Rex', serviceTypes: ['pet_sitting'],
  location: { city: 'Paris 11e', lat: 48.8575, lng: 2.3797 }, reservedBy: { bookingId: null }, createdAt: new Date(),
  startDate: new Date(NOW + 48 * H), endDate: new Date(NOW + 96 * H), ...extra,
})).insertedId);
const stats = (qs) => request(app).get(`/api/v1/posts/requests/public-stats?${qs}`);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  app = require('../src/app');
  Post = require('../src/models/Post'); Owner = require('../src/models/Owner');
  const ins = async (doc) => (await Owner.collection.insertOne({ status: 'active', verified: true, ...doc })).insertedId;
  real = await ins({ name: 'Camille', email: 'camille-stats1617@example.test' });
  real2 = await ins({ name: 'Léo', email: 'leo-stats1617@example.test' });
  testAcc = await ins({ name: 'Test', email: 'dadaciao84+testowner-1617@gmail.com' });
  staff = await ins({ name: 'Staff', email: 'staff-1617@example.test', isStaff: true });
  probe = await ins({ name: 'Probe', email: 'probe-565@invalid.example' });
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(async () => { await Post.deleteMany({}); require('../src/utils/publicRequestStats1617')._resetForTest(); });

test('sans ville ni position → 400', async () => {
  const r = await stats('');
  expect(r.status).toBe(400);
});

test('aucune demande → count 0 et aucune bulle (le site n\'affiche rien)', async () => {
  const r = await stats('city=Paris');
  expect(r.status).toBe(200);
  expect(r.body).toMatchObject({ count: 0, bubbles: [] });
});

test('Paris 11e compte pour Paris ; comptes de test, staff et sonde exclus ; bulle floutée sans nom', async () => {
  const id = await mk(real);
  await mk(real2, { location: { city: 'Paris', lat: 48.84, lng: 2.30 }, serviceTypes: ['dog_walking'], startDate: new Date(NOW + 24 * H), endDate: new Date(NOW + 24 * H + 1800000) });
  await mk(testAcc); await mk(staff); await mk(probe);
  await mk(real, { location: { city: 'Lyon', lat: 45.75, lng: 4.85 } });
  const r = await stats('city=Paris');
  expect(r.status).toBe(200);
  expect(r.body.count).toBe(2);
  expect(r.body.city).toBe('Paris');
  expect(r.body.bubbles).toHaveLength(2);
  const b = r.body.bubbles.find((x) => x.service === 'sitting');
  expect(b).toBeTruthy();
  expect(b.days).toBe(3);
  expect(r.body.bubbles.find((x) => x.service === 'walk').days).toBe(1);
  // Floutée (déplacée) mais à ~1 km au plus, et jamais le nom / l'adresse.
  const km = haversineKm(48.8575, 2.3797, b.lat, b.lng);
  expect(km).toBeGreaterThan(0);
  expect(km).toBeLessThan(1.6);
  for (const x of r.body.bubbles) expect(Object.keys(x).sort()).toEqual(['days', 'lat', 'lng', 'service']);
  expect(JSON.stringify(r.body)).not.toMatch(/Camille|Léo|ownerId|body/);
  // Déterministe : même id → même position.
  const again = await stats('city=paris');
  expect(again.body.bubbles.find((x) => x.service === 'sitting')).toEqual(b);
  expect(id).toBeTruthy();
});

test('fermée, masquée, réservée ou passée → pas comptée ; vieille (> 7 j) sans prestation à venir → pas comptée', async () => {
  await mk(real, { status: 'closed' });
  await mk(real, { hidden: true });
  await mk(real, { reservedBy: { bookingId: new mongoose.Types.ObjectId() } });
  await mk(real, { startDate: new Date(NOW - 72 * H), endDate: new Date(NOW - 48 * H) });
  await mk(real, { createdAt: new Date(NOW - 10 * 24 * H), startDate: null, endDate: null });
  await mk(real2, { createdAt: new Date(NOW - 10 * 24 * H) }); // vieille MAIS prestation à venir → comptée
  await mk(real2, { startDate: null, endDate: null }); // sans date, créée aujourd'hui → comptée
  const r = await stats('city=Paris');
  expect(r.body.count).toBe(2);
});

test('par position et rayon : lat/lng/radius ; une demande sans coordonnées compte par la ville seulement', async () => {
  await mk(real);
  await mk(real2, { location: { city: 'Paris', lat: null, lng: null } });
  const r = await stats(`lat=${PARIS.lat}&lng=${PARIS.lng}&radius=10`);
  expect(r.body.count).toBe(1);
  const byCity = await stats('city=Paris');
  expect(byCity.body.count).toBe(2);
  expect(byCity.body.bubbles).toHaveLength(1);
  const far = await stats('lat=45.75&lng=4.85&radius=10');
  expect(far.body.count).toBe(0);
});

test('cache 5 min : une 2e lecture ne voit pas une demande ajoutée entre-temps', async () => {
  await mk(real);
  expect((await stats('city=Paris')).body.count).toBe(1);
  await mk(real2, { location: { city: 'Paris', lat: 48.84, lng: 2.30 } });
  expect((await stats('city=Paris')).body.count).toBe(1);
  require('../src/utils/publicRequestStats1617')._resetForTest();
  expect((await stats('city=Paris')).body.count).toBe(2);
});

test('50 bulles au plus, le compteur reste exact', async () => {
  for (let i = 0; i < 55; i += 1) await mk(real, { location: { city: 'Paris', lat: 48.85 + i * 0.001, lng: 2.35 } });
  const r = await stats('city=Paris');
  expect(r.body.count).toBe(55);
  expect(r.body.bubbles).toHaveLength(50);
});
