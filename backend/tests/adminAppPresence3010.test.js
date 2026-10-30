// 3010 (ADA, 30/10) — GET /admin/app-presence : total des personnes inscrites, connectés maintenant, actifs 24 h / 7 j (sessions réelles),
// app installée (jeton push), personnes dédoublonnées par e-mail, test/staff/bloqués exclus. Lecture seule.
// Vraie base Mongo en mémoire, vraie route ; authentification et sockets simulés.
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
const mockOnline = new Set();
jest.mock('../src/sockets/emitter', () => ({ getOnlineUserIds: jest.fn(async () => mockOnline) }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let Walker; let ActivityEvent; let AccountDeletion;
const ADMIN = { 'x-test-user': 'admin1', 'x-test-role': 'admin' };
const DAY = 86400000;
let n = 0;
const mk = (M, extra = {}) => { n += 1; return M.create({ name: `P${n}`, email: `presence_${n}@example.org`, password: 'MotDePasse3010!', ...extra }); };
const ev = (userId, agoMs, extra = {}) => ActivityEvent.create({ userId: String(userId), role: 'owner', at: new Date(Date.now() - agoMs), origin: 'app', appVersion: '630', ...extra });
const PUSH = [{ token: 'tok_' + Math.random(), platform: 'ios' }];

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  ActivityEvent = require('../src/models/ActivityEvent'); AccountDeletion = require('../src/models/AccountDeletion').AccountDeletion;
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), ActivityEvent.init(), AccountDeletion.init()]);
  app = express(); app.use(express.json());
  app.use('/admin/app-presence', require('../src/routes/adminAppPresence3010'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

describe('GET /admin/app-presence', () => {
  test('refuse sans admin', async () => {
    expect((await request(app).get('/admin/app-presence')).status).toBe(401);
    expect((await request(app).get('/admin/app-presence').set({ 'x-test-user': 'u1', 'x-test-role': 'owner' })).status).toBe(403);
  });

  test('compte des PERSONNES (e-mail), exclut test / staff / bloqués, variation = fenêtre précédente', async () => {
    // Alice : 2 profils (owner + sitter, même e-mail), app installée, active aujourd'hui et il y a 10 j, en ligne via son profil sitter
    const aliceO = await mk(Owner, { email: 'alice@example.org', fcmDevices: PUSH });
    const aliceS = await mk(Sitter, { email: 'alice@example.org' });
    await ev(aliceO._id, 2 * 3600000); await ev(aliceS._id, 3 * 3600000); await ev(aliceO._id, 10 * DAY);
    mockOnline.add(String(aliceS._id));
    // Bob : actif hier seulement (24-48 h), pas d'app
    const bob = await mk(Owner, { email: 'bob@example.org' });
    await ev(bob._id, 30 * 3600000);
    // Carla : session « script » seulement aujourd'hui → pas active ; app installée
    const carla = await mk(Walker, { email: 'carla@example.org', fcmDevices: PUSH });
    await ev(carla._id, 3600000, { origin: 'script' });
    // Exclus : compte de test, équipe, bloqué — tous en ligne, actifs et avec l'app
    const t = await mk(Owner, { email: 'quelquun+test@example.org', fcmDevices: PUSH });
    const st = await mk(Sitter, { email: 'staff@example.org', isStaff: true, fcmDevices: PUSH });
    const ban = await mk(Walker, { email: 'banni@example.org', status: 'banned', fcmDevices: PUSH });
    for (const d of [t, st, ban]) { await ev(d._id, 3600000); mockOnline.add(String(d._id)); }
    // Dan : bloqué sur un profil, actif sur l'autre → exclu en tant que personne
    const danO = await mk(Owner, { email: 'dan@example.org', status: 'suspended' });
    const danS = await mk(Sitter, { email: 'dan@example.org', fcmDevices: PUSH });
    await ev(danS._id, 3600000); mockOnline.add(String(danS._id)); void danO;

    // Mouvements : Dan (exclu) et un ancien compte créé il y a 10 j ne comptent pas comme arrivées du jour ;
    // 2 suppressions de la même personne aujourd'hui = 1 départ ; une 3e il y a 3 jours → 2 sur 7 j.
    await mk(Owner, { email: 'ancien@example.org', createdAt: new Date(Date.now() - 10 * DAY) });
    await AccountDeletion.collection.insertMany([
      { role: 'owner', emailHash: 'h1', deletedAt: new Date(Date.now() - 3600000) },
      { role: 'sitter', emailHash: 'h1', deletedAt: new Date(Date.now() - 3500000) },
      { role: 'walker', emailHash: 'h2', deletedAt: new Date(Date.now() - 3 * DAY) },
    ]);
    const r = await request(app).get('/admin/app-presence').set(ADMIN);
    expect(r.status).toBe(200);
    expect(r.body.today).toEqual({ joined: 3, left: 1 });   // Alice, Bob, Carla créés à l'instant
    expect(r.body.week).toEqual({ joined: 3, left: 2 });
    expect(r.body.total).toBe(4);           // + l'ancien compte
    expect(r.body.online).toBe(1);          // Alice seulement
    expect(r.body.active24h).toBe(1);       // Alice (2 profils = 1 personne) ; Bob hier, Carla script
    expect(r.body.active7d).toBe(2);        // Alice + Bob
    expect(r.body.installed).toBe(2);       // Alice + Carla
    expect(r.body.previous).toEqual({ active24h: 1, active7d: 1 }); // 24-48 h : Bob · 7-14 j : Alice
    expect(r.body.excludedPeople).toBe(4);  // +test, staff, banni, Dan
    expect(JSON.stringify(r.body)).not.toMatch(/@example\.org/);
    expect(r.body.basis.active).toMatch(/ActivityEvent/);
  });
});
