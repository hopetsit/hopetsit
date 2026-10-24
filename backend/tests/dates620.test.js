// 620 (ZOE, 24/10/2026 — ordre de Daniel « corrige et fais toutes les mises à jour jusqu'à
// publication ») — PARCOURS « dates à prévoir » + « prix par visite », de bout en bout :
//   createPost (3 modes + compat 619 sans dateMode) → candidature INDICATIVE sur une demande
//   sans dates → acceptation refusée 409 DATES_REQUIRED → le propriétaire pose ses dates
//   (PATCH /posts/:id) → candidatures recalculées + notification application_pricing_updated
//   → acceptation 200 (réservation `visit`) ; chemin « Demander à <prénom> » (targetProvider,
//   PawMap) ; contact de la pub « visites » → home_visit tbd ; rappel J+1 / J+3 ;
//   GET /app-config/services ; POST /pricing/estimate ; PUT /users/me/profile (grille).
// VRAIE base Mongo en mémoire, VRAIS routeurs. Firebase, sockets, e-mails, Airwallex,
// traduction et modération simulés. Zone fictive lat -35 / lng -30.
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
const PASS = 'MotDePasseTest620!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': '23.1.589+620' });
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const bell = async (ownerId, type) => { for (let i = 0; i < 30; i += 1) { await wait(100); const n = await Notification.find({ recipientId: ownerId, type }).lean(); if (n.length) return n; } return []; }; // eslint-disable-line no-await-in-loop

const S = {};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Pet = require('../src/models/Pet'); Post = require('../src/models/Post'); Application = require('../src/models/Application');
  Booking = require('../src/models/Booking'); Notification = require('../src/models/Notification');
  require('../src/models/AdLead2210'); require('../src/models/PostDatesReminder620');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Pet.init(), Post.init(), Application.init(), Booking.init(), Notification.init()]);

  S.owner = await Owner.create({ name: 'Camille Durand', email: 'zoe620+owner@example.test', password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, acceptedTerms: true, appLocale: 'fr' });
  S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Rex', petType: 'dog' });
  S.sitter = await Sitter.create({ name: 'Inès Petit', email: 'zoe620+sitter@example.test', password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', dailyRate: 18, visitRate: 12, visitDurationMinutes: 30, verified: true, location: ZONE, service: ['house_sitting', 'home_visit'] });
  S.sitterNoVisit = await Sitter.create({ name: 'Léa Noir', email: 'zoe620+sitter2@example.test', password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', hourlyRate: 10, verified: true, location: ZONE });
  S.walker = await Walker.create({ name: 'Paul Promeneur', email: 'zoe620+walker@example.test', password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, walkRates: [{ durationMinutes: 30, basePrice: 10, currency: 'EUR', enabled: true }] });

  app = express();
  app.use(express.json());
  const adLeads = require('../src/routes/adLeads2210');
  app.use('/admin/ad-leads', adLeads.adminRouter); app.use('/ad-leads', adLeads);
  app.use('/posts', require('../src/routes/postRoutes'));
  app.use('/applications', require('../src/routes/applicationRoutes'));
  app.use('/app-config', require('../src/routes/appConfigRoutes'));
  app.use('/pricing', require('../src/routes/pricingRoutes'));
  app.use('/users', require('../src/routes/userRoutes'));
  app.use('/sitters', require('../src/routes/sitterRoutes'));
}, 180000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

const createPost = (body, who = S.owner) => request(app).post('/posts').set(hdr(who._id, 'owner')).send({
  body: 'Garde de Rex, zone test.', language: 'fr', animalCount: 1, animalTypes: ['dog'], petIds: [String(S.pet._id)], location: LOC, ...body,
});

describe('1. Catalogue et estimation', () => {
  test('GET /app-config/services (public, cache 60 s) contient home_visit avec unité visite', async () => {
    const r = await request(app).get('/app-config/services').expect(200);
    expect(r.headers['cache-control']).toContain('max-age=60');
    const keys = r.body.services.map((s) => s.key);
    expect(keys).toEqual(['house_sitting', 'home_visit', 'day_care', 'dog_walking']);
    expect(r.body.services.find((s) => s.key === 'home_visit')).toMatchObject({ unit: 'visit', durations: [30, 60], visitsPerDay: [1, 2] });
    expect(r.body.services.find((s) => s.key === 'home_visit').label.fr).toBe('Visite à domicile');
  });
  test('POST /pricing/estimate : formulaire (tarif du prestataire), daté puis tbd ; auth requise', async () => {
    await request(app).post('/pricing/estimate').send({}).expect(401);
    const r = await request(app).post('/pricing/estimate').set(hdr(S.owner._id, 'owner')).send({
      serviceType: 'home_visit', providerId: String(S.sitter._id), providerRole: 'sitter',
      post: { dateMode: 'exact', startDate: day(10), endDate: day(14), visitsPerDay: 2 },
    }).expect(200);
    expect(r.body).toMatchObject({ serviceType: 'home_visit', indicative: false, quantity: 10, unit: 'visit', unitRate: 12, unitTotal: 120, commission: 24, ownerTotal: 144, currency: 'EUR', durationMinutes: 30 });
    const t = await request(app).post('/pricing/estimate').set(hdr(S.owner._id, 'owner')).send({ serviceType: 'home_visit', rate: 12, post: { dateMode: 'tbd' } }).expect(200);
    expect(t.body).toMatchObject({ indicative: true, quantity: null, unitRate: 12, ownerTotal: null });
    // gardien connecté sans providerId : son propre tarif ; sans tarif pour ce service → NO_RATE
    const me = await request(app).post('/pricing/estimate').set(hdr(S.sitter._id, 'sitter')).send({ serviceType: 'house_sitting', post: { startDate: day(10), endDate: day(12) } }).expect(200);
    expect(me.body).toMatchObject({ quantity: 3, unit: 'day', unitRate: 18, unitTotal: 54 });
    const none = await request(app).post('/pricing/estimate').set(hdr(S.sitterNoVisit._id, 'sitter')).send({ serviceType: 'home_visit', post: { startDate: day(10), endDate: day(12) } }).expect(200);
    expect(none.body.code).toBe('NO_RATE');
    // 620b : sans tarif ni prestataire visé → « à partir de » du marché (gardien Inès, 12 €/visite), plus jamais 400
    const open = await request(app).post('/pricing/estimate').set(hdr(S.owner._id, 'owner')).send({ serviceType: 'home_visit', post: { dateMode: 'tbd' } }).expect(200);
    expect(open.body).toMatchObject({ indicative: true, fromRate: 12, basedOn: 1, quantity: null, rateSource: 'market' });
  });
});

describe('2. createPost : 3 modes de dates + compatibilité 619', () => {
  test('app 619 (sans dateMode) : deux dates → exact, inchangé pour les anciens clients', async () => {
    const r = await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', startDate: day(20), endDate: day(22) });
    if (r.status !== 201) console.log('createPost 619 →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(201);
    expect(r.body.post.dateMode).toBe('exact');
    expect(r.body.post.visitsPerDay).toBeNull();
    expect(new Date(r.body.post.startDate).toISOString()).toBe(day(20));
    S.postExact = r.body.post;
  });
  test('approx : période (les deux dates) ; tbd : aucune date, dates envoyées refusées', async () => {
    const a = await createPost({ serviceTypes: ['day_care'], dateMode: 'approx', startDate: day(30), endDate: day(33) }).expect(201);
    expect(a.body.post).toMatchObject({ dateMode: 'approx' });
    const bad = await createPost({ serviceTypes: ['day_care'], dateMode: 'approx', startDate: day(40) , endDate: day(38) }).expect(400);
    expect(bad.body.code).toBe('INVALID_DATES');
    const missing = await createPost({ serviceTypes: ['day_care'], dateMode: 'exact' }).expect(400);
    expect(missing.body.code).toBe('DATES_REQUIRED');
    const forbidden = await createPost({ serviceTypes: ['day_care'], dateMode: 'tbd', startDate: day(40), endDate: day(41) }).expect(400);
    expect(forbidden.body.code).toBe('DATES_FORBIDDEN');
    const m = await createPost({ serviceTypes: ['day_care'], dateMode: 'later' }).expect(400);
    expect(m.body.code).toBe('INVALID_DATE_MODE');
  });
  test('home_visit « dates à prévoir » avec 2 visites/jour (publication directe)', async () => {
    const r = await createPost({ body: 'Visites pour Rex, zone test.', serviceTypes: ['home_visit'], dateMode: 'tbd', visitsPerDay: 2 });
    if (r.status !== 201) console.log('createPost tbd →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(201);
    expect(r.body.post).toMatchObject({ dateMode: 'tbd', visitsPerDay: 2, startDate: null, endDate: null, serviceLocation: 'at_owner' });
    expect(r.body.post.serviceTypes).toEqual(['home_visit']);
    S.postTbd = r.body.post;
    expect(await createPost({ serviceTypes: ['home_visit'], visitsPerDay: 3, dateMode: 'tbd' }).then((x) => x.body.code)).toBe('INVALID_VISITS_PER_DAY');
  });
  test('PawMap « Demander à <prénom> » (targetProvider) : mêmes champs, mêmes règles', async () => {
    const r = await createPost({ body: 'Balade pour Rex via la PawMap.', serviceTypes: ['dog_walking'], serviceLocation: 'pickup', walkDurationMinutes: 30, dateMode: 'tbd', targetProvider: { role: 'walker', id: String(S.walker._id) } });
    if (r.status !== 201) console.log('createPost target →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(201);
    expect(r.body.post).toMatchObject({ dateMode: 'tbd', startDate: null, targetProvider: { role: 'walker', id: String(S.walker._id) } });
    // même demande, même service, même ville, mêmes dates (aucune) → doublon refusé comme avant
    const dup = await createPost({ body: 'Balade pour Rex via la PawMap.', serviceTypes: ['dog_walking'], serviceLocation: 'pickup', dateMode: 'tbd' });
    expect(dup.status).toBe(409);
    S.postTarget = r.body.post;
  });
});

describe('3. Candidature indicative → 409 → dates posées → recalcul → 200', () => {
  test('gardien sans tarif par visite → 400 VISIT_RATE_REQUIRED ; gardien avec tarif → candidature INDICATIVE (12 €/visite, totaux null)', async () => {
    const no = await request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(S.sitterNoVisit._id, 'sitter')).send({ postId: S.postTbd.id, serviceType: 'home_visit', description: 'Je passe voir Rex.' });
    expect(no.status).toBe(400);
    expect(no.body.code).toBe('VISIT_RATE_REQUIRED');
    MAILS.length = 0;
    const r = await request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(S.sitter._id, 'sitter')).send({ postId: S.postTbd.id, serviceType: 'home_visit', description: 'Je passe voir Rex.' });
    if (r.status !== 201) console.log('createApplication tbd →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(201);
    expect(r.body.application.pricing).toMatchObject({ indicative: true, pricingTier: 'indicative', appliedRate: 12, unit: 'visit', quantity: null, totalPrice: null, commission: null, netPayout: null, currency: 'EUR', commissionRate: 0.2 });
    S.app = await Application.findById(r.body.application.id || r.body.application._id);
    expect(S.app.serviceDate).toBeNull();
    // notification « candidature reçue » : tarif unitaire dans le texte (cloche, langue fr)
    const n = await bell(S.owner._id, 'application_new');
    expect(n.length).toBe(1);
    expect(n[0].data.priceIndicative).toBe('1');
    const { renderNotificationContent } = require('../src/services/notificationSender');
    expect(renderNotificationContent('application_new', n[0].data, 'fr').body).toContain('12 €/visite');
    await wait(300);
    expect(MAILS.some((m) => m.to === 'zoe620+owner@example.test' && m.text.includes('12 €/visite'))).toBe(true);
  }, 60000);
  test('accepter avant les dates → 409 DATES_REQUIRED (message en français)', async () => {
    const r = await request(app).post(`/applications/${S.app._id}/respond`).set(hdr(S.owner._id, 'owner')).send({ action: 'accept' });
    expect(r.status).toBe(409);
    expect(r.body.code).toBe('DATES_REQUIRED');
    expect(r.body.error).toContain('dates');
    expect(r.body.postId).toBe(S.postTbd.id);
    expect((await Application.findById(S.app._id)).status).toBe('pending');
  });
  test('refuser reste possible en tbd (chemin reject inchangé) — sur une 2e candidature', async () => {
    const r2 = await request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(S.walker._id, 'walker')).send({ postId: S.postTarget.id, serviceType: 'dog_walking', description: 'Balade.' });
    expect(r2.status).toBe(201);
    expect(r2.body.application.pricing).toMatchObject({ indicative: true, appliedRate: 10, unit: 'walk' });
    const rej = await request(app).post(`/applications/${r2.body.application.id || r2.body.application._id}/respond`).set(hdr(S.owner._id, 'owner')).send({ action: 'reject' });
    expect(rej.status).toBe(200);
  });
  test('le propriétaire pose ses dates (PATCH exact, 3 jours) → candidature recalculée 12 × 6 = 72 + 14,40 = 86,40, notification application_pricing_updated', async () => {
    MAILS.length = 0;
    const r = await request(app).patch(`/posts/${S.postTbd.id}`).set(hdr(S.owner._id, 'owner')).send({ dateMode: 'exact', startDate: day(15), endDate: day(17) });
    if (r.status !== 200) console.log('updatePost →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    expect(r.body.post).toMatchObject({ dateMode: 'exact', visitsPerDay: 2 });
    expect(r.body.repricedApplications).toBe(1);
    const a = await Application.findById(S.app._id).lean();
    expect(a.pricing).toMatchObject({ indicative: false, pricingTier: 'visit', appliedRate: 12, quantity: 6, unit: 'visit', basePrice: 72, commission: 14.4, netPayout: 72, totalPrice: 86.4, currency: 'EUR' });
    expect(new Date(a.serviceDate).toISOString()).toBe(day(15));
    const n = await bell(S.owner._id, 'application_pricing_updated');
    expect(n.length).toBe(1);
    expect(n[0].data).toMatchObject({ postId: S.postTbd.id, applicationId: String(S.app._id), candidates: '1' });
    expect(n[0].title).toBe('Tes dates sont posées');
    await wait(300);
    expect(MAILS.some((m) => m.to === 'zoe620+owner@example.test' && m.subject.includes('Tes dates sont posées'))).toBe(true);
    // une 2e modification des dates ne touche plus que les candidatures encore indicatives
    const r2 = await request(app).patch(`/posts/${S.postTbd.id}`).set(hdr(S.owner._id, 'owner')).send({ notes: 'rien' }).expect(200);
    expect(r2.body.repricedApplications).toBeUndefined();
  }, 60000);
  test('accepter après les dates → 200, réservation `visit` au prix réel', async () => {
    const r = await request(app).post(`/applications/${S.app._id}/respond`).set(hdr(S.owner._id, 'owner')).send({ action: 'accept' });
    if (r.status !== 200) console.log('accept →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    const a = await Application.findById(S.app._id).lean();
    expect(a.status).toBe('accepted');
    const b = await Booking.findById(a.bookingId).lean();
    expect(b).toBeTruthy();
    expect(b.pricing).toMatchObject({ pricingTier: 'visit', totalPrice: 86.4, commission: 14.4, netPayout: 72 });
    expect(String((await Post.findById(S.postTbd.id).lean()).reservedBy.bookingId)).toBe(String(b._id));
  }, 60000);
  test('compatibilité : candidature 619 (serviceDate, timeSlot, sans quantity) sur une demande datée → calcul historique inchangé + quantité informative', async () => {
    const d = inDays(20);
    const r = await request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(S.sitterNoVisit._id, 'sitter')).send({
      postId: S.postExact.id, serviceType: 'home_visit', serviceDate: d.toISOString(), startDate: d.toISOString(), endDate: new Date(d.getTime() + 2 * 3600000).toISOString(), timeSlot: 'morning', description: 'Je peux garder Rex.',
    });
    if (r.status !== 201) console.log('createApplication 619 →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(201);
    const p = r.body.application.pricing;
    expect(p).toMatchObject({ indicative: false, pricingTier: 'hourly', appliedRate: 10, basePrice: 20, totalPrice: 24, quantity: 3, unit: 'day' }); // demande datée J+20 → J+22 : 3 jours
  }, 60000);
});

describe('4. Contact de la pub « visites » et rappel « pose tes dates »', () => {
  test('adLeads : service visites → home_visit, visitsPerDay du formulaire, sans dates → tbd', async () => {
    const reg = await request(app).post('/admin/ad-leads').set(ADMIN).send({
      metaLeadId: 'zoe620-visites', email: 'zoe620+lead@example.test', firstName: 'Karine', city: 'Zone test', lat: -35, lng: -30, country: 'FR', lang: 'fr',
      service: 'visites', animal: 'chat', quand: 'plus_tard', visitsPerDay: 2,
    }).expect(200);
    const r = await request(app).post(`/ad-leads/${reg.body.id}/confirm`).send({}).expect(200);
    const post = await Post.findById(r.body.postId).lean();
    expect(post.serviceTypes).toEqual(['home_visit']);
    expect(post).toMatchObject({ dateMode: 'tbd', visitsPerDay: 2, startDate: null, serviceLocation: 'at_owner' });
    S.leadPost = post;
    // avec des dates lisibles : exact
    const reg2 = await request(app).post('/admin/ad-leads').set(ADMIN).send({
      metaLeadId: 'zoe620-visites-dates', email: 'zoe620+lead2@example.test', firstName: 'Nadia', city: 'Zone test', lat: -35, lng: -30, country: 'FR', lang: 'fr',
      service: 'visites', animal: 'chien', quand: 'bientot',
    }).expect(200);
    const r2 = await request(app).post(`/ad-leads/${reg2.body.id}/confirm`).send({}).expect(200);
    const post2 = await Post.findById(r2.body.postId).lean();
    expect(post2).toMatchObject({ dateMode: 'exact', visitsPerDay: 1 });
    expect(post2.startDate).toBeTruthy();
  }, 60000);
  test('rappel post_dates_required : J+1 puis J+3, une fois chacun, jamais sans candidat, jamais la nuit', async () => {
    const svc = require('../src/services/postDatesReminder620');
    const sent = [];
    const send = async (p) => { sent.push(p); };
    const created = new Date('2026-11-02T10:00:00.000Z');
    await Post.collection.updateOne({ _id: S.leadPost._id }, { $set: { createdAt: created } }); // createdAt est immuable côté Mongoose
    // aucun candidat → rien
    let r = await svc.runPostDatesReminders({ now: new Date('2026-11-03T11:00:00.000Z'), send });
    expect(sent.length).toBe(0);
    expect(r.skipped.no_candidate).toBeGreaterThanOrEqual(1); // + la demande PawMap dont la candidature a été refusée
    const leadOwner = await Owner.findOne({ email: 'zoe620+lead@example.test' });
    const leadPet = await Pet.findOne({ ownerId: leadOwner._id });
    const c = await request(app).post(`/applications?ownerId=${leadOwner._id}`).set(hdr(S.sitter._id, 'sitter')).send({ postId: String(S.leadPost._id), serviceType: 'home_visit', description: 'Dispo.', petIds: [String(leadPet._id)] });
    expect(c.status).toBe(201);
    // J+1 à 11 h (Paris, 12 h) → d1
    r = await svc.runPostDatesReminders({ now: new Date('2026-11-03T11:00:00.000Z'), send });
    expect(sent.map((s) => s.type)).toEqual(['post_dates_required']);
    expect(sent[0]).toMatchObject({ role: 'owner', userId: String(leadOwner._id), channels: { email: false } });
    expect(sent[0].data).toMatchObject({ postId: String(S.leadPost._id), candidates: '1', datesReminder620: 'd1' });
    // même jour, 2e passage → rien ; J+2 → rien
    await svc.runPostDatesReminders({ now: new Date('2026-11-03T15:00:00.000Z'), send });
    await svc.runPostDatesReminders({ now: new Date('2026-11-04T11:00:00.000Z'), send });
    expect(sent.length).toBe(1);
    // J+3 à 23 h 30 UTC (00 h 30 Paris) → nuit, attend le matin
    r = await svc.runPostDatesReminders({ now: new Date('2026-11-05T23:30:00.000Z'), send });
    expect(sent.length).toBe(1);
    expect(r.skipped.night).toBe(1);
    r = await svc.runPostDatesReminders({ now: new Date('2026-11-06T08:30:00.000Z'), send });
    expect(sent.length).toBe(2);
    expect(sent[1].data.datesReminder620).toBe('d3');
    await svc.runPostDatesReminders({ now: new Date('2026-11-20T08:30:00.000Z'), send });
    expect(sent.length).toBe(2);
    // le vrai envoi rend un texte propre en 9 langues (cloche)
    const { renderNotificationContent } = require('../src/services/notificationSender');
    for (const l of ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      const out = renderNotificationContent('post_dates_required', sent[0].data, l);
      expect(out.body).toContain('1');
      expect(out.body).not.toMatch(/\{\{/);
    }
  }, 60000);
});

describe('5. Grille de tarifs et prix par service', () => {
  test('PUT /users/me/profile (site) : visitRate, durée, unité par défaut, dailyRate ; PUT /sitters/me/pricing ; relecture', async () => {
    const r = await request(app).put('/users/me/profile').set(hdr(S.sitterNoVisit._id, 'sitter')).send({ dailyRate: 20, visitRate: 9, visitDurationMinutes: 60, defaultRateType: 'visit' });
    if (r.status !== 200) console.log('PUT profile →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    const s = await Sitter.findById(S.sitterNoVisit._id).lean();
    expect(s).toMatchObject({ dailyRate: 20, visitRate: 9, visitDurationMinutes: 60, defaultRateType: 'visit', hourlyRate: 10 });
    await request(app).put('/users/me/profile').set(hdr(S.sitterNoVisit._id, 'sitter')).send({ visitDurationMinutes: 45 }).expect(400);
    const p = await request(app).put('/sitters/me/pricing').set(hdr(S.sitterNoVisit._id, 'sitter')).send({ visitRate: 11 }).expect(200);
    expect(p.body.sitter.visitRate).toBe(11);
    const g = await request(app).get('/sitters/me/pricing').set(hdr(S.sitterNoVisit._id, 'sitter')).expect(200);
    expect(g.body).toMatchObject({ visitRate: 11, visitDurationMinutes: 60, defaultRateType: 'visit', prices: { home_visit: { amount: 11, unit: 'visit', durationMinutes: 60 }, house_sitting: { amount: 20, unit: 'day' } } });
    // promeneur : walkRates par le profil
    const w = await request(app).put('/users/me/profile').set(hdr(S.walker._id, 'walker')).send({ walkRates: [{ durationMinutes: 30, basePrice: 10 }, { durationMinutes: 60, basePrice: 16 }] }).expect(200);
    expect(w.status).toBe(200);
    expect((await Walker.findById(S.walker._id).lean()).walkRates.map((x) => x.basePrice)).toEqual([10, 16]);
  }, 60000);
  test('/sitters/nearby : prices par service, priceFrom compatible (le plus bas) et priceFrom/priceUnit selon ?service=', async () => {
    const r = await request(app).get('/sitters/nearby?lat=-35&lng=-30&radius=50').set(hdr(S.owner._id, 'owner'));
    if (r.status !== 200) console.log('nearby →', r.status, JSON.stringify(r.body).slice(0, 300)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    const me = r.body.sitters.find((s) => s.id === String(S.sitter._id));
    expect(me).toBeTruthy();
    expect(me).toMatchObject({ visitRate: 12, priceFrom: 18, priceUnit: 'day', prices: { house_sitting: { amount: 18, unit: 'day' }, home_visit: { amount: 12, unit: 'visit', durationMinutes: 30 } } });
    const v = await request(app).get('/sitters/nearby?lat=-35&lng=-30&radius=50&service=home_visit').set(hdr(S.owner._id, 'owner')).expect(200);
    expect(v.body.sitters.find((s) => s.id === String(S.sitter._id))).toMatchObject({ priceFrom: 12, priceUnit: 'visit' });
  }, 60000);
});
