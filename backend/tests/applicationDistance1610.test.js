// 16/10/2026 (ADA, demande de Daniel) — REFUS D'UNE CANDIDATURE TROP LOIN DE LA DEMANDE.
// Cas mesuré en production : garde à New York, candidatures de New York (8 km),
// Hartford (≈ 180 km) et Busan, Corée (≈ 11 000 km). Vraie route
// POST /api/v1/applications, base Mongo en mémoire ; push/e-mail captés.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
delete process.env.APPLY_MAX_KM;

jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({ sendEachForMulticast: jest.fn(async (m) => ({ successCount: m.tokens.length, failureCount: 0, responses: [] })) }),
}));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async () => ({ messageId: 'capté' })) };
});
// Géocodage de ville : New York connu, le reste inconnu (aucun appel réseau).
jest.mock('../src/utils/geocodeCity', () => {
  const actual = jest.requireActual('../src/utils/geocodeCity');
  return {
    ...actual,
    geocodeCity: jest.fn(async (city) => (/new york/i.test(String(city)) ? { lat: 40.7128, lng: -74.006 } : null)),
  };
});

const request = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const dist = require('../src/utils/applicationDistance1610');

const NYC = { lat: 40.7128, lng: -74.006 };
const BRONX = [-73.9097, 40.8361]; // [lng, lat] ≈ 16 km
const HARTFORD = [-72.6708, 41.7702]; // ≈ 160 km (< 200)
const BUSAN = [129.036, 35.1718]; // ≈ 11 000 km

let mongo; let app; let Application; let Post; let Sitter;
let owner; let pet;
const tok = (id, role) => `Bearer ${jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '1h' })}`;
const mkSitter = async (name, coords, extra = {}) => (await Sitter.collection.insertOne({
  name, email: `${name.toLowerCase()}-1610@example.test`, status: 'active', verified: true, currency: 'USD', country: 'US',
  dailyRate: 40, ...(coords ? { location: { type: 'Point', coordinates: coords, city: name } } : {}), ...extra,
})).insertedId;
const mkPost = async (location) => String((await Post.collection.insertOne({
  ownerId: owner, postType: 'request', status: 'open', hidden: false, body: 'Garde de 3 semaines',
  serviceTypes: ['pet_sitting'], petIds: [pet], location,
  startDate: new Date('2026-11-05T15:00:00Z'), endDate: new Date('2026-11-29T00:00:00Z'),
  reservedBy: { bookingId: null }, createdAt: new Date(),
})).insertedId);
const applyTo = (postId, sitterId) => request(app).post(`/api/v1/applications?ownerId=${owner}`)
  .set('Authorization', tok(sitterId, 'sitter'))
  .send({ petIds: [String(pet)], serviceType: 'pet_sitting', serviceDate: '2026-11-05T15:00:00.000Z',
    startDate: '2026-11-05T15:00:00.000Z', endDate: '2026-11-29T00:00:00.000Z', timeSlot: '15:00', basePrice: 40, duration: 24, postId });

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  app = require('../src/app');
  Application = require('../src/models/Application'); Post = require('../src/models/Post'); Sitter = require('../src/models/Sitter');
  const Owner = require('../src/models/Owner'); const Pet = require('../src/models/Pet');
  owner = (await Owner.collection.insertOne({ name: 'Abraham', email: 'abraham-1610@example.test', status: 'active', verified: true, currency: 'USD', country: 'US', city: 'New York' })).insertedId;
  pet = (await Pet.collection.insertOne({ ownerId: owner, petName: 'Milo', category: 'cat' })).insertedId;
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
afterEach(() => { delete process.env.APPLY_MAX_KM; });

describe('utilitaire', () => {
  test('position d’une annonce : lat/lng, latitude/longitude, coordinates [lng,lat], sinon null', () => {
    expect(dist.postCenter({ location: { lat: 1, lng: 2 } })).toEqual({ lat: 1, lng: 2 });
    expect(dist.postCenter({ location: { latitude: '1.5', longitude: '2.5' } })).toEqual({ lat: 1.5, lng: 2.5 });
    expect(dist.postCenter({ location: { coordinates: [2, 1] } })).toEqual({ lat: 1, lng: 2 });
    expect(dist.postCenter({ location: { city: 'New York' } })).toBeNull();
    expect(dist.postCenter({ location: { lat: 0, lng: 0 } })).toBeNull();
    expect(dist.postCenter({})).toBeNull();
  });
  test('distance Busan ↔ New York ≈ 11 000 km, Bronx ≈ 16 km', () => {
    const post = { location: NYC };
    expect(dist.distanceKm(post, { location: { coordinates: BUSAN } })).toBeGreaterThan(10500);
    expect(dist.distanceKm(post, { location: { coordinates: BUSAN } })).toBeLessThan(11500);
    expect(dist.distanceKm(post, { location: { coordinates: BRONX } })).toBeLessThan(20);
    expect(dist.distanceKm(post, {})).toBeNull();
  });
  test('message dans les 9 langues de l’API, avec les km et la limite', () => {
    for (const l of dist.LANGS) {
      const m = dist.tooFarMessage(l, 11017.4, 100);
      expect(m).toContain('11,017');
      expect(m).toContain('100');
      expect(m).not.toContain('{km}');
    }
    expect(dist.tooFarMessage('zz', 12.34, 100)).toBe(dist.tooFarMessage('en', 12.3, 100));
    expect(dist.localeOf({ appLocale: 'ko-KR' })).toBe('ko');
    expect(dist.localeOf({ language: 'Français' })).toBe('fr');
    expect(dist.localeOf({})).toBe('en');
  });
  test('APPLY_MAX_KM : défaut 200 (décision Daniel 16/10), 0 = coupé, valeur folle = défaut', async () => {
    expect(dist.maxKm()).toBe(200);
    process.env.APPLY_MAX_KM = '0';
    expect((await dist.checkApplicantDistance({ post: { location: NYC }, provider: { location: { coordinates: BUSAN } } })).reason).toBe('disabled');
    process.env.APPLY_MAX_KM = 'abc';
    expect(dist.maxKm()).toBe(200);
  });
  test('sans position d’un côté : on laisse passer (vieux comptes)', async () => {
    expect((await dist.checkApplicantDistance({ post: { location: NYC }, provider: {} })).reason).toBe('no_provider_position');
    expect((await dist.checkApplicantDistance({ post: { location: { city: 'Nulle-Part' } }, provider: { location: { coordinates: BUSAN } } })).reason).toBe('no_post_position');
  });
});

describe('route POST /applications', () => {
  test('gardien du Bronx (16 km) : candidature acceptée (201)', async () => {
    const s = await mkSitter('Nieheem', BRONX);
    const r = await applyTo(await mkPost({ city: 'New York', ...NYC }), s);
    expect(r.status).toBe(201);
  });
  test('gardien de Busan (11 000 km) : refusée 403 TOO_FAR, message en coréen, rien d’écrit', async () => {
    const s = await mkSitter('Yuju', BUSAN, { appLocale: 'ko' });
    const pid = await mkPost({ city: 'New York', ...NYC });
    const r = await applyTo(pid, s);
    expect(r.status).toBe(403);
    expect(r.body.code).toBe('TOO_FAR');
    expect(r.body.km).toBeGreaterThan(10000);
    expect(r.body.limitKm).toBe(200);
    expect(r.body.error).toBe(dist.tooFarMessage('ko', r.body.km, 200));
    expect(await Application.countDocuments({ postId: pid })).toBe(0);
  });
  test('gardienne de Hartford (≈ 160-190 km) : acceptée, sous les 200 km décidés par Daniel', async () => {
    const s = await mkSitter('Anahi', HARTFORD);
    const r = await applyTo(await mkPost({ city: 'New York', ...NYC }), s);
    expect(r.status).toBe(201);
  });
  test('à 250 km (hors limite) : refusée, message en anglais (pas de langue sur le profil)', async () => {
    const s = await mkSitter('Loin', [-71.0589, 42.3601]); // Boston ≈ 306 km
    const r = await applyTo(await mkPost({ city: 'New York', ...NYC }), s);
    expect(r.status).toBe(403);
    expect(r.body.error).toMatch(/^This request is 3\d\d km away/);
  });
  test('annonce SANS coordonnées mais avec une ville connue : centre de la ville géocodé → Busan refusée', async () => {
    const s = await mkSitter('Yuju2', BUSAN);
    const r = await applyTo(await mkPost({ city: 'New York' }), s);
    expect(r.status).toBe(403);
    expect(r.body.code).toBe('TOO_FAR');
  });
  test('annonce sans coordonnées ni ville connue : on laisse passer', async () => {
    const s = await mkSitter('Yuju3', BUSAN);
    const r = await applyTo(await mkPost({ city: 'Nulle-Part' }), s);
    expect(r.status).toBe(201);
  });
  test('gardien sans position enregistrée : on laisse passer', async () => {
    const s = await mkSitter('Sansposition', null);
    const r = await applyTo(await mkPost({ city: 'New York', ...NYC }), s);
    expect(r.status).toBe(201);
  });
  test('APPLY_MAX_KM=0 : plus aucun refus', async () => {
    process.env.APPLY_MAX_KM = '0';
    const s = await mkSitter('Yuju4', BUSAN);
    const r = await applyTo(await mkPost({ city: 'New York', ...NYC }), s);
    expect(r.status).toBe(201);
  });
});
