/**
 * 616 (BOB, 15/10/2026) — GET /admin/requests0410/reminders615 : lecture du
 * registre des rappels « tu as N candidats » (preuve en production).
 */
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    req.user = { id: req.headers['x-test-user'], role: req.headers['x-test-role'] || 'admin' };
    next();
  },
  requireRole: () => (req, res, next) => next(),
}));
jest.mock('../src/middleware/auditAdmin', () => ({ auditAdmin: (req, res, next) => next() }));
jest.mock('../src/utils/canonicalCity0410', () => ({ canonicalCityName: (s) => s, coordsOfLocation: () => null }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app;
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  app = express();
  app.use(express.json());
  app.use('/admin/requests0410', require('../src/routes/adminRequests0410'));
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

test('registre vide → total 0, liste vide', async () => {
  const r = await request(app).get('/admin/requests0410/reminders615').set(ADMIN);
  expect(r.status).toBe(200);
  expect(r.body).toMatchObject({ total: 0, failed: 0, schedulerOff: false, reminders: [] });
});

test('2 rappels (1 échoué) → comptés, triés du plus récent au plus ancien, sans e-mail', async () => {
  const Reminder = require('../src/models/ApplicationReminder615');
  const postId = new mongoose.Types.ObjectId();
  const ownerId = new mongoose.Types.ObjectId();
  await Reminder.create({ postId, slot: 'r1', ownerId, candidates: 2, serviceKind: 'walk', timeZone: 'Europe/Paris' });
  await Reminder.create({ postId, slot: 'r2', ownerId, candidates: 3, serviceKind: 'walk', timeZone: 'Europe/Paris', status: 'failed', error: 'x' });
  const r = await request(app).get('/admin/requests0410/reminders615?limit=1').set(ADMIN);
  expect(r.status).toBe(200);
  expect(r.body.total).toBe(2);
  expect(r.body.failed).toBe(1);
  expect(r.body.reminders).toHaveLength(1);
  expect(r.body.reminders[0].slot).toBe('r2');
  expect(JSON.stringify(r.body)).not.toMatch(/@/);
});
