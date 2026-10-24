// 620b (ZOE, 24/10/2026 — point relevé par PAM au build 620, ordre de Daniel transmis par BOB)
// POST /pricing/estimate SANS `rate` ni `providerId` = demande OUVERTE → tarif « à partir de » :
// minimum (hors 0) des prestataires du rayon d'alerte (100 km) autour de la demande, devise du
// propriétaire, comptes de test / staff / suspendus exclus, 200 { fromRate:null, basedOn:0 } sans
// personne, tbd = quantité nulle, cache 5 min par (service, zone, devise), appels AVEC rate inchangés.
// VRAIE base Mongo en mémoire, VRAI routeur /pricing. Zone fictive lat -35 / lng -30.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
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

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const day = (n) => { const d = new Date(Date.now() + n * 86400000); return `${d.toISOString().slice(0, 10)}T00:00:00.000Z`; };
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const FAR = { type: 'Point', coordinates: [-30, -37] }; // ~222 km au sud : hors du rayon de 100 km
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role || 'owner', 'X-App-Version': '23.1.589+620' });
const PASS = 'MotDePasseTest620!';

let mongo; let app; let Owner; let Sitter; let Walker; let fromRate620;
const S = {};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  require('../src/models/Block');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init()]);
  fromRate620 = require('../src/services/fromRate620');

  const base = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE };
  S.owner = await Owner.create({ ...base, name: 'Camille Durand', email: 'zoe620b+owner@example.test', acceptedTerms: true });
  S.ownerUsd = await Owner.create({ ...base, name: 'Jane Doe', email: 'zoe620b+ownerusd@example.test', currency: 'USD', country: 'US', acceptedTerms: true });
  S.ownerTest = await Owner.create({ ...base, name: 'Compte Test', email: 'zoe620b+testowner@example.test', acceptedTerms: true });
  S.s12 = await Sitter.create({ ...base, name: 'Inès Petit', email: 'zoe620b+s12@example.test', dailyRate: 18, visitRate: 12, visitDurationMinutes: 30 });
  S.s18 = await Sitter.create({ ...base, name: 'Léa Noir', email: 'zoe620b+s18@example.test', dailyRate: 25, visitRate: 18, visitDurationMinutes: 60 });
  S.sZero = await Sitter.create({ ...base, name: 'Sans visite', email: 'zoe620b+szero@example.test', dailyRate: 15, visitRate: 0 });
  S.sTest = await Sitter.create({ ...base, name: 'Gardien Test', email: 'zoe620b+testsitter@example.test', visitRate: 5 });
  S.sStaff = await Sitter.create({ ...base, name: 'Staff', email: 'zoe620b+staff@example.test', visitRate: 3, isStaff: true });
  S.sSusp = await Sitter.create({ ...base, name: 'Suspendu', email: 'zoe620b+susp@example.test', visitRate: 2, status: 'suspended' });
  S.sUsd = await Sitter.create({ ...base, name: 'Dollar', email: 'zoe620b+usd@example.test', visitRate: 4, currency: 'USD' });
  S.sFar = await Sitter.create({ ...base, name: 'Trop loin', email: 'zoe620b+far@example.test', visitRate: 1, location: FAR, city: 'Ailleurs' });
  S.w10 = await Walker.create({ ...base, name: 'Paul Promeneur', email: 'zoe620b+w10@example.test', walkRates: [{ durationMinutes: 30, basePrice: 10, currency: 'EUR', enabled: true }, { durationMinutes: 60, basePrice: 16, currency: 'EUR', enabled: true }] });

  app = express();
  app.use(express.json());
  app.use('/pricing', require('../src/routes/pricingRoutes'));
}, 180000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(() => fromRate620._resetForTest());

const est = (body, who = S.owner, role = 'owner') => request(app).post('/pricing/estimate').set(hdr(who._id, role)).send(body);

describe('estimation « à partir de » (demande ouverte, sans rate ni providerId)', () => {
  test('minimum correct : 12 (18 et 0 écartés), demande datée 3 j × 2 visites → 6 visites, ~86,40 €', async () => {
    const r = await est({ serviceType: 'home_visit', post: { dateMode: 'exact', startDate: day(10), endDate: day(12), visitsPerDay: 2, location: LOC } }).expect(200);
    expect(r.body).toMatchObject({
      serviceType: 'home_visit', indicative: true, fromRate: 12, unit: 'visit', quantity: 6, ownerTotalFrom: 86.4,
      currency: 'EUR', durationMinutes: 30, radiusKm: 100, rateSource: 'market', unitRate: 12, ownerTotal: null, unitTotal: null, commission: null,
    });
    // basedOn = 12, 18 (gardiens réels, actifs, EUR, dans le rayon) — ni 0, ni test, ni staff, ni suspendu, ni USD, ni trop loin.
    expect(r.body.basedOn).toBe(2);
  });

  test('exclusion des comptes de test et staff, suspendus, hors devise, hors rayon (vérifiée par le service)', async () => {
    const m = await fromRate620.fromRateFor({ serviceType: 'home_visit', center: { lat: -35, lng: -30 }, city: 'Zone test', currency: 'EUR' });
    expect(m).toMatchObject({ fromRate: 12, basedOn: 2, unit: 'visit', cached: false });
    // Sans exclusions, le minimum serait 1 (trop loin), 2 (suspendu), 3 (staff) ou 5 (test).
    expect([1, 2, 3, 4, 5]).not.toContain(m.fromRate);
  });

  test('demande d un compte de test : seuls des comptes de test comptent → 5', async () => {
    const r = await est({ serviceType: 'home_visit', post: { dateMode: 'tbd', location: LOC } }, S.ownerTest).expect(200);
    expect(r.body).toMatchObject({ fromRate: 5, basedOn: 1, quantity: null, ownerTotalFrom: null, indicative: true });
  });

  test('devise : propriétaire USD → seul le gardien en USD (4 $), EUR inchangé', async () => {
    const usd = await est({ serviceType: 'home_visit', post: { dateMode: 'tbd', location: LOC } }, S.ownerUsd).expect(200);
    expect(usd.body).toMatchObject({ fromRate: 4, basedOn: 1, currency: 'USD' });
    const eur = await est({ serviceType: 'home_visit', post: { dateMode: 'tbd', location: LOC } }).expect(200);
    expect(eur.body).toMatchObject({ fromRate: 12, basedOn: 2, currency: 'EUR' });
    // devise explicite dans le corps : prime sur le profil
    const forced = await est({ serviceType: 'home_visit', currency: 'USD', post: { dateMode: 'tbd', location: LOC } }).expect(200);
    expect(forced.body).toMatchObject({ fromRate: 4, currency: 'USD' });
  });

  test('aucun prestataire : 200 { fromRate:null, basedOn:0 } — jamais une erreur', async () => {
    const r = await est({ serviceType: 'home_visit', post: { dateMode: 'exact', startDate: day(10), endDate: day(10), location: { city: 'Nulle part', lat: 10, lng: 10 } } }).expect(200);
    expect(r.body).toMatchObject({ fromRate: null, basedOn: 0, unit: 'visit', quantity: 1, ownerTotalFrom: null, indicative: true, unitRate: 0 });
    // service sans aucun tarif autour (garderie : les gardiens EUR ont un dailyRate → day_care trouve 18 ; la balade 60 min trouve 16)
    const walk = await est({ serviceType: 'dog_walking', durationMinutes: 60, post: { dateMode: 'tbd', location: LOC } }).expect(200);
    expect(walk.body).toMatchObject({ fromRate: 16, unit: 'walk', basedOn: 1, durationMinutes: 60 });
    const day_ = await est({ serviceType: 'day_care', post: { dateMode: 'tbd', location: LOC } }).expect(200);
    expect(day_.body).toMatchObject({ fromRate: 15, unit: 'day', basedOn: 3 }); // 18, 25, 15 (le gardien « sans visite » a un dailyRate)
  });

  test('tbd : quantité nulle, fromRate seul ; position reprise du profil quand la demande n en a pas', async () => {
    const r = await est({ serviceType: 'home_visit', post: { dateMode: 'tbd' } }).expect(200);
    expect(r.body).toMatchObject({ fromRate: 12, quantity: null, ownerTotalFrom: null, dateMode: 'tbd', indicative: true });
    // position de la ville seule (sans coordonnées) : géocodée → même résultat
    const byCity = await est({ serviceType: 'home_visit', city: 'Zone test', post: { dateMode: 'tbd' } }).expect(200);
    expect(byCity.body).toMatchObject({ fromRate: 12, basedOn: 2 });
  });

  test('cache 5 min par (service, zone, devise) : un gardien moins cher ajouté n apparaît qu après expiration', async () => {
    const first = await fromRate620.fromRateFor({ serviceType: 'home_visit', center: { lat: -35, lng: -30 }, currency: 'EUR', now: 1000 });
    expect(first).toMatchObject({ fromRate: 12, cached: false });
    const cheap = await Sitter.create({ password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, name: 'Pas cher', email: 'zoe620b+cheap@example.test', visitRate: 9 });
    const again = await fromRate620.fromRateFor({ serviceType: 'home_visit', center: { lat: -35.01, lng: -30.01 }, currency: 'EUR', now: 1000 + 4 * 60 * 1000 });
    expect(again).toMatchObject({ fromRate: 12, cached: true });
    const later = await fromRate620.fromRateFor({ serviceType: 'home_visit', center: { lat: -35, lng: -30 }, currency: 'EUR', now: 1000 + fromRate620.CACHE_TTL_MS + 1 });
    expect(later).toMatchObject({ fromRate: 9, basedOn: 3, cached: false });
    // une autre devise ou un autre service = une autre entrée
    const usd = await fromRate620.fromRateFor({ serviceType: 'home_visit', center: { lat: -35, lng: -30 }, currency: 'USD', now: 1000 });
    expect(usd).toMatchObject({ fromRate: 4, cached: false });
    await Sitter.deleteOne({ _id: cheap._id });
  });

  test('compatibilité : avec rate (ou providerId) la réponse ne change pas', async () => {
    const r = await est({ serviceType: 'home_visit', rate: 12, post: { dateMode: 'exact', startDate: day(10), endDate: day(12), visitsPerDay: 2 } }).expect(200);
    expect(r.body).toMatchObject({ indicative: false, quantity: 6, unitRate: 12, unitTotal: 72, commission: 14.4, ownerTotal: 86.4, rateSource: 'body' });
    expect(r.body.fromRate).toBeUndefined();
    const p = await est({ serviceType: 'home_visit', providerId: String(S.s18._id), providerRole: 'sitter', post: { dateMode: 'tbd' } }).expect(200);
    expect(p.body).toMatchObject({ indicative: true, unitRate: 18, rateSource: 'visitRate' });
    expect(p.body.fromRate).toBeUndefined();
    // gardien connecté sans rate : son propre tarif, pas le marché
    const me = await est({ serviceType: 'home_visit', post: { dateMode: 'tbd' } }, S.s18, 'sitter').expect(200);
    expect(me.body).toMatchObject({ unitRate: 18, rateSource: 'visitRate' });
    await est({ post: { dateMode: 'tbd' } }).expect(400); // serviceType toujours requis
  });
});
