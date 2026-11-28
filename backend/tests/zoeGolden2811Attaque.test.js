// ZOE, 28/11/2026 — contrôle indépendant du lot « 2 peluches dorées par semaine + dorée gardée 13 jours ».
// Vraie base en mémoire, vrai service, vraie route admin ; seule l'horloge (Date) est déplacée.
// Zone fictive (lat -35 / lng -30), aucune vraie ville.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => { req.user = { id: 'admin1', role: 'admin' }; next(); },
  requireRole: () => (req, res, next) => next(),
}));

const mongoose = require('mongoose');
const express = require('express');
const request = require('supertest');
const { MongoMemoryServer } = require('mongodb-memory-server');
const plush = require('../src/services/plushService607');
const map = require('../src/sockets/mapSocket');

const DAY = 86400000;
const Z = { lat: -35.2, lng: -30.4 };
let mongo; let Owner; let MapPOI; let PawPlush; let app; let city;

const setNow = (t) => jest.setSystemTime(new Date(t));
beforeAll(async () => {
  jest.useFakeTimers({ doNotFake: ['nextTick', 'setImmediate', 'clearImmediate', 'setInterval', 'clearInterval', 'setTimeout', 'clearTimeout', 'queueMicrotask', 'performance', 'hrtime', 'requestAnimationFrame', 'cancelAnimationFrame', 'requestIdleCallback', 'cancelIdleCallback'] });
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  MapPOI = require('../src/models/MapPOI');
  PawPlush = require('../src/models/PawPlush');
  await Promise.all([Owner.init(), MapPOI.init(), PawPlush.init(), require('../src/models/Sitter').init(), require('../src/models/Walker').init()]);
  // 8 parcs à chiens dans un rayon de ~400 m (tous dans le rayon de vue).
  for (let i = 0; i < 8; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    await MapPOI.create({ title: 'Dog park', category: 'park', status: 'active', source: 'seed', osmId: `way/zoe2811${i}`, location: { type: 'Point', coordinates: [Z.lng + (i - 4) / 2500, Z.lat + (i - 4) / 3000] } });
  }
  app = express();
  app.use('/admin/pawpoints-insights', require('../src/routes/adminPawPointsInsights607'));
}, 60000);
afterAll(async () => { jest.useRealTimers(); await mongoose.disconnect(); if (mongo) await mongo.stop(); });

let n = 0;
async function makeOwner() {
  n += 1;
  return Owner.create({ name: `Zoe ${n}`, email: `zoe2811_${n}@example.org`, password: 'MotDePasse2811!', location: { type: 'Point', coordinates: [Z.lng, Z.lat], city: 'Zone Zoé', updatedAt: new Date() } });
}
const walk = (u, lat = Z.lat, lng = Z.lng) => map.touchLiveSession({ userId: String(u._id), role: 'owner', lat, lng });
const pts = async (u) => (await Owner.findById(u._id).select('pawPoints').lean()).pawPoints || 0;
async function tryCatch(u, p, now) {
  const [lng, lat] = p.location ? p.location.coordinates : [p.lng, p.lat];
  setNow(now);
  walk(u, lat, lng);
  try { return { status: 200, body: await plush.catchPlush({ userId: String(u._id), role: 'owner', plushId: String(p._id || p.id), lat, lng, accuracy: 5, now }) }; } catch (e) { return { status: e.status, code: e.code }; }
}

test('dorée gardée 13 jours : invisible, imprenable (410), hors des comptes, hors de l\'admin du jour, et son lieu resservi', async () => {
  const anna = await makeOwner();   // en Balade
  const bob = await makeOwner();    // hors Balade (compteur seulement)
  const noon = Date.parse(`${new Date().toISOString().slice(0, 10)}T15:00:00Z`);
  setNow(noon);
  [city] = (await plush.activeCities({ force: true })).filter((c) => Math.abs(c.lat - Z.lat) < 0.2);
  expect(city).toBeTruthy();
  // Premier jour doré de la zone dont le LENDEMAIN n'est pas doré.
  let t0 = noon;
  for (let i = 0; i < 30; i += 1, t0 += DAY) {
    const d = plush.dayKeyFor(city.lng, t0, city.lat); const d1 = plush.dayKeyFor(city.lng, t0 + DAY, city.lat);
    if (plush.isGoldenDay(city.key, d) && !plush.isGoldenDay(city.key, d1)) break;
  }
  setNow(t0);
  walk(anna);
  const j0 = await plush.listActive({ userId: String(anna._id), lat: Z.lat, lng: Z.lng, now: t0 });
  expect(j0.walkActive).toBe(true);
  const gold0 = j0.plushies.filter((p) => p.golden);
  expect(gold0).toHaveLength(1);
  const goldDoc = await PawPlush.findById(gold0[0].id).lean();
  expect(Math.round((goldDoc.expireAt - t0) / DAY)).toBe(13);
  const goldPoi = String(goldDoc.poiId);

  let reused = false; let sawNextGold = null;
  for (let k = 1; k <= 12; k += 1) {
    const t = t0 + k * DAY;
    setNow(t);
    const today = plush.dayKeyFor(Z.lng, t, Z.lat);
    walk(anna);
    // eslint-disable-next-line no-await-in-loop
    const la = await plush.listActive({ userId: String(anna._id), lat: Z.lat, lng: Z.lng, now: t });
    // eslint-disable-next-line no-await-in-loop
    const todays = await PawPlush.find({ cityKey: city.key, day: today }).lean();
    // VUE : seules les peluches du jour, jamais l'ancienne dorée.
    expect(la.plushies.every((p) => p.day === today)).toBe(true);
    expect(la.plushies.map((p) => p.id)).not.toContain(String(goldDoc._id));
    expect(la.plushies).toHaveLength(todays.length);
    expect(la.plushies.filter((p) => p.golden).length).toBe(plush.isGoldenDay(city.key, today) ? 1 : 0);
    // COMPTEUR hors Balade : le nombre du jour, pas une de plus.
    // eslint-disable-next-line no-await-in-loop
    const lb = await plush.listActive({ userId: String(bob._id), lat: Z.lat, lng: Z.lng, now: t });
    expect(lb.walkActive).toBe(false);
    expect(lb.plushies).toHaveLength(0);
    expect(lb.nearbyCount).toBe(todays.length);
    // L'ancienne dorée est toujours en base (c'est le but) …
    // eslint-disable-next-line no-await-in-loop
    expect(await PawPlush.exists({ _id: goldDoc._id, caughtByPerson: null })).toBeTruthy();
    // … mais ne s'attrape plus : 410 EXPIRED, 0 point (même un autre jour DORÉ).
    // eslint-disable-next-line no-await-in-loop
    const before = await pts(anna);
    // eslint-disable-next-line no-await-in-loop
    const r = await tryCatch(anna, goldDoc, t);
    expect(r).toEqual({ status: 410, code: 'EXPIRED' });
    // eslint-disable-next-line no-await-in-loop
    expect(await pts(anna)).toBe(before);
    // Son lieu n'est pas bloqué : il resservira à une peluche d'un autre jour.
    if (todays.some((x) => String(x.poiId) === goldPoi)) reused = true;
    // Dorée suivante : jamais au lieu de la précédente.
    const g = todays.find((x) => x.golden);
    if (g && !sawNextGold) { sawNextGold = g; expect(String(g.poiId)).not.toBe(goldPoi); }
    // ADMIN au lendemain : tirage du jour = peluches du jour seulement, 0 dorée ; la dorée d'hier listée UNE fois.
    if (k === 1) {
      // eslint-disable-next-line no-await-in-loop
      const res = await request(app).get('/admin/pawpoints-insights');
      expect(res.status).toBe(200);
      const d = res.body.plush.draws.find((x) => x.day === today);
      expect(d).toBeTruthy();
      expect(d.total).toBe(todays.length);
      expect(d.golden).toBe(0);
      expect(d.caught).toBe(0);
      expect(res.body.plush.draws.filter((x) => x.day !== today)).toHaveLength(0);
      const gw = res.body.plush.goldenWeek;
      expect(gw).toHaveLength(1);
      expect(gw[0]).toMatchObject({ day: goldDoc.day, caught: false });
    }
    // ADMIN le jour de la dorée suivante : lastGoldenDay est ENFIN rempli (c'était null en production).
    if (g && String(g._id) === String(sawNextGold._id)) {
      // eslint-disable-next-line no-await-in-loop
      const res = await request(app).get('/admin/pawpoints-insights');
      const d = res.body.plush.draws.find((x) => x.day === today);
      expect(d.golden).toBe(1);
      expect(d.rotation.lastGoldenDay).toBe(goldDoc.day);
      expect(d.rotation.goldenSameAsLast).toBe(false);
    }
  }
  expect(sawNextGold).toBeTruthy();
  expect(reused).toBe(true);
}, 120000);

test('points : 2 dorées la même semaine = 200 + 200, jamais plus de 2 captures par jour, dorée jamais « à deux »', async () => {
  const cara = await makeOwner(); const dan = await makeOwner();
  // Une semaine vierge, loin après le 1er test : ses 2 jours dorés.
  const monday = Date.parse(`${plush.weekOf(plush.dayKeyFor(Z.lng, Date.now() + 28 * DAY, Z.lat))}T15:00:00Z`);
  const golds = [];
  for (let i = 0; i < 7; i += 1) if (plush.isGoldenDay(city.key, plush.dayKeyFor(Z.lng, monday + i * DAY, Z.lat))) golds.push(monday + i * DAY);
  expect(golds).toHaveLength(2);
  let total = 0;
  for (const t of golds) {
    setNow(t);
    walk(cara);
    // eslint-disable-next-line no-await-in-loop
    const la = await plush.listActive({ userId: String(cara._id), lat: Z.lat, lng: Z.lng, now: t });
    const g = la.plushies.filter((p) => p.golden);
    expect(g).toHaveLength(1);
    // eslint-disable-next-line no-await-in-loop
    const r1 = await tryCatch(cara, g[0], t);
    expect(r1.status).toBe(200);
    expect(r1.body.points).toBe(200);
    expect(r1.body.bonuses.map((b) => b.kind)).toEqual(['golden_boost']);
    total += 200;
    // Une autre personne sur la dorée déjà prise : 409, pas de copie, 0 point.
    // eslint-disable-next-line no-await-in-loop
    const r2 = await tryCatch(dan, g[0], t + 60000);
    expect(r2).toEqual({ status: 409, code: 'ALREADY_CAUGHT' });
    // eslint-disable-next-line no-await-in-loop
    expect(await pts(dan)).toBe(0);
    // 2e capture du jour (ordinaire) : +20 ; 3e : refusée.
    const ord = la.plushies.filter((p) => !p.golden);
    // eslint-disable-next-line no-await-in-loop
    const r3 = await tryCatch(cara, ord[0], t + 3600000);
    expect(r3.status).toBe(200);
    expect(r3.body.points).toBe(20);
    total += 20;
    // eslint-disable-next-line no-await-in-loop
    const r4 = await tryCatch(cara, ord[1], t + 7200000);
    expect(r4).toEqual({ status: 429, code: 'DAILY_LIMIT' });
    // eslint-disable-next-line no-await-in-loop
    expect(await pts(cara)).toBe(total);
  }
  expect(total).toBe(440);
  // Les dorées attrapées restent pour toujours (plus de date d'effacement).
  expect(await PawPlush.countDocuments({ caughtByPerson: { $ne: null }, golden: true, expireAt: { $ne: null } })).toBe(0);
}, 120000);
