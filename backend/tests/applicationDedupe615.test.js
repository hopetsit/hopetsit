// 615 (ZOE, 07/10/2026 — décision BOB) — DOUBLON DE CANDIDATURE = MÊME DEMANDE seulement.
// Bug mesuré au banc : un promeneur déjà candidat à la balade de mardi d'un
// propriétaire ne pouvait pas candidater à sa balade de mercredi (même animal) :
// le serveur renvoyait 200 « déjà envoyée » avec la candidature de MARDI.
// Vraie route POST /api/v1/applications, base Mongo en mémoire ; push/e-mail captés.
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
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Application; let Post;
let owner; let walker; let pet;
const tok = (id, role) => `Bearer ${jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '1h' })}`;
const mkPost = async (day) => String((await Post.collection.insertOne({
  ownerId: owner, postType: 'request', status: 'open', hidden: false, body: `Balade du ${day}`,
  serviceTypes: ['dog_walking'], petIds: [pet], location: { city: 'Zone test', lat: -35, lng: -30 },
  startDate: new Date(`2026-10-${day}T18:30:00Z`), endDate: new Date(`2026-10-${day}T19:00:00Z`),
  reservedBy: { bookingId: null }, createdAt: new Date(),
})).insertedId);
const applyTo = (postId, day) => request(app).post(`/api/v1/applications?ownerId=${owner}`)
  .set('Authorization', tok(walker, 'walker'))
  .send({ petIds: [String(pet)], serviceType: 'dog_walking', serviceDate: `2026-10-${day}T18:30:00.000Z`,
    startDate: `2026-10-${day}T18:30:00.000Z`, timeSlot: '18:30', basePrice: 10, duration: 30, postId });

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  app = require('../src/app');
  Application = require('../src/models/Application'); Post = require('../src/models/Post');
  const Owner = require('../src/models/Owner'); const Walker = require('../src/models/Walker'); const Pet = require('../src/models/Pet');
  owner = (await Owner.collection.insertOne({ name: 'Nicola', email: 'nicola-dedupe615@example.test', status: 'active', verified: true, currency: 'EUR', country: 'FR' })).insertedId;
  walker = (await Walker.collection.insertOne({ name: 'Paul', email: 'paul-dedupe615@example.test', status: 'active', verified: true, currency: 'EUR', country: 'FR',
    walkRates: [{ durationMinutes: 30, basePrice: 10, currency: 'EUR', enabled: true }] })).insertedId;
  pet = (await Pet.collection.insertOne({ ownerId: owner, petName: 'Rex', category: 'dog' })).insertedId;
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

test('2 balades du même propriétaire : le même promeneur peut candidater aux deux', async () => {
  const mardi = await mkPost('13');
  const mercredi = await mkPost('14');
  const a = await applyTo(mardi, '13');
  expect(a.status).toBe(201);
  const b = await applyTo(mercredi, '14');
  expect(b.status).toBe(201); // avant le correctif : 200 « duplicatePrevented » avec la candidature de mardi
  expect(b.body.duplicatePrevented).toBeUndefined();
  const rows = await Application.find({ walkerId: walker, status: 'pending' }).lean();
  expect(rows.map((r) => String(r.postId)).sort()).toEqual([mardi, mercredi].sort());
});

test('double appui sur la MÊME demande : toujours bloqué, aucune 2e candidature', async () => {
  const jeudi = await mkPost('15');
  expect((await applyTo(jeudi, '15')).status).toBe(201);
  const again = await applyTo(jeudi, '15');
  expect(again.status).toBe(200);
  expect(again.body.duplicatePrevented).toBe(true);
  expect(await Application.countDocuments({ postId: jeudi })).toBe(1);
});
