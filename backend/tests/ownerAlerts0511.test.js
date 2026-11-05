// 05/11 (BOB) — GET /admin/requests613/owner-alerts : le propriétaire a-t-il été prévenu de chaque
// candidature (cloche, push possible, e-mail) ? Lecture seule, propriétaires réels seulement.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => { req.user = { id: 'a', role: req.headers['x-test-role'] || 'owner' }; next(); },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  optionalAuth: (req, res, next) => next(),
}));
const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app;
const O = () => new mongoose.Types.ObjectId();
beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  app = express();
  app.use(express.json());
  app.use('/admin/requests613', require('../src/routes/adminRequestJourney613'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); await mongo.stop(); });

test('cloche, push possible et e-mail par candidature ; comptes test exclus ; pas d’adresse', async () => {
  const Owner = require('../src/models/Owner');
  const Application = require('../src/models/Application');
  const Notification = require('../src/models/Notification');
  const AppEmail = require('../src/models/ApplicationEmail2610');
  const ins = async (M, d) => (await M.collection.insertOne(d)).insertedId;
  const ingrid = await ins(Owner, { name: 'Ingrid B', email: 'ingrid0511@example.org', fcmTokens: [] });
  const shannan = await ins(Owner, { name: 'Shannan', email: 'shannan0511@example.org', fcmTokens: ['tok'] });
  const testy = await ins(Owner, { name: 'Testy', email: 'dadaciao84+testowner@gmail.com' });
  const p1 = O(); const p2 = O(); const p3 = O();
  const a1 = await ins(Application, { postId: p1, ownerId: ingrid, sitterId: O(), status: 'pending', createdAt: new Date() });
  const a2 = await ins(Application, { postId: p2, ownerId: shannan, walkerId: O(), status: 'pending', createdAt: new Date() });
  const a3 = await ins(Application, { postId: p2, ownerId: shannan, walkerId: O(), status: 'pending', createdAt: new Date() });
  await ins(Application, { postId: p3, ownerId: testy, sitterId: O(), status: 'pending', createdAt: new Date() });
  await ins(Notification, { type: 'application_new', recipientRole: 'owner', recipientId: ingrid, data: { applicationId: String(a1) }, readAt: new Date(), createdAt: new Date() });
  await ins(Notification, { type: 'application_new', recipientRole: 'owner', recipientId: shannan, data: { applicationId: String(a2) }, readAt: null, createdAt: new Date() });
  await ins(AppEmail, { postId: p1, ownerId: ingrid, sentIds: [a1], queuedIds: [], lastSentAt: new Date(), emails: 1, lastResult: 'ok' });
  await ins(AppEmail, { postId: p2, ownerId: shannan, sentIds: [a2], queuedIds: [a3], lastSentAt: new Date(), emails: 1 });

  expect((await request(app).get('/admin/requests613/owner-alerts')).status).toBe(403);
  const r = await request(app).get('/admin/requests613/owner-alerts?days=14').set('x-test-role', 'admin');
  expect(r.status).toBe(200);
  expect(r.body.summary).toMatchObject({ applications: 3, bell: 2, bellRead: 1, pushPossible: 2, emailSent: 2, emailQueued: 1, emailMissing: 0, skippedNotReal: 1 });
  const byId = Object.fromEntries(r.body.items.map((i) => [i.applicationId, i]));
  expect(byId[String(a1)]).toMatchObject({ owner: 'Ingrid', bell: true, bellRead: true, pushPossible: false, email: 'sent' });
  expect(byId[String(a3)]).toMatchObject({ bell: false, pushPossible: true, email: 'queued' });
  expect(JSON.stringify(r.body)).not.toContain('@');
});
