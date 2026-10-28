// 620b (ZOE, 24/10/2026 — ordre de Daniel « requalifie la demande de Svitlana en visites à domicile,
// 1 par jour, et préviens les gardiens », puis « mets à jour les annonces déjà publiées »).
// LA DEMANDE CHANGE DE SERVICE (PATCH /posts/:id : serviceTypes / visitsPerDay / houseSittingVenue)
// avec des candidatures EN ATTENTE :
//   · prestataire avec un tarif pour le nouveau service → candidature recalculée (moteur 620),
//     notification application_pricing_updated au prestataire ET au propriétaire ;
//   · sans tarif → pricing.indicative + pricing.stale (totaux null, « tarif à venir »),
//     notification application_service_changed au prestataire (9 langues) ;
//   · aucun double envoi (re-PATCH identique, rejeu admin POST /admin/reprice-620/posts/:id) ;
//   · demande « dates à prévoir » : même règle, tarif unitaire indicatif.
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
let Owner; let Sitter; let Pet; let Post; let Application; let Notification;
const PASS = 'MotDePasseTest620!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': '23.1.589+620' });
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const bell = async (userId, type) => { await wait(400); return Notification.find({ recipientId: userId, type }).sort({ createdAt: 1 }).lean(); };

const S = {};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter');
  Pet = require('../src/models/Pet'); Post = require('../src/models/Post'); Application = require('../src/models/Application');
  Notification = require('../src/models/Notification');
  require('../src/models/Walker'); require('../src/models/Booking'); require('../src/models/Block');
  await Promise.all([Owner.init(), Sitter.init(), Pet.init(), Post.init(), Application.init(), Notification.init()]);

  const base = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  S.owner = await Owner.create({ ...base, name: 'Svitlana Test', email: 'zoe620b+svit@example.test', acceptedTerms: true });
  S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Chat', petType: 'cat' });
  // Hanene : garde 18 €/j ET visites 12 €/visite → recalculée ; Sohane : garde 50 €/j seulement → « tarif à venir »
  S.hanene = await Sitter.create({ ...base, name: 'Hanene Test', email: 'zoe620b+hanene@example.test', dailyRate: 18, visitRate: 12, visitDurationMinutes: 30 });
  S.sohane = await Sitter.create({ ...base, name: 'Sohane Test', email: 'zoe620b+sohane@example.test', dailyRate: 50, visitRate: 0, appLocale: 'en' });

  app = express();
  app.use(express.json());
  app.use('/posts', require('../src/routes/postRoutes'));
  app.use('/applications', require('../src/routes/applicationRoutes'));
  app.use('/admin/reprice-620', require('../src/routes/adminReprice620'));
  app.use('/sitters', require('../src/routes/sitterRoutes'));
}, 180000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

const createPost = (body) => request(app).post('/posts').set(hdr(S.owner._id, 'owner')).send({
  body: 'Garde de mon chat, zone test.', language: 'fr', animalCount: 1, animalTypes: ['cat'], petIds: [String(S.pet._id)], location: LOC, ...body,
});
const apply = (sitter, postId, serviceType) => request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(sitter._id, 'sitter')).send({ postId, serviceType, description: 'Dispo pour votre chat.', serviceDate: day(10), timeSlot: 'morning', houseSittingVenue: 'owners_home' });

describe('A. demande DATÉE : garde à domicile (3 jours) → visites à domicile 1/jour', () => {
  test('mise en place : demande house_sitting datée, 2 candidatures à la journée (18 €/j et 50 €/j)', async () => {
    const r = await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'exact', startDate: day(10), endDate: day(12) });
    if (r.status !== 201) console.log('createPost →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(201);
    S.post = r.body.post;
    const a = await apply(S.hanene, S.post.id, 'house_sitting');
    if (a.status !== 201) console.log('apply hanene →', a.status, JSON.stringify(a.body)); // eslint-disable-line no-console
    expect(a.status).toBe(201);
    S.appHanene = a.body.application.id || a.body.application._id;
    const b = await apply(S.sohane, S.post.id, 'house_sitting');
    expect(b.status).toBe(201);
    S.appSohane = b.body.application.id || b.body.application._id;
    // 2810b — un gardien qui a un tarif jour est désormais facturé à ce tarif sur une demande de visites
    // (plus de « tarif à venir ») : pour garder la couverture du cas « aucun tarif », on retire ici TOUS ses tarifs.
    await Sitter.updateOne({ _id: S.sohane._id }, { $set: { dailyRate: 0, weeklyRate: 0, monthlyRate: 0, hourlyRate: 0 } });
    const h = await Application.findById(S.appHanene).lean();
    expect(h.pricing.totalPrice).toBeGreaterThan(0);
    expect(h.pricing.indicative).toBe(false);
    S.totalBefore = h.pricing.totalPrice;
    await Notification.deleteMany({});
  });

  test('PATCH serviceTypes → home_visit, visitsPerDay 1 : Hanene recalculée 3 × 12 = 36 + 20 % = 43,20 ; Sohane « tarif à venir » (stale)', async () => {
    const r = await request(app).patch(`/posts/${S.post.id}`).set(hdr(S.owner._id, 'owner')).send({ serviceTypes: ['home_visit'], visitsPerDay: 1 });
    if (r.status !== 200) console.log('updatePost →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    expect(r.body.post.serviceTypes).toEqual(['home_visit']);
    expect(r.body.serviceChanged).toEqual({ repriced: 1, stale: 1, aligned: 0 });
    const h = await Application.findById(S.appHanene).lean();
    expect(h.serviceType).toBe('home_visit');
    expect(h.pricing).toMatchObject({ indicative: false, stale: false, pricingTier: 'visit', appliedRate: 12, quantity: 3, unit: 'visit', basePrice: 36, commission: 7.2, netPayout: 36, totalPrice: 43.2, currency: 'EUR' });
    const s = await Application.findById(S.appSohane).lean();
    expect(s.serviceType).toBe('home_visit');
    expect(s.pricing).toMatchObject({ indicative: true, stale: true, pricingTier: 'indicative', appliedRate: 0, unit: 'visit', quantity: null, totalPrice: null, commission: null, netPayout: null });
    // lecture API : `stale` toujours présent (« tarif à venir » côté propriétaire / app / site)
    const { sanitizeApplication } = require('../src/utils/sanitize');
    expect(sanitizeApplication(s).pricing.stale).toBe(true);
    expect(sanitizeApplication(h).pricing.stale).toBe(false);
  });

  test('notifications : Hanene (prix recalculé, fr), Sohane (ajoute ton tarif, en), propriétaire (nouveaux prix) — une chacune', async () => {
    const nh = await bell(S.hanene._id, 'application_pricing_updated');
    expect(nh.length).toBe(1);
    expect(nh[0].data).toMatchObject({ postId: S.post.id, applicationId: String(S.appHanene), serviceChanged: '1', serviceKey: 'home_visit' });
    expect(nh[0].title).toBe('La demande a changé de service');
    expect(nh[0].body).toContain('Visite à domicile');
    expect(nh[0].body).toMatch(/43,20.€/);
    const ns = await bell(S.sohane._id, 'application_service_changed');
    expect(ns.length).toBe(1);
    expect(ns[0].title).toBe('The request changed service');
    expect(ns[0].body).toBe('The request is now Home visit: add your rate per visit to stay a candidate');
    expect(await bell(S.sohane._id, 'application_pricing_updated')).toHaveLength(0);
    const no = await bell(S.owner._id, 'application_pricing_updated');
    expect(no.length).toBe(1);
    expect(no[0].title).toBe('Ta demande est passée en Visite à domicile');
    expect(no[0].data).toMatchObject({ candidates: '1', serviceChanged: '1', applicationId: String(S.appHanene) });
    // e-mail parti aux trois (texte de la langue du lecteur)
    await wait(300);
    expect(MAILS.some((m) => m.to === 'zoe620b+sohane@example.test' && m.subject.includes('Home visit'))).toBe(true);
    expect(MAILS.some((m) => m.to === 'zoe620b+hanene@example.test' && m.subject.includes('Visite à domicile'))).toBe(true);
  });

  test('aucun double envoi : re-PATCH identique, puis rejeu admin → candidatures alignées, 0 notification de plus', async () => {
    const r = await request(app).patch(`/posts/${S.post.id}`).set(hdr(S.owner._id, 'owner')).send({ serviceTypes: ['home_visit'], visitsPerDay: 1 });
    expect(r.status).toBe(200);
    expect(r.body.serviceChanged).toBeUndefined();
    const dry = await request(app).post(`/admin/reprice-620/posts/${S.post.id}?dryRun=1`).set(ADMIN).send({});
    expect(dry.status).toBe(200);
    expect(dry.body).toMatchObject({ dryRun: true, service: 'home_visit', visitsPerDay: 1, repriced: [], stale: [] });
    expect(dry.body.aligned).toHaveLength(2);
    const replay = await request(app).post(`/admin/reprice-620/posts/${S.post.id}`).set(ADMIN).send({});
    expect(replay.status).toBe(200);
    expect(replay.body.aligned).toHaveLength(2);
    expect(replay.body.notified).toEqual({ owner: false, providers: 0 });
    await wait(400);
    expect(await Notification.countDocuments({ recipientId: S.hanene._id })).toBe(1);
    expect(await Notification.countDocuments({ recipientId: S.sohane._id })).toBe(1);
    expect(await Notification.countDocuments({ recipientId: S.owner._id, type: 'application_pricing_updated' })).toBe(1);
    await request(app).post('/admin/reprice-620/posts/000000000000000000000000').set(ADMIN).send({}).expect(404);
    await request(app).post(`/admin/reprice-620/posts/${S.post.id}`).set(hdr(S.owner._id, 'owner')).send({}).expect(403);
  });

  test('Sohane ajoute son tarif par visite (15 €) → recalcul AUTOMATIQUE dès le PUT (620c) : 3 × 15 = 45 + 9 = 54, une notification de chaque côté, stale = false ; le rejeu admin ne trouve plus rien à faire', async () => {
    const p = await request(app).put('/sitters/me/pricing').set(hdr(S.sohane._id, 'sitter')).send({ visitRate: 15, visitDurationMinutes: 30 });
    if (p.status !== 200) console.log('pricing →', p.status, JSON.stringify(p.body)); // eslint-disable-line no-console
    expect(p.status).toBe(200);
    expect(p.body.repricedApplications).toBe(1);
    const s = await Application.findById(S.appSohane).lean();
    expect(s.pricing).toMatchObject({ indicative: false, stale: false, pricingTier: 'visit', appliedRate: 15, quantity: 3, totalPrice: 54 });
    await wait(400);
    expect(await Notification.countDocuments({ recipientId: S.sohane._id, type: 'application_pricing_updated' })).toBe(1);
    expect(await Notification.countDocuments({ recipientId: S.owner._id, type: 'application_pricing_updated' })).toBe(2);
    // rejeu admin : les deux candidatures sont alignées, 0 envoi (idempotent)
    const replay = await request(app).post(`/admin/reprice-620/posts/${S.post.id}`).set(ADMIN).send({});
    expect(replay.status).toBe(200);
    expect(replay.body.repriced).toEqual([]);
    expect(replay.body.aligned.sort()).toEqual([String(S.appHanene), String(S.appSohane)].sort());
    expect(replay.body.notified).toEqual({ owner: false, providers: 0 });
    await wait(300);
    expect(await Notification.countDocuments({ recipientId: S.sohane._id, type: 'application_pricing_updated' })).toBe(1);
    expect(await Notification.countDocuments({ recipientId: S.owner._id, type: 'application_pricing_updated' })).toBe(2);
  });

  test('visitsPerDay 1 → 2 (même service) : recalcul 6 visites, Hanene 72 + 14,40 = 86,40', async () => {
    const r = await request(app).patch(`/posts/${S.post.id}`).set(hdr(S.owner._id, 'owner')).send({ visitsPerDay: 2 });
    expect(r.status).toBe(200);
    expect(r.body.serviceChanged).toEqual({ repriced: 2, stale: 0, aligned: 0 });
    const h = await Application.findById(S.appHanene).lean();
    expect(h.pricing).toMatchObject({ quantity: 6, totalPrice: 86.4 });
  });
});

describe('B. demande « dates à prévoir » : garde → visites', () => {
  test('candidatures indicatives recalculées au tarif unitaire du nouveau service ; sans tarif → stale', async () => {
    await Sitter.updateOne({ _id: S.sohane._id }, { $set: { visitRate: 0 } });
    const r = await createPost({ body: 'Garde, dates à prévoir, zone test.', serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'tbd' });
    expect(r.status).toBe(201);
    const post = r.body.post;
    const a = await request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(S.hanene._id, 'sitter')).send({ postId: post.id, serviceType: 'house_sitting', houseSittingVenue: 'owners_home', description: 'Dispo.' });
    expect(a.status).toBe(201);
    expect(a.body.application.pricing).toMatchObject({ indicative: true, appliedRate: 18, unit: 'day' });
    await Sitter.updateOne({ _id: S.sohane._id }, { $set: { dailyRate: 50 } });
    const b = await request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(S.sohane._id, 'sitter')).send({ postId: post.id, serviceType: 'house_sitting', houseSittingVenue: 'owners_home', description: 'Dispo.' });
    expect(b.status).toBe(201);
    // 2810b — un gardien qui a un tarif jour est désormais facturé à ce tarif sur une demande de visites
    // (plus de « tarif à venir ») : pour garder la couverture du cas « aucun tarif », on retire ici TOUS ses tarifs.
    await Sitter.updateOne({ _id: S.sohane._id }, { $set: { dailyRate: 0, weeklyRate: 0, monthlyRate: 0, hourlyRate: 0 } });
    await Notification.deleteMany({});
    const u = await request(app).patch(`/posts/${post.id}`).set(hdr(S.owner._id, 'owner')).send({ serviceTypes: ['home_visit'], visitsPerDay: 1 });
    expect(u.status).toBe(200);
    expect(u.body.serviceChanged).toEqual({ repriced: 1, stale: 1, aligned: 0 });
    const h = await Application.findById(a.body.application.id || a.body.application._id).lean();
    expect(h.pricing).toMatchObject({ indicative: true, stale: false, pricingTier: 'indicative', appliedRate: 12, unit: 'visit', quantity: null, totalPrice: null });
    const s = await Application.findById(b.body.application.id || b.body.application._id).lean();
    expect(s.pricing).toMatchObject({ indicative: true, stale: true, appliedRate: 0, unit: 'visit', totalPrice: null });
    const nh = await bell(S.hanene._id, 'application_pricing_updated');
    expect(nh.length).toBe(1);
    expect(nh[0].body).toMatch(/12,00.€ par visite/);
    expect(await bell(S.sohane._id, 'application_service_changed')).toHaveLength(1);
    expect(await bell(S.owner._id, 'application_pricing_updated')).toHaveLength(1);
  });
});
