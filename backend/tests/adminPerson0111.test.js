// 0111 (ADA) — règle de Daniel du 31/10 « toujours les 3 profils » dans l'admin :
// (a) recherche d'utilisateurs = appareils de la PERSONNE, (b) « Dernière connexion » = une ligne par
// personne avec ses rôles, (c) listes Utilisateurs : « vérifié » si l'un des profils l'est.
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
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => ({ ok: true })) }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let Walker; let ActivityEvent;
const ADMIN = { 'x-test-user': 'admin1', 'x-test-role': 'admin' };
const PW = 'MotDePasse0111!';
let caroleO; let caroleS; let caroleW; let solo;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  ActivityEvent = require('../src/models/ActivityEvent');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), ActivityEvent.init()]);
  app = express(); app.use(express.json());
  app.use('/admin', require('../src/routes/adminRoutes'));
  // Carole : 3 profils au même e-mail. Téléphone iOS sur le profil propriétaire seulement,
  // le même jeton aussi sur le profil gardien (même téléphone), un Android sur le promeneur.
  // Seul le profil gardien porte verified:true (synchro passée à côté).
  caroleO = await Owner.create({ name: 'Carole0111', email: 'carole0111@example.org', password: PW, verified: false,
    fcmTokens: ['tokA'], fcmDevices: [{ token: 'tokA', platform: 'ios', at: new Date() }] });
  caroleS = await Sitter.create({ name: 'Carole0111', email: 'carole0111@example.org', password: PW, verified: true,
    fcmTokens: ['tokA'], fcmDevices: [{ token: 'tokA', platform: 'ios', at: new Date() }] });
  caroleW = await Walker.create({ name: 'Carole0111', email: 'carole0111@example.org', password: PW, verified: false,
    fcmTokens: ['tokB'], fcmDevices: [{ token: 'tokB', platform: 'android', at: new Date() }] });
  solo = await Owner.create({ name: 'Solo0111', email: 'solo0111@example.org', password: PW, verified: false });
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

describe('(a) GET /admin/users/search — appareils de la personne', () => {
  test('chaque profil de Carole affiche 2 appareils distincts (iOS + Android), pas son seul profil', async () => {
    const r = await request(app).get('/admin/users/search?q=Carole0111').set(ADMIN);
    expect(r.status).toBe(200);
    expect(r.body.results).toHaveLength(3);
    for (const u of r.body.results) {
      expect(u.devices).toBe(2); // tokA compté une seule fois
      expect(u.platforms.sort()).toEqual(['android', 'ios']);
      expect(u.roles).toEqual(['owner', 'sitter', 'walker']);
      expect(u.fcmTokens).toBeUndefined();
    }
    const own = Object.fromEntries(r.body.results.map((u) => [u.role, u.profileDevices]));
    expect(own).toEqual({ owner: 1, sitter: 1, walker: 1 });
  });
  test('une personne à un seul profil garde ses chiffres', async () => {
    const r = await request(app).get('/admin/users/search?q=Solo0111').set(ADMIN);
    expect(r.body.results).toHaveLength(1);
    expect(r.body.results[0]).toMatchObject({ devices: 0, platforms: [], roles: ['owner'] });
  });
});

describe('(c) listes Utilisateurs — vérifié par personne', () => {
  test('/owners, /sitters, /walkers : person.verified vrai pour les 3 profils de Carole, faux pour Solo', async () => {
    const [o, s, w] = await Promise.all(['owners', 'sitters', 'walkers'].map((p) => request(app).get(`/admin/${p}?limit=1000`).set(ADMIN)));
    const co = o.body.owners.find((u) => String(u._id) === String(caroleO._id));
    const cs = s.body.sitters.find((u) => String(u._id) === String(caroleS._id));
    const cw = w.body.walkers.find((u) => String(u._id) === String(caroleW._id));
    for (const u of [co, cs, cw]) expect(u.person).toMatchObject({ verified: true, devices: 2, roles: ['owner', 'sitter', 'walker'] });
    expect(co.verified).toBe(false); // le champ du profil n'est pas réécrit
    const so = o.body.owners.find((u) => String(u._id) === String(solo._id));
    expect(so.person).toMatchObject({ verified: false, devices: 0, roles: ['owner'] });
  });
});

describe('(b) GET /admin/activity — une ligne par personne', () => {
  test('Carole connectée en propriétaire puis en promeneur = 1 ligne, ses rôles, dernière connexion la plus récente, sessions additionnées', async () => {
    const now = Date.now();
    await ActivityEvent.create([
      { userId: String(caroleO._id), role: 'owner', at: new Date(now - 3 * 3600e3), origin: 'app', platform: 'ios', city: 'Paris' },
      { userId: String(caroleO._id), role: 'owner', at: new Date(now - 2 * 3600e3), origin: 'app', platform: 'ios', city: 'Paris' },
      { userId: String(caroleW._id), role: 'walker', at: new Date(now - 1 * 3600e3), origin: 'app', platform: 'android', city: 'Vanves' },
      { userId: String(solo._id), role: 'owner', at: new Date(now - 5 * 3600e3), origin: 'web', platform: '' },
      { userId: String(caroleS._id), role: 'sitter', at: new Date(now - 10 * 60e3), origin: 'script' }, // nos scripts : jamais
    ]);
    const r = await request(app).get('/admin/activity?days=7').set(ADMIN);
    expect(r.status).toBe(200);
    const carole = r.body.users.filter((u) => u.name === 'Carole0111');
    expect(carole).toHaveLength(1);
    expect(carole[0]).toMatchObject({ roles: ['owner', 'sitter', 'walker'], sessions: 3, platform: 'android', city: 'Vanves', role: 'walker' });
    expect(new Date(carole[0].lastAt).getTime()).toBe(now - 3600e3);
    expect(carole[0].userIds.sort()).toEqual([String(caroleO._id), String(caroleW._id)].sort());
    expect(r.body.users.filter((u) => u.name === 'Solo0111')).toHaveLength(1);
    expect(r.body.users.map((u) => u.name)).toEqual(['Carole0111', 'Solo0111']); // du plus récent au plus ancien
  });
  test('le détail d\'une ligne donne les sessions de la personne (tous profils)', async () => {
    const r = await request(app).get(`/admin/activity/${caroleO._id}`).set(ADMIN);
    expect(r.status).toBe(200);
    const roles = new Set(r.body.sessions.map((x) => x.role));
    expect(roles.has('owner')).toBe(true);
    expect(roles.has('walker')).toBe(true);
    expect(r.body.sessions.length).toBe(4); // 2 owner + 1 walker + 1 script du gardien (historique brut)
  });
});
