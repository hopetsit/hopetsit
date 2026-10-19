// 618 (ZOE, 19/10/2026) — COLLECTION DU MOIS (décision de Daniel du 19/10,
// PROCHAIN_BUILD_618.md §C) : chaque mois civil (heure de Paris), les 5 types
// attrapés PENDANT le mois = +500 une fois par mois (kind 'collector_month',
// key 'YYYY-MM'). Départ le 01/11/2026 ; octobre = collection d'origine
// (bonus 'collector' inchangé), aucun bonus rétroactif.
// Vraie base en mémoire, vrai service de capture. Zone fictive (-35 / -30).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mongoose = require('mongoose');
const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

const plush = require('../src/services/plushService607');
const map = require('../src/sockets/mapSocket');

let mongo; let Owner; let PawPlush; let PawPlushBonus; let app;
const P = { lat: -35.21, lng: -30.41 };
const TYPES = ['teddy', 'bunny', 'kitty', 'puppy', 'fox'];
const tok = (u) => `Bearer ${jwt.sign({ id: String(u._id), role: 'owner' }, process.env.JWT_SECRET)}`;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  PawPlush = require('../src/models/PawPlush');
  ({ PawPlushBonus } = require('../src/models/PawPlush'));
  await Promise.all([Owner.init(), PawPlush.init(), PawPlushBonus.init()]);
  app = express();
  app.use(express.json());
  app.use('/plush', require('../src/routes/plushRoutes'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

let n = 0;
async function person() {
  n += 1;
  return Owner.create({ name: `Mois${n} Test`, email: `mois618_${n}@example.org`, password: 'MotDePasse618!',
    location: { type: 'Point', coordinates: [P.lng, P.lat], city: 'Zonefictive618', updatedAt: new Date() } });
}

let k = 0;
/** Pose une peluche du jour (à l'instant `now`) puis l'attrape. */
async function catchAt(u, type, now) {
  k += 1;
  const doc = await PawPlush.create({
    cityKey: `z:618:${k}`, cityLabel: 'Zone 618', day: plush.dayKeyFor(P.lng, now, P.lat), slot: 0, type,
    location: { type: 'Point', coordinates: [P.lng, P.lat] },
  });
  plush._resetForTests();
  const s = map.touchLiveSession({ userId: String(u._id), role: 'owner', lat: P.lat, lng: P.lng });
  s.lastSeenAt = now; s.at = now;
  return plush.catchPlush({ userId: String(u._id), role: 'owner', plushId: String(doc._id), lat: P.lat, lng: P.lng, now });
}
// Deux captures par jour au maximum : on étale sur plusieurs jours.
const at = (iso) => Date.parse(iso);

test('barème public : monthly { points: 500, startsOn: 2026-11-01 }, collector inchangé', async () => {
  const r = await request(app).get('/plush/rules');
  expect(r.status).toBe(200);
  expect(r.body.monthly).toEqual(expect.objectContaining({ points: 500, startsOn: '2026-11-01', timeZone: 'Europe/Paris' }));
  expect(r.body.monthly.themes).toHaveLength(12);
  for (const t of r.body.monthly.themes) {
    expect(Object.keys(t.labels).sort()).toEqual(['de', 'en', 'es', 'fr', 'it', 'ja', 'ko', 'pl', 'pt']);
  }
  expect(r.body.monthly.themes.find((t) => t.month === 11).theme).toBe('autumn');
  expect(r.body.monthly.themes.find((t) => t.month === 12).theme).toBe('winter');
  expect(r.body.collector).toEqual({ points: 500, badge: 'collector', types: 5 });
});

test('bornes du mois à l\'heure de Paris (hiver/été)', () => {
  expect(plush.monthBounds('2026-11')).toEqual({
    startsAt: new Date('2026-10-31T23:00:00.000Z'), endsAt: new Date('2026-11-30T23:00:00.000Z'),
  });
  expect(plush.monthBounds('2027-04').startsAt.toISOString()).toBe('2027-03-31T22:00:00.000Z');
  expect(plush.monthlyStarted(at('2026-10-31T22:59:59Z'))).toBe(false);
  expect(plush.monthlyStarted(at('2026-10-31T23:00:00Z'))).toBe(true);
  expect(plush.themeAt(at('2026-10-31T22:00:00Z'))).toBeNull();
  expect(plush.themeAt(at('2026-10-31T23:30:00Z'))).toBe('autumn');
});

let october;
test('AVANT le 01/11 : octobre complet = bonus d\'origine seul, aucun collector_month, thème null', async () => {
  october = await person();
  const days = ['2026-10-20T10:00:00Z', '2026-10-20T11:00:00Z', '2026-10-21T10:00:00Z', '2026-10-21T11:00:00Z', '2026-10-22T10:00:00Z'];
  let last;
  for (let i = 0; i < 5; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    last = await catchAt(october, TYPES[i], at(days[i]));
    expect(last.plush.theme).toBeNull();
  }
  expect(last.bonuses.map((b) => b.kind)).toEqual(['collector']);
  expect(await PawPlushBonus.countDocuments({ personKey: String(october._id), kind: 'collector_month' })).toBe(0);
  const col = await plush.collection({ userId: String(october._id), now: at('2026-10-22T12:00:00Z') });
  expect(col.monthly).toEqual(expect.objectContaining({
    key: '2026-11', theme: 'autumn', label: 'Automne', color: '#C2571A', caughtTypes: [], complete: false,
    bonusPoints: 500, startsAt: '2026-10-31T23:00:00.000Z', endsAt: '2026-11-30T23:00:00.000Z', started: false, bonusGranted: false,
  }));
  expect(new Date(col.monthly.startsAt).getTime()).toBeGreaterThan(at('2026-10-22T12:00:00Z'));
  expect(col.badges).toEqual(['collector']);
  expect(col.monthlyBadges).toEqual([]);
  expect(col.items.every((x) => x.theme === null && x.month === '2026-10')).toBe(true);
});

test('APRÈS le 01/11 : les captures d\'octobre ne comptent pas pour novembre', async () => {
  const r = await catchAt(october, 'fox', at('2026-11-02T10:00:00Z'));
  expect(r.plush.theme).toBe('autumn');
  expect(r.bonuses).toEqual([]);
  const col = await plush.collection({ userId: String(october._id), now: at('2026-11-02T12:00:00Z'), lang: 'en' });
  expect(col.monthly.caughtTypes).toEqual(['fox']);
  expect(col.monthly.complete).toBe(false);
  expect(col.monthly.started).toBe(true);
  expect(col.monthly.label).toBe('Autumn');
});

let nov;
test('novembre complet : +500 collector_month une fois, thème autumn, badge du mois', async () => {
  nov = await person();
  // 00:30 à Paris le 01/11 (encore le 31/10 en UTC) : compte pour NOVEMBRE
  const days = ['2026-10-31T23:30:00Z', '2026-11-01T09:00:00Z', '2026-11-03T10:00:00Z', '2026-11-03T11:00:00Z', '2026-11-05T10:00:00Z'];
  let last;
  for (let i = 0; i < 5; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    last = await catchAt(nov, TYPES[i], at(days[i]));
    expect(last.plush.theme).toBe('autumn');
  }
  const monthB = last.bonuses.find((b) => b.kind === 'collector_month');
  expect(monthB).toEqual({ kind: 'collector_month', key: '2026-11', points: 500, theme: 'autumn', badge: 'collection_2026-11' });
  // le bonus d'origine (une seule fois dans la vie) est toujours là, à part
  expect(last.bonuses.find((b) => b.kind === 'collector')).toEqual(expect.objectContaining({ points: 500 }));
  const pts = (await Owner.findById(nov._id).select('pawPoints').lean()).pawPoints;
  expect(pts).toBe(5 * 20 + 500 + 500);
  const r = await request(app).get('/plush/collection?lang=fr').set('Authorization', tok(nov));
  expect(r.status).toBe(200);
  // la route utilise l'heure réelle : on vérifie la forme ; le contenu daté est vérifié par le service
  expect(r.body.monthly).toEqual(expect.objectContaining({ bonusPoints: 500, theme: expect.any(String), label: expect.any(String) }));
  const col = await plush.collection({ userId: String(nov._id), now: at('2026-11-06T12:00:00Z') });
  expect(col.monthly).toEqual(expect.objectContaining({ key: '2026-11', complete: true, bonusGranted: true }));
  expect(col.monthly.caughtTypes).toEqual(TYPES);
  expect(col.monthlyBadges).toEqual([{ key: '2026-11', theme: 'autumn', color: '#C2571A', badge: 'collection_2026-11', badgeLabel: 'Collection novembre 2026' }]);
  expect(col.items.every((x) => x.month === '2026-11' && x.theme === 'autumn')).toBe(true);
});

test('pas de double bonus dans le même mois', async () => {
  const r1 = await catchAt(nov, 'teddy', at('2026-11-10T10:00:00Z'));
  const r2 = await catchAt(nov, 'fox', at('2026-11-10T11:00:00Z'));
  expect([...r1.bonuses, ...r2.bonuses].filter((b) => b.kind === 'collector_month')).toEqual([]);
  expect(await PawPlushBonus.countDocuments({ kind: 'collector_month', key: '2026-11' })).toBe(1);
  const pts = (await Owner.findById(nov._id).select('pawPoints').lean()).pawPoints;
  expect(pts).toBe(7 * 20 + 500 + 500);
});

test('décembre : nouvelle collection (winter), nouveau bonus possible', async () => {
  const days = ['2026-12-01T10:00:00Z', '2026-12-01T11:00:00Z', '2026-12-02T10:00:00Z', '2026-12-02T11:00:00Z', '2026-12-03T10:00:00Z'];
  let last;
  for (let i = 0; i < 5; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    last = await catchAt(nov, TYPES[i], at(days[i]));
    expect(last.plush.theme).toBe('winter');
  }
  expect(last.bonuses.filter((b) => b.kind === 'collector_month')).toEqual([
    { kind: 'collector_month', key: '2026-12', points: 500, theme: 'winter', badge: 'collection_2026-12' },
  ]);
  // le bonus 'collector' d'origine ne revient jamais
  expect(last.bonuses.find((b) => b.kind === 'collector')).toBeUndefined();
  const col = await plush.collection({ userId: String(nov._id), now: at('2026-12-04T10:00:00Z'), lang: 'de' });
  expect(col.monthly).toEqual(expect.objectContaining({ key: '2026-12', theme: 'winter', label: 'Winter', complete: true }));
  expect(col.monthlyBadges.map((b) => b.key)).toEqual(['2026-12', '2026-11']);
  expect(col.monthlyBadges[0].badgeLabel).toBe('Sammlung Dezember 2026');
});

test('course : deux validations simultanées du même mois → un seul bonus', async () => {
  const someone = await person();
  const key = String(someone._id);
  const results = await Promise.all([
    PawPlushBonus.create({ personKey: key, kind: 'collector_month', key: '2027-01', points: 500 }).then(() => 1, () => 0),
    PawPlushBonus.create({ personKey: key, kind: 'collector_month', key: '2027-01', points: 500 }).then(() => 1, () => 0),
  ]);
  expect(results.reduce((a, b) => a + b, 0)).toBe(1);
});

test('libellés du mois dans les 9 langues', () => {
  const info = plush.monthInfo('2026-11', 'ja');
  expect(info.label).toBe('秋');
  expect(Object.keys(info.labels).sort()).toEqual(['de', 'en', 'es', 'fr', 'it', 'ja', 'ko', 'pl', 'pt']);
  expect(Object.keys(info.badgeLabels)).toHaveLength(9);
  expect(plush.monthInfo('2026-11', 'xx').label).toBe('Automne'); // langue inconnue → fr
});
