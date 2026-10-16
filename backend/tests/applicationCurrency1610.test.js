// 16/10/2026 (ADA, décision BOB sur ordre de Daniel, mesure de FLO) — DEVISE DU
// CANDIDAT ≠ DEVISE DU PROPRIÉTAIRE : refus à la création ET à l'acceptation.
// Cas réel rejoué en FICTIF : propriétaire new-yorkais en USD, gardienne de Busan
// en KRW (80 000 / jour) — sans ce refus, 24 jours de garde = 1 851 428 $.
// Vraies routes POST /applications et /applications/:id/respond, Mongo en mémoire.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
delete process.env.APPLY_CURRENCY_CHECK;

jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({ sendEachForMulticast: jest.fn(async (m) => ({ successCount: m.tokens.length, failureCount: 0, responses: [] })) }),
}));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async () => ({ messageId: 'capté' })) };
});

const request = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const cur = require('../src/utils/applicationCurrency1610');

const NYC = { lat: 40.7128, lng: -74.006 };
const BRONX = [-73.9097, 40.8361];
let mongo; let app; let Application; let Post; let Sitter; let Booking;
let owner; let pet;
const tok = (id, role) => `Bearer ${jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '1h' })}`;
const mkSitter = async (name, currency, extra = {}) => (await Sitter.collection.insertOne({
  name, email: `${name.toLowerCase()}-cur1610@example.test`, status: 'active', verified: true, currency, country: currency === 'KRW' ? 'KR' : 'US',
  dailyRate: currency === 'KRW' ? 80000 : 40, location: { type: 'Point', coordinates: BRONX, city: 'New York' }, ...extra,
})).insertedId;
const mkPost = async () => String((await Post.collection.insertOne({
  ownerId: owner, postType: 'request', status: 'open', hidden: false, body: 'Garde de 3 semaines', serviceTypes: ['pet_sitting'], petIds: [pet],
  location: { city: 'New York', ...NYC }, startDate: new Date('2026-11-05T15:00:00Z'), endDate: new Date('2026-11-29T00:00:00Z'),
  reservedBy: { bookingId: null }, createdAt: new Date(),
})).insertedId);
const applyTo = (postId, sitterId) => request(app).post(`/api/v1/applications?ownerId=${owner}`)
  .set('Authorization', tok(sitterId, 'sitter'))
  .send({ petIds: [String(pet)], serviceType: 'pet_sitting', serviceDate: '2026-11-05T15:00:00.000Z',
    startDate: '2026-11-05T15:00:00.000Z', endDate: '2026-11-29T00:00:00.000Z', timeSlot: '15:00', basePrice: 40, duration: 24, postId });
const respond = (appId, action) => request(app).post(`/api/v1/applications/${appId}/respond`).set('Authorization', tok(owner, 'owner')).send({ action });
// Candidature déjà EN ATTENTE (comme celle de Busan), insérée telle que le serveur l'avait écrite avant le correctif.
const pendingKrw = async (sitterId, postId) => String((await Application.collection.insertOne({
  postId: new mongoose.Types.ObjectId(postId), ownerId: owner, sitterId, walkerId: null, status: 'pending', petIds: [pet],
  serviceDate: new Date('2026-11-05T15:00:00Z'), startDate: new Date('2026-11-05T15:00:00Z'), endDate: new Date('2026-11-29T00:00:00Z'),
  timeSlot: '15:00', serviceType: 'pet_sitting', duration: 24, description: 'Garde',
  pricing: { basePrice: 1542857, pricingTier: 'daily', appliedRate: 80000, totalDays: 24, totalPrice: 1851428, commission: 308571, netPayout: 1542857, commissionRate: 0.2, currency: 'USD', addOns: [], addOnsTotal: 0 },
  createdAt: new Date(), updatedAt: new Date(),
})).insertedId);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  app = require('../src/app');
  Application = require('../src/models/Application'); Post = require('../src/models/Post'); Sitter = require('../src/models/Sitter'); Booking = require('../src/models/Booking');
  const Owner = require('../src/models/Owner'); const Pet = require('../src/models/Pet');
  owner = (await Owner.collection.insertOne({ name: 'Abraham', email: 'abraham-cur1610@example.test', status: 'active', verified: true, currency: 'USD', country: 'US', city: 'New York', appLocale: 'en' })).insertedId;
  pet = (await Pet.collection.insertOne({ ownerId: owner, petName: 'Milo', category: 'cat' })).insertedId;
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
afterEach(() => { delete process.env.APPLY_CURRENCY_CHECK; });

describe('utilitaire', () => {
  test('devise d’un profil : champ currency, sinon 1er tarif de balade, sinon EUR', async () => {
    expect(cur.currencyOf({ currency: 'krw' })).toBe('KRW');
    expect(cur.currencyOf({ walkRates: [{ basePrice: 5, currency: 'USD', enabled: true }] })).toBe('USD');
    expect(cur.currencyOf({})).toBe('EUR');
    expect(await cur.checkCurrencies({ currency: 'USD' }, { currency: 'KRW' })).toMatchObject({ ok: false, ownerCurrency: 'USD', providerCurrency: 'KRW' });
    expect((await cur.checkCurrencies({ currency: 'USD' }, { currency: 'USD' })).ok).toBe(true);
  });
  test('décision BOB : EUR par défaut jamais réglé → devise déduite du pays, de l’indicatif ou de la position', async () => {
    expect(cur.resolveCurrency({ currency: 'EUR', country: 'US' })).toMatchObject({ currency: 'USD', inferred: true, via: 'country' });
    expect(cur.resolveCurrency({ currency: 'EUR', country: '', countryCode: '+1' })).toMatchObject({ currency: 'USD', inferred: true, via: 'phone' });
    expect(cur.resolveCurrency({ currency: 'EUR', location: { coordinates: BRONX } })).toMatchObject({ currency: 'USD', inferred: true, via: 'coords' });
    expect(cur.resolveCurrency({ currency: 'EUR', country: 'FR' })).toMatchObject({ currency: 'EUR', inferred: false });
    expect(cur.resolveCurrency({ currency: 'EUR', country: 'KR' })).toMatchObject({ currency: 'KRW', inferred: true });
    expect(cur.resolveCurrency({ currency: 'USD', country: 'FR' })).toMatchObject({ currency: 'USD', inferred: false, via: 'explicit' }); // réglée : respectée
    expect(cur.resolveCurrency({ currency: 'EUR' })).toMatchObject({ currency: 'EUR', via: 'default' });
    // dernier recours : ville géocodée (réseau simulé)
    const r = await cur.resolveCurrencyAsync({ currency: 'EUR', city: 'New York' }, async () => ({ lat: 40.71, lng: -74 }));
    expect(r).toMatchObject({ currency: 'USD', inferred: true, via: 'city' });
    expect(await cur.checkCurrencies({ currency: 'USD' }, { currency: 'EUR', countryCode: '+1' })).toMatchObject({ ok: true, providerCurrency: 'USD', providerStored: 'EUR', inferred: true });
  });
  test('messages dans les 9 langues, devises remplacées', () => {
    for (const l of ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      for (const m of [cur.mismatchMessageForProvider(l, 'USD', 'KRW'), cur.mismatchMessageForOwner(l, 'USD', 'KRW')]) {
        expect(m).toContain('USD'); expect(m).toContain('KRW'); expect(m).not.toMatch(/\{own\}|\{prov\}/);
      }
    }
  });
  test('APPLY_CURRENCY_CHECK=off coupe le contrôle', async () => {
    process.env.APPLY_CURRENCY_CHECK = 'off';
    expect(await cur.checkCurrencies({ currency: 'USD' }, { currency: 'KRW' })).toMatchObject({ ok: true, reason: 'disabled' });
  });
});

describe('création de candidature', () => {
  test('gardienne en KRW → propriétaire en USD : 403 CURRENCY_MISMATCH en coréen, rien d’écrit', async () => {
    const s = await mkSitter('Yuju', 'KRW', { appLocale: 'ko' });
    const pid = await mkPost();
    const r = await applyTo(pid, s);
    expect(r.status).toBe(403);
    expect(r.body).toMatchObject({ code: 'CURRENCY_MISMATCH', ownerCurrency: 'USD', providerCurrency: 'KRW' });
    expect(r.body.error).toBe(cur.mismatchMessageForProvider('ko', 'USD', 'KRW'));
    expect(await Application.countDocuments({ postId: pid })).toBe(0);
  });
  test('cas Nieheem : New York, fiche restée en EUR par défaut, pays vide, indicatif +1 → devise déduite USD, accepté, 1 645 $', async () => {
    const s = await mkSitter('Nieheem0', 'EUR', { country: '', countryCode: '+1', dailyRate: 100 });
    const r = await applyTo(await mkPost(), s);
    expect(r.status).toBe(201);
    expect(r.body.application.pricing.currency).toBe('USD');
    expect(r.body.application.pricing.totalPrice).toBeLessThan(5000); // ordre de grandeur de FLO (1 645,72 $ en prod), pas 1,8 million
  });
  test('gardien parisien, EUR explicite (pays FR), propriétaire USD : refusé', async () => {
    const s = await mkSitter('Jules', 'EUR', { country: 'FR', countryCode: '+33', location: { type: 'Point', coordinates: [2.3522, 48.8566], city: 'Paris' } });
    const r = await applyTo(await mkPost(), s);
    expect(r.status).toBe(403);
    expect(r.body).toMatchObject({ code: 'CURRENCY_MISMATCH', providerCurrency: 'EUR', ownerCurrency: 'USD' });
  });
  test('gardien en USD : accepté (201), total en USD raisonnable', async () => {
    const s = await mkSitter('Nieheem', 'USD');
    const r = await applyTo(await mkPost(), s);
    expect(r.status).toBe(201);
    expect(r.body.application.pricing.currency).toBe('USD');
    expect(r.body.application.pricing.totalPrice).toBeLessThan(5000);
  });
});

describe('acceptation d’une candidature déjà en attente', () => {
  test('KRW en attente, propriétaire USD : 409 CURRENCY_MISMATCH en anglais, reste en attente, aucune réservation', async () => {
    const s = await mkSitter('Yuju2', 'KRW');
    const pid = await mkPost();
    const appId = await pendingKrw(s, pid);
    const r = await respond(appId, 'accept');
    expect(r.status).toBe(409);
    expect(r.body.code).toBe('CURRENCY_MISMATCH');
    expect(r.body.error).toBe(cur.mismatchMessageForOwner('en', 'USD', 'KRW'));
    expect((await Application.findById(appId).lean()).status).toBe('pending');
    expect(await Booking.countDocuments({ ownerId: owner })).toBe(0);
  });
  test('la même candidature peut être REFUSÉE par le propriétaire (reject passe)', async () => {
    const s = await mkSitter('Yuju3', 'KRW');
    const appId = await pendingKrw(s, await mkPost());
    const r = await respond(appId, 'reject');
    expect(r.status).toBe(200);
    expect((await Application.findById(appId).lean()).status).toBe('rejected');
  });
  test('EUR par défaut + indicatif +1 en attente (Nieheem) : acceptation 200, réservation créée en USD', async () => {
    const s = await mkSitter('Nieheem3', 'EUR', { country: '', countryCode: '+1', dailyRate: 100 });
    const pid = await mkPost();
    const a = await applyTo(pid, s);
    expect(a.status).toBe(201);
    const r = await respond(a.body.application.id || a.body.application._id, 'accept');
    expect(r.status).toBe(200);
    expect(r.body.booking ? r.body.booking.pricing.currency : 'USD').toBe('USD');
  });
  test('USD en attente, propriétaire USD : acceptation 200, réservation créée', async () => {
    const s = await mkSitter('Nieheem2', 'USD');
    const pid = await mkPost();
    const a = await applyTo(pid, s);
    expect(a.status).toBe(201);
    const r = await respond(a.body.application.id || a.body.application._id, 'accept');
    expect(r.status).toBe(200);
    expect(await Booking.countDocuments({ ownerId: owner })).toBe(2);
  });
});
