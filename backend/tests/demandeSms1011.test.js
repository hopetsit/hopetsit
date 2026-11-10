// 10/11/2026 (BOB, accord de Daniel) — accord SMS FACULTATIF de la page de demande : POST /ad-leads/sms-consent.
// VRAIE base Mongo en mémoire, zone fictive (lat −35 / lng −30), aucun réseau, aucun e-mail ni SMS réel.
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
beforeEach(() => { require('../src/routes/adLeadsSite3110')._resetForTest(); require('../src/routes/demandeCode0811')._resetForTest(); require('../src/routes/demandeSms1011')._resetForTest(); delete process.env.DEMANDE_SMS_1011; delete process.env.DEMANDE_SMS_1011_COUNTRIES; });

const US = { ...BASE, email: 'sms.us@example.test', firstName: 'Ava', country: 'US', lang: 'en', postalCode: '10001', campaign: 'nyc_owners', page: '/request' };
const FR = { ...BASE, email: 'sms.fr@example.test' };
const sms = (userId, body) => { const r = request(app).post('/ad-leads/sms-consent'); if (userId) r.set('x-test-user', String(userId)); return r.send(body); };
const NUM = '(212) 555-0142'; // numéro fictif (plage 555-01xx réservée à la fiction)
let usId; let usOwner; let frId; let frOwner;

test('publication par code : le serveur propose le bloc SMS aux USA, pas en France', async () => {
  const a = await site(US).expect(202);
  usId = a.body.id;
  const okUs = await check(usId, codeOf(lastMail())).expect(200);
  expect(okUs.body.smsConsent).toBe(true);
  usOwner = String((await AdLead.findById(usId).lean()).ownerId);
  const b = await site(FR).expect(202);
  frId = b.body.id;
  const okFr = await check(frId, codeOf(lastMail())).expect(200);
  expect(okFr.body.smsConsent).toBeUndefined();
  frOwner = String((await AdLead.findById(frId).lean()).ownerId);
});

test('sans session → 401 ; contact de quelqu\'un d\'autre → 403 ; identifiant inconnu → 404 ; rien n\'est écrit', async () => {
  expect((await sms(null, { id: usId, phone: NUM, consent: true })).status).toBe(401);
  expect((await sms(frOwner, { id: usId, phone: NUM, consent: true })).status).toBe(403);
  expect((await sms(usOwner, { id: 'f'.repeat(32), phone: NUM, consent: true })).status).toBe(404);
  expect((await sms(usOwner, { id: 'pas-un-id', phone: NUM, consent: true })).status).toBe(404);
  const lead = await AdLead.findById(usId).lean();
  expect(lead.smsPhone || '').toBe('');
  expect(lead.smsConsentAt).toBeFalsy();
});

test('case non cochée → 400 CONSENT_REQUIRED (même avec "true" en texte) ; numéro faux → 400 PHONE_INVALID', async () => {
  for (const consent of [undefined, false, 'true', 1]) {
    const r = await sms(usOwner, { id: usId, phone: NUM, consent });
    expect(r.status).toBe(400);
    expect(r.body.code).toBe('CONSENT_REQUIRED');
    require('../src/routes/demandeSms1011')._resetForTest();
  }
  for (const phone of ['', '12345', '555-0142', '(012) 555-0142', 'appelle-moi', '+1 212 555 0142 ext 9']) {
    const r = await sms(usOwner, { id: usId, phone, consent: true });
    expect(r.status).toBe(400);
    expect(r.body.code).toBe('PHONE_INVALID');
    require('../src/routes/demandeSms1011')._resetForTest();
  }
  expect((await AdLead.findById(usId).lean()).smsConsentAt).toBeFalsy();
});

test('bon cas : numéro au format international, date, texte exact accepté (version), sans rien d\'autre de changé', async () => {
  const before = await AdLead.findById(usId).lean();
  const r = await sms(usOwner, { id: usId, phone: NUM, consent: true }).expect(200);
  expect(r.body).toEqual({ ok: true });
  const lead = await AdLead.findById(usId).lean();
  expect(lead.smsPhone).toBe('+12125550142');
  expect(lead.smsConsentAt).toBeTruthy();
  const m = require('../src/routes/demandeSms1011');
  expect(lead.smsConsentText).toBe(`${m.VERSION} | ${m.CONSENT_TEXT.en}`);
  expect(lead.smsConsentText).toContain('Reply STOP');
  expect(lead.smsConsentText).toContain('not a condition of purchase');
  expect(lead.smsOptOutAt).toBeFalsy();
  expect(String(lead.postId)).toBe(String(before.postId));
  expect(lead.email).toBe(before.email);
});

test('5 essais par heure et par contact, le 6e → 429', async () => {
  for (let i = 0; i < 5; i += 1) await sms(usOwner, { id: usId, phone: 'x', consent: true }).expect(400);
  expect((await sms(usOwner, { id: usId, phone: NUM, consent: true })).status).toBe(429);
});

test('pays non ouvert → 404 ; ouvert par DEMANDE_SMS_1011_COUNTRIES → 200 (numéro français mis en +33)', async () => {
  expect((await sms(frOwner, { id: frId, phone: '06 12 34 56 78', consent: true })).status).toBe(404);
  process.env.DEMANDE_SMS_1011_COUNTRIES = 'US,FR';
  await sms(frOwner, { id: frId, phone: '06 12 34 56 78', consent: true }).expect(200);
  const lead = await AdLead.findById(frId).lean();
  expect(lead.smsPhone).toBe('+33612345678');
  expect(lead.smsConsentText).toContain('Réponds STOP');
});

test('coupe-circuit DEMANDE_SMS_1011=off : route 404 (avant même la session) et plus de drapeau', async () => {
  process.env.DEMANDE_SMS_1011 = 'off';
  expect((await sms(usOwner, { id: usId, phone: NUM, consent: true })).status).toBe(404);
  expect((await sms(null, { id: usId, phone: NUM, consent: true })).status).toBe(404);
  const m = require('../src/routes/demandeSms1011');
  expect(m.offeredFor({ country: 'US' })).toBe(false);
  delete process.env.DEMANDE_SMS_1011;
  expect(m.offeredFor({ country: 'US' })).toBe(true);
  expect(m.offeredFor({ country: 'FR' })).toBe(false);
  expect(m.offeredFor(null)).toBe(false);
});

test('normalizePhone : formats acceptés et refusés', () => {
  const { normalizePhone: n } = require('../src/routes/demandeSms1011');
  expect(n('212-555-0142', 'US')).toBe('+12125550142');
  expect(n('1 212 555 0142', 'US')).toBe('+12125550142');
  expect(n('+1 (212) 555-0142', 'FR')).toBe('+12125550142');
  expect(n('0033 6 12 34 56 78', 'US')).toBe('+33612345678');
  expect(n('+33 6 12 34 56 78', 'US')).toBe('+33612345678');
  expect(n('212 555 0142', 'FR')).toBe('');
  expect(n('212 555 0142', '')).toBe('');
  expect(n('+0612345678', 'FR')).toBe('');
  expect(n('+1 112 555 0142', 'US')).toBe('');
  expect(n('+1234567', 'US')).toBe('');
  expect(n('+1234567890123456', 'US')).toBe('');
  expect(n(null, 'US')).toBe('');
});
