// 28/11/2026 (BOB, ordre de Daniel « corrige les 2 et rajoute des peluches dorées ») — vraie base en mémoire, vrai tirage.
// 1) DEUX dorées par ville et par semaine, deux jours différents, sur 10 semaines (changement d'année compris).
// 2) Une dorée jamais attrapée reste 13 jours en base (les autres 3 ; 13 = écart maximal de 11 jours entre deux dorées + marge) : le tirage suivant sait où elle était et ne la
//    repose pas au même endroit ; elle ne s'attrape toujours que son jour (le tirage du jour ne montre que le jour).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const plush = require('../src/services/plushService607');

let mongo; let PawPlush; let MapPOI;
beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  PawPlush = require('../src/models/PawPlush');
  MapPOI = require('../src/models/MapPOI');
  await Promise.all([PawPlush.init(), MapPOI.init()]);
  for (let i = 0; i < 14; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    await MapPOI.create({ title: 'Dog park', category: 'park', status: 'active', source: 'seed', osmId: `way/2811${i}`, location: { type: 'Point', coordinates: [-30.40 + i / 400, -35.20 + i / 600] } });
  }
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

test('barème public : 2 dorées par ville et par semaine', () => {
  expect(plush.PLUSH_RULES.golden).toMatchObject({ points: 200, boostHours: 24, perCityPerWeek: 2 });
  expect(plush.GOLDEN_PER_WEEK).toBe(2);
});

test('70 jours de tirages : 2 dorées par semaine complète, 1 seule par jour, lieux différents d\'une dorée à la suivante, gardées 13 jours', async () => {
  const city = { key: 'zone-or-2811', label: 'Zone test', lat: -35.2, lng: -30.4 };
  const start = Date.parse('2026-11-30T12:00:00Z'); // un lundi
  const golds = []; const perWeek = {};
  for (let d = 0; d < 70; d += 1) {
    const now = start + d * 86400000;
    // eslint-disable-next-line no-await-in-loop
    const r = await plush.ensureDraw(city, { now });
    // eslint-disable-next-line no-await-in-loop
    const docs = await PawPlush.find({ cityKey: city.key, day: r.day }).lean();
    expect(docs.length).toBeGreaterThanOrEqual(3);
    const g = docs.filter((x) => x.golden);
    expect(g.length).toBeLessThanOrEqual(1);
    const keep = docs.map((x) => Math.round((new Date(x.expireAt).getTime() - now) / 86400000));
    docs.forEach((x, i) => expect(keep[i]).toBe(x.golden ? 13 : 3));
    if (g.length) { golds.push({ day: r.day, poi: String(g[0].poiId) }); perWeek[plush.weekOf(r.day)] = (perWeek[plush.weekOf(r.day)] || 0) + 1; }
  }
  expect(Object.keys(perWeek)).toHaveLength(10);
  expect(Object.values(perWeek).every((n) => n === 2)).toBe(true);
  for (let i = 1; i < golds.length; i += 1) {
    const gap = (Date.parse(golds[i].day) - Date.parse(golds[i - 1].day)) / 86400000;
    // l'écart entre deux dorées ne dépasse jamais 11 jours : la précédente (gardée 13 jours) est toujours en base
    expect(gap).toBeLessThanOrEqual(11);
    expect(golds[i].poi).not.toBe(golds[i - 1].poi);
  }
}, 120000);
