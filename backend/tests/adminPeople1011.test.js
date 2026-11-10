/**
 * 1011 (ADA) — GET /admin/people-1011/activity : « a publié / a candidaté /
 * a payé » par profil, pour l'onglet Inscriptions de l'admin.
 * Lecture seule, compteurs par identifiant, aucune donnée personnelle.
 */
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  optionalAuth: (req, res, next) => next(),
}));
jest.mock('../src/middleware/auditAdmin', () => ({ auditAdmin: (req, res, next) => next() }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo;
let app;
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const oid = () => new mongoose.Types.ObjectId();

// Écrit directement dans les collections : on teste le comptage, pas les validations des modèles.
const insert = (name, doc) => mongoose.connection.collection(require(`../src/models/${name}`).collection.name).insertOne(doc);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  app = express();
  app.use(express.json());
  app.use('/admin/people-1011', require('../src/routes/adminPeople1011'));
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

test('réservé à l\'admin', async () => {
  const anon = await request(app).get('/admin/people-1011/activity');
  expect(anon.status).toBe(401);
  const owner = await request(app).get('/admin/people-1011/activity').set({ 'x-test-user': String(oid()), 'x-test-role': 'owner' });
  expect(owner.status).toBe(403);
});

test('base vide : aucune personne, pas d\'erreur', async () => {
  const r = await request(app).get('/admin/people-1011/activity').set(ADMIN);
  expect(r.status).toBe(200);
  expect(r.body.people).toEqual({});
  expect(typeof r.body.generatedAt).toBe('string');
});

test('compte les demandes, les candidatures et les réservations payées par profil', async () => {
  const ownerA = oid();
  const ownerB = oid();
  const sitter = oid();
  const walker = oid();

  // ownerA : 2 demandes + 1 publication « media » (ne compte pas). ownerB : 1 demande.
  await insert('Post', { ownerId: ownerA, postType: 'request', body: 'test' });
  await insert('Post', { ownerId: ownerA, postType: 'request', body: 'test' });
  await insert('Post', { ownerId: ownerA, postType: 'media', body: 'test' });
  await insert('Post', { ownerId: ownerB, postType: 'request', body: 'test' });

  // Le gardien a candidaté 2 fois, le promeneur 1 fois.
  await insert('Application', { ownerId: ownerA, sitterId: sitter, walkerId: null, status: 'pending' });
  await insert('Application', { ownerId: ownerB, sitterId: sitter, walkerId: null, status: 'rejected' });
  await insert('Application', { ownerId: ownerA, sitterId: null, walkerId: walker, status: 'pending' });

  // Réservations : payée (paymentStatus), terminée (status), payée par paidAt,
  // remboursée (ne compte pas), remboursement échoué « refund » (ne compte pas), en attente (ne compte pas).
  await insert('Booking', { ownerId: ownerA, sitterId: sitter, walkerId: null, status: 'paid', paymentStatus: 'paid', paidAt: new Date() });
  await insert('Booking', { ownerId: ownerA, sitterId: null, walkerId: walker, status: 'completed', paymentStatus: 'pending', paidAt: null });
  await insert('Booking', { ownerId: ownerB, sitterId: sitter, walkerId: null, status: 'agreed', paymentStatus: 'pending', paidAt: new Date() });
  await insert('Booking', { ownerId: ownerB, sitterId: sitter, walkerId: null, status: 'refunded', paymentStatus: 'refunded', paidAt: new Date() });
  await insert('Booking', { ownerId: ownerB, sitterId: sitter, walkerId: null, status: 'cancelled', paymentStatus: 'refund', paidAt: new Date() });
  await insert('Booking', { ownerId: ownerB, sitterId: null, walkerId: walker, status: 'pending', paymentStatus: 'pending', paidAt: null });

  const r = await request(app).get('/admin/people-1011/activity').set(ADMIN);
  expect(r.status).toBe(200);
  const p = r.body.people;
  expect(p[`owner:${ownerA}`]).toEqual({ published: 2, paid: 2 });
  expect(p[`owner:${ownerB}`]).toEqual({ published: 1, paid: 1 });
  expect(p[`sitter:${sitter}`]).toEqual({ applied: 2, paid: 2 });
  expect(p[`walker:${walker}`]).toEqual({ applied: 1, paid: 1 });
  expect(Object.keys(p).length).toBe(4);
});

test('la réponse ne contient aucune donnée personnelle', async () => {
  const r = await request(app).get('/admin/people-1011/activity').set(ADMIN);
  const raw = JSON.stringify(r.body);
  expect(raw).not.toMatch(/@/);
  expect(raw).not.toMatch(/email|phone|mobile|name|address/i);
  Object.keys(r.body.people).forEach((k) => expect(k).toMatch(/^(owner|sitter|walker):[0-9a-f]{24}$/));
  Object.values(r.body.people).forEach((v) => {
    Object.keys(v).forEach((kk) => expect(['published', 'applied', 'paid']).toContain(kk));
    Object.values(v).forEach((n) => expect(Number.isInteger(n)).toBe(true));
  });
});
