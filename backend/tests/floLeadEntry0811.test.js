// 08/11/2026 (FLO, ordre de Daniel « le proprio doit pouvoir payer du site OU de l'app ») — comment un
// compte « lead » (créé par le formulaire du site / de la pub, SANS mot de passe connu) entre dans l'APP :
//   1. « Mot de passe oublié » : code reçu par e-mail → nouveau mot de passe → connexion → sa demande visible ;
//   2. « Continuer avec Google » (ou Apple) avec le MÊME e-mail → même compte, pas de doublon ;
//   3. sans ces deux chemins : aucun mot de passe ne marche (401).
// VRAIE base Mongo en mémoire, vrai createPost, zone fictive (−35 / −30), aucun réseau, aucun e-mail réel.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.POSTAL_GEOCODE = 'off';
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => null), leadOwnerEmailLink: jest.fn(async (r, u, l) => l), resolveAppLocaleAcrossRoles: jest.fn(async () => 'fr') }));
const mockVerifyIdToken = jest.fn();
jest.mock('../src/config/firebaseAdmin', () => ({
  auth: () => ({ verifyIdToken: (...a) => mockVerifyIdToken(...a) }),
  messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }),
}));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/sockets/emitter', () => ({ emitToUser: jest.fn(), isUserOnline: jest.fn(async () => false) }));
const MAILS = [];
jest.mock('../src/services/emailService', () => ({
  sendEmail: jest.fn(async (to, subject, text, html) => { MAILS.push({ to, subject, text, html }); return { messageId: 'mock' }; }),
  sendTemplatedEmail: jest.fn(async () => ({})),
  sendVerificationEmail: jest.fn(async (to, code) => { MAILS.push({ to, subject: 'verify', text: String(code) }); }),
  sendPasswordResetEmail: jest.fn(async (to, code) => { MAILS.push({ to, subject: 'reset-fallback', text: String(code) }); }),
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
const D = (n) => new Date(Date.now() + n * 86400000).toISOString().slice(0, 10);
const LEAD = {
  email: 'lea.lead0811@example.test', firstName: 'Léa', service: 'garde', animal: 'chien',
  city: 'Zone test', postalCode: '75015', lat: -35, lng: -30, country: 'FR', lang: 'fr', startDate: D(12), endDate: D(14),
  campaign: 'paris_owners', page: '/demande',
};
const BROWSER = { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Safari/604.1' };
const NEW_PASSWORD = 'NouveauMotDePasse0811!';
const lastMailTo = (to) => [...MAILS].reverse().find((m) => m.to === to);
const codeIn = (m) => ((m && (m.text || '')).match(/\b(\d{6})\b/) || [])[1];

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Post = require('../src/models/Post');
  AdLead = require('../src/models/AdLead2210');
  await Promise.all([Owner.init(), Post.init(), AdLead.init()]);
  const auth = require('../src/controllers/authController');
  app = express();
  app.use(express.json());
  app.use('/ad-leads', require('../src/routes/adLeads2210'));
  app.use('/posts', require('../src/routes/postRoutes'));
  app.use('/applications', require('../src/routes/applicationRoutes'));
  app.post('/auth/forgot-password', auth.forgotPassword);
  app.post('/auth/verify-password-reset-otp', auth.verifyPasswordResetOtp);
  app.post('/auth/reset-password', auth.resetPassword);
  app.post('/auth/login', auth.login);
  app.post('/auth/google', auth.googleAuth);
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

let owner; let postId;

test('compte lead : créé par le site, publié au clic, AUCUN mot de passe ne marche (401)', async () => {
  const r = await request(app).post('/ad-leads/site').send(LEAD).expect(202);
  const c = (await request(app).post(`/ad-leads/${r.body.id}/confirm`).set(BROWSER).send({}).expect(200)).body;
  postId = c.postId;
  owner = await Owner.findOne({ email: LEAD.email });
  expect(owner.verified).toBe(true);
  expect(postId).toMatch(/^[a-f0-9]{24}$/);
  for (const password of ['motdepasse', 'Propriétaire', LEAD.email, '12345678']) {
    const l = await request(app).post('/auth/login').send({ email: LEAD.email, password, role: 'owner' });
    expect(l.status).toBe(401);
  }
});

test('entrée 1 : « mot de passe oublié » → code par e-mail → nouveau mot de passe → connexion → sa demande visible', async () => {
  await request(app).post('/auth/forgot-password').send({ email: LEAD.email }).expect(200);
  const m = lastMailTo(LEAD.email);
  const code = codeIn(m);
  expect(code).toMatch(/^\d{6}$/);
  expect(m.html || m.text).not.toContain('undefined');
  await request(app).post('/auth/verify-password-reset-otp').send({ email: LEAD.email, code }).expect(200);
  await request(app).post('/auth/reset-password').send({ email: LEAD.email, newPassword: NEW_PASSWORD }).expect(200);
  const l = await request(app).post('/auth/login').send({ email: LEAD.email, password: NEW_PASSWORD, role: 'owner' }).expect(200);
  expect(l.body.role).toBe('owner');
  expect(l.body.emailVerified).not.toBe(false); // e-mail prouvé → le paiement (requireVerifiedEmail) ne sera pas refusé
  expect(jwt.verify(l.body.token, process.env.JWT_SECRET)).toMatchObject({ id: String(owner._id), role: 'owner' });
  expect(await Owner.countDocuments({ email: LEAD.email })).toBe(1);
  // Même session que l'app : GET /posts/my et GET /applications/my (ApplicationsController.loadApplications)
  const H = { 'x-test-user': String(owner._id), 'x-test-role': 'owner' };
  const p = await request(app).get('/posts/my').set(H).expect(200);
  const posts = p.body.posts || p.body;
  expect(posts.map((x) => String(x.id || x._id))).toContain(String(postId));
  const a = await request(app).get('/applications/my').set(H).expect(200);
  expect(Array.isArray(a.body.applications || a.body)).toBe(true);
});

test('entrée 2 : « Continuer avec Google » avec le même e-mail → MÊME compte (pas de doublon), vérifié', async () => {
  mockVerifyIdToken.mockResolvedValue({ uid: 'google-uid-0811', email: LEAD.email, name: 'Léa L.', picture: '', firebase: { sign_in_provider: 'google.com' } });
  const g = await request(app).post('/auth/google').send({ idToken: 'jeton-firebase-simule', role: 'owner' }).expect(200);
  expect(g.body.existingUser).toBe(true);
  expect(g.body.role).toBe('owner');
  expect(jwt.verify(g.body.token, process.env.JWT_SECRET)).toMatchObject({ id: String(owner._id), role: 'owner' });
  expect(await Owner.countDocuments({ email: LEAD.email })).toBe(1);
  const again = await Owner.findById(owner._id);
  expect(again.verified).toBe(true);
  expect(again.firebaseUid).toBe('google-uid-0811');
});

test('entrée 2 bis : Google avec un e-mail INCONNU → nouveau compte, pas celui du lead', async () => {
  mockVerifyIdToken.mockResolvedValue({ uid: 'google-uid-autre', email: 'autre.0811@example.test', name: 'Autre', picture: '', firebase: { sign_in_provider: 'google.com' } });
  const g = await request(app).post('/auth/google').send({ idToken: 'jeton-firebase-simule-2', role: 'owner' });
  expect([200, 201]).toContain(g.status);
  expect(g.body.existingUser).toBe(false);
  expect(jwt.verify(g.body.token, process.env.JWT_SECRET).id).not.toBe(String(owner._id));
});
