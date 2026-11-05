// 05/11/2026 (SAM, décision de Daniel du 05/11 — plan PLAN_PUB_0511.md, bloc A2) — POST /ad-leads/thanks/confirm :
// la page de remerciement du formulaire Meta publie la demande du contact sans passer par la boîte mail.
// VRAIE base Mongo en mémoire, vrai createPost, zone fictive (lat −35 / lng −30), aucun réseau, aucun e-mail réel.
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

let mongo; let app; let Owner; let Post; let AdLead; let thanks;
const BROWSER = { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Safari/604.1' };
const SCRIPT = { 'User-Agent': 'python-requests/2.32' };
/** Contact tel que leads_suivi.py l'enregistre (POST /admin/ad-leads) puis le met en brouillon (/draft). */
const META_LEAD = (over = {}) => ({
  metaLeadId: `meta_${Math.random().toString(16).slice(2)}`,
  email: 'Jeanne.Thanks0511@example.test', firstName: 'Jeanne', city: 'Zone test', lat: -35, lng: -30,
  country: 'FR', lang: 'fr', service: 'garde', animal: 'chien', quand: 'bientot', pendingConfirm: true, ...over,
});
const post = (body, headers = BROWSER, ip) => {
  let r = request(app).post('/ad-leads/thanks/confirm').set(headers);
  if (ip) r = r.set('X-Forwarded-For', ip);
  return r.send(body);
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Post = require('../src/models/Post');
  AdLead = require('../src/models/AdLead2210');
  await Promise.all([Owner.init(), Post.init(), AdLead.init()]);
  const routes = require('../src/routes/adLeads2210');
  thanks = require('../src/routes/adLeadsThanks0511');
  app = express();
  app.set('trust proxy', 1);
  app.use(express.json());
  // Même ordre que app.js : /ad-leads/thanks AVANT /ad-leads.
  app.use('/ad-leads/thanks', thanks);
  app.use('/admin/ad-leads', routes.adminRouter);
  app.use('/ad-leads', routes);
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(() => thanks._resetForTest());

test('garde-fous : e-mail invalide 400, adresse de test 403, script 403 — rien publié', async () => {
  expect((await post({ email: 'pas-un-email' })).status).toBe(400);
  expect((await post({ email: 'dadaciao84+testowner@gmail.com' })).status).toBe(403);
  const s = await post({ email: 'jeanne.thanks0511@example.test' }, SCRIPT);
  expect(s.status).toBe(403);
  expect(s.body.code).toBe('SCRIPT');
  const noUa = await post({ email: 'jeanne.thanks0511@example.test' }, {});
  expect(noUa.status).toBe(403); // sans User-Agent = script
  expect(await Post.countDocuments()).toBe(0);
  expect(await Owner.countDocuments()).toBe(0);
});

test('aucun contact pub encore relevé → 202 { pending } ; rien créé', async () => {
  const r = await post({ email: 'inconnue.thanks0511@example.test', city: 'paris' });
  expect(r.status).toBe(202);
  expect(r.body).toEqual({ pending: true });
  expect(await Owner.countDocuments()).toBe(0);
  expect(await Post.countDocuments()).toBe(0);
});

test('le contact existe (< 24 h, brouillon) : publication, compte vérifié, session ; 2e appui = la même demande', async () => {
  const ns = require('../src/services/notificationSender');
  const lead = await AdLead.create(META_LEAD());
  // Insensible à la casse + espaces : l'adresse tapée par la personne sur la page.
  const r = await post({ email: '  JEANNE.thanks0511@Example.test ', city: 'paris' });
  expect(r.status).toBe(200);
  expect(r.body.leadId).toBe(String(lead._id));
  expect(r.body.postId).toMatch(/^[a-f0-9]{24}$/);
  expect(r.body.existing).toBe(false);
  expect(r.body.user).toMatchObject({ email: 'jeanne.thanks0511@example.test', role: 'owner' });
  const owner = await Owner.findOne({ email: 'jeanne.thanks0511@example.test' });
  expect(owner).toBeTruthy();
  expect(jwt.verify(r.body.token, process.env.JWT_SECRET)).toMatchObject({ id: String(owner._id), role: 'owner' });
  // Décision de Daniel 05/11 : pour un contact Meta, l'appui vaut confirmation de la boîte.
  expect(owner.verified).toBe(true);
  expect(owner.emailProofSource).toBe('thanks_web');
  expect(owner.emailProvenAt).toBeTruthy();
  const p = await Post.findById(r.body.postId).lean();
  expect(String(p.ownerId)).toBe(String(owner._id));
  expect(p.status).toBe('open');
  expect(p.serviceTypes).toEqual(['house_sitting']);
  expect(p.location && p.location.city).toBe('Zone test');
  const l = await AdLead.findById(lead._id).lean();
  expect(String(l.postId)).toBe(r.body.postId);
  expect(l.pendingConfirm).toBe(false);
  expect(l.confirmedAt).toBeTruthy();
  expect(l.clickedAt).toBeTruthy();
  expect(l.page).toBe('/posts/merci'); // marque « publié depuis la page de remerciement » (mesure)
  expect(MAILS).toHaveLength(0); // aucun e-mail envoyé par cette route
  // 2e appui sur le bouton : même demande, même propriétaire, pas de 2e annonce ni de 2e compte.
  const nBefore = ns.sendNotification.mock.calls.length;
  const r2 = await post({ email: 'jeanne.thanks0511@example.test' });
  expect(r2.status).toBe(200);
  expect(r2.body.postId).toBe(r.body.postId);
  expect(r2.body.existing).toBe(true);
  expect(jwt.verify(r2.body.token, process.env.JWT_SECRET)).toMatchObject({ id: String(owner._id) });
  expect(await Post.countDocuments({ ownerId: owner._id })).toBe(1);
  expect(await Owner.countDocuments({ email: 'jeanne.thanks0511@example.test' })).toBe(1);
  expect(ns.sendNotification.mock.calls.length).toBe(nBefore);
  // Le lien de l'e-mail (/ad-leads/:id/confirm) reste idempotent après coup : même demande.
  const c = await request(app).post(`/ad-leads/${lead._id}/confirm`).set(BROWSER).send({}).expect(200);
  expect(c.body.postId).toBe(r.body.postId);
});

test('contact de plus de 24 h → 202 pending (le lien de l\'e-mail reste la voie) ; brouillon du SITE ignoré', async () => {
  await AdLead.create(META_LEAD({ email: 'vieux.thanks0511@example.test', createdAt: new Date(Date.now() - 25 * 3600 * 1000) }));
  const r = await post({ email: 'vieux.thanks0511@example.test' });
  expect(r.status).toBe(202);
  expect(await Owner.countDocuments({ email: 'vieux.thanks0511@example.test' })).toBe(0);
  // Brouillon venu du site (sécurité du 31/10 : compte existant, publication seulement au clic e-mail) : jamais ici.
  await AdLead.create(META_LEAD({ email: 'site.thanks0511@example.test', source: 'site', metaLeadId: 'site:abc' }));
  const s = await post({ email: 'site.thanks0511@example.test' });
  expect(s.status).toBe(202);
  expect(await Post.countDocuments({ 'location.city': 'Zone test' })).toBe(1); // seule la demande de Jeanne
});

test('limiteur : 5 essais par IP sur 10 min, le 6e répond 429 ; une autre IP passe', async () => {
  for (let i = 0; i < 5; i += 1) {
    expect((await post({ email: `essai${i}.thanks0511@example.test` }, BROWSER, '203.0.113.7')).status).toBe(202);
  }
  const r = await post({ email: 'essai5.thanks0511@example.test' }, BROWSER, '203.0.113.7');
  expect(r.status).toBe(429);
  expect(r.body.code).toBe('TOO_MANY');
  expect((await post({ email: 'essai6.thanks0511@example.test' }, BROWSER, '203.0.113.8')).status).toBe(202);
});

test('createPost refuse → son code d\'erreur remonte tel quel, aucune session, contact non publié', async () => {
  const pc = require('../src/controllers/postController');
  const spy = jest.spyOn(pc, 'createPost').mockImplementationOnce(async (req, res) => res.status(400).json({ error: 'DATES_INVALID' }));
  const lead = await AdLead.create(META_LEAD({ email: 'refus.thanks0511@example.test' }));
  const r = await post({ email: 'refus.thanks0511@example.test' });
  expect(spy).toHaveBeenCalledTimes(1);
  expect(r.status).toBe(400);
  expect(r.body.error).toBe('DATES_INVALID');
  expect(r.body.token).toBeUndefined();
  expect((await AdLead.findById(lead._id).lean()).postId).toBeFalsy();
  expect((await Owner.findOne({ email: 'refus.thanks0511@example.test' })).verified).toBe(false); // rien prouvé sans publication
  spy.mockRestore();
});
