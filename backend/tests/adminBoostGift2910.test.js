// 2910 (BOB) — POST /admin/users/:role/:id/boost-gift : PawBoost profil offert jusqu'à une date,
// sans ligne d'achat (revenus inchangés), jamais raccourci, 90 jours max.
// Vraie base Mongo en mémoire, vraie route ; seule l'authentification est simulée.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role)
    ? next() : res.status(403).json({ error: 'forbidden' })),
  optionalAuth: (req, res, next) => next(),
}));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => ({ ok: true })) }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Sitter; let Walker;
const ADMIN = { 'x-test-user': 'admin1', 'x-test-role': 'admin' };
const DAY = 86400000;
const gift = (role, id, body) => request(app).post(`/admin/users/${role}/${id}/boost-gift`).set(ADMIN).send(body);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  await Promise.all([Sitter.init(), Walker.init()]);
  app = express();
  app.use(express.json());
  app.use('/admin', require('../src/routes/adminRoutes'));
});
afterAll(async () => { await mongoose.disconnect(); await mongo.stop(); });

test('offre le boost au profil gardien jusqu’à la date, sans ligne d’achat', async () => {
  const s = await Sitter.create({ name: 'Agnes', email: 'boost2910a@example.org', password: 'MotDePasse2910!' });
  const until = new Date(Date.now() + 30 * DAY).toISOString();
  const r = await gift('sitter', s._id, { until, tier: 'platinum' });
  expect(r.status).toBe(200);
  const d = await Sitter.findById(s._id).lean();
  expect(new Date(d.boostExpiry).toISOString()).toBe(until);
  expect(d.boostTier).toBe('platinum');
  expect(d.boostPurchases || []).toHaveLength(0);
});

test('ne raccourcit jamais un boost plus long', async () => {
  const long = new Date(Date.now() + 60 * DAY);
  const w = await Walker.create({ name: 'W', email: 'boost2910b@example.org', password: 'MotDePasse2910!', boostExpiry: long, boostTier: 'gold' });
  const r = await gift('walker', w._id, { until: new Date(Date.now() + 10 * DAY).toISOString(), tier: 'bronze' });
  expect(r.status).toBe(200);
  const d = await Walker.findById(w._id).lean();
  expect(new Date(d.boostExpiry).getTime()).toBe(long.getTime());
  expect(d.boostTier).toBe('gold');
});

test('refuse une date passée, au-delà de 90 jours, un rôle propriétaire et un non-admin', async () => {
  const s = await Sitter.create({ name: 'X', email: 'boost2910c@example.org', password: 'MotDePasse2910!' });
  expect((await gift('sitter', s._id, { until: new Date(Date.now() - DAY).toISOString() })).status).toBe(400);
  expect((await gift('sitter', s._id, { until: new Date(Date.now() + 91 * DAY).toISOString() })).status).toBe(400);
  expect((await gift('owner', s._id, { until: new Date(Date.now() + DAY).toISOString() })).status).toBe(400);
  const r = await request(app).post(`/admin/users/sitter/${s._id}/boost-gift`).set({ 'x-test-user': 'u', 'x-test-role': 'sitter' }).send({ until: new Date(Date.now() + DAY).toISOString() });
  expect(r.status).toBe(403);
  expect((await Sitter.findById(s._id).lean()).boostExpiry || null).toBeNull();
});
