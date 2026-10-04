// 611 (PAM, 04/10/2026) — vocal de Cam : « j'ai 36 points et je ne sais pas
// à quoi je les ai gagnés ». GET /pawpoints/history = MES gains (3 profils),
// raison + points + date, plus récents d'abord, 30 au plus ; le passé sans
// trace n'est jamais inventé (« avant le journal : N »). Vraie base en mémoire.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: () => (req, res, next) => next(),
  optionalAuth: (req, res, next) => next(),
}));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => ({ ok: true })) }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let svc; let act; let PawPointsEvent;
beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  PawPointsEvent = require('../src/models/PawPointsEvent');
  await Promise.all([Owner.init(), Sitter.init(), PawPointsEvent.init()]);
  svc = require('../src/services/pawPointsService');
  act = require('../src/services/pawPointsActivity607');
  app = express();
  app.use(express.json());
  app.use('/pawpoints', require('../src/routes/pawPointsRoutes'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

let n = 0;
async function person(M = Owner, email, lifetime = 0) {
  n += 1;
  const u = await M.create({ name: `Histo ${n}`, email: email || `histo611_${n}@example.test`, password: 'MotDePasse611!' });
  await M.collection.updateOne({ _id: u._id }, { $set: { pawPoints: lifetime, pawPointsSpendable: lifetime } });
  return u;
}
const as = (u, role = 'owner') => ({ 'x-test-user': String(u._id), 'x-test-role': role });

test('gains en clair, plus récents d\'abord, sur les 3 profils ; passé sans trace = une ligne', async () => {
  const email = `cam611_${Date.now()}@example.test`;
  const o = await person(Owner, email, 16); // 16 points d'avant le journal, sans trace
  const s = await person(Sitter, email, 16);
  await svc.awardPointsDetailed({ userId: String(o._id), role: 'owner', points: 10, reason: 'spot created' });
  await new Promise((r) => setTimeout(r, 5));
  await svc.awardPointsDetailed({ userId: String(s._id), role: 'sitter', points: 20, reason: 'mini-peluche fox' });
  await new Promise((r) => setTimeout(r, 5));
  await svc.awardPointsDetailed({ userId: String(o._id), role: 'owner', points: 1, reason: 'map report confirmed' });
  const r = await request(app).get('/pawpoints/history').set(as(o));
  expect(r.status).toBe(200);
  expect(r.body.items.map((x) => [x.key, x.points])).toEqual([['correctReport', 1], ['plushCaught', 20], ['spotCreated', 10]]);
  expect(r.body.beforeJournal).toBe(16);
  expect(r.body.lifetime).toBe(47);
  // même chose vue depuis son profil gardien
  const rs = await request(app).get('/pawpoints/history').set(as(s, 'sitter'));
  expect(rs.body.items).toHaveLength(3);
});

test('activité 607 (Pionnier) : une seule ligne, pas de doublon avec le journal', async () => {
  const u = await person();
  await act.awardActivity({ userId: String(u._id), role: 'owner', key: 'pioneer' });
  const r = await request(app).get('/pawpoints/history').set(as(u));
  expect(r.body.items.map((x) => x.key)).toEqual(['pioneer']);
  expect(r.body.beforeJournal).toBe(0);
});

test('trace 607 d\'avant le journal : gardée (vraie), jamais inventée', async () => {
  const u = await person(Owner, undefined, 300);
  const pk = act.personKeyFromEmail((await Owner.findById(u._id).lean()).email);
  await PawPointsEvent.create({ personKey: pk, userId: String(u._id), role: 'owner', key: 'pioneer', points: 200, credited: 200, dedupeKey: `${pk}:pioneer`, at: new Date('2026-10-02T10:00:00Z') });
  const r = await request(app).get('/pawpoints/history').set(as(u));
  expect(r.body.items).toEqual([{ key: 'pioneer', points: 200, at: '2026-10-02T10:00:00.000Z' }]);
  expect(r.body.beforeJournal).toBe(100);
});

test('reprise (spot supprimé) : ligne négative', async () => {
  const u = await person();
  await svc.awardPointsDetailed({ userId: String(u._id), role: 'owner', points: 10, reason: 'spot created' });
  await svc.revokePoints({ userId: String(u._id), role: 'owner', points: 10, reason: 'spot deleted' });
  const r = await request(app).get('/pawpoints/history').set(as(u));
  expect(r.body.items.map((x) => x.points).sort()).toEqual([-10, 10]);
});

test('30 lignes au plus ; jamais les gains d\'une autre personne ; 401 sans compte', async () => {
  const a = await person();
  const b = await person();
  for (let i = 0; i < 35; i += 1) await svc.awardPointsDetailed({ userId: String(a._id), role: 'owner', points: 2, reason: 'spot comment' });
  await svc.awardPointsDetailed({ userId: String(b._id), role: 'owner', points: 10, reason: 'spot created' });
  const ra = await request(app).get('/pawpoints/history').set(as(a));
  expect(ra.body.items).toHaveLength(30);
  expect(ra.body.items.every((x) => x.key === 'usefulComment')).toBe(true);
  const rb = await request(app).get('/pawpoints/history').set(as(b));
  expect(rb.body.items).toHaveLength(1);
  expect((await request(app).get('/pawpoints/history')).status).toBe(401);
});
