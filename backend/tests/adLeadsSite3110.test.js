// 31/10/2026 (LEO, feu vert BOB 14 h 20) — POST /ad-leads/site : demande publiée en 1 étape depuis la
// page d'arrivée, sans compte ni mot de passe. VRAIE base Mongo en mémoire, vrai createPost, zone
// fictive (lat −35 / lng −30), aucun réseau (POSTAL_GEOCODE=off), aucun e-mail réel (emailService simulé).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.POSTAL_GEOCODE = 'off';
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => null), leadOwnerEmailLink: jest.fn(async (r, u, l) => l) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
const MAILS = [];
jest.mock('../src/services/emailService', () => ({
  sendEmail: jest.fn(async (to, subject, text, html) => { MAILS.push({ to, subject, text, html }); return { messageId: 'mock' }; }),
  sendTemplatedEmail: jest.fn(async () => ({})),
}));
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => { const id = req.headers['x-test-user']; if (!id) return res.status(401).json({ error: 'auth' }); req.user = { id, role: req.headers['x-test-role'] || 'owner' }; return next(); },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  optionalAuth: (req, res, next) => next(),
}));

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Post; let AdLead;
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const BASE = {
  email: 'camille.site3110@example.test', firstName: 'Camille', service: 'garde', animal: 'chien',
  city: 'Zone test', lat: -35, lng: -30, country: 'FR', lang: 'fr', startDate: '2026-11-20', endDate: '2026-11-23',
  campaign: 'paris_owners', page: '/garde-animaux/paris',
};
const post = (body) => request(app).post('/ad-leads/site').send(body);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Post = require('../src/models/Post');
  AdLead = require('../src/models/AdLead2210');
  await Promise.all([Owner.init(), Post.init(), AdLead.init()]);
  const routes = require('../src/routes/adLeads2210');
  app = express();
  app.use(express.json());
  app.use('/admin/ad-leads', routes.adminRouter);
  app.use('/ad-leads', routes);
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

test('création : compte propriétaire NON vérifié, demande publiée et visible, session, e-mail « en ligne » UNE fois, source site', async () => {
  const r = await post(BASE).expect(201);
  expect(r.body.existing).toBe(false);
  expect(r.body.id).toMatch(/^[a-f0-9]{32}$/);
  expect(r.body.postId).toMatch(/^[a-f0-9]{24}$/);
  const owner = await Owner.findOne({ email: BASE.email });
  expect(owner).toBeTruthy();
  expect(owner.verified).toBe(false); // règle de Daniel du 27/10 : prouvé seulement par un clic
  expect(owner.adLeadAt).toBeTruthy();
  expect(owner.currency).toBe('EUR');
  expect(jwt.verify(r.body.token, process.env.JWT_SECRET)).toMatchObject({ id: String(owner._id), role: 'owner' });
  expect(r.body.user).toMatchObject({ id: String(owner._id), role: 'owner' });
  const p = await Post.findById(r.body.postId).lean();
  expect(p).toBeTruthy();
  expect(String(p.ownerId)).toBe(String(owner._id));
  expect(p.status).toBe('open');
  expect(p.serviceTypes).toEqual(['house_sitting']);
  expect(p.location && p.location.city).toBe('Zone test');
  expect(new Date(p.startDate).toISOString().slice(0, 10)).toBe('2026-11-20');
  expect(new Date(p.endDate).toISOString().slice(0, 10)).toBe('2026-11-23');
  const lead = await AdLead.findById(r.body.id).lean();
  expect(lead.source).toBe('site');
  expect(lead.campaign).toBe('paris_owners');
  expect(lead.metaLeadId.startsWith('site:')).toBe(true);
  expect(lead.siteEmailAt).toBeTruthy();
  // e-mail : une fois, au bon destinataire, au « tu », lien d'ouverture de session (sans mot de passe)
  expect(MAILS.filter((m) => m.to === BASE.email)).toHaveLength(1);
  const m = MAILS[0];
  expect(m.subject).toContain('Camille, ta demande est en ligne');
  expect(m.text).toContain(`/posts/confirmer?l=${r.body.id}&next=%2Fposts&utm_source=site`);
  expect(m.text).toContain('72 h');
  expect(m.text).not.toMatch(/\bvous\b/i);
});

test('doublon e-mail : même demande, même propriétaire, pas de 2e compte ni de 2e e-mail', async () => {
  const first = await AdLead.findOne({ email: BASE.email }).lean();
  const r = await post({ ...BASE, firstName: 'Camille bis' }).expect(200);
  expect(r.body.existing).toBe(true);
  expect(r.body.postId).toBe(String(first.postId));
  expect(await Owner.countDocuments({ email: BASE.email })).toBe(1);
  expect(await Post.countDocuments({ ownerId: first.ownerId })).toBe(1);
  expect(MAILS.filter((m) => m.to === BASE.email)).toHaveLength(1);
  expect(jwt.verify(r.body.token, process.env.JWT_SECRET)).toMatchObject({ id: String(first.ownerId), role: 'owner' });
});

test('champ piège rempli → 400 ROBOT, rien créé', async () => {
  const before = await AdLead.countDocuments({});
  const r = await post({ ...BASE, email: 'robot.site3110@example.test', website: 'http://spam' }).expect(400);
  expect(r.body.code).toBe('ROBOT');
  expect(await AdLead.countDocuments({})).toBe(before);
  expect(await Owner.countDocuments({ email: 'robot.site3110@example.test' })).toBe(0);
});

test('e-mail invalide → 400 ; service manquant → 400 ; sans lieu → 400', async () => {
  expect((await post({ ...BASE, email: 'pas-un-mail' })).status).toBe(400);
  expect((await post({ ...BASE, email: 'x.site3110@example.test', service: 'yoga' })).body.code).toBe('SERVICE_REQUIRED');
  expect((await post({ ...BASE, email: 'y.site3110@example.test', city: '', postalCode: '', country: 'ZZ' })).body.code).toBe('PLACE_REQUIRED');
});

test('+test / staff refusés (403), rien créé', async () => {
  for (const email of ['dadaciao84+testowner@gmail.com', 'hopetsit@gmail.com', 'dadaciao84@gmail.com', 'probe-565@invalid.example']) {
    // eslint-disable-next-line no-await-in-loop
    const r = await post({ ...BASE, email });
    expect(r.status).toBe(403);
    expect(r.body.code).toBe('TEST_ACCOUNT');
  }
  expect(await Owner.countDocuments({ email: /\+test|hopetsit@|dadaciao84@|probe-/ })).toBe(0);
});

test('limiteur par e-mail : au-delà de 3 envois en 10 min → 429', async () => {
  const email = 'limite.site3110@example.test';
  // 1er = création (201), 2e et 3e = doublon (200), 4e = 429
  expect((await post({ ...BASE, email })).status).toBe(201);
  expect((await post({ ...BASE, email })).status).toBe(200);
  expect((await post({ ...BASE, email })).status).toBe(200);
  const r = await post({ ...BASE, email });
  expect(r.status).toBe(429);
  expect(r.body.code).toBe('TOO_MANY');
});

test('sans dates → demande « dates à prévoir » ; promenade / visites → bons services ; EN New York → anglais', async () => {
  const a = await post({ ...BASE, email: 'tbd.site3110@example.test', startDate: '', endDate: '', service: 'promenade' }).expect(201);
  const pa = await Post.findById(a.body.postId).lean();
  expect(pa.dateMode).toBe('tbd');
  expect(pa.serviceTypes).toEqual(['dog_walking']);
  const b = await post({ ...BASE, email: 'ny.site3110@example.test', service: 'visites', visitsPerDay: 2, country: 'US', lang: 'en', city: 'Zone test', campaign: 'nyc_owners', page: '/pet-sitting/new-york' }).expect(201);
  const pb = await Post.findById(b.body.postId).lean();
  expect(pb.serviceTypes).toEqual(['home_visit']);
  expect(pb.visitsPerDay).toBe(2);
  const ob = await Owner.findOne({ email: 'ny.site3110@example.test' }).lean();
  expect(ob.currency).toBe('USD');
  const m = MAILS.find((x) => x.to === 'ny.site3110@example.test');
  expect(m.subject).toContain('your request is live');
  expect(m.text).toContain('See my request');
});

test('« Réserver <prénom> » : prestataire ciblé → la demande le porte (prévenu en premier) ; cible inconnue ignorée', async () => {
  const Sitter = require('../src/models/Sitter');
  const sitter = await Sitter.create({ name: 'Zoé Test', email: 'zoe.cible3110@example.test', password: 'Hopetsit2026!', city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: { lat: -35.01, lng: -30.01 }, acceptedTerms: true });
  const r = await post({ ...BASE, email: 'cible.site3110@example.test', targetProvider: { role: 'sitter', id: String(sitter._id) } }).expect(201);
  const p = await Post.findById(r.body.postId).lean();
  expect(p.targetProvider && String(p.targetProvider.id)).toBe(String(sitter._id));
  expect(p.targetProvider.role).toBe('sitter');
  const lead = await AdLead.findById(r.body.id).lean();
  expect(lead.targetRole).toBe('sitter');
  const r2 = await post({ ...BASE, email: 'cible2.site3110@example.test', targetProvider: { role: 'sitter', id: 'ffffffffffffffffffffffff' } }).expect(201);
  const p2 = await Post.findById(r2.body.postId).lean();
  expect(p2.targetProvider == null || !p2.targetProvider.id).toBe(true);
});

test('position : code postal sans réseau → repli centre de la ville du pays (jamais sans position)', async () => {
  const r = await post({ ...BASE, email: 'cp.site3110@example.test', city: '', lat: undefined, lng: undefined, postalCode: '75011' }).expect(201);
  const lead = await AdLead.findById(r.body.id).lean();
  expect(lead.postalCode).toBe('75011');
  expect(lead.city).toBe('Paris');
  expect(lead.lat).toBeCloseTo(48.8566, 2);
});

test('les stats admin de la pub ignorent les contacts du site', async () => {
  const s = await request(app).get('/admin/ad-leads/stats?days=7').set(ADMIN).expect(200);
  expect(s.body.d7).toBe(0);
  expect(s.body.total).toBe(0);
  expect(s.body.site).toBeGreaterThanOrEqual(4);
});
