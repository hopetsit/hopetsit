// 0511 (BOB) — « qu'est-ce qui vous retient ? » en 1 clic : lien signé par demande, page 4 boutons,
// réponse enregistrée (la dernière gagne, historique gardé), mauvais tag = 404, admin protégé.
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
jest.mock('../src/middleware/auditAdmin', () => ({ auditAdmin: (req, res, next) => next() }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let routes;
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const OWNER = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'owner' };

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  routes = require('../src/routes/ownerWhy0511');
  app = express();
  app.use(express.json());
  app.use('/owner-why', routes);
  app.use('/admin/owner-why', routes.adminRouter);
}, 60000);

afterAll(async () => { await mongoose.disconnect(); await mongo.stop(); });

test('admin : lien signé ; public : page 4 boutons, réponse enregistrée, dernière réponse gagne', async () => {
  const postId = String(new mongoose.Types.ObjectId());
  expect((await request(app).post('/admin/owner-why/link').set(OWNER).send({ postId })).status).toBe(403);
  const l = await request(app).post('/admin/owner-why/link').set(ADMIN).send({ postId, lang: 'fr' });
  expect(l.status).toBe(200);
  expect(l.body.url).toContain(`/owner-why?p=${postId}&t=${routes.tagFor(postId)}`);
  const path = l.body.url.replace(/^https?:\/\/[^/]+/, '');
  const page = await request(app).get(path);
  expect(page.status).toBe(200);
  expect(page.text).toContain('Qu&#39;est-ce qui vous retient ?'.replace('&#39;', '\''));
  expect(page.text).toContain('a=price'); expect(page.text).toContain('a=talk');
  // mauvais tag → 404, rien d'enregistré
  expect((await request(app).get(`/owner-why/answer?p=${postId}&t=deadbeefdeadbeef&a=price`)).status).toBe(404);
  expect(await routes.OwnerWhy.countDocuments({})).toBe(0);
  const a1 = await request(app).get(`/owner-why/answer?p=${postId}&t=${routes.tagFor(postId)}&a=price&lang=fr`);
  expect(a1.status).toBe(200); expect(a1.text).toContain('Merci');
  const a2 = await request(app).get(`/owner-why/answer?p=${postId}&t=${routes.tagFor(postId)}&a=talk&lang=en`);
  expect(a2.status).toBe(200); expect(a2.text).toContain('See my candidates');
  const docs = await routes.OwnerWhy.find({}).lean();
  expect(docs).toHaveLength(1);
  expect(docs[0].answer).toBe('talk'); expect(docs[0].history).toHaveLength(2);
  const list = await request(app).get('/admin/owner-why').set(ADMIN);
  expect(list.status).toBe(200); expect(list.body.counts).toEqual({ talk: 1 });
  expect((await request(app).get('/admin/owner-why').set(OWNER)).status).toBe(403);
  // réponse inconnue → 404
  expect((await request(app).get(`/owner-why/answer?p=${postId}&t=${routes.tagFor(postId)}&a=foo`)).status).toBe(404);
});
