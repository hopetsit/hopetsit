// 08/11/2026 (NEO, ordre de Daniel 16 h 45) — page /demande : la demande est publiée dès que le CODE reçu par e-mail
// est tapé sur la page (POST /ad-leads/site { codeFlow } → /ad-leads/code/check). Règle du 31/10 maintenue : rien n'est
// publié sans e-mail vérifié. VRAIE base Mongo en mémoire, vrai createPost, zone fictive (lat −35 / lng −30), aucun
// réseau (POSTAL_GEOCODE=off), aucun e-mail réel (emailService simulé).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.POSTAL_GEOCODE = 'off';
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => null), leadOwnerEmailLink: jest.fn(async (r, u, l) => `${l}?k=signed`) }));
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

let mongo; let app; let Owner; let Post; let AdLead; let VerificationCode;
const D = (n) => new Date(Date.now() + n * 86400000).toISOString().slice(0, 10);
const BASE = {
  email: 'lea.demande0811@example.test', firstName: 'Léa', service: 'garde', animal: 'chat',
  city: 'Zone test', postalCode: '75015', lat: -35, lng: -30, country: 'FR', lang: 'fr', startDate: D(10), endDate: D(12),
  campaign: 'paris_owners', page: '/demande', codeFlow: true,
};
const site = (body) => request(app).post('/ad-leads/site').send(body);
const send = (id) => request(app).post('/ad-leads/code/send').send({ id });
const check = (id, code) => request(app).post('/ad-leads/code/check').send({ id, code });
const lastMail = () => MAILS[MAILS.length - 1];
const codeOf = (mail) => { const m = /\b(\d{6})\b/.exec(mail.text); return m ? m[1] : ''; };

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Post = require('../src/models/Post');
  AdLead = require('../src/models/AdLead2210');
  VerificationCode = require('../src/models/VerificationCode');
  await Promise.all([Owner.init(), Post.init(), AdLead.init(), VerificationCode.init()]);
  const routes = require('../src/routes/adLeads2210');
  app = express();
  app.use(express.json());
  app.use('/ad-leads', routes);
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(() => { require('../src/routes/adLeadsSite3110')._resetForTest(); require('../src/routes/demandeCode0811')._resetForTest(); });

test('nouveau contact : 202, compte NON vérifié, rien publié, UN e-mail avec un code à 6 chiffres ET le bouton « Confirmer et publier »', async () => {
  const before = MAILS.length;
  const r = await site(BASE).expect(202);
  expect(r.body.pending).toBe(true);
  expect(r.body.code).toBe(true);
  expect(r.body.token).toBeUndefined();
  expect(r.body.id).toMatch(/^[a-f0-9]{32}$/);
  expect(MAILS.length).toBe(before + 1);
  const mail = lastMail();
  expect(mail.to).toBe(BASE.email);
  expect(codeOf(mail)).toMatch(/^\d{6}$/);
  expect(mail.subject).toContain(codeOf(mail));
  expect(mail.text).toContain(`/posts/confirmer?l=${r.body.id}`); // filet : le même bouton que l'e-mail actuel
  expect(mail.html).toContain('Confirmer et publier');
  const owner = await Owner.findOne({ email: BASE.email });
  expect(owner.verified).toBe(false);
  expect(await Post.countDocuments({ ownerId: owner._id })).toBe(0);
  const lead = await AdLead.findById(r.body.id).lean();
  expect(lead.pendingConfirm).toBe(true);
  expect(lead.confirmEmailAt).toBeTruthy(); // le rappel +3 h (adLeadConfirmReminder3110) prend le relais si la page est fermée
  expect(lead.postId).toBeFalsy();
  const rec = await VerificationCode.findOne({ email: BASE.email, purpose: 'email_verification' }).lean();
  expect(rec).toBeTruthy();
  expect(rec.code).not.toBe(codeOf(mail)); // haché
});

test('mauvais code → 400 CODE_INVALID (rien publié) ; bon code → publié, vérifié (3 profils), session + lien signé', async () => {
  const ns = require('../src/services/notificationSender');
  const id = (await AdLead.findOne({ email: BASE.email }).lean())._id;
  const bad = await check(id, '000000');
  expect(bad.status).toBe(400);
  expect(bad.body.code).toBe('CODE_INVALID');
  expect(bad.body.left).toBe(5);
  expect(await Post.countDocuments({})).toBe(0);
  const notifBefore = ns.sendNotification.mock.calls.length;
  const good = await check(id, codeOf(lastMail())).expect(200);
  expect(good.body.published).toBe(true);
  expect(good.body.postId).toMatch(/^[a-f0-9]{24}$/);
  expect(good.body.link).toContain('/posts');
  expect(good.body.link).toContain('k=signed');
  expect(good.body.user.role).toBe('owner');
  const payload = jwt.verify(good.body.token, process.env.JWT_SECRET);
  expect(payload.role).toBe('owner');
  const owner = await Owner.findOne({ email: BASE.email }).lean();
  expect(String(payload.id)).toBe(String(owner._id));
  expect(owner.verified).toBe(true);
  expect(owner.emailProvenAt).toBeTruthy();
  expect(owner.emailProofSource).toBe('lead_code');
  const post = await Post.findById(good.body.postId).lean();
  expect(post).toBeTruthy();
  expect(String(post.ownerId)).toBe(String(owner._id));
  expect(ns.sendNotification.mock.calls.length).toBeGreaterThanOrEqual(notifBefore); // gardiens : createPost (zone fictive = 0)
  const lead = await AdLead.findById(id).lean();
  expect(String(lead.postId)).toBe(good.body.postId);
  expect(lead.pendingConfirm).toBe(false);
  expect(lead.confirmedAt).toBeTruthy();
  expect(lead.clickedAt).toBeTruthy();
  expect(await VerificationCode.findOne({ email: BASE.email })).toBeNull(); // code consommé
  // Code déjà consommé → 410, pas de 2e demande.
  const again = await check(id, '123456');
  expect(again.status).toBe(410);
  expect(await Post.countDocuments({ ownerId: owner._id })).toBe(1);
});

test('renvoyer le code : 60 s de délai (429 RESEND_TOO_SOON), puis nouvel e-mail avec un autre code ; 5 envois / 24 h max', async () => {
  const email = 'marc.demande0811@example.test';
  const r = await site({ ...BASE, email, firstName: 'Marc' }).expect(202);
  const first = codeOf(lastMail());
  const soon = await send(r.body.id);
  expect(soon.status).toBe(429);
  expect(soon.body.code).toBe('RESEND_TOO_SOON');
  expect(soon.body.retryAfter).toBeGreaterThan(0);
  // On recule l'horodatage du dernier envoi (mémoire + base) : le délai est passé.
  require('../src/routes/demandeCode0811')._resetForTest();
  await VerificationCode.updateOne({ email }, { $set: { updatedAt: new Date(Date.now() - 61000) } }, { timestamps: false });
  const ok = await send(r.body.id).expect(200);
  expect(ok.body.sent).toBe(true);
  const second = codeOf(lastMail());
  expect(second).toMatch(/^\d{6}$/);
  expect(await check(r.body.id, first).then((x) => x.status)).toBe(400); // l'ancien code ne vaut plus
  // Plafond : 5 envois / 24 h.
  const mod = require('../src/routes/demandeCode0811');
  mod._resetForTest();
  for (let i = 0; i < 5; i += 1) {
    mod._backdateForTest(r.body.id, 61000);
    await VerificationCode.updateOne({ email }, { $set: { updatedAt: new Date(Date.now() - 61000) } }, { timestamps: false });
    const x = await send(r.body.id);
    expect(x.status).toBe(200);
  }
  mod._backdateForTest(r.body.id, 61000);
  await VerificationCode.updateOne({ email }, { $set: { updatedAt: new Date(Date.now() - 61000) } }, { timestamps: false });
  const capped = await send(r.body.id);
  expect(capped.status).toBe(429);
  expect(capped.body.code).toBe('TOO_MANY');
  // Le dernier code marche toujours.
  await check(r.body.id, codeOf(lastMail())).expect(200);
});

test('6 mauvais codes en 1 h → 429 TOO_MANY_TRIES, même avec le bon code', async () => {
  const email = 'nina.demande0811@example.test';
  const r = await site({ ...BASE, email, firstName: 'Nina' }).expect(202);
  const good = codeOf(lastMail());
  for (let i = 0; i < 6; i += 1) {
    const x = await check(r.body.id, String(100000 + i));
    expect(x.status).toBe(400);
  }
  const blocked = await check(r.body.id, good);
  expect(blocked.status).toBe(429);
  expect(blocked.body.code).toBe('TOO_MANY_TRIES');
  expect(await Post.countDocuments({ ownerId: (await Owner.findOne({ email }))._id })).toBe(0);
});

test('compte propriétaire DÉJÀ existant : brouillon + e-mail code ; le code publie et ouvre la session de CE compte', async () => {
  const email = 'paul.demande0811@example.test';
  const existing = await Owner.create({ name: 'Paul', firstName: 'Paul', lastName: 'X', email, password: 'x'.repeat(24), city: 'Zone test', country: 'FR', currency: 'EUR', acceptedTerms: true, verified: true });
  const before = MAILS.length;
  const r = await site({ ...BASE, email, firstName: 'Paul' }).expect(202);
  expect(r.body.pending).toBe(true);
  expect(r.body.code).toBe(true);
  expect(MAILS.length).toBe(before + 1);
  expect(await Post.countDocuments({ ownerId: existing._id })).toBe(0);
  const ok = await check(r.body.id, codeOf(lastMail())).expect(200);
  expect(ok.body.user.id).toBe(String(existing._id));
  expect(await Post.countDocuments({ ownerId: existing._id })).toBe(1);
  expect(await Owner.countDocuments({ email })).toBe(1); // pas de 2e compte
});

test('adresse de test → 403, aucun e-mail ; id inconnu → 404 ; code mal formé → 400', async () => {
  const before = MAILS.length;
  await site({ ...BASE, email: 'dadaciao84+testowner@gmail.com' }).expect(403);
  expect(MAILS.length).toBe(before);
  await send('f'.repeat(32)).expect(404);
  await check('f'.repeat(32), '123456').expect(404);
  const id = (await AdLead.findOne({ email: BASE.email }).lean())._id;
  await check(id, 'abc').expect(400);
});

test('sans codeFlow : le parcours d\'avant ne change pas (e-mail « un clic pour publier », pas de code)', async () => {
  const email = 'zoe.classique0811@example.test';
  const before = MAILS.length;
  const r = await site({ ...BASE, email, firstName: 'Zoé', codeFlow: undefined }).expect(202);
  expect(r.body.code).toBeUndefined();
  expect(MAILS.length).toBe(before + 1);
  expect(lastMail().subject).toMatch(/un clic pour publier/i);
  expect(await VerificationCode.findOne({ email })).toBeNull();
  // …mais la page /demande peut quand même demander un code pour ce brouillon (reprise d'un brouillon < 24 h).
  const ok = await send(r.body.id).expect(200);
  expect(ok.body.sent).toBe(true);
  await check(r.body.id, codeOf(lastMail())).expect(200);
});
