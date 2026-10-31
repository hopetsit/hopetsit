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

// 3110 (FLO, alerte prix de BOB du 31/10/2026) — les 2 demandes RÉELLES signalées, rejouées avec
// les VRAIS tarifs des gardiens (lus en prod le 31/10, aucun nom complet ni coordonnée ici) :
//   · Saint-Maur-des-Fossés, visites à domicile 1/jour du 01/11/2026 au 30/06/2027 (242 jours)
//   · Égly, garde au domicile du 01/11 au 03/11/2026 (3 jours calendaires, 2 nuits)
// et le GARDE-FOU « prix à confirmer par le gardien » (utils/priceSanity3110.js).
// VRAIE base Mongo en mémoire, VRAIS routeurs. Zone fictive lat -35 / lng -30.
const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const engine = require('../src/utils/pricingEngine620');
const rp = require('../src/services/applicationRepricing620');
const sanity = require('../src/utils/priceSanity3110');

const SAINT_MAUR = { serviceTypes: ['home_visit'], dateMode: 'exact', visitsPerDay: 1, startDate: '2026-11-01T00:00:00.000Z', endDate: '2027-06-30T00:00:00.000Z' };
const EGLY = { serviceTypes: ['house_sitting'], dateMode: 'exact', startDate: '2026-11-01T00:00:00.000Z', endDate: '2026-11-03T00:00:00.000Z' };
// tarifs réels (prod, 31/10)
const NOEMIE = { dailyRate: 20, weeklyRate: 90, monthlyRate: 300, visitRate: null, hourlyRate: 0 };
const HANENE = { dailyRate: 18, weeklyRate: 120, monthlyRate: 520, visitRate: null, hourlyRate: 0 };
const SOHANE = { dailyRate: 50, weeklyRate: 100, monthlyRate: 300, visitRate: null, hourlyRate: 0 };
const FREDERIC = { dailyRate: 10, weeklyRate: 10, monthlyRate: 10, visitRate: 0, hourlyRate: 0 };
const AGNES_A_LA_CANDIDATURE = { dailyRate: 60 }; // prix figé de sa candidature du 28/10 (tarif actuel : 50 €/jour)

describe('1. Reconstitution des totaux réels (moteur unique, commission 20 %)', () => {
  test('Saint-Maur : 242 jours ; noémie sans tarif visite → tarif jour 20 € + tarif semaine 90 € : 34 sem × 90 + 4 j × 20 = 3 140 + 20 % = 3 768 €', () => {
    expect(engine.dayCount(SAINT_MAUR)).toBe(242);
    const pr = rp.priceApplication({ application: { pricing: { addOns: [] } }, post: SAINT_MAUR, provider: NOEMIE, providerRole: 'sitter' });
    expect(pr).toMatchObject({ appliedRate: 20, unit: 'day', quantity: 242, basePrice: 3140, commission: 628, totalPrice: 3768, weeklyApplied: true, weeks: 34 });
  });
  test('Saint-Maur : 2,70 € et 7,50 € = l\'ANCIEN calcul « 1 heure » (tarif jour ÷ 8 + 20 %), restés sur 2 candidatures refusées le 24/10 ; le moteur actuel donne 4 982,40 € et 14 520 €', () => {
    expect(Math.round((18 / 8) * 1.2 * 100) / 100).toBe(2.7);
    expect(Math.round((50 / 8) * 1.2 * 100) / 100).toBe(7.5);
    const h = rp.priceApplication({ application: { pricing: { addOns: [] } }, post: SAINT_MAUR, provider: HANENE, providerRole: 'sitter' });
    expect(h).toMatchObject({ basePrice: 4152, totalPrice: 4982.4 }); // 34 × 120 + 4 × 18
    const s = rp.priceApplication({ application: { pricing: { addOns: [] } }, post: SAINT_MAUR, provider: SOHANE, providerRole: 'sitter' });
    expect(s).toMatchObject({ basePrice: 12100, totalPrice: 14520, weeklyApplied: false }); // tarif semaine 100 < 3 × 50 → ignoré
  });
  test('Égly : 3 jours (01 → 03 inclus, règle 620) ; frederic 10 €/jour → 30 + 6 = 36 € ; Agnès 60 €/jour → 180 + 36 = 216 €', () => {
    expect(engine.quantityFor(EGLY, 'house_sitting')).toMatchObject({ quantity: 3, unit: 'day' });
    const f = rp.priceApplication({ application: { pricing: { addOns: [] } }, post: EGLY, provider: FREDERIC, providerRole: 'sitter' });
    expect(f).toMatchObject({ appliedRate: 10, quantity: 3, basePrice: 30, commission: 6, totalPrice: 36, netPayout: 30 });
    const a = rp.priceApplication({ application: { pricing: { addOns: [] } }, post: EGLY, provider: AGNES_A_LA_CANDIDATURE, providerRole: 'sitter' });
    expect(a).toMatchObject({ basePrice: 180, commission: 36, totalPrice: 216, netPayout: 180 });
  });
});

describe('2. Garde-fou (décision de BOB du 31/10 soir) : seul un prix PÉRIMÉ et < 10 € est bloqué', () => {
  test('2,70 € pour 242 jours alors que le tarif actuel donne 4 982,40 € → stale_too_low', () => {
    expect(sanity.checkTotal({ total: 2.7, days: 242, recalculated: 4982.4 })).toMatchObject({ toVerify: true, reason: 'stale_too_low' });
    expect(sanity.checkTotal({ total: 7.5, days: 242, recalculated: null })).toMatchObject({ toVerify: true, reason: 'stale_too_low' }); // plus aucun tarif
  });
  test('un VRAI tarif de gardien n\'est jamais bloqué, même bas', () => {
    expect(sanity.checkTotal({ total: 9.6, days: 4, recalculated: 9.6 })).toMatchObject({ toVerify: false });
    expect(sanity.checkTotal({ total: 36, days: 3, recalculated: 36 })).toMatchObject({ toVerify: false });
    expect(sanity.checkTotal({ total: 36, days: 3, recalculated: 30 })).toMatchObject({ toVerify: false }); // ≥ 10 : jamais bloqué
    expect(sanity.checkTotal({ total: 8.4, days: 1, recalculated: 99 })).toMatchObject({ toVerify: false }); // un seul jour
  });
  test('l\'écart × 5 à la médiane n\'est qu\'une indication admin', () => {
    expect(sanity.outlierHint(36, [216])).toMatchObject({ outlier: 'low', median: 216 });
    expect(sanity.outlierHint(216, [36])).toMatchObject({ outlier: null });
    expect(sanity.outlierHint(8064, [216, 240])).toMatchObject({ outlier: 'high' });
  });
  test('cas réels : Hanene / Sohane (refusées, 2,70 / 7,50) marquées ; noémie 3 768 € et frederic 36 € payables', () => {
    expect(sanity.checkApplication({ _id: 'h', pricing: { totalPrice: 2.7, addOns: [] } }, SAINT_MAUR, HANENE, 'sitter')).toMatchObject({ toVerify: true, reason: 'stale_too_low' });
    expect(sanity.checkApplication({ _id: 's', pricing: { totalPrice: 7.5, addOns: [] } }, SAINT_MAUR, SOHANE, 'sitter')).toMatchObject({ toVerify: true });
    expect(sanity.checkApplication({ _id: 'n', pricing: { totalPrice: 3768, addOns: [] } }, SAINT_MAUR, NOEMIE, 'sitter')).toMatchObject({ toVerify: false });
    expect(sanity.checkApplication({ _id: 'f', pricing: { totalPrice: 36, addOns: [] } }, EGLY, FREDERIC, 'sitter')).toMatchObject({ toVerify: false });
  });
  test('dates à prévoir / tarif à venir : jamais marqué (pas de total)', () => {
    expect(sanity.checkApplication({ _id: 'x', pricing: { indicative: true, totalPrice: null } }, { dateMode: 'tbd' }, HANENE, 'sitter')).toMatchObject({ toVerify: false });
    expect(sanity.checkApplication({ _id: 'x', pricing: { stale: true, totalPrice: 2.7 } }, EGLY, null, 'sitter')).toMatchObject({ toVerify: false });
  });
  test('message et libellé dans la langue du propriétaire', () => {
    expect(sanity.priceToConfirmLabel('fr')).toBe('Prix à confirmer par le gardien');
    expect(sanity.priceToConfirmMessage('en')).toMatch(/^Price to be confirmed by the sitter/);
    expect(sanity.priceToConfirmMessage('xx')).toMatch(/^Price to be confirmed/);
  });
});
describe('3. Parcours réel (routes) : cas d\'Égly rejoué, aucun prix ni commission modifiés', () => {
  let mongo; let app; let Owner; let Sitter; let Pet; let Post; let Application; let Booking; let Notification;
  const PASS = 'MotDePasseTest3110!';
  const ZONE = { type: 'Point', coordinates: [-30, -35] };
  const LOC = { city: 'Zone test', lat: -35, lng: -30 };
  const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': '23.1.590+621' });
  const S = {};
  // dates dans le futur, même forme que la demande d'Égly (3 jours calendaires)
  const day = (n) => `${new Date(Date.now() + n * 86400000).toISOString().slice(0, 10)}T00:00:00.000Z`;

  beforeAll(async () => {
    mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
    await mongoose.connect(mongo.getUri());
    Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Pet = require('../src/models/Pet');
    Post = require('../src/models/Post'); Application = require('../src/models/Application'); Booking = require('../src/models/Booking');
    Notification = require('../src/models/Notification');
    require('../src/models/Walker'); require('../src/models/Block');
    await Promise.all([Owner.init(), Sitter.init(), Pet.init(), Post.init(), Application.init(), Booking.init(), Notification.init()]);
    const fr = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
    S.owner = await Owner.create({ ...fr, name: 'Fabrice Test', email: 'flo3110+owner@example.test', acceptedTerms: true });
    S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Rex', petType: 'dog' });
    S.fred = await Sitter.create({ ...fr, name: 'Fred Test', email: 'flo3110+fred@example.test', ...FREDERIC, visitRate: 0 });
    S.agnes = await Sitter.create({ ...fr, name: 'Agnes Test', email: 'flo3110+agnes@example.test', dailyRate: 60, weeklyRate: 300, monthlyRate: 2000 });
    app = express();
    app.use(express.json());
    app.use('/posts', require('../src/routes/postRoutes'));
    app.use('/applications', require('../src/routes/applicationRoutes'));
    app.use('/admin/reprice-620', require('../src/routes/adminReprice620'));
  }, 180000);
  afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

  const createPost = (extra) => request(app).post('/posts').set(hdr(S.owner._id, 'owner')).send({
    body: 'Demande de test 3110, zone test.', language: 'fr', animalCount: 1, animalTypes: ['dog'], petIds: [String(S.pet._id)], location: LOC,
    serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'exact', ...extra,
  });
  const applyTo = (post, who, a, b) => request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(who._id, 'sitter')).send({
    postId: post.id || String(post._id), description: 'Je suis disponible.', timeSlot: 'morning', serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: a, startDate: a, endDate: b,
  });

  test('Égly : frederic 36 € (son vrai tarif 10 €/jour) N\'EST PAS bloqué et se choisit : réservation 36 € = 30 + 6', async () => {
    const post = (await createPost({ startDate: day(20), endDate: day(22) }).expect(201)).body.post;
    expect((await applyTo(post, S.fred, day(20), day(22))).status).toBe(201);
    expect((await applyTo(post, S.agnes, day(20), day(22))).status).toBe(201);
    const fredApp = await Application.findOne({ sitterId: S.fred._id }).lean();
    expect(fredApp.pricing).toMatchObject({ totalPrice: 36, commission: 6, netPayout: 30, commissionRate: 0.2 });
    const list = (await request(app).get('/applications/my').set(hdr(S.owner._id, 'owner')).expect(200)).body.applications;
    for (const a of list) expect(a.pricing.priceToConfirm).toBeUndefined();
    const acc = await request(app).post(`/applications/${fredApp._id}/respond`).set(hdr(S.owner._id, 'owner')).send({ action: 'accept' });
    if (acc.status !== 200) console.log('accept frederic →', acc.status, JSON.stringify(acc.body)); // eslint-disable-line no-console
    expect(acc.status).toBe(200);
    const b = await Booking.findOne({ sitterId: S.fred._id }).lean();
    expect(b.pricing).toMatchObject({ totalPrice: 36, commission: 6, netPayout: 30 });
  }, 90000);

  test('prix PÉRIMÉ 2,70 € sur 10 jours, gardien sans tarif aujourd\'hui → « prix à confirmer », choix refusé (409), rien d\'écrit', async () => {
    S.ghost = await Sitter.create({ password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr', name: 'Ghost Test', email: 'flo3110+ghost@example.test', dailyRate: 18 });
    const post = (await createPost({ body: 'Demande de test 3110 bis, zone test.', startDate: day(30), endDate: day(39) }).expect(201)).body.post;
    expect((await applyTo(post, S.ghost, day(30), day(39))).status).toBe(201);
    const g = await Application.findOne({ sitterId: S.ghost._id }).lean();
    expect(g.pricing.totalPrice).toBe(216); // 10 × 18 + 20 %
    // comme en prod : ancien prix « 1 heure » resté en base, et le gardien a retiré ses tarifs
    await Application.updateOne({ _id: g._id }, { $set: { 'pricing.totalPrice': 2.7 } });
    await Sitter.updateOne({ _id: S.ghost._id }, { $set: { dailyRate: 0 } });
    const list = (await request(app).get('/applications/my').set(hdr(S.owner._id, 'owner')).expect(200)).body.applications;
    const lg = list.find((a) => String(a.id || a._id) === String(g._id));
    expect(lg.pricing).toMatchObject({ totalPrice: 2.7, priceToConfirm: true, priceCheckReason: 'stale_too_low', priceToConfirmLabel: 'Prix à confirmer par le gardien' });
    const before = await Booking.countDocuments({});
    const acc = await request(app).post(`/applications/${g._id}/respond`).set(hdr(S.owner._id, 'owner')).send({ action: 'accept' });
    expect(acc.status).toBe(409);
    expect(acc.body).toMatchObject({ code: 'PRICE_TO_CONFIRM', reason: 'stale_too_low' });
    expect((await Application.findById(g._id).lean())).toMatchObject({ status: 'pending', pricing: expect.objectContaining({ totalPrice: 2.7 }) });
    expect(await Booking.countDocuments({})).toBe(before);
  }, 90000);

  test('recalcul silencieux avec includeRejected : la candidature REFUSÉE à 2,70 € repasse au tarif actuel, 0 notification, 0 e-mail', async () => {
    const ag = await Application.findOne({ sitterId: S.agnes._id }).lean();
    expect(ag.status).toBe('rejected'); // refusée automatiquement quand frederic a été choisi
    await Application.updateOne({ _id: ag._id }, { $set: { 'pricing.totalPrice': 2.7 } });
    const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
    const before = { n: await Notification.countDocuments({}), m: MAILS.length, p: PUSHES.length };
    const dry = await request(app).post(`/admin/reprice-620/posts/${ag.postId}?dryRun=1&silent=1&includeRejected=1`).set(ADMIN).send({}).expect(200);
    expect(dry.body.repriced).toEqual([String(ag._id)]);
    expect((await Application.findById(ag._id).lean()).pricing.totalPrice).toBe(2.7);
    // sans includeRejected : la refusée n'est pas touchée
    const plain = await request(app).post(`/admin/reprice-620/posts/${ag.postId}?silent=1`).set(ADMIN).send({}).expect(200);
    expect(plain.body.repriced).toEqual([]);
    const run = await request(app).post(`/admin/reprice-620/posts/${ag.postId}?silent=1&includeRejected=1`).set(ADMIN).send({}).expect(200);
    expect(run.body).toMatchObject({ silent: true, includeRejected: true, repriced: [String(ag._id)] });
    const after = await Application.findById(ag._id).lean();
    expect(after.status).toBe('rejected');
    expect(after.pricing).toMatchObject({ totalPrice: 216, commission: 36, netPayout: 180 });
    await new Promise((r) => setTimeout(r, 300));
    expect(await Notification.countDocuments({})).toBe(before.n);
    expect(MAILS.length).toBe(before.m);
    expect(PUSHES.length).toBe(before.p);
  }, 90000);
});
