// 04/11 (BOB) — POST /admin/users/:role/:id/password : remplace le mot de passe sur les
// 3 profils de la personne, toujours chiffré, jamais renvoyé. Vraie base en mémoire.
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

let mongo; let app; let Owner; let Sitter; let Walker;
const ADMIN = { 'x-test-user': 'admin1', 'x-test-role': 'admin' };
const setPwd = (role, id, password) => request(app).post(`/admin/users/${role}/${id}/password`).set(ADMIN).send({ password });

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init()]);
  app = express();
  app.use(express.json());
  app.use('/admin', require('../src/routes/adminRoutes'));
});
afterAll(async () => { await mongoose.disconnect(); await mongo.stop(); });

test('remplace le mot de passe sur les profils de la même personne, chiffré', async () => {
  const email = 'kathy0411@example.org';
  const s = await Sitter.create({ name: 'Kathy', email, password: 'AncienMdp0411!' });
  const w = await Walker.create({ name: 'Kathy', email, password: 'AncienMdp0411!' });
  const other = await Walker.create({ name: 'Autre', email: 'autre0411@example.org', password: 'AutreMdp0411!' });
  const r = await setPwd('sitter', s._id, 'NouveauMdp0411');
  expect(r.status).toBe(200);
  expect(r.body.profiles).toEqual({ owner: 0, sitter: 1, walker: 1 });
  expect(JSON.stringify(r.body)).not.toContain('NouveauMdp0411');
  const s2 = await Sitter.findById(s._id);
  const w2 = await Walker.findById(w._id);
  expect(s2.password).not.toBe('NouveauMdp0411');
  expect(await s2.comparePassword('NouveauMdp0411')).toBe(true);
  expect(await w2.comparePassword('NouveauMdp0411')).toBe(true);
  expect(await w2.comparePassword('AncienMdp0411!')).toBe(false);
  const o2 = await Walker.findById(other._id);
  expect(await o2.comparePassword('AutreMdp0411!')).toBe(true);
});

test('refuse un mot de passe trop court, un rôle ou un id inconnu', async () => {
  const s = await Sitter.create({ name: 'Z', email: 'court0411@example.org', password: 'AncienMdp0411!' });
  expect((await setPwd('sitter', s._id, 'court')).status).toBe(400);
  expect((await setPwd('admin', s._id, 'NouveauMdp0411')).status).toBe(400);
  expect((await setPwd('sitter', new mongoose.Types.ObjectId(), 'NouveauMdp0411')).status).toBe(404);
  expect(await (await Sitter.findById(s._id)).comparePassword('AncienMdp0411!')).toBe(true);
});
