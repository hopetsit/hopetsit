process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

jest.mock('../src/services/airwallexService', () => {
  const actual = jest.requireActual('../src/services/airwallexService');
  return {
    ...actual,
    findOrCreateCustomer: jest.fn(async ({ userId }) => ({ id: `cus_test_${userId}` })),
    findCustomerByMerchantId: jest.fn(async () => null),
    retrieveCustomer: jest.fn(async (id) => ({ id })),
    listAllPaymentConsents: jest.fn(async () => []),
    listPaymentMethods: jest.fn(async () => []),
    createPlatformPaymentIntent: jest.fn(async (body) => ({ id: 'int_620', client_secret: 'cs', status: 'REQUIRES_PAYMENT_METHOD', amount: body.amount / 100, currency: body.currency })),
    retrievePaymentIntent: jest.fn(async (id) => ({ id })),
    cancelPaymentIntent: jest.fn(async (id) => ({ id, status: 'CANCELLED' })),
  };
});
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
  return { ...actual, sendEmail: jest.fn(async (to, subject, text) => { MAILS.push({ to, subject, text: String(text || '') }); return { messageId: 'mock' }; }), sendTemplatedEmail: jest.fn(async () => ({})) };
});
const PUSHES = [];
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async (m) => { PUSHES.push(m); return { successCount: m.tokens.length, failureCount: 0, responses: [] }; }) }) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
jest.mock('../src/sockets/emitter', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0), isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false) }));
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/services/paymentAlert0410', () => new Proxy({}, { get: () => jest.fn(async () => null) }));
jest.mock('../src/utils/geocodeCity', () => ({
  baseCityName: (c) => String(c || ''), geocodeCity: jest.fn(async () => null), peekCity: () => undefined, warmCities: () => {}, ensureAnchorsLoaded: async () => {},
}));


// 2810 (ZOE, 28/10/2026 — ordre de BOB, bloquant pour la 1re réservation payée) — DEMANDES DE VISITES
// À DOMICILE (Lili, Marine, Svitlana) : « aucun candidat n'a de prix ». Mesuré en production : les 6
// gardiens candidats n'ont AUCUN tarif par visite (visitRate absent ou 0) ; leurs candidatures datent
// du 23/10 (avant la règle 620 VISIT_RATE_REQUIRED) et sont « tarif à venir » ; sur Marine, la seule
// candidate avec un prix (Agnès, 15 × 30 € + 20 % = 540 €) était la 6e, cachée du tableau admin.
//   A. gardien avec tarif par visite → total = jours × visites/jour × tarif + 20 % (pas son tarif jour) ;
//   B. gardien sans tarif par visite → refusé à la candidature (VISIT_RATE_REQUIRED) ;
//   C. candidature « tarif à venir » → Choisir = 409 RATE_PENDING, phrase claire, AUCUNE réservation ;
//   D. le gardien ajoute son tarif par visite → prix total calculé tout seul, Choisir → réservation au bon prix ;
//   E. tableau admin : la candidate avec prix apparaît en tête de who[], tarif 30 €/visite (pas 60 €/jour),
//      compteurs pricedPending / ratePending.
// VRAIE base Mongo en mémoire, VRAIS routeurs. Zone fictive lat -35 / lng -30. Aucun envoi réel.
const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const inDays = (n) => new Date(Date.now() + n * 86400000);
const day = (n) => { const d = inDays(n); return `${d.toISOString().slice(0, 10)}T00:00:00.000Z`; };
let mongo; let app;
let Owner; let Sitter; let Pet; let Post; let Application; let Booking;
const PASS = 'MotDePasseTest2810!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': '23.1.590+625' });
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const S = {};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter');
  Pet = require('../src/models/Pet'); Post = require('../src/models/Post'); Application = require('../src/models/Application');
  Booking = require('../src/models/Booking');
  const Notification = require('../src/models/Notification');
  require('../src/models/Walker'); require('../src/models/Block');
  await Promise.all([Owner.init(), Sitter.init(), Pet.init(), Post.init(), Application.init(), Booking.init(), Notification.init()]);
  const base = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  S.owner = await Owner.create({ ...base, name: 'Marine Visites', email: 'zoe2810.marine@example.test', acceptedTerms: true });
  S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Minou', petType: 'cat' });
  // Copies des profils mesurés en production le 28/10 (tarifs seulement).
  S.agnes = await Sitter.create({ ...base, name: 'Agnes Visites', email: 'zoe2810.agnes@example.test', dailyRate: 60, weeklyRate: 350, monthlyRate: 2000, visitRate: 30, visitDurationMinutes: 60 });
  S.sohane = await Sitter.create({ ...base, name: 'Sohane Visites', email: 'zoe2810.sohane@example.test', dailyRate: 50, weeklyRate: 100, monthlyRate: 300 });
  S.sasha = await Sitter.create({ ...base, name: 'Sasha Visites', email: 'zoe2810.sasha@example.test', dailyRate: 35, visitRate: 0, visitDurationMinutes: 30 });
  app = express();
  app.use(express.json());
  app.use('/posts', require('../src/routes/postRoutes'));
  app.use('/applications', require('../src/routes/applicationRoutes'));
  app.use('/sitters', require('../src/routes/sitterRoutes'));
  app.use('/admin/requests613', require('../src/routes/adminRequestJourney613'));
}, 180000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

const createPost = (body) => request(app).post('/posts').set(hdr(S.owner._id, 'owner')).send({
  body: 'Visites pour mon chat, zone test.', language: 'fr', animalCount: 1, animalTypes: ['cat'], petIds: [String(S.pet._id)], location: LOC, ...body,
});
const apply = (sitter, postId, serviceType) => request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(sitter._id, 'sitter')).send({ postId, serviceType, description: 'Dispo pour votre chat.', serviceDate: day(30), timeSlot: 'morning', houseSittingVenue: 'owners_home' });
const idOf = (r) => r.body.application.id || r.body.application._id;

describe('Demande de visites à domicile datée sur 15 jours, 1 visite par jour (cas Marine)', () => {
  test('A. Agnès (60 €/jour, 30 €/visite) : 15 visites × 30 = 450 + 20 % = 540 €, unité visite (pas son tarif jour)', async () => {
    const r = await createPost({ serviceTypes: ['home_visit'], visitsPerDay: 1, dateMode: 'exact', startDate: day(30), endDate: day(44) });
    if (r.status !== 201) console.log('createPost →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(201);
    S.post = r.body.post;
    const a = await apply(S.agnes, S.post.id, 'home_visit');
    if (a.status !== 201) console.log('apply agnes →', a.status, JSON.stringify(a.body)); // eslint-disable-line no-console
    expect(a.status).toBe(201);
    S.appAgnes = idOf(a);
    const doc = await Application.findById(S.appAgnes).lean();
    expect(doc.pricing).toMatchObject({ unit: 'visit', quantity: 15, appliedRate: 30, totalPrice: 540, indicative: false });
    expect(doc.pricing.stale === true).toBe(false);
  }, 60000);

  test('B. Sohane (aucun tarif par visite) et Sasha (tarif par visite à 0) : candidature refusée VISIT_RATE_REQUIRED', async () => {
    const r1 = await apply(S.sohane, S.post.id, 'home_visit');
    expect(r1.status).toBe(400);
    expect(r1.body.code).toBe('VISIT_RATE_REQUIRED');
    const r2 = await apply(S.sasha, S.post.id, 'home_visit');
    expect(r2.status).toBe(400);
    expect(r2.body.code).toBe('VISIT_RATE_REQUIRED');
  }, 60000);
});

describe('Candidature « tarif à venir » (état mesuré sur Lili, Marine, Svitlana)', () => {
  test('C. (2810b) Sohane (50 €/jour, aucun tarif par visite) candidate sur une garde, la demande passe en visites → PLUS de « tarif à venir » : son tarif jour par jour, 8 × 50 = 400 + 20 % = 480 € ; Choisir → réservation à 480 €', async () => {
    const r = await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'exact', startDate: day(50), endDate: day(57) });
    expect(r.status).toBe(201);
    S.post2 = r.body.post;
    const a = await apply(S.sohane, S.post2.id, 'house_sitting');
    expect(a.status).toBe(201);
    S.appSohane = idOf(a);
    await request(app).patch(`/posts/${S.post2.id}`).set(hdr(S.owner._id, 'owner')).send({ serviceTypes: ['home_visit'], visitsPerDay: 2 }).expect(200);
    await new Promise((res) => setTimeout(res, 300));
    const st = await Application.findById(S.appSohane).lean();
    // 2 visites par jour ne doublent pas le prix : 8 JOURS au tarif jour.
    expect(st.pricing).toMatchObject({ stale: false, indicative: false, unit: 'day', quantity: 8, appliedRate: 50, totalPrice: 480 });
    // rejeu admin idempotent : la candidature est « alignée », rien n'est réécrit.
    const rp = require('../src/services/applicationRepricing620');
    const again = await rp.repriceAfterServiceChange(await Post.findById(S.post2.id), { notify: false });
    expect(again.aligned).toContain(String(S.appSohane));
    expect(again.repriced.length + again.stale.length).toBe(0);
  }, 60000);

  test('C ter. (2810b) un gardien SANS AUCUN tarif reste « tarif à venir » : Choisir = 409 RATE_PENDING, aucune réservation', async () => {
    const nul = await Sitter.create({ password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, name: 'Nul Visites', email: 'zoe2810.nul@example.test', dailyRate: 0 });
    const post = await Post.findById(S.post2.id).lean();
    const ins = await Application.collection.insertOne({
      ownerId: S.owner._id, sitterId: nul._id, postId: post._id, petIds: [S.pet._id], serviceType: 'home_visit', status: 'pending',
      serviceDate: inDays(50), timeSlot: 'flexible', createdAt: new Date(), updatedAt: new Date(),
      pricing: { stale: true, indicative: true, totalPrice: null, appliedRate: 0, unit: 'visit', currency: 'EUR' },
    });
    const acc = await request(app).post(`/applications/${ins.insertedId}/respond`).set(hdr(S.owner._id, 'owner')).send({ action: 'accept' });
    expect(acc.status).toBe(409);
    expect(acc.body.code).toBe('RATE_PENDING');
    expect(acc.body.unit).toBe('visit');
    expect(acc.body.error).toBe('Nul n’a pas encore de tarif par visite : son prix sera calculé dès qu’il l’aura ajouté, puis tu pourras le choisir.');
    expect(await Booking.countDocuments({ sitterId: nul._id })).toBe(0);
    await Application.collection.deleteOne({ _id: ins.insertedId });
  }, 60000);

  test('C bis. message dans les 9 langues, prénom et unité insérés, aucune accolade restante', () => {
    const rp = require('../src/services/applicationRepricing620');
    for (const l of ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      const m = rp.ratePendingMessage(l, 'Sohane Visites', 'visit');
      expect(m).toContain('Sohane');
      expect(m).not.toMatch(/[{}]/);
    }
    expect(rp.ratePendingMessage('en', 'Sohane', 'visit')).toContain('per visit');
    expect(rp.ratePendingMessage('xx', '', 'day')).toContain('per day');
  });

  test('D. Sohane ajoute 20 €/visite → sa candidature passe à son vrai prix visite (8 jours × 2 visites = 16 × 20 = 320 + 64 = 384 €), puis Choisir → réservation à 384 €', async () => {
    const put = await request(app).put('/sitters/me/pricing').set(hdr(S.sohane._id, 'sitter')).send({ visitRate: 20 });
    if (put.status !== 200) console.log('PUT pricing →', put.status, JSON.stringify(put.body)); // eslint-disable-line no-console
    expect(put.status).toBe(200);
    const doc = await Application.findById(S.appSohane).lean();
    expect(doc.pricing).toMatchObject({ stale: false, indicative: false, unit: 'visit', quantity: 16, appliedRate: 20, totalPrice: 384 });
    const acc = await request(app).post(`/applications/${S.appSohane}/respond`).set(hdr(S.owner._id, 'owner')).send({ action: 'accept' });
    if (acc.status !== 200) console.log('accept →', acc.status, JSON.stringify(acc.body)); // eslint-disable-line no-console
    expect(acc.status).toBe(200);
    const b = await Booking.findOne({ sitterId: S.sohane._id }).lean();
    expect(b.pricing.totalPrice).toBe(384);
  }, 60000);

  test('D bis. (2810b) Choisir une candidature au tarif jour → réservation au même prix que la carte (pas de 409)', async () => {
    const r = await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'exact', startDate: day(70), endDate: day(72) });
    expect(r.status).toBe(201);
    const a = await apply(S.sasha, r.body.post.id, 'house_sitting');
    expect(a.status).toBe(201);
    const id = idOf(a);
    await request(app).patch(`/posts/${r.body.post.id}`).set(hdr(S.owner._id, 'owner')).send({ serviceTypes: ['home_visit'], visitsPerDay: 1 }).expect(200);
    await new Promise((res) => setTimeout(res, 300));
    const doc = await Application.findById(id).lean();
    expect(doc.pricing).toMatchObject({ stale: false, unit: 'day', quantity: 3, appliedRate: 35, totalPrice: 126 });
    const acc = await request(app).post(`/applications/${id}/respond`).set(hdr(S.owner._id, 'owner')).send({ action: 'accept' });
    if (acc.status !== 200) console.log('accept sasha →', acc.status, JSON.stringify(acc.body)); // eslint-disable-line no-console
    expect(acc.status).toBe(200);
    const b = await Booking.findOne({ sitterId: S.sasha._id }).lean();
    expect(b.pricing.totalPrice).toBe(126);
  }, 60000);
});

describe('Tableau admin des demandes (mesure)', () => {
  test('E. la candidate avec prix passe en tête de who[] même si elle est la 6e ; tarif affiché = 30 €/visite ; compteurs', async () => {
    // 5 candidatures « tarif à venir » plus anciennes qu'Agnès (copie de l'état de Marine).
    const post = await Post.findById(S.post.id).lean();
    const older = new Date(Date.now() - 5 * 86400000);
    for (let i = 0; i < 5; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      const s = await Sitter.create({ password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, name: `Ancien${i} Visites`, email: `zoe2810.old${i}@example.test`, dailyRate: 20 });
      // eslint-disable-next-line no-await-in-loop
      await Application.collection.insertOne({
        ownerId: S.owner._id, sitterId: s._id, postId: post._id, petIds: [S.pet._id], serviceType: 'home_visit', status: 'pending',
        serviceDate: inDays(30), timeSlot: 'flexible', createdAt: new Date(older.getTime() + i * 60000), updatedAt: older,
        pricing: { stale: true, indicative: true, totalPrice: null, appliedRate: 0, unit: 'visit', currency: 'EUR' },
      });
    }
    const r = await request(app).get('/admin/requests613/board?limit=50').set(ADMIN);
    expect(r.status).toBe(200);
    const item = r.body.items.find((x) => x.postId === String(S.post.id));
    expect(item).toBeTruthy();
    const ap = item.stages.applications;
    expect(ap.count).toBe(6);
    expect(ap.pricedPending).toBe(1);
    expect(ap.ratePending).toBe(5);
    expect(ap.who[0]).toMatchObject({ name: 'Agnes', total: 540, rate: { amount: 30, unit: 'visit' }, stale: false });
    const j = await request(app).get(`/admin/requests613/${S.post.id}/journey`).set(ADMIN);
    expect(j.status).toBe(200);
    const ag = j.body.applications.find((x) => x.name === 'Agnes');
    expect(ag.rate).toEqual({ amount: 30, unit: 'visit' });
    expect(j.body.applications.filter((x) => x.stale).every((x) => x.rate === null)).toBe(true);
  }, 60000);
});
