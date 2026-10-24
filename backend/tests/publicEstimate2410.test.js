// 2410 (ZOE, 24/10/2026 — demande de BOB, point relevé par LEO) — POST /pricing/estimate/public :
// estimation « à partir de » SANS session pour les visiteurs de la pub (/posts/create avant compte).
// Même réponse que la route authentifiée, devise déduite du pays, position = lat/lng sinon code
// postal sinon ville, jamais de donnée personnelle, limité en débit, cache 5 min.
// VRAIE base Mongo en mémoire, VRAI routeur /pricing. Zone fictive lat -35 / lng -30 ; aucun réseau
// (geocodeCity et geocodePostal2310 simulés).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
process.env.PUBLIC_ESTIMATE_RPM = '1000';

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res) => res.status(401).json({ error: 'auth' }),
  requireRole: () => (req, res, next) => next(),
  requireVerifiedEmail: (req, res, next) => next(),
  attachUserFromToken: (req, res, next) => next(),
  attachOwnerFromToken: (req, res, next) => next(),
  optionalAuth: (req, res, next) => next(),
}));
jest.mock('../src/utils/geocodeCity', () => ({
  baseCityName: (c) => String(c || ''),
  geocodeCity: jest.fn(async (city) => (String(city).toLowerCase() === 'zone test' ? { lat: -35, lng: -30 } : null)),
  peekCity: () => undefined, warmCities: () => {}, ensureAnchorsLoaded: async () => {},
}));
jest.mock('../src/utils/geocodePostal2310', () => {
  const real = jest.requireActual('../src/utils/geocodePostal2310');
  return {
    ...real,
    locationFromPostal: jest.fn(async (code, { country } = {}) => (
      String(code) === '99999' && String(country).toUpperCase() === 'FR' ? { city: 'Zone test', lat: -35, lng: -30, postalCode: '99999' } : null)),
  };
});

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const day = (n) => { const d = new Date(Date.now() + n * 86400000); return `${d.toISOString().slice(0, 10)}T00:00:00.000Z`; };
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const PASS = 'MotDePasseTest2410!';

let mongo; let app; let Owner; let Sitter; let Walker; let fromRate620; let ctrl;
const S = {};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  require('../src/models/Block');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init()]);
  fromRate620 = require('../src/services/fromRate620');
  ctrl = require('../src/controllers/pricingController');

  const base = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE };
  S.s12 = await Sitter.create({ ...base, name: 'Inès Petit', email: 'zoe2410+s12@example.test', dailyRate: 18, visitRate: 12, visitDurationMinutes: 30 });
  S.s18 = await Sitter.create({ ...base, name: 'Léa Noir', email: 'zoe2410+s18@example.test', dailyRate: 25, visitRate: 18, visitDurationMinutes: 60 });
  S.sTest = await Sitter.create({ ...base, name: 'Gardien Test', email: 'zoe2410+testsitter@example.test', visitRate: 5 });
  S.sUsd = await Sitter.create({ ...base, name: 'Dollar', email: 'zoe2410+usd@example.test', visitRate: 4, currency: 'USD', country: 'US' });
  S.w10 = await Walker.create({ ...base, name: 'Paul Promeneur', email: 'zoe2410+w10@example.test', walkRates: [{ durationMinutes: 30, basePrice: 10, currency: 'EUR', enabled: true }, { durationMinutes: 60, basePrice: 16, currency: 'EUR', enabled: true }] });

  app = express();
  app.use(express.json());
  app.use('/pricing', require('../src/routes/pricingRoutes'));
}, 180000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(() => { fromRate620._resetForTest(); ctrl._resetPublicCacheForTest(); });

const pub = (body) => request(app).post('/pricing/estimate/public').send(body); // AUCUN jeton
const PERSONAL = /@|Inès|Léa|Paul|Dollar|[0-9a-f]{24}/;

describe('POST /pricing/estimate/public — sans session', () => {
  test('la route authentifiée refuse sans jeton ; la publique répond 200 avec le même format', async () => {
    await request(app).post('/pricing/estimate').send({ serviceType: 'home_visit', lat: -35, lng: -30 }).expect(401);
    const r = await pub({ serviceType: 'home_visit', country: 'FR', lat: -35, lng: -30, startDate: day(10), endDate: day(12), visitsPerDay: 2 }).expect(200);
    expect(r.body).toMatchObject({
      serviceType: 'home_visit', fromRate: 12, unit: 'visit', quantity: 6, ownerTotalFrom: 86.4, basedOn: 2, currency: 'EUR',
      indicative: true, dateMode: 'exact', positionSource: 'coords', country: 'FR', public: true, cached: false, rateSource: 'market',
    });
    expect(Object.keys(r.body)).toEqual(expect.arrayContaining(['fromRate', 'unit', 'quantity', 'ownerTotalFrom', 'basedOn', 'indicative', 'commissionRate', 'radiusKm']));
    expect(JSON.stringify(r.body)).not.toMatch(PERSONAL); // ni nom, ni id, ni e-mail
  });

  test('position : code postal (geocodePostal2310) puis ville (geocodeCity) ; sans dates = tbd', async () => {
    const byPostal = await pub({ serviceType: 'home_visit', postalCode: '99999', country: 'FR' }).expect(200);
    expect(byPostal.body).toMatchObject({ fromRate: 12, basedOn: 2, quantity: null, ownerTotalFrom: null, dateMode: 'tbd', positionSource: 'postal' });
    const byCity = await pub({ serviceType: 'home_visit', city: 'Zone test', country: 'FR' }).expect(200);
    expect(byCity.body).toMatchObject({ fromRate: 12, basedOn: 2, positionSource: 'city' });
    // code postal inconnu → on retombe sur la ville
    const fallback = await pub({ serviceType: 'home_visit', postalCode: '11111', city: 'Zone test', country: 'FR' }).expect(200);
    expect(fallback.body).toMatchObject({ fromRate: 12, positionSource: 'city' });
    // balade 60 min → 16 (promeneur), walkDurationMinutes lu
    const walk = await pub({ serviceType: 'dog_walking', walkDurationMinutes: 60, city: 'Zone test', country: 'FR' }).expect(200);
    expect(walk.body).toMatchObject({ fromRate: 16, unit: 'walk', basedOn: 1, durationMinutes: 60 });
  });

  test('devise déduite du pays : US → USD → seul le gardien en dollars (4 $) ; pays déduit de la langue + code postal', async () => {
    const us = await pub({ serviceType: 'home_visit', country: 'us', lat: -35, lng: -30 }).expect(200);
    expect(us.body).toMatchObject({ currency: 'USD', fromRate: 4, basedOn: 1, country: 'US' });
    const fr = await pub({ serviceType: 'home_visit', lang: 'fr', postalCode: '99999' }).expect(200);
    expect(fr.body).toMatchObject({ currency: 'EUR', country: 'FR', fromRate: 12, positionSource: 'postal' });
  });

  test('zone fictive sans personne / aucune position / service manquant : 200 basedOn 0, 200 basedOn 0, 400', async () => {
    const nobody = await pub({ serviceType: 'home_visit', country: 'FR', lat: 10, lng: 10 }).expect(200);
    expect(nobody.body).toMatchObject({ fromRate: null, basedOn: 0, ownerTotalFrom: null, unitRate: 0, indicative: true, positionSource: 'coords' });
    const nowhere = await pub({ serviceType: 'home_visit' }).expect(200);
    expect(nowhere.body).toMatchObject({ fromRate: null, basedOn: 0, positionSource: 'none', currency: 'EUR' });
    const bad = await pub({ city: 'Zone test' }).expect(400);
    expect(bad.body.code).toBe('SERVICE_REQUIRED');
    // coordonnées absurdes ignorées → ville
    const absurd = await pub({ serviceType: 'home_visit', country: 'FR', lat: 999, lng: 5, city: 'Zone test' }).expect(200);
    expect(absurd.body.positionSource).toBe('city');
  });

  test('cache 5 min : un gardien moins cher ajouté n apparaît pas avant expiration ; comptes de test exclus', async () => {
    const body = { serviceType: 'home_visit', country: 'FR', lat: -35, lng: -30 };
    const a = await pub(body).expect(200);
    expect(a.body).toMatchObject({ fromRate: 12, cached: false }); // le gardien +testsitter à 5 € n'est pas compté
    const cheap = await Sitter.create({ password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, name: 'Pas Cher', email: 'zoe2410+cheap@example.test', visitRate: 7 });
    const b = await pub(body).expect(200);
    expect(b.body).toMatchObject({ fromRate: 12, cached: true });
    fromRate620._resetForTest(); ctrl._resetPublicCacheForTest();
    const c = await pub(body).expect(200);
    expect(c.body).toMatchObject({ fromRate: 7, basedOn: 3, cached: false });
    await Sitter.deleteOne({ _id: cheap._id });
  });

  test('limite de débit : au-delà de PUBLIC_ESTIMATE_RPM appels par minute et par IP → 429', async () => {
    process.env.PUBLIC_ESTIMATE_RPM = '1';
    const r = await pub({ serviceType: 'home_visit', country: 'FR', lat: -35, lng: -30 });
    expect(r.status).toBe(429);
    expect(r.body).toMatchObject({ code: 'RATE_LIMITED' });
    process.env.PUBLIC_ESTIMATE_RPM = '1000';
  });
});
