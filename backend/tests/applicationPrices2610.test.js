// 2610 (ZOE, 26/10/2026 — ordre de Daniel « corrige le bug et les prix de toutes les candidatures en
// attente, SANS envoyer de message aux clients »). 0 acceptée sur 103 candidatures : les propriétaires
// voyaient des prix faux (2,70 € pour 18 €/jour, 8 064 € pour 12 €/balade).
//   1. Nouvelles candidatures : dates à prévoir, garde 1 jour, garde 15 jours (tarif semaine ignoré),
//      balades multi-jours (1/jour), balade 1 jour, US en dollars → prix du moteur unique.
//   2. Recalcul admin : les prix faux ne sont plus « alignés » ; dryRun n'écrit rien ; silent=1 corrige
//      SANS aucune notification, aucun e-mail, aucun push ; les candidatures justes ne bougent pas.
//   3. Filet à l'acceptation : la réservation part toujours au bon prix.
// VRAIE base Mongo en mémoire, VRAIS routeurs. Zone fictive lat -35 / lng -30.
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


const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const inDays = (n) => new Date(Date.now() + n * 86400000);
const day = (n) => { const d = inDays(n); return `${d.toISOString().slice(0, 10)}T00:00:00.000Z`; };
let mongo; let app;
let Owner; let Sitter; let Walker; let Pet; let Post; let Application; let Booking; let Notification;
const PASS = 'MotDePasseTest2610!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': '23.1.590+621' });
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const S = {};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Pet = require('../src/models/Pet'); Post = require('../src/models/Post'); Application = require('../src/models/Application');
  Booking = require('../src/models/Booking'); Notification = require('../src/models/Notification');
  require('../src/models/Block');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Pet.init(), Post.init(), Application.init(), Booking.init(), Notification.init()]);
  const fr = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  const us = { password: PASS, city: 'Zone test', country: 'US', currency: 'USD', verified: true, location: ZONE, appLocale: 'en' };
  S.owner = await Owner.create({ ...fr, name: 'Karine Test', email: 'zoe2610+owner@example.test', acceptedTerms: true });
  S.ownerUs = await Owner.create({ ...us, name: 'Lillian Test', email: 'zoe2610+owner-us@example.test', acceptedTerms: true });
  S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Rex', petType: 'dog' });
  S.petUs = await Pet.create({ ownerId: S.ownerUs._id, petName: 'Max', petType: 'dog' });
  // Hanene : 18 €/jour ; Sohane : 50 €/jour MAIS 100 €/semaine (grille incohérente : le tarif jour fait foi) ;
  // Imane : promeneuse 12 €/30 min ; Nieheem : 100 $/jour (US).
  S.hanene = await Sitter.create({ ...fr, name: 'Hanene Test', email: 'zoe2610+hanene@example.test', dailyRate: 18 });
  S.sohane = await Sitter.create({ ...fr, name: 'Sohane Test', email: 'zoe2610+sohane@example.test', dailyRate: 50, weeklyRate: 100 });
  S.imane = await Walker.create({ ...fr, name: 'Imane Test', email: 'zoe2610+imane@example.test', walkRates: [{ durationMinutes: 30, basePrice: 12, currency: 'EUR', enabled: true }] });
  S.nieheem = await Sitter.create({ ...us, name: 'Nieheem Test', email: 'zoe2610+nieheem@example.test', dailyRate: 100 });

  app = express();
  app.use(express.json());
  app.use('/posts', require('../src/routes/postRoutes'));
  app.use('/applications', require('../src/routes/applicationRoutes'));
  app.use('/admin/reprice-620', require('../src/routes/adminReprice620'));
}, 180000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

const createPost = (body, who = S.owner, pet = S.pet) => request(app).post('/posts').set(hdr(who._id, 'owner')).send({
  body: 'Demande de test 2610, zone test.', language: 'fr', animalCount: 1, animalTypes: ['dog'], petIds: [String(pet._id)], location: LOC, ...body,
});
const apply = (post, who, role, extra = {}, owner = S.owner) => request(app).post(`/applications?ownerId=${owner._id}`).set(hdr(who._id, role)).send({
  postId: post.id || String(post._id), description: 'Je suis disponible.', timeSlot: 'morning', ...extra,
});
const pricingOf = async (r) => {
  if (r.status !== 201) console.log('apply →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
  expect(r.status).toBe(201);
  return (await Application.findById(r.body.application.id || r.body.application._id).lean()).pricing;
};

describe('1. Nouvelles candidatures : prix du moteur unique (cause racine des prix faux)', () => {
  test('dates à prévoir (garde) → indicatif : 18 €/jour, AUCUN total (avant : 2,70 €)', async () => {
    S.postTbd = (await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'tbd' }).expect(201)).body.post;
    const d = inDays(3);
    const p = await pricingOf(await apply(S.postTbd, S.hanene, 'sitter', { serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: d.toISOString() }));
    expect(p).toMatchObject({ indicative: true, appliedRate: 18, totalPrice: null, unit: 'day' });
  }, 60000);
  test('garde datée sur UN seul jour (fin = début, cas Lillian) → 1 jour × 18 = 18 + 20 % = 21,60 (avant : 2,70)', async () => {
    S.postOneDay = (await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'exact', startDate: day(20), endDate: day(20) }).expect(201)).body.post;
    const p = await pricingOf(await apply(S.postOneDay, S.hanene, 'sitter', { serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: day(20), startDate: day(20), endDate: day(20) }));
    expect(p).toMatchObject({ indicative: false, appliedRate: 18, quantity: 1, unit: 'day', basePrice: 18, commission: 3.6, totalPrice: 21.6, currency: 'EUR' });
    expect(p.totalPrice).toBeGreaterThanOrEqual(p.appliedRate);
  }, 60000);
  test('garde datée 15 jours : tarif JOUR × 15, jamais le tarif semaine en douce (Sohane 50 €/j → 900 €, pas 257 €)', async () => {
    S.postGarde = (await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'exact', startDate: day(30), endDate: day(44) }).expect(201)).body.post;
    const p = await pricingOf(await apply(S.postGarde, S.sohane, 'sitter', { serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: day(30), startDate: day(30), endDate: day(44) }));
    expect(p).toMatchObject({ appliedRate: 50, quantity: 15, unit: 'day', basePrice: 750, commission: 150, totalPrice: 900 });
    // l'app envoie une SEULE date (ancien client) : même prix, ce sont les dates de la demande qui comptent
    const p2 = await pricingOf(await apply(S.postGarde, S.hanene, 'sitter', { serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: day(30) }));
    expect(p2).toMatchObject({ appliedRate: 18, quantity: 15, totalPrice: 324 });
  }, 60000);
  test('balades datées sur 15 jours : 1 balade par jour × 12 € = 180 + 20 % = 216 (avant : 8 064 €)', async () => {
    S.postWalk = (await createPost({ serviceTypes: ['dog_walking'], serviceLocation: 'pickup', walkDurationMinutes: 30, dateMode: 'exact', startDate: day(30), endDate: day(44) }).expect(201)).body.post;
    const p = await pricingOf(await apply(S.postWalk, S.imane, 'walker', { serviceType: 'dog_walking', duration: 30, serviceDate: day(30), startDate: day(30), endDate: day(44) }));
    expect(p).toMatchObject({ appliedRate: 12, quantity: 15, unit: 'walk', basePrice: 180, commission: 36, totalPrice: 216 });
  }, 60000);
  test('balade sur un seul jour → 1 balade : 12 + 20 % = 14,40', async () => {
    const post = (await createPost({ body: 'Balade unique 2610.', serviceTypes: ['dog_walking'], serviceLocation: 'pickup', walkDurationMinutes: 30, dateMode: 'exact', startDate: day(50), endDate: day(50) }).expect(201)).body.post;
    const p = await pricingOf(await apply(post, S.imane, 'walker', { serviceType: 'dog_walking', duration: 30, serviceDate: day(50) }));
    expect(p).toMatchObject({ quantity: 1, unit: 'walk', totalPrice: 14.4 });
  }, 60000);
  test('US (dollars) : garde 25 jours à 100 $/jour → 2 500 + 20 % = 3 000 $ (avant : 1 645,72 $)', async () => {
    const post = (await createPost({ serviceTypes: ['pet_sitting'], dateMode: 'exact', startDate: day(60), endDate: day(84) }, S.ownerUs, S.petUs).expect(201)).body.post;
    const p = await pricingOf(await apply(post, S.nieheem, 'sitter', { serviceType: 'long_stay', serviceDate: day(60), startDate: day(60), endDate: day(84) }, S.ownerUs));
    expect(p).toMatchObject({ appliedRate: 100, quantity: 25, unit: 'day', basePrice: 2500, commission: 500, totalPrice: 3000, currency: 'USD' });
  }, 60000);
});

describe('2. Recalcul admin des candidatures déjà faussées : reconnues, corrigées, SANS AUCUN ENVOI', () => {
  test('les prix faux stockés ne sont plus « alignés » ; dryRun n\'écrit rien ; silent=1 corrige sans push, e-mail ni cloche', async () => {
    // on fausse les candidatures comme en production (ancien calcul horaire)
    const tbdApp = await Application.findOne({ postId: S.postTbd.id });
    await Application.updateOne({ _id: tbdApp._id }, { $set: { 'pricing.indicative': false, 'pricing.totalPrice': 2.7, 'pricing.basePrice': 2.25, 'pricing.commission': 0.45, 'pricing.appliedRate': 2.25, 'pricing.pricingTier': 'hourly', 'pricing.quantity': null } });
    const walkApp = await Application.findOne({ postId: S.postWalk.id });
    await Application.updateOne({ _id: walkApp._id }, { $set: { 'pricing.totalPrice': 8064, 'pricing.quantity': 1, 'pricing.appliedRate': 12 } });
    const oneApp = await Application.findOne({ postId: S.postOneDay.id });
    await Application.updateOne({ _id: oneApp._id }, { $set: { 'pricing.totalPrice': 2.7, 'pricing.appliedRate': 18, 'pricing.quantity': 1, 'pricing.unit': 'day' } });
    const gardeOk = await Application.find({ postId: S.postGarde.id }).lean();

    const dry = await request(app).post(`/admin/reprice-620/posts/${S.postTbd.id}?dryRun=1`).set(ADMIN).send({}).expect(200);
    expect(dry.body.repriced).toEqual([String(tbdApp._id)]);
    expect(dry.body.details[0]).toMatchObject({ totalBefore: 2.7, total: null, rate: 18, indicative: true });
    expect((await Application.findById(tbdApp._id).lean()).pricing.totalPrice).toBe(2.7); // rien écrit

    const before = { notif: await Notification.countDocuments({}), mails: MAILS.length, pushes: PUSHES.length };
    const runs = {};
    for (const p of [S.postTbd, S.postWalk, S.postOneDay, S.postGarde]) {
      // eslint-disable-next-line no-await-in-loop
      runs[p.id] = (await request(app).post(`/admin/reprice-620/posts/${p.id}?silent=1`).set(ADMIN).send({}).expect(200)).body;
    }
    expect(runs[S.postTbd.id]).toMatchObject({ silent: true, repriced: [String(tbdApp._id)], notified: { owner: false, providers: 0 } });
    expect(runs[S.postWalk.id].details[0]).toMatchObject({ totalBefore: 8064, total: 216, quantity: 15 });
    expect(runs[S.postOneDay.id].details[0]).toMatchObject({ totalBefore: 2.7, total: 21.6 });
    // les candidatures justes ne sont pas retouchées
    expect(runs[S.postGarde.id].repriced).toEqual([]);
    expect(runs[S.postGarde.id].aligned.sort()).toEqual(gardeOk.map((a) => String(a._id)).sort());
    await wait(500);
    expect(await Notification.countDocuments({})).toBe(before.notif);
    expect(MAILS.length).toBe(before.mails);
    expect(PUSHES.length).toBe(before.pushes);

    expect((await Application.findById(tbdApp._id).lean()).pricing).toMatchObject({ indicative: true, totalPrice: null, appliedRate: 18 });
    expect((await Application.findById(walkApp._id).lean()).pricing).toMatchObject({ totalPrice: 216, quantity: 15 });
    // rejeu : tout est aligné, rien n'est réécrit
    const replay = await request(app).post(`/admin/reprice-620/posts/${S.postWalk.id}?silent=1`).set(ADMIN).send({}).expect(200);
    expect(replay.body.repriced).toEqual([]);
    expect(replay.body.aligned).toEqual([String(walkApp._id)]);
  }, 90000);
});

describe('3. Filet au moment du choix + règles d\'incohérence', () => {
  test('un prix stocké faux est remplacé AVANT de créer la réservation', async () => {
    const a = await Application.findOne({ postId: S.postGarde.id, sitterId: S.hanene._id });
    await Application.updateOne({ _id: a._id }, { $set: { 'pricing.totalPrice': 2.7 } });
    const r = await request(app).post(`/applications/${a._id}/respond`).set(hdr(S.owner._id, 'owner')).send({ action: 'accept' });
    if (r.status !== 200) console.log('accept →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    const saved = await Application.findById(a._id).lean();
    expect(saved.pricing.totalPrice).toBe(324);
    const b = await Booking.findById(saved.bookingId).lean();
    expect(b.pricing).toMatchObject({ totalPrice: 324, commission: 54, netPayout: 270 });
  }, 60000);
  test('isIncoherentTotal : total < tarif unitaire, ou absent sur une demande datée', () => {
    const { isIncoherentTotal } = require('../src/services/applicationRepricing620');
    expect(isIncoherentTotal({ totalPrice: 2.7, appliedRate: 18 })).toBe(true);
    expect(isIncoherentTotal({ totalPrice: null, appliedRate: 18 })).toBe(true);
    expect(isIncoherentTotal({ totalPrice: 21.6, appliedRate: 18 })).toBe(false);
    expect(isIncoherentTotal({ indicative: true, totalPrice: null, appliedRate: 18 })).toBe(false);
    expect(isIncoherentTotal({ stale: true, indicative: true, totalPrice: null })).toBe(false);
  });
});
