// 611 (PAM, 04/10/2026) — Daniel + vocal de Cam : « tu peux en attraper
// qu'une, c'est con… au moins deux par jour ». Règle : 2 captures par
// personne et par jour, +20 chacune ; dorée inchangée ; anti-triche gardé
// (vitesse, précision, une même peluche une fois par personne).
// Vraie base en mémoire, vraies routes.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mongoose = require('mongoose');
const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

const plush = require('../src/services/plushService607');
const map = require('../src/sockets/mapSocket');

let mongo; let Owner; let MapPOI; let PawPlush; let app;
const C = { lat: 43.3, lng: 5.4 };
const PARKS = [[43.301, 5.401], [43.299, 5.402], [43.302, 5.398], [43.298, 5.399], [43.3005, 5.4035]];
const tok = (u) => `Bearer ${jwt.sign({ id: String(u._id), role: 'owner' }, process.env.JWT_SECRET)}`;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  MapPOI = require('../src/models/MapPOI');
  PawPlush = require('../src/models/PawPlush');
  await Promise.all([Owner.init(), MapPOI.init()]);
  // index de l'ancienne règle (1 par jour), comme en prod : la migration doit le retirer
  await PawPlush.collection.createIndex({ day: 1, caughtByPerson: 1 }, {
    unique: true, name: 'day_person_unique_607b',
    partialFilterExpression: { caughtByPerson: { $type: 'string' }, testCopy: false },
  });
  plush._resetIndexFixForTests();
  app = express();
  app.use(express.json());
  app.use('/plush', require('../src/routes/plushRoutes'));
  let i = 0;
  for (const [lat, lng] of PARKS) {
    i += 1;
    await MapPOI.create({ title: 'Dog park', category: 'park', status: 'active', source: 'seed', osmId: `way/72${i}`, location: { type: 'Point', coordinates: [lng, lat] } });
  }
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

let n = 0;
async function person() {
  n += 1;
  return Owner.create({ name: `Deux ${n}`, email: `deux611_${n}@example.org`, password: 'MotDePasse611!',
    location: { type: 'Point', coordinates: [C.lng, C.lat], city: 'Marseille', updatedAt: new Date() } });
}
const walk = (u, p) => map.touchLiveSession({ userId: String(u._id), role: 'owner', lat: p.lat, lng: p.lng });
const list = (u, at = C) => request(app).get(`/plush/active?lat=${at.lat}&lng=${at.lng}`).set('Authorization', tok(u));
const grab = (u, p) => request(app).post(`/plush/${p.id}/catch`).set('Authorization', tok(u)).send({ lat: p.lat, lng: p.lng });

let plushies;
test('barème public : 2 par jour', async () => {
  const r = await request(app).get('/plush/rules');
  expect(r.body.perDay).toBe(2);
  const cat = require('../src/services/pawPointsCatalog607');
  const rule = cat.EARN_RULES.find((x) => x.key === 'plushCaught');
  expect(rule.limit).toBe('daily2');
});

test('2 captures le même jour (+20 chacune), la 3e : DAILY_LIMIT ; liste vide après la 2e', async () => {
  const a = await person();
  walk(a, C);
  plushies = (await list(a)).body.plushies.filter((p) => !p.golden);
  expect(plushies.length).toBeGreaterThanOrEqual(3);
  const [p1, p2, p3] = plushies;
  plush._resetForTests(); walk(a, p1);
  const r1 = await grab(a, p1);
  expect(r1.status).toBe(200);
  expect(r1.body.points).toBe(20);
  // après la 1re : on voit encore des peluches (pas celle prise)
  const mid = await list(a, p1);
  expect(mid.body.caughtToday).toBe(false);
  expect(mid.body.caughtTodayCount).toBe(1);
  expect(mid.body.dailyMax).toBe(2);
  expect(mid.body.plushies.map((x) => x.id)).not.toContain(p1.id);
  expect(mid.body.plushies.length).toBeGreaterThan(0);
  // la même peluche une 2e fois : 613 — on lui RAPPELLE sa capture (réponse
  // perdue), sans recréditer : 200 already, mêmes points, total inchangé.
  const again = await grab(a, p1);
  expect(again.status).toBe(200);
  expect(again.body).toMatchObject({ ok: true, already: true, points: 20 });
  expect((await Owner.findById(a._id).select('pawPoints').lean()).pawPoints).toBe(20);
  plush._resetForTests(); walk(a, p2);
  const r2 = await grab(a, p2);
  expect(r2.status).toBe(200);
  expect(r2.body.points).toBe(20);
  const doc = await Owner.findById(a._id).select('pawPoints').lean();
  expect(doc.pawPoints).toBe(40);
  plush._resetForTests(); walk(a, p3);
  const r3 = await grab(a, p3);
  expect(r3.status).toBe(429);
  expect(r3.body.code).toBe('DAILY_LIMIT');
  const end = await list(a, p3);
  expect(end.body.caughtToday).toBe(true);
  expect(end.body.caughtTodayCount).toBe(2);
  expect(end.body.plushies).toEqual([]);
});

test('course au même endroit : 3 demandes simultanées sur 3 peluches posées au même point → exactement 2', async () => {
  const day = plush.dayKeyFor(C.lng, Date.now(), C.lat);
  const docs = await PawPlush.insertMany([0, 1, 2].map((k) => ({ cityKey: 'race611', cityLabel: 'Course', day, slot: k, type: 'fox', location: { type: 'Point', coordinates: [C.lng, C.lat] } })));
  const c = await person();
  plush._resetForTests(); walk(c, C);
  const rs = await Promise.all(docs.map((d) => request(app).post(`/plush/${d._id}/catch`)
    .set('Authorization', tok(c)).send({ lat: C.lat, lng: C.lng })));
  expect(rs.filter((r) => r.status === 200)).toHaveLength(2);
  expect(rs.filter((r) => r.status === 429).map((r) => r.body.code)).toEqual(['DAILY_LIMIT']);
});

test('migration : l\'index « 1 par jour » est retiré, une capture d\'avant compte pour 1', async () => {
  const idx = await PawPlush.collection.indexes();
  expect(idx.some((i) => i.name === 'day_person_unique_607b')).toBe(false);
  expect(idx.some((i) => i.name === 'day_person_slot_611')).toBe(true);
  const d = await person();
  const pk = require('../src/utils/followers589').personKey([String(d._id)]);
  const day = plush.dayKeyFor(C.lng, Date.now(), C.lat);
  // capture « ancienne » (sans rang de capture), comme les captures déjà en base
  await PawPlush.collection.insertOne({ cityKey: 'old611', day, slot: 0, type: 'bunny', golden: false, testCopy: false, copyOf: null,
    caughtByPerson: pk, caughtBy: { userId: String(d._id), role: 'owner', at: new Date() }, location: { type: 'Point', coordinates: [C.lng, C.lat] } });
  const [p1, p2] = (await PawPlush.insertMany([0, 1].map((k) => ({ cityKey: 'old611b', day, slot: k, type: 'kitty', location: { type: 'Point', coordinates: [C.lng, C.lat] } }))));
  plush._resetForTests(); walk(d, C);
  expect((await request(app).post(`/plush/${p1._id}/catch`).set('Authorization', tok(d)).send(C)).status).toBe(200);
  plush._resetForTests();
  const third = await request(app).post(`/plush/${p2._id}/catch`).set('Authorization', tok(d)).send(C);
  expect(third.status).toBe(429);
});
