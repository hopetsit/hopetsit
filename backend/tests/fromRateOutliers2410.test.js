// 2410b (ZOE, 24/10/2026 23 h 20 — DÉCISION DE DANIEL transmise par BOB) — TARIFS ABERRANTS du
// « à partir de » (services/fromRate620, POST /pricing/estimate et /pricing/estimate/public) :
// tout tarif STRICTEMENT inférieur à la moitié du tarif MÉDIAN des prestataires retenus (après les
// exclusions existantes : test, staff, suspendus, bloqués, 0) est écarté ; avec 1 ou 2 prestataires
// pas de médiane fiable → minimum tel quel ; la réponse porte `excludedOutliers` et `median`.
// Partie 1 : règle pure. Partie 2 : VRAIE base Mongo en mémoire + VRAI routeur /pricing, zone fictive
// lat -35 / lng -30 (cas mesuré en prod : Paris garde 5 €/jour = un profil isolé, médiane bien plus haute).
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
jest.mock('../src/utils/geocodePostal2310', () => ({
  cleanCode: (c) => String(c || '').trim().toUpperCase().replace(/\s+/g, ''),
  guessCountry: () => 'FR',
  locationFromPostal: jest.fn(async (code) => (code === '99999' ? { lat: -35, lng: -30, city: 'Zone test' } : null)),
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const { applyOutlierRule, medianOf, MIN_FOR_OUTLIER_RULE } = require('../src/services/fromRate620');
const R = (...rates) => rates.map((rate) => ({ rate, unit: 'day' }));

describe('applyOutlierRule — règle pure (Daniel 24/10 : < moitié de la médiane = écarté)', () => {
  test('médiane : impaire, paire (moyenne des deux centrales), vide, arrondie au centime', () => {
    expect(medianOf([30, 5, 25])).toBe(25);
    expect(medianOf([5, 20, 30, 40])).toBe(25);
    expect(medianOf([10.005, 10.015, 10.011])).toBe(10.01);
    expect(medianOf([])).toBeNull();
    expect(medianOf(['x', null])).toBeNull();
    expect(MIN_FOR_OUTLIER_RULE).toBe(3);
  });

  test('le cas Paris : 5 € isolé parmi des tarifs à 20-40 € est écarté, le minimum devient le premier tarif sain', () => {
    const out = applyOutlierRule(R(5, 20, 25, 25, 30, 40));
    expect(out.median).toBe(25); // (25 + 25) / 2
    expect(out.excludedOutliers).toBe(1);
    expect(out.kept.map((r) => r.rate)).toEqual([20, 25, 25, 30, 40]);
  });

  test('frontière : exactement la moitié de la médiane est GARDÉ (strictement inférieur seulement)', () => {
    const out = applyOutlierRule(R(12.5, 20, 25, 30, 40)); // médiane 25, moitié 12,5
    expect(out).toMatchObject({ excludedOutliers: 0, median: 25 });
    expect(out.kept[0].rate).toBe(12.5);
    const under = applyOutlierRule(R(12.49, 20, 25, 30, 40));
    expect(under).toMatchObject({ excludedOutliers: 1, median: 25 });
    expect(under.kept[0].rate).toBe(20);
  });

  test('plusieurs aberrants écartés d un coup ; la médiane est celle de TOUS les tarifs retenus (avant écart)', () => {
    const out = applyOutlierRule(R(1, 2, 3, 30, 30, 30, 32));
    expect(out.median).toBe(30);
    expect(out.excludedOutliers).toBe(3);
    expect(out.kept.map((r) => r.rate)).toEqual([30, 30, 30, 32]);
  });

  test('1 ou 2 prestataires : pas de médiane fiable, minimum tel quel, rien d écarté', () => {
    expect(applyOutlierRule(R(5))).toMatchObject({ excludedOutliers: 0, median: 5 });
    expect(applyOutlierRule(R(5)).kept.map((r) => r.rate)).toEqual([5]);
    const two = applyOutlierRule(R(5, 40)); // 5 < 22,5 / 2 mais la règle ne s applique pas
    expect(two).toMatchObject({ excludedOutliers: 0, median: 22.5 });
    expect(two.kept.map((r) => r.rate)).toEqual([5, 40]);
    expect(applyOutlierRule([])).toEqual({ kept: [], excludedOutliers: 0, median: null });
    expect(applyOutlierRule(null)).toEqual({ kept: [], excludedOutliers: 0, median: null });
  });

  test('3 prestataires : la règle s applique dès le troisième', () => {
    const out = applyOutlierRule(R(5, 30, 40)); // médiane 30, moitié 15
    expect(out).toMatchObject({ excludedOutliers: 1, median: 30 });
    expect(out.kept.map((r) => r.rate)).toEqual([30, 40]);
    // tous proches : rien d écarté
    expect(applyOutlierRule(R(18, 25, 15))).toMatchObject({ excludedOutliers: 0, median: 18 });
  });
});

const ZONE = { type: 'Point', coordinates: [-30, -35] };
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role || 'owner', 'X-App-Version': '23.1.589+620' });
const PASS = 'MotDePasseTest620!';

let mongo; let app; let Owner; let Sitter; let fromRate620; let ctrl;
const S = {};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter');
  require('../src/models/Walker'); require('../src/models/Block');
  await Promise.all([Owner.init(), Sitter.init()]);
  fromRate620 = require('../src/services/fromRate620');
  ctrl = require('../src/controllers/pricingController');

  const base = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE };
  S.owner = await Owner.create({ ...base, name: 'Camille Durand', email: 'zoe2410b+owner@example.test', acceptedTerms: true });
  // Garde (dailyRate) : 5 (aberrant), 20, 25, 25, 30, 40 → médiane 25, moitié 12,5 → 5 écarté, « à partir de 20 €/jour ».
  S.s5 = await Sitter.create({ ...base, name: 'Cinq Euros', email: 'zoe2410b+s5@example.test', dailyRate: 5 });
  S.s20 = await Sitter.create({ ...base, name: 'Vingt', email: 'zoe2410b+s20@example.test', dailyRate: 20, visitRate: 12 });
  S.s25a = await Sitter.create({ ...base, name: 'Vingt-cinq A', email: 'zoe2410b+s25a@example.test', dailyRate: 25, visitRate: 18 });
  S.s25b = await Sitter.create({ ...base, name: 'Vingt-cinq B', email: 'zoe2410b+s25b@example.test', dailyRate: 25 });
  S.s30 = await Sitter.create({ ...base, name: 'Trente', email: 'zoe2410b+s30@example.test', dailyRate: 30 });
  S.s40 = await Sitter.create({ ...base, name: 'Quarante', email: 'zoe2410b+s40@example.test', dailyRate: 40 });
  // Exclusions EXISTANTES : ces tarifs ne comptent ni dans la médiane ni dans le minimum.
  S.sTest = await Sitter.create({ ...base, name: 'Gardien Test', email: 'zoe2410b+testsitter@example.test', dailyRate: 1 });
  S.sStaff = await Sitter.create({ ...base, name: 'Staff', email: 'zoe2410b+staff@example.test', dailyRate: 1, isStaff: true });
  S.sSusp = await Sitter.create({ ...base, name: 'Suspendu', email: 'zoe2410b+susp@example.test', dailyRate: 1, status: 'suspended' });
  S.sZero = await Sitter.create({ ...base, name: 'Zéro', email: 'zoe2410b+zero@example.test', dailyRate: 0, visitRate: 0 });

  app = express();
  app.use(express.json());
  app.use('/pricing', require('../src/routes/pricingRoutes'));
}, 180000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(() => { fromRate620._resetForTest(); ctrl._resetPublicCacheForTest(); });

const est = (body, who, role) => request(app).post('/pricing/estimate').set(hdr((who || S.owner)._id, role)).send(body);
const pub = (body) => request(app).post('/pricing/estimate/public').send(body);

describe('POST /pricing/estimate et /public — l aberrant ne fait plus le « à partir de »', () => {
  test('route authentifiée : garde 5 € écarté → fromRate 20, basedOn 5, excludedOutliers 1, median 25', async () => {
    const r = await est({ serviceType: 'house_sitting', post: { dateMode: 'tbd', location: LOC } }).expect(200);
    expect(r.body).toMatchObject({ fromRate: 20, unit: 'day', basedOn: 5, excludedOutliers: 1, median: 25, indicative: true, rateSource: 'market' });
    // les exclusions existantes (test, staff, suspendu, 0) restent hors de la médiane : 6 retenus, pas 10
    expect(r.body.basedOn + r.body.excludedOutliers).toBe(6);
    // daté : l estimation repart du tarif sain (3 jours × 20 € + 20 %)
    const d = (n) => new Date(Date.now() + n * 86400000).toISOString().slice(0, 10);
    const dated = await est({ serviceType: 'house_sitting', post: { dateMode: 'exact', startDate: d(10), endDate: d(12), location: LOC } }).expect(200);
    expect(dated.body).toMatchObject({ fromRate: 20, quantity: 3, ownerTotalFrom: 72, unitRate: 20 });
  });

  test('route publique (visiteur de la pub) : mêmes champs, aberrant écarté, sans donnée personnelle', async () => {
    const r = await pub({ serviceType: 'house_sitting', country: 'FR', postalCode: '99999' }).expect(200);
    expect(r.body).toMatchObject({ fromRate: 20, basedOn: 5, excludedOutliers: 1, median: 25, positionSource: 'postal', public: true, cached: false });
    expect(JSON.stringify(r.body)).not.toMatch(/@|Cinq|Vingt|[0-9a-f]{24}/);
    // le cache public rend la même réponse (champs compris)
    const c = await pub({ serviceType: 'house_sitting', country: 'FR', postalCode: '99999' }).expect(200);
    expect(c.body).toMatchObject({ fromRate: 20, excludedOutliers: 1, median: 25, cached: true });
  });

  test('2 prestataires (visites 12 et 18) : minimum tel quel, excludedOutliers 0, median 15', async () => {
    const r = await est({ serviceType: 'home_visit', post: { dateMode: 'tbd', location: LOC } }).expect(200);
    expect(r.body).toMatchObject({ fromRate: 12, basedOn: 2, excludedOutliers: 0, median: 15 });
    // 1 prestataire très bas face à un seul autre : gardé aussi (pas de médiane fiable)
    const low = await Sitter.create({ password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, name: 'Pas cher', email: 'zoe2410b+low@example.test', visitRate: 2 });
    fromRate620._resetForTest();
    const three = await est({ serviceType: 'home_visit', post: { dateMode: 'tbd', location: LOC } }).expect(200);
    // 3 tarifs (2, 12, 18) : médiane 12, moitié 6 → 2 écarté
    expect(three.body).toMatchObject({ fromRate: 12, basedOn: 2, excludedOutliers: 1, median: 12 });
    await Sitter.deleteOne({ _id: low._id });
    fromRate620._resetForTest();
    const one = await est({ serviceType: 'home_visit', post: { dateMode: 'tbd', location: { city: 'Nulle part', lat: 10, lng: 10 } } }).expect(200);
    expect(one.body).toMatchObject({ fromRate: null, basedOn: 0, excludedOutliers: 0, median: null });
  });

  test('cache 5 min : la valeur mise en cache porte excludedOutliers et median ; expiration = recalcul', async () => {
    const first = await fromRate620.fromRateFor({ serviceType: 'house_sitting', center: { lat: -35, lng: -30 }, currency: 'EUR', now: 1000 });
    expect(first).toMatchObject({ fromRate: 20, basedOn: 5, excludedOutliers: 1, median: 25, cached: false });
    const again = await fromRate620.fromRateFor({ serviceType: 'house_sitting', center: { lat: -35.01, lng: -30.01 }, currency: 'EUR', now: 1000 + 4 * 60 * 1000 });
    expect(again).toMatchObject({ fromRate: 20, excludedOutliers: 1, median: 25, cached: true });
    // le profil à 5 € remonte à 15 € : plus d aberrant après expiration (15 ≥ 12,5)
    await Sitter.updateOne({ _id: S.s5._id }, { $set: { dailyRate: 15 } });
    const stale = await fromRate620.fromRateFor({ serviceType: 'house_sitting', center: { lat: -35, lng: -30 }, currency: 'EUR', now: 1000 + 4.5 * 60 * 1000 });
    expect(stale).toMatchObject({ fromRate: 20, cached: true });
    const later = await fromRate620.fromRateFor({ serviceType: 'house_sitting', center: { lat: -35, lng: -30 }, currency: 'EUR', now: 1000 + fromRate620.CACHE_TTL_MS + 1 });
    expect(later).toMatchObject({ fromRate: 15, basedOn: 6, excludedOutliers: 0, median: 25, cached: false });
    await Sitter.updateOne({ _id: S.s5._id }, { $set: { dailyRate: 5 } });
  });
});
