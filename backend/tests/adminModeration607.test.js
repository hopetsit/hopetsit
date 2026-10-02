// 607 (ADA, 02/10/2026) — épingles PawMap signalées : détail complet + « Masquer ».
// Vraie base Mongo en mémoire, vraies routes ; seule l'authentification est simulée.
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

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let MapReport; let AdminAuditLog;
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  MapReport = require('../src/models/MapReport');
  AdminAuditLog = require('../src/models/AdminAuditLog');
  await Promise.all([Owner.init(), Sitter.init(), MapReport.init()]);
  app = express();
  app.use(express.json());
  app.use('/admin/moderation607', require('../src/routes/adminModeration607'));
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

async function pin(extra = {}) {
  const author = await Owner.create({ name: 'Camille Durand', email: `auteur${Date.now()}@example.org`, password: 'MotDePasse607!' });
  const flagger = await Sitter.create({ name: 'Paul Martin', email: `flag${Date.now()}@example.org`, password: 'MotDePasse607!' });
  return MapReport.create({
    type: 'lost_pet', note: 'Chien perdu près du parc', location: { type: 'Point', coordinates: [-30, -35], city: 'Zone test' },
    reporterId: author._id, reporterModel: 'Owner',
    flags: [{ userId: flagger._id, userModel: 'Sitter', reason: 'spam', at: new Date('2026-05-24T10:00:00Z') }],
    ...extra,
  });
}

describe('épingles signalées', () => {
  test('401 sans jeton, 403 pour un non-admin', async () => {
    await request(app).get('/admin/moderation607/flagged-map-reports').expect(401);
    await request(app).get('/admin/moderation607/flagged-map-reports').set({ 'x-test-user': 'u', 'x-test-role': 'owner' }).expect(403);
  });

  test('détail complet : texte, position, auteur « Prénom I. », motifs et qui a signalé, sans e-mail', async () => {
    const p = await pin();
    await MapReport.create({ type: 'lost_pet', location: { type: 'Point', coordinates: [-30, -35] }, reporterId: p.reporterId, reporterModel: 'Owner' });
    const r = await request(app).get('/admin/moderation607/flagged-map-reports').set(ADMIN).expect(200);
    expect(r.body.items).toHaveLength(1); // l'épingle non signalée n'apparaît pas
    const it = r.body.items[0];
    expect(it).toMatchObject({ id: String(p._id), type: 'lost_pet', note: 'Chien perdu près du parc', lat: -35, lng: -30, hidden: false });
    expect(it.author).toMatchObject({ name: 'Camille D.', role: 'owner' });
    expect(it.flags).toEqual([expect.objectContaining({ reason: 'spam', by: expect.objectContaining({ name: 'Paul M.', role: 'sitter' }) })]);
    expect(JSON.stringify(r.body)).not.toMatch(/@/);
  });

  test('Masquer : épingle masquée, signalements gardés, action journalisée ; 404 et 400', async () => {
    const p = await pin();
    await request(app).post(`/admin/moderation607/map-reports/${p._id}/hide`).set(ADMIN).expect(200);
    const after = await MapReport.findById(p._id).lean();
    expect(after.hidden).toBe(true);
    expect(after.flags).toHaveLength(1);
    await new Promise((ok) => setTimeout(ok, 200));
    expect(await AdminAuditLog.countDocuments({ method: 'POST', path: { $regex: 'hide' } })).toBe(1);
    await request(app).post(`/admin/moderation607/map-reports/${new mongoose.Types.ObjectId()}/hide`).set(ADMIN).expect(404);
    await request(app).post('/admin/moderation607/map-reports/abc/hide').set(ADMIN).expect(400);
    await request(app).post(`/admin/moderation607/map-reports/${p._id}/hide`).set({ 'x-test-user': 'u', 'x-test-role': 'owner' }).expect(403);
  });
});
