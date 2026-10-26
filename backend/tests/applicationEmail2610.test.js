// 2610 (ZOE, 26/10/2026 — décision de Daniel, proposition A de SAM) — E-MAIL « CANDIDATS REÇUS »
// au propriétaire : objet = la demande (service, animal, ville, prix du moteur), 1 à 3 candidats avec
// photo/prix/km/avis, bouton « Voir mes candidats » ; 1er tout de suite, suivants regroupés UNE fois
// par jour au plus et par demande ; 0 doublon ; push et cloche inchangés ; 9 langues ; coupe-circuit.
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
  return { ...actual, sendEmail: jest.fn(async (to, subject, text, html) => { MAILS.push({ to, subject, text: String(text || ''), html: String(html || '') }); return { messageId: 'mock' }; }), sendTemplatedEmail: jest.fn(async () => ({})) };
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



const fs = require('fs');
const path = require('path');
const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const inDays = (n) => new Date(Date.now() + n * 86400000);
const day = (n) => { const d = inDays(n); return `${d.toISOString().slice(0, 10)}T00:00:00.000Z`; };
let mongo; let app;
let Owner; let Sitter; let Pet; let Post; let Application; let Notification; let Registry;
const PASS = 'MotDePasseTest2610!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': '23.1.590+621' });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const S = {};
const svc = () => require('../src/services/applicationEmail2610');
const mailsTo = (addr) => MAILS.filter((m) => m.to === addr);
const OUT = process.env.ZOE_EMAIL_OUT || '';
const save = (name, html) => { if (OUT) fs.writeFileSync(path.join(OUT, name), html); };

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter');
  Pet = require('../src/models/Pet'); Post = require('../src/models/Post'); Application = require('../src/models/Application');
  Notification = require('../src/models/Notification'); Registry = require('../src/models/ApplicationEmail2610');
  require('../src/models/Walker'); require('../src/models/Booking'); require('../src/models/Block');
  await Promise.all([Owner.init(), Sitter.init(), Pet.init(), Post.init(), Application.init(), Notification.init(), Registry.init()]);
  const fr = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  S.owner = await Owner.create({ ...fr, name: 'Karine Test', email: 'zoe2610m+owner@example.test', acceptedTerms: true });
  S.ownerEn = await Owner.create({ ...fr, name: 'Brenda Test', email: 'zoe2610m+owner-en@example.test', acceptedTerms: true, appLocale: 'en' });
  S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Mina', petType: 'cat' });
  S.petEn = await Pet.create({ ownerId: S.ownerEn._id, petName: 'Max', petType: 'dog' });
  S.hanene = await Sitter.create({ ...fr, name: 'Hanene Test', email: 'zoe2610m+hanene@example.test', dailyRate: 18, averageRating: 4.8, reviewsCount: 12, avatar: { url: 'https://res.cloudinary.com/demo/image/upload/sample.jpg' } });
  S.sohane = await Sitter.create({ ...fr, name: 'Sohane Test', email: 'zoe2610m+sohane@example.test', dailyRate: 50 });
  S.elisa = await Sitter.create({ ...fr, name: 'Elisabeth Test', email: 'zoe2610m+elisa@example.test', dailyRate: 15 });
  app = express();
  app.use(express.json());
  app.use('/posts', require('../src/routes/postRoutes'));
  app.use('/applications', require('../src/routes/applicationRoutes'));
}, 180000);
afterAll(async () => { svc().stopApplicationEmailScheduler(); await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

const createPost = (body, who = S.owner, pet = S.pet) => request(app).post('/posts').set(hdr(who._id, 'owner')).send({
  body: 'Demande de test 2610 (e-mail), zone test.', language: 'fr', animalCount: 1, location: LOC, petIds: [String(pet._id)], ...body,
});
const apply = async (post, who, owner = S.owner, extra = {}) => {
  const r = await request(app).post(`/applications?ownerId=${owner._id}`).set(hdr(who._id, 'sitter')).send({
    postId: post.id, description: 'Disponible.', timeSlot: 'morning', serviceType: 'house_sitting', houseSittingVenue: 'owners_home', ...extra,
  });
  if (r.status !== 201) console.log('apply →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
  expect(r.status).toBe(201);
  await wait(400);
  return r.body.application;
};

describe('1. Le 1er candidat : e-mail tout de suite, utile, dans la langue du propriétaire', () => {
  test('dates à prévoir : objet « Hanene peut garder votre chat à Zone test · 21,60 €/jour » (frais compris), photo, note, ligne « posez vos dates », bouton « Voir mes candidats », jamais « 2 minutes »', async () => {
    S.post = (await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'tbd', animalTypes: ['cat'] }).expect(201)).body.post;
    MAILS.length = 0;
    await apply(S.post, S.hanene);
    const m = mailsTo('zoe2610m+owner@example.test');
    expect(m).toHaveLength(1);
    expect(m[0].subject).toBe('Hanene peut garder votre chat à Zone test · 21,60 €/jour'); // 18 € + 20 % de frais
    expect(m[0].html).toContain('Voir mes candidats');
    expect(m[0].html).toContain('https://res.cloudinary.com/demo/image/upload/sample.jpg');
    expect(m[0].html).toContain('★ 4,8 · 12 avis');
    expect(m[0].html).toContain('Posez vos dates pour voir le prix total');
    expect(m[0].html).toContain('www.hopetsit.com/application/'); // toujours la page des candidats (test de FLO)
    expect(m[0].html).not.toMatch(/2 minutes|choisis et paie/);
    expect(m[0].html).not.toContain('{{');
    save('email_fr_1er.html', m[0].html);
    // cloche + push : inchangés (gabarit 617, une entrée par candidature)
    const bells = await Notification.find({ recipientId: S.owner._id, type: 'application_new' }).lean();
    expect(bells).toHaveLength(1);
  }, 60000);
});

describe('2. Les suivants : regroupés, UN e-mail par jour au plus, zéro doublon', () => {
  test('2 candidats de plus → 0 e-mail immédiat (cloche à chaque fois), puis 1 e-mail regroupé après 24 h, puis plus rien', async () => {
    MAILS.length = 0;
    S.appSohane = await apply(S.post, S.sohane);
    S.appElisa = await apply(S.post, S.elisa);
    expect(mailsTo('zoe2610m+owner@example.test')).toHaveLength(0);
    expect(await Notification.countDocuments({ recipientId: S.owner._id, type: 'application_new' })).toBe(3);
    // avant 24 h : rien
    expect((await svc().runDigest({ now: new Date(Date.now() + 2 * 3600000) })).sent).toBe(0);
    expect(mailsTo('zoe2610m+owner@example.test')).toHaveLength(0);
    // après 24 h : UN e-mail avec les 2 nouveaux
    const r = await svc().runDigest({ now: new Date(Date.now() + 25 * 3600000) });
    expect(r.sent).toBe(1);
    const m = mailsTo('zoe2610m+owner@example.test');
    expect(m).toHaveLength(1);
    expect(m[0].subject).toBe('2 nouveaux candidats pour garder votre chat à Zone test');
    expect(m[0].html).toContain('Sohane');
    expect(m[0].html).toContain('Elisabeth');
    expect(m[0].html).toContain('+ 1 autre candidat sur votre demande');
    save('email_fr_regroupe.html', m[0].html);
    // rejouer le balayage (même échéance, ou plus tard sans nouveau candidat) : 0 doublon
    expect((await svc().runDigest({ now: new Date(Date.now() + 25 * 3600000) })).sent).toBe(0);
    expect((await svc().runDigest({ now: new Date(Date.now() + 60 * 3600000) })).sent).toBe(0);
    expect(mailsTo('zoe2610m+owner@example.test')).toHaveLength(1);
    const row = await Registry.findOne({ postId: S.post.id }).lean();
    expect(row.emails).toBe(2);
    expect(row.queuedIds).toHaveLength(0);
    expect(row.sentIds.map(String).sort()).toHaveLength(3);
  }, 90000);
  test('un candidat refusé avant le regroupement n\'est pas annoncé ; une demande close n\'en reçoit plus', async () => {
    const o2 = await Owner.create({ password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr', name: 'Corinne Test', email: 'zoe2610m+owner2@example.test', acceptedTerms: true });
    const p2 = await Pet.create({ ownerId: o2._id, petName: 'Tigre', petType: 'cat' });
    const post = (await createPost({ body: 'Deuxième demande 2610.', serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'tbd', animalTypes: ['cat'] }, o2, p2).expect(201)).body.post;
    MAILS.length = 0;
    await apply(post, S.hanene, o2);
    const a2 = await apply(post, S.sohane, o2);
    await Application.updateOne({ _id: a2.id || a2._id }, { $set: { status: 'rejected' } });
    expect((await svc().runDigest({ now: new Date(Date.now() + 25 * 3600000) })).sent).toBe(0);
    expect(mailsTo('zoe2610m+owner2@example.test')).toHaveLength(1); // le 1er seulement
    await apply(post, S.elisa, o2);
    await Post.updateOne({ _id: post.id }, { $set: { status: 'closed' } });
    expect((await svc().runDigest({ now: new Date(Date.now() + 50 * 3600000) })).sent).toBe(0);
    expect(mailsTo('zoe2610m+owner2@example.test')).toHaveLength(1);
  }, 90000);
});

describe('3. Langues', () => {
  test('propriétaire anglophone, demande datée : « Hanene can look after your dog in Zone test · €64.80 in total », « See my candidates »', async () => {
    const post = (await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'exact', startDate: day(20), endDate: day(22), animalTypes: ['dog'] }, S.ownerEn, S.petEn).expect(201)).body.post;
    MAILS.length = 0;
    await apply(post, S.hanene, S.ownerEn, { serviceDate: day(20) });
    const m = mailsTo('zoe2610m+owner-en@example.test');
    expect(m).toHaveLength(1);
    expect(m[0].subject).toBe('Hanene can look after your dog in Zone test · €64.80 in total');
    expect(m[0].html).toContain('See my candidates');
    expect(m[0].html).not.toContain('Set your dates');
    save('email_en_1er.html', m[0].html);
  }, 60000);
  test('les 9 langues : gabarit présent, objet et bouton traduits, aucune variable non remplacée', () => {
    const t = require('../src/utils/applicationEmailText2610');
    const post = { serviceTypes: ['home_visit'], animalTypes: ['cat'], animalCount: 2, location: { city: 'Clamart' }, dateMode: 'tbd' };
    const cards = [{ name: 'Hanene', role: 'sitter', pricing: { indicative: true, appliedRate: 12, unit: 'visit', currency: 'EUR' }, km: 3.2, rating: 0, reviews: 0 }];
    const seen = new Set();
    for (const l of t.LANGS) {
      const tmpl = JSON.parse(fs.readFileSync(path.join(__dirname, `../src/locales/${l}/notifications.json`), 'utf8')).application_new_2610;
      expect(tmpl && tmpl.emailBody).toContain('{{candidatesHtml2610}}');
      const one = t.buildEmailData({ lang: l, post, cards, newCount: 1, totalPending: 3 });
      const many = t.buildEmailData({ lang: l, post, cards, newCount: 2, totalPending: 3 });
      expect(one.subjectLine).toContain('Hanene');
      expect(one.subjectLine).toContain('Clamart');
      expect(one.subjectLine).toMatch(/14[.,]40|14\.4/); // 12 € + 20 % de frais
      expect(many.subjectLine).toContain('2');
      expect(one.candidatesHtml2610).toContain('~3 km');
      expect(`${one.subjectLine}${one.candidatesHtml2610}${one.ctaLabel}`).not.toMatch(/undefined|\{\{|NaN/);
      seen.add(one.ctaLabel);
    }
    expect(seen.size).toBe(9);
    // FR : pluriel et visite
    expect(t.buildEmailData({ lang: 'fr', post, cards, newCount: 1, totalPending: 1 }).subjectLine).toBe('Hanene peut rendre visite à vos chats à Clamart · 14,40 €/visite');
  });
  test('un prénom piégé est échappé dans le HTML', () => {
    const t = require('../src/utils/applicationEmailText2610');
    const h = t.cardsHtml('fr', [{ name: '<a href=x>Bob</a>', role: 'sitter', avatar: 'javascript:alert(1)' }]);
    expect(h).not.toContain('<a href=x>');
    expect(h).not.toContain('javascript:');
  });
});

describe('4. Demande directe (sans annonce) et coupe-circuit : e-mail par candidature comme avant', () => {
  test('APPLICATION_EMAIL_2610=off → e-mail 617 à chaque candidature (retour arrière sans déploiement)', async () => {
    process.env.APPLICATION_EMAIL_2610 = 'off';
    try {
      const o3 = await Owner.create({ password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr', name: 'Nadia Test', email: 'zoe2610m+owner3@example.test', acceptedTerms: true });
      const p3 = await Pet.create({ ownerId: o3._id, petName: 'Lou', petType: 'cat' });
      const post = (await createPost({ body: 'Troisième demande 2610.', serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'tbd', animalTypes: ['cat'] }, o3, p3).expect(201)).body.post;
      MAILS.length = 0;
      await apply(post, S.hanene, o3);
      await apply(post, S.sohane, o3);
      const m = mailsTo('zoe2610m+owner3@example.test');
      expect(m).toHaveLength(2);
      expect(m[0].subject).toContain('a répondu');
      expect(await Registry.countDocuments({ postId: post.id })).toBe(0);
    } finally { delete process.env.APPLICATION_EMAIL_2610; }
  }, 60000);
});
