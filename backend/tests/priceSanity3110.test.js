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

describe('2. Garde-fou : règles', () => {
  test('total < 10 sur au moins 2 jours → too_low (2,70 € et 7,50 € pour 242 jours)', () => {
    expect(sanity.checkTotal({ total: 2.7, days: 242, otherTotals: [3768] })).toMatchObject({ toVerify: true, reason: 'too_low' });
    expect(sanity.checkTotal({ total: 7.5, days: 242, otherTotals: [] })).toMatchObject({ toVerify: true, reason: 'too_low' });
    expect(sanity.checkTotal({ total: 9.99, days: 2 })).toMatchObject({ toVerify: true });
    // une balade d'un jour à 8,40 € reste normale
    expect(sanity.checkTotal({ total: 8.4, days: 1 })).toMatchObject({ toVerify: false });
  });
  test('plus de 5 fois sous la médiane des autres → outlier_low (frederic 36 € face à 216 €) ; le plus cher des deux n\'est pas marqué', () => {
    expect(sanity.checkTotal({ total: 36, days: 3, otherTotals: [216] })).toMatchObject({ toVerify: true, reason: 'outlier_low', median: 216 });
    expect(sanity.checkTotal({ total: 216, days: 3, otherTotals: [36] })).toMatchObject({ toVerify: false });
    expect(sanity.checkTotal({ total: 50, days: 3, otherTotals: [216] })).toMatchObject({ toVerify: false }); // écart 4,3 : toléré
  });
  test('plus de 5 fois au-dessus de la médiane d\'au moins 2 autres → outlier_high (ex. 8 064 € face à 216 € et 240 €)', () => {
    expect(sanity.checkTotal({ total: 8064, days: 15, otherTotals: [216, 240] })).toMatchObject({ toVerify: true, reason: 'outlier_high' });
  });
  test('Saint-Maur aujourd\'hui : noémie 3 768 € seule en attente (les 2 refusées ne comptent pas dans la médiane) → payable', () => {
    const post = SAINT_MAUR;
    const sibs = [
      { _id: 'n', status: 'pending', pricing: { totalPrice: 3768 } },
      { _id: 'h', status: 'rejected', pricing: { totalPrice: 2.7 } },
      { _id: 's', status: 'rejected', pricing: { totalPrice: 7.5 } },
    ];
    expect(sanity.checkApplication(sibs[0], post, sibs)).toMatchObject({ toVerify: false });
    expect(sanity.checkApplication(sibs[1], post, sibs)).toMatchObject({ toVerify: true, reason: 'too_low' });
    expect(sanity.checkApplication(sibs[2], post, sibs)).toMatchObject({ toVerify: true, reason: 'too_low' });
  });
  test('dates à prévoir / tarif à venir : jamais marqué (pas de total)', () => {
    expect(sanity.checkApplication({ _id: 'x', pricing: { indicative: true, totalPrice: null } }, { dateMode: 'tbd' }, [])).toMatchObject({ toVerify: false });
    expect(sanity.checkApplication({ _id: 'x', pricing: { stale: true, totalPrice: 2.7 } }, EGLY, [])).toMatchObject({ toVerify: false });
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
  }, 180000);
  afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

  test('frederic 36 € marqué « prix à confirmer » et NON payable ; Agnès 216 € choisie normalement', async () => {
    const post = (await request(app).post('/posts').set(hdr(S.owner._id, 'owner')).send({
      body: 'Demande de test 3110, zone test.', language: 'fr', animalCount: 1, animalTypes: ['dog'], petIds: [String(S.pet._id)], location: LOC,
      serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'exact', startDate: day(20), endDate: day(22),
    }).expect(201)).body.post;
    const apply = (who) => request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(who._id, 'sitter')).send({
      postId: post.id || String(post._id), description: 'Je suis disponible.', timeSlot: 'morning', serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: day(20), startDate: day(20), endDate: day(22),
    });
    const rf = await apply(S.fred); expect(rf.status).toBe(201);
    const ra = await apply(S.agnes); expect(ra.status).toBe(201);
    const fredApp = await Application.findOne({ sitterId: S.fred._id }).lean();
    const agnesApp = await Application.findOne({ sitterId: S.agnes._id }).lean();
    expect(fredApp.pricing).toMatchObject({ totalPrice: 36, commission: 6, netPayout: 30, commissionRate: 0.2 });
    expect(agnesApp.pricing).toMatchObject({ totalPrice: 216, commission: 36, netPayout: 180, commissionRate: 0.2 });

    // la liste du propriétaire marque frederic, pas Agnès
    const list = (await request(app).get('/applications/my').set(hdr(S.owner._id, 'owner')).expect(200)).body.applications;
    const lf = list.find((a) => String(a.id || a._id) === String(fredApp._id));
    const la = list.find((a) => String(a.id || a._id) === String(agnesApp._id));
    expect(lf.pricing).toMatchObject({ totalPrice: 36, priceToConfirm: true, priceCheckReason: 'outlier_low', priceToConfirmLabel: 'Prix à confirmer par le gardien' });
    expect(la.pricing.priceToConfirm).toBeUndefined();

    // choisir frederic : refusé, rien d'écrit, aucune réservation
    const bookingsBefore = await Booking.countDocuments({});
    const acc = await request(app).post(`/applications/${fredApp._id}/respond`).set(hdr(S.owner._id, 'owner')).send({ action: 'accept' });
    expect(acc.status).toBe(409);
    expect(acc.body).toMatchObject({ code: 'PRICE_TO_CONFIRM', reason: 'outlier_low' });
    expect(acc.body.error).toMatch(/^Prix à confirmer par le gardien/);
    const fredAfter = await Application.findById(fredApp._id).lean();
    expect(fredAfter.status).toBe('pending');
    expect(fredAfter.pricing).toMatchObject({ totalPrice: 36, commission: 6, netPayout: 30 }); // aucun prix touché
    expect(await Booking.countDocuments({})).toBe(bookingsBefore);

    // choisir Agnès : le garde-fou laisse passer, réservation au prix juste (commission 20 % ajoutée)
    const accA = await request(app).post(`/applications/${agnesApp._id}/respond`).set(hdr(S.owner._id, 'owner')).send({ action: 'accept' });
    if (accA.status !== 200) console.log('accept Agnès →', accA.status, JSON.stringify(accA.body)); // eslint-disable-line no-console
    expect(accA.status).toBe(200);
    const b = await Booking.findOne({}).sort({ createdAt: -1 }).lean();
    expect(b.pricing).toMatchObject({ totalPrice: 216, commission: 36, netPayout: 180 });
  }, 90000);
});
