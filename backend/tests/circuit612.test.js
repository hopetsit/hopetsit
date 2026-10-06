// 612 §8 (ZOE, 05/10/2026) — CIRCUIT DE L'ARGENT (ordre de Daniel : « vérifie bien que
// le owner qui poste des demandes reçoit bien les candidatures et peut payer »).
// Deux défauts MESURÉS sur le vrai serveur local (scripts/mesure_circuit_612.js) :
//   1. une demande publiée SANS animal enregistré (app 600, site) ne pouvait recevoir
//      AUCUNE candidature : 400 « petIds (or petId) is required », bouton gris dans l'app ;
//   2. `application:new` (nouvelle candidature) et `booking:paid` n'étaient JAMAIS émis
//      en direct : `require('../sockets')` n'exporte pas emitToUser (échec silencieux).
// VRAIE base Mongo en mémoire, VRAIES routes HTTP, vrai emitter ; Firebase, SMTP et le
// réseau Airwallex sont captés. Aucun paiement réel.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({ sendEachForMulticast: jest.fn(async (m) => ({ successCount: m.tokens.length, failureCount: 0, responses: [] })) }),
}));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async () => ({ messageId: 'capté' })) };
});
jest.mock('../src/services/translationService', () => ({
  translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })),
}));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/utils/geocodeCity', () => {
  const actual = jest.requireActual('../src/utils/geocodeCity');
  return { ...actual, geocodeCity: jest.fn(async () => null) };
});
const mockIntents = new Map();
jest.mock('../src/services/airwallexService', () => {
  const actual = jest.requireActual('../src/services/airwallexService');
  let n = 0;
  const create = jest.fn(async (o) => {
    n += 1;
    const pi = { id: `int_612_${n}`, client_secret: 'cs', status: 'REQUIRES_PAYMENT_METHOD', amount: Number(o.amount) / 100, currency: o.currency, metadata: o.metadata || {} };
    mockIntents.set(pi.id, pi);
    return pi;
  });
  return {
    ...actual,
    findOrCreateCustomer: jest.fn(async () => ({ id: 'cus_612' })),
    findCustomerByMerchantId: jest.fn(async () => null),
    listPaymentMethods: jest.fn(async () => []),
    listAllPaymentConsents: jest.fn(async () => []),
    createPlatformPaymentIntent: create,
    createPaymentIntent: create,
    retrievePaymentIntent: jest.fn(async (id) => mockIntents.get(id) || { id, status: 'REQUIRES_PAYMENT_METHOD' }),
    constructWebhookEvent: jest.fn((body) => JSON.parse(Buffer.isBuffer(body) ? body.toString('utf8') : body)),
  };
});

const mongoose = require('mongoose');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let Walker; let Pet; let Post; let Booking; let Notification;
const emitted = [];
const fakeIo = {
  to: (room) => ({ emit: (ev, p) => emitted.push({ room: String(room), ev, p }) }),
  in: () => ({ fetchSockets: async () => [] }),
  fetchSockets: async () => [],
  sockets: { adapter: { rooms: new Map() }, sockets: new Map() },
};
const tok = (id, role) => jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '1h' });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const api = (method, path, token) => {
  const r = request(app)[method](path).set('X-App-Version', '612').set('X-App-Platform', 'ios');
  return token ? r.set('Authorization', `Bearer ${token}`) : r;
};
const until = async (fn, ms = 3000) => { for (let i = 0; i < ms / 25; i += 1) { if (await fn()) return true; await wait(25); } return false; };
const zone = (d = 0) => ({ type: 'Point', coordinates: [-30 + d, -35], city: 'Zone test' });
const start = () => { const d = new Date(Date.now() + 3 * 86400000); d.setUTCHours(9, 0, 0, 0); return d; };
const mk = async (Model, doc) => Model.create({ password: 'MotDePasse612!', verified: true, appLocale: 'fr', city: 'Zone test', currency: 'EUR', ...doc });

let W; let S; let tW; let tS;
beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Pet = require('../src/models/Pet'); Post = require('../src/models/Post'); Booking = require('../src/models/Booking');
  Notification = require('../src/models/Notification');
  await require('../src/models/RequestAlert612').init();
  require('../src/sockets/emitter').setSocketServer(fakeIo);
  app = require('../src/app');
  try { await require('../src/services/pricingService').init(); } catch (_) { /* grille par défaut */ }
  W = await mk(Walker, { name: 'Paul Promeneur', email: 'w612c@example.test', location: zone(0.02), walkRates: [{ durationMinutes: 60, basePrice: 18, currency: 'EUR', enabled: true }] });
  S = await mk(Sitter, { name: 'Sasha Gardien', email: 's612c@example.test', location: zone(0.01), hourlyRate: 12, dailyRate: 40 });
  tW = tok(W._id, 'walker'); tS = tok(S._id, 'sitter');
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(() => { emitted.length = 0; });

const publish = (tO, extra) => api('post', '/api/v1/posts', tO).send({
  body: 'Balade pour mon chien', serviceTypes: ['dog_walking'], serviceLocation: 'at_owner', walkDurationMinutes: 60,
  startDate: start().toISOString(), endDate: new Date(start().getTime() + 3600000).toISOString(),
  location: { city: 'Zone test', lat: -35, lng: -30 }, ...extra,
});
const apply = (token, ownerId, post, petIds, extra = {}) => api('post', `/api/v1/applications?ownerId=${ownerId}`, token).send({
  petIds, serviceType: 'dog_walking', serviceDate: start().toISOString(), startDate: start().toISOString(),
  timeSlot: '9:00 AM', basePrice: 18, duration: 60, postId: String(post), ...extra,
});

describe('demande publiée SANS animal enregistré (app 600, site)', () => {
  test('propriétaire sans aucun animal : une fiche minimale est créée et rattachée, le prestataire peut postuler, le propriétaire accepter', async () => {
    const O = await mk(Owner, { name: 'Nina Site', email: 'o612a@example.test', location: zone() });
    const tO = tok(O._id, 'owner');
    const pub = await publish(tO, { petIds: [], animalTypes: ['dog'], animalCount: 1 });
    expect(pub.status).toBe(201);
    const postId = pub.body.post.id || pub.body.post._id;
    const pets = await Pet.find({ ownerId: O._id }).lean();
    expect(pets).toHaveLength(1);
    expect(pets[0]).toMatchObject({ petName: 'Chien', category: 'dog', autoCreated: true });
    const post = await Post.findById(postId).lean();
    expect(post.petIds.map(String)).toEqual([String(pets[0]._id)]);
    expect(post.animalTypes).toEqual(['dog']); // ce que le propriétaire a déclaré reste intact
    // La carte expose l'animal : c'est ce qui dégrise « Proposer mes services » dans toutes les apps.
    const near = await api('get', '/api/v1/posts/requests/nearby?lat=-35&lng=-30&maxDistance=50', tW);
    const row = near.body.posts.find((p) => String(p.id || p._id) === String(postId));
    expect(row.petIds).toEqual([String(pets[0]._id)]);
    const ap = await apply(tW, O._id, postId, row.petIds);
    expect(ap.status).toBe(201); // avant : 400 « petIds (or petId) is required »
    const acc = await api('post', `/api/v1/applications/${ap.body.application.id || ap.body.application._id}/respond`, tO).send({ action: 'accept' });
    expect(acc.status).toBe(200);
    expect(await Booking.countDocuments({ ownerId: O._id, status: 'agreed' })).toBe(1);
  });

  test('langue du propriétaire : la fiche porte le nom de l’espèce dans SA langue', async () => {
    const O = await mk(Owner, { name: 'Tom', email: 'o612en@example.test', appLocale: 'en', location: zone() });
    await publish(tok(O._id, 'owner'), { petIds: [], animalTypes: ['cat'], animalCount: 1 });
    expect((await Pet.findOne({ ownerId: O._id }).lean()).petName).toBe('Cat');
  });

  test('propriétaire qui a DÉJÀ un animal : rien n’est créé, son animal est rattaché', async () => {
    const O = await mk(Owner, { name: 'Léa', email: 'o612b@example.test', location: zone() });
    const rex = await Pet.create({ ownerId: O._id, petName: 'Rex', category: 'dog' });
    const pub = await publish(tok(O._id, 'owner'), { petIds: [], animalTypes: ['dog'], animalCount: 1 });
    expect(await Pet.countDocuments({ ownerId: O._id })).toBe(1);
    const post = await Post.findById(pub.body.post.id || pub.body.post._id).lean();
    expect(post.petIds.map(String)).toEqual([String(rex._id)]);
  });

  test('demande publiée AVEC un animal : inchangée', async () => {
    const O = await mk(Owner, { name: 'Marc', email: 'o612c@example.test', location: zone() });
    const a = await Pet.create({ ownerId: O._id, petName: 'Milo', category: 'dog' });
    await Pet.create({ ownerId: O._id, petName: 'Luna', category: 'cat' });
    const pub = await publish(tok(O._id, 'owner'), { petIds: [String(a._id)] });
    const post = await Post.findById(pub.body.post.id || pub.body.post._id).lean();
    expect(post.petIds.map(String)).toEqual([String(a._id)]);
    expect(await Pet.countDocuments({ ownerId: O._id })).toBe(2);
  });

  test('ANCIENNE demande déjà en base sans animal : la candidature (sans petIds) la répare au passage', async () => {
    const O = await mk(Owner, { name: 'Ancienne', email: 'o612d@example.test', location: zone() });
    const r = await Post.collection.insertOne({
      ownerId: O._id, body: 'Garde de mon chat', postType: 'request', serviceTypes: ['dog_walking'], petIds: [], petId: null,
      animalTypes: ['cat'], animalCount: 1, location: { city: 'Zone test', lat: -35, lng: -30 }, startDate: start(), createdAt: new Date(),
    });
    const ap = await apply(tW, O._id, r.insertedId, []);
    expect(ap.status).toBe(201);
    const post = await Post.findById(r.insertedId).lean();
    expect(post.petIds).toHaveLength(1);
    expect((await Pet.findById(post.petIds[0]).lean())).toMatchObject({ petName: 'Chat', autoCreated: true });
  });

  test('sans petIds ET sans annonce : toujours refusé (400)', async () => {
    const O = await mk(Owner, { name: 'Vide', email: 'o612e@example.test', location: zone() });
    const ap = await api('post', `/api/v1/applications?ownerId=${O._id}`, tW).send({ petIds: [], serviceType: 'dog_walking', serviceDate: start().toISOString(), timeSlot: '9:00 AM', basePrice: 18, duration: 60 });
    expect(ap.status).toBe(400);
  });

  test('rattrapage admin : SIMULATION par défaut (rien d’écrit), puis réparation', async () => {
    const O = await mk(Owner, { name: 'Rattrapage', email: 'o612f@example.test', location: zone() });
    const r = await Post.collection.insertOne({ ownerId: O._id, body: 'Demande du site', postType: 'request', serviceTypes: ['pet_sitting'], petIds: [], animalTypes: ['dog'], location: { city: 'Zone test' }, createdAt: new Date() });
    const Admin = mongoose.models.Admin || require('../src/models/Admin');
    const adm = await Admin.collection.insertOne({ email: 'admin612@example.test', role: 'admin', name: 'Admin' });
    const tA = tok(adm.insertedId, 'admin');
    const dry = await api('post', '/admin/requests0410/pets612/backfill', tA).send({});
    expect(dry.status).toBe(200);
    expect(dry.body.dryRun).toBe(true);
    expect(dry.body.posts.some((p) => p.postId === String(r.insertedId))).toBe(true);
    expect(await Pet.countDocuments({ ownerId: O._id })).toBe(0);
    const real = await api('post', '/admin/requests0410/pets612/backfill', tA).send({ dryRun: false });
    expect(real.body.dryRun).toBe(false);
    expect((await Post.findById(r.insertedId).lean()).petIds).toHaveLength(1);
    const again = await api('post', '/admin/requests0410/pets612/backfill', tA).send({});
    expect(again.body.posts.some((p) => p.postId === String(r.insertedId))).toBe(false);
  });
});

describe('le propriétaire est prévenu de la candidature — et « payé » arrive en direct', () => {
  test('candidature : cloche pour le propriétaire + événements temps réel notification.new ET application:new', async () => {
    const O = await mk(Owner, { name: 'Camille', email: 'o612g@example.test', location: zone() });
    const pet = await Pet.create({ ownerId: O._id, petName: 'Rex', category: 'dog' });
    const tO = tok(O._id, 'owner');
    const pub = await publish(tO, { petIds: [String(pet._id)] });
    const postId = pub.body.post.id || pub.body.post._id;
    emitted.length = 0;
    const ap = await apply(tW, O._id, postId, [String(pet._id)]);
    expect(ap.status).toBe(201);
    const room = `user:owner:${O._id}`;
    expect(await until(async () => emitted.some((e) => e.room === room && e.ev === 'notification.new' && e.p.type === 'application_new'))).toBe(true);
    // Avant le correctif : jamais émis (TypeError avalé) → la liste des candidats ne bougeait qu'au rechargement.
    expect(emitted.some((e) => e.room === room && e.ev === 'application:new' && e.p.applicationId)).toBe(true);
    const bell = await Notification.find({ recipientId: O._id, type: 'application_new' }).lean();
    expect(bell).toHaveLength(1);
    expect(bell[0].data.postId).toBe(String(postId));

    // Accepter → payer (webhook simulé) → « payé » en direct des DEUX côtés.
    const acc = await api('post', `/api/v1/applications/${ap.body.application.id || ap.body.application._id}/respond`, tO).send({ action: 'accept' });
    expect(acc.status).toBe(200);
    const booking = await Booking.findOne({ ownerId: O._id }).lean();
    expect(booking.pricing).toMatchObject({ basePrice: 18, commission: 3.6, totalPrice: 21.6, netPayout: 18 });
    const pi = await api('post', `/api/v1/bookings/${booking._id}/create-payment-intent`, tO).send({});
    expect(pi.status).toBe(200);
    expect(pi.body.amount).toBe(2160); // centimes : tarif 18 € + 20 % de commission
    mockIntents.get(pi.body.paymentIntentId).status = 'SUCCEEDED';
    emitted.length = 0;
    const wh = await request(app).post('/webhooks/airwallex').set('Content-Type', 'application/json')
      .send(JSON.stringify({ id: 'evt_612_1', name: 'payment_intent.succeeded', data: { id: pi.body.paymentIntentId, amount: 21.6, currency: 'EUR', metadata: {} } }));
    expect(wh.status).toBe(200);
    expect(await until(async () => (await Booking.findById(booking._id).lean()).paymentStatus === 'paid')).toBe(true);
    // Après le paiement : flux de remise armé (code à 4 chiffres pour le propriétaire,
    // libération automatique programmée si personne ne confirme).
    const paidDoc = await Booking.findById(booking._id).lean();
    expect(paidDoc.confirmationStatus).toBe('awaiting_start');
    expect(String(paidDoc.handoverCode || '')).toMatch(/^\d{4}$/);
    expect(paidDoc.scheduledPayoutAt).toBeTruthy();
    expect(await until(async () => emitted.some((e) => e.room === `user:walker:${W._id}` && e.ev === 'booking:paid'))).toBe(true);
    expect(emitted.some((e) => e.room === room && e.ev === 'booking:paid')).toBe(true);
    expect(await until(async () => (await Notification.countDocuments({ recipientId: W._id, type: 'booking_paid' })) === 1)).toBe(true);
  });

  test('refus d’une candidature : le prestataire est prévenu', async () => {
    const O = await mk(Owner, { name: 'Refus', email: 'o612h@example.test', location: zone() });
    const pet = await Pet.create({ ownerId: O._id, petName: 'Rex', category: 'dog' });
    const tO = tok(O._id, 'owner');
    const pub = await api('post', '/api/v1/posts', tO).send({
      body: 'Garde de Rex', serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', serviceLocation: 'at_owner',
      startDate: start().toISOString(), endDate: new Date(start().getTime() + 2 * 86400000).toISOString(),
      location: { city: 'Zone test', lat: -35, lng: -30 }, petIds: [String(pet._id)],
    });
    const ap = await api('post', `/api/v1/applications?ownerId=${O._id}`, tS).send({
      petIds: [String(pet._id)], serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: start().toISOString(),
      startDate: start().toISOString(), endDate: new Date(start().getTime() + 2 * 86400000).toISOString(), timeSlot: '9:00 AM', basePrice: 12,
      postId: String(pub.body.post.id || pub.body.post._id),
    });
    expect(ap.status).toBe(201);
    const rj = await api('post', `/api/v1/applications/${ap.body.application.id || ap.body.application._id}/respond`, tO).send({ action: 'reject' });
    expect(rj.status).toBe(200);
    expect(await until(async () => (await Notification.countDocuments({ recipientId: S._id, type: 'application_rejected' })) === 1)).toBe(true);
  });
});
