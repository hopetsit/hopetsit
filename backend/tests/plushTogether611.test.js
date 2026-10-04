// 611 (PAM, 04/10/2026) — vidéo de Daniel et Cam à Alhama (18 h 09) : « on est
// dessus, c'est une blague… ça bugue… elle bouge… on est grave loin ».
// Mesuré en prod (admin, lecture) : 2 peluches tirées à Alhama ce jour-là, UNE
// seule capture (17 h 34, profil « Cam Chetmou »). Deux personnes qui marchent
// ENSEMBLE : la 1re attrape, la 2e reçoit 409 ALREADY_CAUGHT — l'app 610 retire
// la peluche SANS RIEN DIRE et la pastille saute sur la peluche suivante, loin.
// Règles 611 rejouées ici (vraie base en mémoire, vraies routes) :
//   1. une peluche ORDINAIRE s'attrape une fois PAR PERSONNE (balade à deux :
//      chacun la sienne), toujours 1 capture par personne et par jour ;
//   2. la peluche DORÉE reste à la première personne ;
//   3. une fois la peluche du jour attrapée, la Balade ne montre plus de
//      peluches impossibles à prendre (plus d'appât) ;
//   4. tolérance GPS : l'app 611 envoie la précision ; à 3 m réels le GPS peut
//      dire 38 m : accepté si la précision le couvre (20 m au plus) ;
//   5. une peluche ne bouge pas d'une demande à l'autre pendant la Balade.
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
const ALHAMA = { lat: 37.8516, lng: -1.4249 };
const PARKS = [[37.8530, -1.4230], [37.8490, -1.4270], [37.8560, -1.4200], [37.8470, -1.4300]];
const tokenFor = (id, role) => jwt.sign({ id: String(id), role }, process.env.JWT_SECRET);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  MapPOI = require('../src/models/MapPOI');
  PawPlush = require('../src/models/PawPlush');
  await Promise.all([Owner.init(), MapPOI.init(), PawPlush.init()]);
  app = express();
  app.use(express.json());
  app.use('/plush', require('../src/routes/plushRoutes'));
  let i = 0;
  for (const [lat, lng] of PARKS) {
    i += 1;
    await MapPOI.create({ title: 'Dog park', category: 'park', status: 'active', source: 'seed', osmId: `way/61${i}`, location: { type: 'Point', coordinates: [lng, lat] } });
  }
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

let n = 0;
async function person(name) {
  n += 1;
  return Owner.create({
    name, email: `ensemble611_${n}@example.org`, password: 'MotDePasse611!',
    location: { type: 'Point', coordinates: [ALHAMA.lng, ALHAMA.lat], city: 'Alhama de Murcia', updatedAt: new Date() },
  });
}
const walk = (u, lat, lng) => map.touchLiveSession({ userId: String(u._id), role: 'owner', lat, lng });
const list = (u, at = ALHAMA) => request(app).get(`/plush/active?lat=${at.lat}&lng=${at.lng}`).set('Authorization', `Bearer ${tokenFor(u._id, 'owner')}`);
const grab = (u, p, body) => request(app).post(`/plush/${p.id}/catch`).set('Authorization', `Bearer ${tokenFor(u._id, 'owner')}`).send(body);

let cam; let daniel; let plushies;
beforeAll(async () => {
  cam = await person('Cam Promeneuse');
  daniel = await person('Daniel Promeneur');
  walk(cam, ALHAMA.lat, ALHAMA.lng);
  walk(daniel, ALHAMA.lat, ALHAMA.lng);
  const r = await list(cam);
  plushies = r.body.plushies;
});

test('5. une peluche ne bouge pas : mêmes ids, mêmes coordonnées à chaque demande', async () => {
  expect(plushies.length).toBeGreaterThanOrEqual(3);
  for (let k = 0; k < 3; k += 1) {
    const again = await list(daniel);
    const a = again.body.plushies.map((p) => `${p.id}@${p.lat},${p.lng}`).sort();
    expect(a).toEqual(plushies.map((p) => `${p.id}@${p.lat},${p.lng}`).sort());
  }
});

test('1. balade à deux : Cam l\'attrape, Daniel attrape LA MÊME juste après (chacun la sienne)', async () => {
  const p = plushies.find((x) => !x.golden);
  plush._resetForTests();
  walk(cam, p.lat, p.lng);
  const a = await grab(cam, p, { lat: p.lat, lng: p.lng });
  expect(a.status).toBe(200);
  // Daniel voit toujours la peluche (il ne l'a pas encore)
  walk(daniel, p.lat, p.lng);
  const seen = await list(daniel, p);
  expect(seen.body.plushies.map((x) => x.id)).toContain(p.id);
  const b = await grab(daniel, p, { lat: p.lat + 0.00003, lng: p.lng }); // 3 m
  expect(b.status).toBe(200);
  expect(b.body).toMatchObject({ ok: true, points: 20, plush: { type: p.type } });
  // chacun l'a dans SA collection
  for (const u of [cam, daniel]) {
    const c = await request(app).get('/plush/collection').set('Authorization', `Bearer ${tokenFor(u._id, 'owner')}`);
    expect(c.body.counts[p.type]).toBeGreaterThanOrEqual(1);
  }
  // 611 — 2 par personne et par jour, la 3e refusée
  const others = plushies.filter((x) => x.id !== p.id && !x.golden);
  const q = others[0];
  walk(daniel, q.lat, q.lng);
  plush._resetForTests();
  expect((await grab(daniel, q, { lat: q.lat, lng: q.lng })).status).toBe(200);
  const r3 = others[1];
  walk(daniel, r3.lat, r3.lng);
  plush._resetForTests();
  const lim = await grab(daniel, r3, { lat: r3.lat, lng: r3.lng });
  expect(lim.status).toBe(429);
  expect(lim.body.code).toBe('DAILY_LIMIT');
  // la même peluche une 2e fois : refusée
  walk(cam, p.lat, p.lng);
  const twice = await grab(cam, p, { lat: p.lat, lng: p.lng });
  expect([409, 429]).toContain(twice.status);
});

test('3. peluches du jour prises (2/2) : la Balade ne montre plus de peluches impossibles à attraper', async () => {
  walk(daniel, ALHAMA.lat, ALHAMA.lng);
  const r = await list(daniel);
  expect(r.body.walkActive).toBe(true);
  expect(r.body.caughtToday).toBe(true);
  expect(r.body.plushies).toEqual([]);
});

test('2. la peluche DORÉE reste à la première personne', async () => {
  const eve = await person('Eve');
  const fred = await person('Fred');
  const base = await PawPlush.findById(plushies[0].id).lean();
  const gd = await PawPlush.create({ cityKey: 'gold611', cityLabel: 'Alhama', day: base.day, slot: 0, type: 'fox', golden: true,
    location: { type: 'Point', coordinates: [ALHAMA.lng + 0.001, ALHAMA.lat] } });
  const g = { id: String(gd._id), lat: ALHAMA.lat, lng: ALHAMA.lng + 0.001 };
  plush._resetForTests();
  walk(eve, g.lat, g.lng);
  expect((await grab(eve, g, { lat: g.lat, lng: g.lng })).status).toBe(200);
  walk(fred, g.lat, g.lng);
  const f = await grab(fred, g, { lat: g.lat, lng: g.lng });
  expect(f.status).toBe(409);
  expect(f.body.code).toBe('ALREADY_CAUGHT');
  const seen = await list(fred, g);
  expect(seen.body.plushies.map((x) => x.id)).not.toContain(g.id);
});

test('4. tolérance de précision GPS (20 m au plus), jamais sans précision', async () => {
  const p = plushies.find((x) => !x.golden);
  const far = { lat: p.lat + 0.00034, lng: p.lng }; // ≈ 38 m
  const g1 = await person('Gina');
  plush._resetForTests();
  walk(g1, far.lat, far.lng);
  const noAcc = await grab(g1, p, far);
  expect(noAcc.status).toBe(422);
  expect(noAcc.body.code).toBe('TOO_FAR');
  plush._resetForTests();
  const huge = await grab(g1, p, { ...far, accuracy: 500 }); // plafonnée à 20 m
  expect(huge.status).toBe(200); // 38 ≤ 30 + 20
  const g2 = await person('Hugo');
  plush._resetForTests();
  const far2 = { lat: p.lat + 0.00055, lng: p.lng }; // ≈ 61 m
  walk(g2, far2.lat, far2.lng);
  const tooFar = await grab(g2, p, { ...far2, accuracy: 500 });
  expect(tooFar.status).toBe(422);
  expect(tooFar.body.code).toBe('TOO_FAR');
  expect(tooFar.body.distanceM).toBeGreaterThan(50);
});
