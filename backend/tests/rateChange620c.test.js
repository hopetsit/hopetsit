// 620c (ZOE, 24/10/2026 — décision de Daniel, 21 h, transmise par BOB) — LE PRESTATAIRE AJOUTE OU
// CHANGE SON TARIF : ses candidatures en attente « tarif à venir » (pricing.stale) sont
// recalculées par le moteur 620, propriétaire et prestataire prévenus (application_pricing_updated,
// gabarits application_rate_added_owner / application_rate_added, 9 langues) ;
//   · une candidature NON stale n'est jamais retouchée (une offre faite reste une offre), rien d'envoyé ;
//   · un tarif qui ne concerne pas le service de la demande → rien ; un PUT sans tarif → rien ;
//   · idempotent : un second PUT identique n'envoie rien ;
//   · promeneur (PUT /walkers/me/rates) : même règle.
// VRAIE base Mongo en mémoire, VRAIS routeurs. Zone fictive lat -35 / lng -30.
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
    createPlatformPaymentIntent: jest.fn(async (body) => ({ id: 'int_620c', client_secret: 'cs', status: 'REQUIRES_PAYMENT_METHOD', amount: body.amount / 100, currency: body.currency })),
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
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async (m) => ({ successCount: m.tokens.length, failureCount: 0, responses: [] })) }) }));
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
let Owner; let Sitter; let Walker; let Pet; let Post; let Application; let Notification;
const PASS = 'MotDePasseTest620c!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': '23.1.589+620' });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const bell = async (userId, type = 'application_pricing_updated') => { await wait(400); return Notification.find({ recipientId: userId, type }).sort({ createdAt: 1 }).lean(); };
const TYPE = 'application_pricing_updated';

const S = {};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Pet = require('../src/models/Pet'); Post = require('../src/models/Post'); Application = require('../src/models/Application');
  Notification = require('../src/models/Notification');
  require('../src/models/Booking'); require('../src/models/Block');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Pet.init(), Post.init(), Application.init(), Notification.init()]);

  const base = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  S.owner = await Owner.create({ ...base, name: 'Svitlana Test', email: 'zoe620c+svit@example.test', acceptedTerms: true });
  S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Chat', petType: 'cat' });
  S.dog = await Pet.create({ ownerId: S.owner._id, petName: 'Rex', petType: 'dog' });
  // Hanene : garde 18 €/j ET visites 12 € → jamais stale ; Sohane (en) et Nadia : garde seulement → « tarif à venir »
  S.hanene = await Sitter.create({ ...base, name: 'Hanene Test', email: 'zoe620c+hanene@example.test', dailyRate: 18, visitRate: 12, visitDurationMinutes: 30 });
  S.sohane = await Sitter.create({ ...base, name: 'Sohane Test', email: 'zoe620c+sohane@example.test', dailyRate: 50, visitRate: 0, appLocale: 'en' });
  S.nadia = await Sitter.create({ ...base, name: 'Nadia Test', email: 'zoe620c+nadia@example.test', dailyRate: 20, visitRate: 0 });
  S.walker = await Walker.create({ ...base, name: 'Paul Promeneur', email: 'zoe620c+paul@example.test', walkRates: [{ durationMinutes: 30, basePrice: 10, currency: 'EUR', enabled: true }] });

  app = express();
  app.use(express.json());
  app.use('/posts', require('../src/routes/postRoutes'));
  app.use('/applications', require('../src/routes/applicationRoutes'));
  app.use('/users', require('../src/routes/userRoutes'));
  app.use('/sitters', require('../src/routes/sitterRoutes'));
  app.use('/walkers', require('../src/routes/walkerRoutes'));
  app.use('/notifications', require('../src/routes/notificationRoutes'));
}, 180000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

const createPost = (body) => request(app).post('/posts').set(hdr(S.owner._id, 'owner')).send({
  body: 'Garde de mon chat, zone test.', language: 'fr', animalCount: 1, animalTypes: ['cat'], petIds: [String(S.pet._id)], location: LOC, ...body,
});
const apply = (sitter, postId, extra = {}) => request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(sitter._id, 'sitter')).send({ postId, serviceType: 'house_sitting', description: 'Dispo pour votre chat.', houseSittingVenue: 'owners_home', ...extra });
const appId = (r) => r.body.application.id || r.body.application._id;
const countAll = async (userId) => { await wait(300); return Notification.countDocuments({ recipientId: userId }); };

describe('mise en place : deux demandes requalifiées en visites → 3 candidatures « tarif à venir »', () => {
  test('demande A datée (3 j) : Hanene recalculée, Sohane et Nadia stale ; demande B « dates à prévoir » : Sohane stale', async () => {
    const a = await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'exact', startDate: day(10), endDate: day(12) });
    expect(a.status).toBe(201);
    S.postA = a.body.post;
    S.appHanene = appId(await apply(S.hanene, S.postA.id, { serviceDate: day(10), timeSlot: 'morning' }));
    S.appSohaneA = appId(await apply(S.sohane, S.postA.id, { serviceDate: day(10), timeSlot: 'morning' }));
    S.appNadia = appId(await apply(S.nadia, S.postA.id, { serviceDate: day(10), timeSlot: 'morning' }));
    const b = await createPost({ body: 'Garde, dates à prévoir, zone test.', serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'tbd' });
    expect(b.status).toBe(201);
    S.postB = b.body.post;
    S.appSohaneB = appId(await apply(S.sohane, S.postB.id));
    const ra = await request(app).patch(`/posts/${S.postA.id}`).set(hdr(S.owner._id, 'owner')).send({ serviceTypes: ['home_visit'], visitsPerDay: 1 });
    expect(ra.status).toBe(200);
    expect(ra.body.serviceChanged).toEqual({ repriced: 1, stale: 2, aligned: 0 });
    const rb = await request(app).patch(`/posts/${S.postB.id}`).set(hdr(S.owner._id, 'owner')).send({ serviceTypes: ['home_visit'], visitsPerDay: 2 });
    expect(rb.status).toBe(200);
    expect(rb.body.serviceChanged).toEqual({ repriced: 0, stale: 1, aligned: 0 });
    const h = await Application.findById(S.appHanene).lean();
    expect(h.pricing).toMatchObject({ stale: false, indicative: false, appliedRate: 12, quantity: 3, totalPrice: 43.2 });
    for (const id of [S.appSohaneA, S.appNadia, S.appSohaneB]) {
      // eslint-disable-next-line no-await-in-loop
      const s = await Application.findById(id).lean();
      expect(s.pricing).toMatchObject({ stale: true, indicative: true, appliedRate: 0, totalPrice: null });
    }
    await wait(500);
    await Notification.deleteMany({});
    MAILS.length = 0;
  });
});

describe('1. candidature stale + le gardien ajoute son tarif → recalcul + 2 notifications', () => {
  test('Sohane PUT /sitters/me/pricing visitRate 15 → A : 3 × 15 = 45 + 9 = 54 (stale false) ; B (tbd) : 15 €/visite indicatif ; réponse repricedApplications: 2', async () => {
    const p = await request(app).put('/sitters/me/pricing').set(hdr(S.sohane._id, 'sitter')).send({ visitRate: 15, visitDurationMinutes: 30 });
    if (p.status !== 200) console.log('pricing →', p.status, JSON.stringify(p.body)); // eslint-disable-line no-console
    expect(p.status).toBe(200);
    expect(p.body.repricedApplications).toBe(2);
    const a = await Application.findById(S.appSohaneA).lean();
    expect(a.pricing).toMatchObject({ stale: false, indicative: false, pricingTier: 'visit', appliedRate: 15, quantity: 3, unit: 'visit', basePrice: 45, commission: 9, netPayout: 45, totalPrice: 54, currency: 'EUR' });
    expect(a.timeSlot).toBeTruthy();
    const b = await Application.findById(S.appSohaneB).lean();
    expect(b.pricing).toMatchObject({ stale: false, indicative: true, pricingTier: 'indicative', appliedRate: 15, unit: 'visit', quantity: null, totalPrice: null });
    // Hanene (jamais stale) et Nadia (toujours sans tarif) : intouchées
    const h = await Application.findById(S.appHanene).lean();
    expect(h.pricing).toMatchObject({ stale: false, appliedRate: 12, totalPrice: 43.2 });
    const n = await Application.findById(S.appNadia).lean();
    expect(n.pricing).toMatchObject({ stale: true, totalPrice: null });
  });

  test('notifications : propriétaire « Sohane a ajouté son tarif : 54,00 € » (+ « 15,00 € par visite » pour B), Sohane en anglais « Your rate is saved » — une par candidature, rien pour Hanene ni Nadia', async () => {
    const no = await bell(S.owner._id);
    expect(no).toHaveLength(2);
    const byApp = Object.fromEntries(no.map((x) => [x.data.applicationId, x]));
    const oa = byApp[String(S.appSohaneA)];
    expect(oa.title).toBe('Sohane a ajouté son tarif');
    expect(oa.body).toMatch(/^Sohane a ajouté son tarif : 54,00.€/);
    expect(oa.data).toMatchObject({ postId: S.postA.id, providerName: 'Sohane', rateAdded: '1', serviceKey: 'home_visit', candidates: '1' });
    const ob = byApp[String(S.appSohaneB)];
    expect(ob.body).toMatch(/18,00.€ par visite/); // 2610 : 15 € + 20 % de frais, ce que paie le propriétaire
    expect(ob.data.postId).toBe(S.postB.id);
    const ns = await bell(S.sohane._id);
    expect(ns).toHaveLength(2);
    expect(ns[0].title).toBe('Your rate is saved');
    expect(ns.map((x) => x.body).sort()).toEqual(['Your application (Home visit) was recalculated: €15.00 per visit', 'Your application (Home visit) was recalculated: €54.00'].sort());
    // la CLOCHE (GET /notifications/my re-rend le texte à la lecture) montre le bon gabarit, pas « Tes dates sont posées »
    const cl = await request(app).get('/notifications/my?limit=10').set(hdr(S.owner._id, 'owner'));
    expect(cl.status).toBe(200);
    const mine = (cl.body.notifications || []).filter((x) => x.type === TYPE);
    expect(mine).toHaveLength(2);
    expect(mine.map((x) => x.title)).toEqual(['Sohane a ajouté son tarif', 'Sohane a ajouté son tarif']);
    expect(mine.some((x) => /54,00.€/.test(x.body))).toBe(true);
    const clEs = await request(app).get('/notifications/my?limit=10&lang=es').set(hdr(S.owner._id, 'owner'));
    expect((clEs.body.notifications || []).filter((x) => x.type === TYPE)[0].title).toBe('Sohane añadió su tarifa');
    const clS = await request(app).get('/notifications/my?limit=10').set(hdr(S.sohane._id, 'sitter'));
    expect((clS.body.notifications || []).filter((x) => x.type === TYPE).map((x) => x.title)).toEqual(['Your rate is saved', 'Your rate is saved']);
    expect(await Notification.countDocuments({ recipientId: S.hanene._id })).toBe(0);
    expect(await Notification.countDocuments({ recipientId: S.nadia._id })).toBe(0);
    expect(await Notification.countDocuments({ recipientId: S.sohane._id, type: 'application_service_changed' })).toBe(0);
    await wait(300);
    expect(MAILS.filter((m) => m.to === 'zoe620c+svit@example.test' && /^Sohane a ajouté son tarif : /.test(m.subject))).toHaveLength(2);
    expect(MAILS.filter((m) => m.to === 'zoe620c+sohane@example.test' && m.subject.startsWith('Your rate is saved'))).toHaveLength(2);
  });
});

describe('2. candidature NON stale : le tarif change, l’offre faite reste l’offre', () => {
  test('Hanene PUT /users/me/profile visitRate 12 → 20 : total toujours 43,20 au tarif 12, rien d’envoyé', async () => {
    const before = await Notification.countDocuments({});
    const r = await request(app).put('/users/me/profile').set(hdr(S.hanene._id, 'sitter')).send({ visitRate: 20 });
    if (r.status !== 200) console.log('profile →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    expect(r.body.repricedApplications).toBeUndefined();
    expect((await Sitter.findById(S.hanene._id).lean()).visitRate).toBe(20);
    const h = await Application.findById(S.appHanene).lean();
    expect(h.pricing).toMatchObject({ stale: false, appliedRate: 12, quantity: 3, totalPrice: 43.2 });
    await wait(300);
    expect(await Notification.countDocuments({})).toBe(before);
  });
});

describe('3. aucun tarif pour le service de la demande → rien', () => {
  test('Nadia PUT /sitters/me/profile dailyRate 30 (pas de visitRate) : toujours « tarif à venir », 0 notification ; PUT sans champ de tarif : rien non plus', async () => {
    const before = await Notification.countDocuments({});
    const r = await request(app).put('/sitters/me/profile').set(hdr(S.nadia._id, 'sitter')).send({ dailyRate: 30 });
    if (r.status !== 200) console.log('sitter profile →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    expect(r.body.repricedApplications).toBeUndefined();
    expect((await Sitter.findById(S.nadia._id).lean()).dailyRate).toBe(30);
    expect((await Application.findById(S.appNadia).lean()).pricing).toMatchObject({ stale: true, totalPrice: null });
    const r2 = await request(app).put('/sitters/me/pricing').set(hdr(S.nadia._id, 'sitter')).send({ responseTimeMinutes: 30 });
    expect(r2.status).toBe(200);
    expect(r2.body.repricedApplications).toBeUndefined();
    await wait(300);
    expect(await Notification.countDocuments({})).toBe(before);
    expect(await countAll(S.nadia._id)).toBe(0);
  });

  test('Nadia ajoute ensuite visitRate 10 via « Modifier le profil » → recalcul 3 × 10 = 30 + 6 = 36, une notification de chaque côté', async () => {
    const r = await request(app).put('/sitters/me/profile').set(hdr(S.nadia._id, 'sitter')).send({ visitRate: 10 });
    expect(r.status).toBe(200);
    expect(r.body.repricedApplications).toBe(1);
    expect((await Application.findById(S.appNadia).lean()).pricing).toMatchObject({ stale: false, appliedRate: 10, quantity: 3, totalPrice: 36 });
    expect(await bell(S.nadia._id)).toHaveLength(1);
    const no = await bell(S.owner._id);
    expect(no).toHaveLength(3);
    expect(no[2].title).toBe('Nadia a ajouté son tarif');
    expect(no[2].body).toMatch(/36,00.€/);
  });
});

describe('4. idempotent : un second PUT identique n’envoie rien', () => {
  test('Sohane re-PUT visitRate 15 → aucune candidature stale, 0 notification de plus', async () => {
    const before = await Notification.countDocuments({});
    const p = await request(app).put('/sitters/me/pricing').set(hdr(S.sohane._id, 'sitter')).send({ visitRate: 15 });
    expect(p.status).toBe(200);
    expect(p.body.repricedApplications).toBeUndefined();
    await wait(300);
    expect(await Notification.countDocuments({})).toBe(before);
    expect((await Application.findById(S.appSohaneA).lean()).pricing.totalPrice).toBe(54);
  });
});

describe('5. promeneur : PUT /walkers/me/rates recalcule sa candidature « tarif à venir »', () => {
  test('balade datée, candidature marquée stale (aucun chemin ne la produit encore pour un promeneur : état posé en base), tarif 30 min 12 € → 12 + 20 % = 14,40, 2 notifications', async () => {
    const r = await createPost({ body: 'Balade pour Rex, zone test.', serviceTypes: ['dog_walking'], serviceLocation: 'pickup', walkDurationMinutes: 30, animalTypes: ['dog'], petIds: [String(S.dog._id)], dateMode: 'exact', startDate: day(8), endDate: day(8) });
    if (r.status !== 201) console.log('walk post →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(201);
    S.postW = r.body.post;
    const a = await request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(S.walker._id, 'walker')).send({ postId: S.postW.id, serviceType: 'dog_walking', description: 'Balade.', serviceDate: day(8), timeSlot: 'morning', duration: 30 });
    if (a.status !== 201) console.log('walk apply →', a.status, JSON.stringify(a.body)); // eslint-disable-line no-console
    expect(a.status).toBe(201);
    S.appWalker = appId(a);
    expect((await Application.findById(S.appWalker).lean()).pricing.totalPrice).toBe(12);
    // le promeneur retire son tarif ; sa candidature est « tarif à venir »
    await Walker.updateOne({ _id: S.walker._id }, { $set: { walkRates: [] } });
    await Application.updateOne({ _id: S.appWalker }, { $set: { 'pricing.stale': true, 'pricing.indicative': true, 'pricing.totalPrice': null, 'pricing.appliedRate': 0 } });
    await wait(500);
    await Notification.deleteMany({});
    const w = await request(app).put('/walkers/me/rates').set(hdr(S.walker._id, 'walker')).send({ walkRates: [{ durationMinutes: 30, basePrice: 12, currency: 'EUR' }] });
    if (w.status !== 200) console.log('walk rates →', w.status, JSON.stringify(w.body)); // eslint-disable-line no-console
    expect(w.status).toBe(200);
    expect(w.body.repricedApplications).toBe(1);
    const app2 = await Application.findById(S.appWalker).lean();
    expect(app2.pricing).toMatchObject({ stale: false, indicative: false, pricingTier: 'walk', appliedRate: 12, quantity: 1, unit: 'walk', basePrice: 12, commission: 2.4, totalPrice: 14.4 });
    const no = await bell(S.owner._id);
    expect(no).toHaveLength(1);
    expect(no[0].title).toBe('Paul a ajouté son tarif');
    expect(no[0].body).toMatch(/14,40.€/);
    expect(no[0].data).toMatchObject({ postId: S.postW.id, applicationId: String(S.appWalker), serviceKey: 'dog_walking' });
    const nw = await bell(S.walker._id);
    expect(nw).toHaveLength(1);
    expect(nw[0].body).toMatch(/14,40.€/);
    // second PUT identique → rien
    const w2 = await request(app).put('/walkers/me/rates').set(hdr(S.walker._id, 'walker')).send({ walkRates: [{ durationMinutes: 30, basePrice: 12, currency: 'EUR' }] });
    expect(w2.status).toBe(200);
    expect(w2.body.repricedApplications).toBeUndefined();
    await wait(300);
    expect(await Notification.countDocuments({})).toBe(2);
  });
});
