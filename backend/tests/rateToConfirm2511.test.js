// 25/11/2026 (BOB, décision de Daniel : « ils doivent recevoir tarif à confirmer et savoir comment faire ») — un gardien
// qui n'a qu'un tarif à l'heure n'est plus tarifé « heure × 8 » (30 €/h → 240 €/nuit, 1 440 € les 5 nuits) ni refusé :
// sa candidature part en « tarif à venir », il reçoit la marche à suivre en 3 gestes, et dès qu'il pose son tarif à la
// journée la candidature passe à son vrai prix. Une ancienne candidature restée à « heure × 8 » est recalculée aussi.
// VRAIS routeurs, VRAIE base Mongo en mémoire, zone fictive lat -35 / lng -30.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  requireVerifiedEmail: (req, res, next) => next(),
  attachUserFromToken: (req, res, next) => next(),
  attachOwnerFromToken: (req, res, next) => next(),
  optionalAuth: (req, res, next) => next(),
}));
const MAILS = [];
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async (to, subject, text, html) => { MAILS.push({ to, subject, text: String(text || ''), html: String(html || '') }); return { messageId: 'mock' }; }), sendTemplatedEmail: jest.fn(async () => ({})) };
});
const PUSHES = [];
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async (m) => { PUSHES.push(m); return { successCount: m.tokens.length, failureCount: 0, responses: m.tokens.map(() => ({ success: true })) }; }) }) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0), emitToConversation: jest.fn(), emitChatMessage: jest.fn(),
  isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false), touchConversationOpen: jest.fn(async () => {}),
  buildPresenceIndex: jest.fn(async () => new Map()), isIdentityOnline: jest.fn(() => false),
}));
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/services/paymentAlert0410', () => new Proxy({}, { get: () => jest.fn(async () => null) }));
jest.mock('../src/utils/geocodeCity', () => ({
  baseCityName: (c) => String(c || ''), geocodeCity: jest.fn(async () => null), peekCity: () => undefined, warmCities: () => {}, ensureAnchorsLoaded: async () => {},
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');


const PASS = 'MotDePasseTest2511!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': 'web' });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
let mongo; let app; let Owner; let Sitter; let Pet; let Application; let rp;
const S = {};
const d = (n) => `${new Date(Date.now() + n * 86400000).toISOString().slice(0, 10)}T00:00:00.000Z`;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); require('../src/models/Walker');
  Pet = require('../src/models/Pet'); const Post = require('../src/models/Post'); Application = require('../src/models/Application');
  require('../src/models/Conversation'); require('../src/models/Message'); require('../src/models/Booking'); require('../src/models/Block'); require('../src/models/Notification');
  await Promise.all([Owner.init(), Sitter.init(), Pet.init(), Post.init(), Application.init()]);
  const fr = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  S.owner = await Owner.create({ ...fr, name: 'Marie Site', email: 'bob2511+owner@example.test', acceptedTerms: true });
  S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Nana', petType: 'cat' });
  S.hourly = await Sitter.create({ ...fr, name: 'Solene Test', email: 'bob2511+solene@example.test', hourlyRate: 30 }); // balades seulement
  S.daily = await Sitter.create({ ...fr, name: 'Isabelle Test', email: 'bob2511+isabelle@example.test', dailyRate: 15, hourlyRate: 30 });
  S.none = await Sitter.create({ ...fr, name: 'Sans Tarif', email: 'bob2511+sanstarif@example.test' });
  rp = require('../src/services/applicationRepricing620');
  app = express();
  app.use(express.json());
  app.use('/posts', require('../src/routes/postRoutes'));
  app.use('/applications', require('../src/routes/applicationRoutes'));
  const p = await request(app).post('/posts').set(hdr(S.owner._id, 'owner')).send({
    body: 'Garde de Nana, zone test.', language: 'fr', animalCount: 1, location: LOC, petIds: [String(S.pet._id)],
    serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', startDate: d(30), endDate: d(34), animalTypes: ['cat'],
  });
  expect(p.status).toBe(201);
  S.post = p.body.post;
  await wait(300);
  MAILS.length = 0;
}, 180000);
afterAll(async () => {
  try { require('../src/services/applicationEmail2610').stopApplicationEmailScheduler(); } catch (_) { /* pas démarré */ }
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
}, 60000);

const apply = (who) => request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(who._id, 'sitter'))
  .send({ postId: S.post.id, description: 'Disponible.', timeSlot: 'morning', serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: d(30) });

describe('2511 — tarif à la journée manquant : « tarif à venir » et marche à suivre', () => {
  test('gardienne avec un tarif à la journée : prix normal, inchangé (15 €/jour, jamais 240)', async () => {
    const r = await apply(S.daily);
    expect(r.status).toBe(201);
    const a = await Application.findById(r.body.application.id || r.body.application._id).lean();
    expect(a.pricing.appliedRate).toBe(15);
    expect(a.pricing.stale).not.toBe(true);
    expect(a.pricing.totalPrice).toBeGreaterThan(0);
    S.days = a.pricing.quantity;
    S.normalTotal = a.pricing.totalPrice;
  }, 60000);

  test('gardienne avec SEULEMENT un tarif à l\'heure : acceptée en « tarif à venir », aucun prix, et elle reçoit les 3 gestes par e-mail', async () => {
    MAILS.length = 0;
    const r = await apply(S.hourly);
    expect(r.status).toBe(201);
    await wait(600);
    S.appHourly = String(r.body.application.id || r.body.application._id);
    const a = await Application.findById(S.appHourly).lean();
    expect(a.pricing.stale).toBe(true);
    expect(a.pricing.indicative).toBe(true);
    expect(a.pricing.totalPrice == null).toBe(true); // surtout pas 240 €/nuit
    expect(a.pricing.appliedRate).toBe(0);
    const m = MAILS.filter((x) => x.to === 'bob2511+solene@example.test');
    expect(m).toHaveLength(1);
    expect(m[0].subject).toBe('Il manque ton tarif à la journée (20 secondes)');
    expect(m[0].html).toContain('Garde — par jour ou par nuit');
    expect(m[0].html).toContain('3 gestes');
    expect(m[0].html).not.toContain('{{');
    // Le propriétaire est prévenu d'une candidature, sans aucun prix dans l'objet.
    const o = MAILS.filter((x) => x.to === 'bob2511+owner@example.test');
    expect(o.every((x) => !/Solene[^·]*·.*(240|1[  ]?440)/.test(x.subject))).toBe(true);
  }, 60000);

  test('sans AUCUN tarif : acceptée aussi en « tarif à venir » avec les 3 gestes ; interrupteur coupé : refus comme avant', async () => {
    MAILS.length = 0;
    const r = await apply(S.none);
    expect(r.status).toBe(201);
    await wait(600);
    const a = await Application.findById(r.body.application.id || r.body.application._id).lean();
    expect(a.pricing.stale).toBe(true);
    expect(a.pricing.totalPrice == null).toBe(true);
    expect(MAILS.filter((x) => x.to === 'bob2511+sanstarif@example.test' && /tarif à la journée/.test(x.subject))).toHaveLength(1);
    process.env.RATE_CONFIRM_2511 = 'off';
    const base = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
    const h = await Sitter.create({ ...base, name: 'Autre Test', email: 'bob2511+autre@example.test', hourlyRate: 25 });
    const n = await Sitter.create({ ...base, name: 'Rien Test', email: 'bob2511+rien@example.test' });
    const r2 = await apply(h); const r3 = await apply(n);
    delete process.env.RATE_CONFIRM_2511;
    expect(r2.status).toBe(400);
    expect(r2.body.code).toBe('RATE_REQUIRED');
    expect(r3.status).toBe(400);
  }, 60000);

  test('correction unique : une ancienne proposition à 240 €/jour (30 € × 8) passe en « tarif à venir », la gardienne est prévenue une fois ; les vrais tarifs ne bougent pas', async () => {
    MAILS.length = 0;
    const old = Math.round(S.days * 240 * 1.2 * 100) / 100;
    await Application.updateOne({ _id: S.appHourly }, { $set: { 'pricing.appliedRate': 240, 'pricing.unit': 'day', 'pricing.stale': false, 'pricing.indicative': false, 'pricing.totalPrice': old, 'pricing.basePrice': S.days * 240, 'pricing.quantity': S.days } });
    const sim = await rp.markHourlyFallbackStale2511({ dryRun: true });
    expect(sim.changed.map((c) => c.id)).toEqual([S.appHourly]);
    expect((await Application.findById(S.appHourly).lean()).pricing.totalPrice).toBe(old); // la simulation n'écrit rien
    const out = await rp.markHourlyFallbackStale2511();
    expect(out.changed).toHaveLength(1);
    expect(out.changed[0]).toMatchObject({ id: S.appHourly, appliedRate: 240, totalPrice: old }); // anciennes valeurs gardées
    expect(out.notified).toBe(1);
    await wait(500);
    const a = await Application.findById(S.appHourly).lean();
    expect(a.pricing.stale).toBe(true);
    expect(a.pricing.totalPrice == null).toBe(true);
    expect(a.status).toBe('pending');
    expect(MAILS.filter((x) => x.to === 'bob2511+solene@example.test' && /tarif à la journée/.test(x.subject))).toHaveLength(1);
    // Isabelle (15 €/jour) n'est pas touchée ; un second passage ne trouve plus rien.
    expect((await Application.findOne({ sitterId: S.daily._id }).lean()).pricing.totalPrice).toBe(S.normalTotal);
    expect((await rp.markHourlyFallbackStale2511()).changed).toHaveLength(0);
  }, 60000);

  test('elle pose son tarif à la journée : la candidature passe à son vrai prix, les deux sont prévenus', async () => {
    MAILS.length = 0;
    await Sitter.updateOne({ _id: S.hourly._id }, { $set: { dailyRate: 20 } });
    const out = await rp.repriceAfterRateChange({ providerId: String(S.hourly._id), providerRole: 'sitter' });
    expect(out.repriced).toEqual([S.appHourly]);
    await wait(500);
    const a = await Application.findById(S.appHourly).lean();
    expect(a.pricing.stale).toBe(false);
    expect(a.pricing.appliedRate).toBe(20);
    expect(a.pricing.totalPrice).toBeCloseTo(Math.round(S.days * 20 * 1.2 * 100) / 100, 2);
    // Un second passage ne refait rien.
    const again = await rp.repriceAfterRateChange({ providerId: String(S.hourly._id), providerRole: 'sitter' });
    expect(again.repriced).toEqual([]);
  }, 60000);

  test('ancienne candidature restée au prix « heure × 8 » : recalculée dès que le tarif à la journée existe ; une candidature au bon prix n\'est pas touchée', async () => {
    // On remet la candidature de Solene dans l'état d'avant le 25/11 : 240 €/jour (30 € × 8), non « stale ».
    await Application.updateOne({ _id: S.appHourly }, { $set: { 'pricing.appliedRate': 240, 'pricing.unit': 'day', 'pricing.stale': false, 'pricing.indicative': false, 'pricing.totalPrice': Math.round(S.days * 240 * 1.2 * 100) / 100 } });
    const out = await rp.repriceAfterRateChange({ providerId: String(S.hourly._id), providerRole: 'sitter' }, { notify: false });
    expect(out.repriced).toEqual([S.appHourly]);
    expect((await Application.findById(S.appHourly).lean()).pricing.appliedRate).toBe(20);
    // Isabelle (15 €/jour, 30 €/h) : sa candidature à 15 €/jour n'est pas au prix « heure × 8 », rien ne bouge.
    const out2 = await rp.repriceAfterRateChange({ providerId: String(S.daily._id), providerRole: 'sitter' }, { notify: false });
    expect(out2.repriced).toEqual([]);
    const still = await Application.findOne({ sitterId: S.daily._id }).lean();
    expect(still.pricing.totalPrice).toBe(S.normalTotal);
  }, 60000);
});
