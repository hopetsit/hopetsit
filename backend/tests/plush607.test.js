// 607 (PAM, 02/10/2026) — mini-peluches de la PawMap : tirage dans les parcs
// OSM des villes actives, visibles seulement en Balade, capture < 30 m,
// anti-triche (vitesse, 1/personne/jour, 1/peluche), +20 PawPoints.
// Vraie base Mongo en mémoire + vraies routes HTTP (supertest + JWT).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mongoose = require('mongoose');
const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

const plush = require('../src/services/plushService607');
const map = require('../src/sockets/mapSocket');

let mongo; let Owner; let Sitter; let MapPOI; let PawPlush; let app;
const PARIS = { lat: 48.8566, lng: 2.3522 };
// 6 parcs à chiens OSM autour du centre (≈ 300 m à 3 km) + 1 « déjection ».
const PARKS = [
  [48.8600, 2.3500], [48.8530, 2.3600], [48.8700, 2.3400],
  [48.8450, 2.3300], [48.8650, 2.3700], [48.8500, 2.3450],
];
const tokenFor = (id, role) => jwt.sign({ id: String(id), role }, process.env.JWT_SECRET);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  MapPOI = require('../src/models/MapPOI');
  PawPlush = require('../src/models/PawPlush');
  await Promise.all([Owner.init(), Sitter.init(), MapPOI.init(), PawPlush.init()]);
  app = express();
  app.use(express.json());
  app.use('/plush', require('../src/routes/plushRoutes'));
  let i = 0;
  for (const [lat, lng] of PARKS) {
    i += 1;
    await MapPOI.create({ title: 'Dog park', category: 'park', status: 'active', source: 'seed', osmId: `way/${i}`, location: { type: 'Point', coordinates: [lng, lat] } });
  }
  await MapPOI.create({ title: 'Espace de Déjection Canin', category: 'park', status: 'active', source: 'seed', osmId: 'node/99', location: { type: 'Point', coordinates: [2.3510, 48.8570] } });
  await MapPOI.create({ title: 'Jardin privé proposé', category: 'park', status: 'pending', source: 'user', location: { type: 'Point', coordinates: [2.3515, 48.8575] } });
  // Lyon : seul un compte +test y a une position → ville NON active.
  await MapPOI.create({ title: 'Dog park', category: 'park', status: 'active', source: 'seed', osmId: 'way/500', location: { type: 'Point', coordinates: [4.8357, 45.7640] } });
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

let n = 0;
async function makeOwner({ email, lat = PARIS.lat, lng = PARIS.lng, city = 'Paris 11e' } = {}) {
  n += 1;
  return Owner.create({
    name: `Propriétaire ${n}`,
    email: email || `vrai${n}@example.org`,
    password: 'MotDePasse607!',
    location: { type: 'Point', coordinates: [lng, lat], city, updatedAt: new Date() },
  });
}
function startWalk(u, lat, lng) {
  map.touchLiveSession({ userId: String(u._id), role: 'owner', lat, lng });
}

describe('outils purs', () => {
  test('ville normalisée : arrondissements et accents', () => {
    expect(plush.normalizeCityKey('Paris 11e')).toBe('paris');
    expect(plush.normalizeCityKey('  PARIS ')).toBe('paris');
    expect(plush.normalizeCityKey('Saint-Étienne')).toBe('saint etienne');
    expect(plush.normalizeCityKey('')).toBe('');
  });
  test('jour local : Dallas est encore la veille quand Paris a changé de jour', () => {
    const t = Date.parse('2026-10-03T03:00:00Z');
    expect(plush.dayKeyFor(2.35, t)).toBe('2026-10-03');
    expect(plush.dayKeyFor(-96.8, t)).toBe('2026-10-02');
  });
  test('tirage : 3 à 5 peluches, parcs distincts, même ville + même jour = même tirage', () => {
    const parks = PARKS.map(([lat, lng], i) => ({ _id: `p${i}`, lat, lng }));
    for (const day of ['2026-10-02', '2026-10-03', '2026-10-04', '2026-10-05']) {
      const a = plush.pickPlushies(parks, 'paris', day);
      expect(a.length).toBeGreaterThanOrEqual(3);
      expect(a.length).toBeLessThanOrEqual(5);
      expect(new Set(a.map((x) => x.park._id)).size).toBe(a.length);
      a.forEach((x) => expect(plush.PLUSH_TYPES).toContain(x.type));
      expect(plush.pickPlushies(parks, 'paris', day)).toEqual(a);
    }
    expect(plush.pickPlushies(parks.slice(0, 2), 'paris', '2026-10-02')).toHaveLength(2);
  });
  test('parcs utilisables : OSM actif seulement, jamais les espaces de déjection', () => {
    const ok = { category: 'park', status: 'active', source: 'seed', osmId: 'way/1', title: 'Dog park', location: { coordinates: [2, 48] } };
    expect(plush.isUsablePark(ok)).toBe(true);
    expect(plush.isUsablePark({ ...ok, source: 'user' })).toBe(false);
    expect(plush.isUsablePark({ ...ok, status: 'pending' })).toBe(false);
    expect(plush.isUsablePark({ ...ok, title: 'Espace de déjection canine' })).toBe(false);
    expect(plush.isUsablePark({ ...ok, category: 'vet' })).toBe(false);
  });
  test('vitesse : à pied oui, en voiture non', () => {
    const a = { lat: 48.8566, lng: 2.3522, t: 0 };
    // 100 m en 60 s = 6 km/h
    expect(plush.speedOk(a, { lat: 48.8575, lng: 2.3522, t: 60000 })).toBe(true);
    // 1 km en 60 s = 60 km/h
    expect(plush.speedOk(a, { lat: 48.8656, lng: 2.3522, t: 60000 })).toBe(false);
    // bruit GPS (< 40 m) jamais jugé
    expect(plush.speedOk(a, { lat: 48.8569, lng: 2.3522, t: 1 })).toBe(true);
  });
});

describe('API réelle', () => {
  let alice; let bob; let tokA; let tokB;
  beforeAll(async () => {
    alice = await makeOwner();
    bob = await makeOwner();
    await makeOwner({ email: 'dadaciao84+testlyon@gmail.com', lat: 45.764, lng: 4.8357, city: 'Lyon' });
    tokA = tokenFor(alice._id, 'owner');
    tokB = tokenFor(bob._id, 'owner');
    plush._resetForTests();
  });

  test('villes actives : Paris oui (vrais comptes), Lyon non (compte +test seul)', async () => {
    const cities = await plush.activeCities({ force: true });
    const keys = cities.map((c) => c.key);
    expect(keys).toContain('paris');
    expect(keys).not.toContain('lyon');
  });

  test('sans Balade en cours : liste vide, capture refusée', async () => {
    const r = await request(app).get(`/plush/active?lat=${PARIS.lat}&lng=${PARIS.lng}`).set('Authorization', `Bearer ${tokA}`);
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ walkActive: false, plushies: [] });
    expect(await PawPlush.countDocuments()).toBe(0); // rien tiré pour un curieux
    const c = await request(app).post(`/plush/${new mongoose.Types.ObjectId()}/catch`).set('Authorization', `Bearer ${tokA}`).send(PARIS);
    expect(c.status).toBe(403);
    expect(c.body.code).toBe('WALK_REQUIRED');
  });

  test('sans jeton : 401', async () => {
    const r = await request(app).get('/plush/active?lat=1&lng=1');
    expect(r.status).toBe(401);
  });

  let first;
  test('en Balade : 3 à 5 peluches, toutes sur un parc OSM, tirage stable', async () => {
    startWalk(alice, PARIS.lat, PARIS.lng);
    const r = await request(app).get(`/plush/active?lat=${PARIS.lat}&lng=${PARIS.lng}`).set('Authorization', `Bearer ${tokA}`);
    expect(r.status).toBe(200);
    expect(r.body.walkActive).toBe(true);
    expect(r.body.catchRadiusM).toBe(30);
    expect(r.body.reward).toBe(20);
    const list = r.body.plushies;
    expect(list.length).toBeGreaterThanOrEqual(3);
    expect(list.length).toBeLessThanOrEqual(5);
    for (const p of list) {
      expect(PARKS.some(([la, ln]) => la === p.lat && ln === p.lng)).toBe(true);
      expect(['teddy', 'bunny', 'kitty', 'puppy', 'fox']).toContain(p.type);
    }
    const again = await request(app).get(`/plush/active?lat=${PARIS.lat}&lng=${PARIS.lng}`).set('Authorization', `Bearer ${tokA}`);
    expect(again.body.plushies.map((p) => p.id).sort()).toEqual(list.map((p) => p.id).sort());
    expect(await PawPlush.countDocuments()).toBe(list.length);
    first = [...list].sort((a, b) => (a.golden ? 1 : 0) - (b.golden ? 1 : 0)); // la dorée (si c'est son jour) en dernier
  });

  test('capture trop loin : 422 TOO_FAR avec la distance', async () => {
    plush._resetForTests();
    const p = first[0];
    startWalk(alice, p.lat + 0.0005, p.lng); // ~55 m
    const c = await request(app).post(`/plush/${p.id}/catch`).set('Authorization', `Bearer ${tokA}`).send({ lat: p.lat + 0.0005, lng: p.lng });
    expect(c.status).toBe(422);
    expect(c.body.code).toBe('TOO_FAR');
    expect(c.body.distanceM).toBeGreaterThan(30);
  });

  test('téléportation (position du direct à 5 km il y a un instant) : 422 TOO_FAST', async () => {
    plush._resetForTests();
    const p = first[0];
    startWalk(alice, p.lat + 0.045, p.lng);
    const c = await request(app).post(`/plush/${p.id}/catch`).set('Authorization', `Bearer ${tokA}`).send({ lat: p.lat, lng: p.lng });
    expect(c.status).toBe(422);
    expect(c.body.code).toBe('TOO_FAST');
  });

  test('capture valide : +20 PawPoints, puis 1 seule par jour, puis peluche déjà prise', async () => {
    plush._resetForTests();
    const p = first[0];
    startWalk(alice, p.lat, p.lng);
    const ok = await request(app).post(`/plush/${p.id}/catch`).set('Authorization', `Bearer ${tokA}`).send({ lat: p.lat + 0.0001, lng: p.lng });
    expect(ok.status).toBe(200);
    expect(ok.body).toMatchObject({ ok: true, points: 20, plush: { id: p.id, type: p.type } });
    const doc = await Owner.findById(alice._id).select('pawPoints pawPointsSpendable').lean();
    expect(doc.pawPoints).toBe(20);
    expect(doc.pawPointsSpendable).toBe(20);
    // 2e peluche le même jour
    const q = first[1];
    startWalk(alice, q.lat, q.lng);
    plush._resetForTests();
    const lim = await request(app).post(`/plush/${q.id}/catch`).set('Authorization', `Bearer ${tokA}`).send({ lat: q.lat, lng: q.lng });
    expect(lim.status).toBe(429);
    expect(lim.body.code).toBe('DAILY_LIMIT');
    // Bob vise la peluche déjà attrapée par Alice
    startWalk(bob, p.lat, p.lng);
    const taken = await request(app).post(`/plush/${p.id}/catch`).set('Authorization', `Bearer ${tokB}`).send({ lat: p.lat, lng: p.lng });
    expect(taken.status).toBe(409);
    expect(taken.body.code).toBe('ALREADY_CAUGHT');
    // … elle n'est plus dans la liste de Bob, et Alice sait qu'elle a déjà joué
    const lb = await request(app).get(`/plush/active?lat=${p.lat}&lng=${p.lng}`).set('Authorization', `Bearer ${tokB}`);
    expect(lb.body.plushies.map((x) => x.id)).not.toContain(p.id);
    const la = await request(app).get(`/plush/active?lat=${p.lat}&lng=${p.lng}`).set('Authorization', `Bearer ${tokA}`);
    expect(la.body.caughtToday).toBe(true);
    expect(lb.body.caughtToday).toBe(false);
  });

  test('deux captures simultanées de la même personne : une seule passe', async () => {
    const carl = await makeOwner();
    const tok = tokenFor(carl._id, 'owner');
    const [a, b] = [first[1], first[2]];
    // même endroit pour les deux (on pose le direct sur la 1re, la 2e est hors portée mais
    // on vérifie l'index : on force via le service directement)
    startWalk(carl, a.lat, a.lng);
    plush._resetForTests();
    const r1 = await request(app).post(`/plush/${a.id}/catch`).set('Authorization', `Bearer ${tok}`).send({ lat: a.lat, lng: a.lng });
    expect(r1.status).toBe(200);
    // l'index unique (jour, personne) refuse une 2e écriture même sans passer par l'API
    const pk = (await PawPlush.findById(a.id).lean()).caughtByPerson;
    await expect(PawPlush.updateOne({ _id: b.id }, { $set: { caughtByPerson: pk } })).rejects.toMatchObject({ code: 11000 });
  });

  test('collection : compteur par type, 3 profils confondus', async () => {
    const r = await request(app).get('/plush/collection').set('Authorization', `Bearer ${tokA}`);
    expect(r.status).toBe(200);
    expect(r.body.total).toBe(1);
    expect(r.body.counts[first[0].type]).toBe(1);
    expect(Object.keys(r.body.counts).sort()).toEqual(['bunny', 'fox', 'kitty', 'puppy', 'teddy']);
    expect(r.body.items[0]).toMatchObject({ id: first[0].id, type: first[0].type });
    const rb = await request(app).get('/plush/collection').set('Authorization', `Bearer ${tokB}`);
    expect(rb.body.total).toBe(0);
  });

  test('une peluche d\'hier ne s\'attrape plus : 410 EXPIRED', async () => {
    const old = await PawPlush.create({ cityKey: 'paris', day: '2020-01-01', slot: 0, type: 'fox', location: { type: 'Point', coordinates: [PARIS.lng, PARIS.lat] } });
    const dan = await makeOwner();
    startWalk(dan, PARIS.lat, PARIS.lng);
    plush._resetForTests();
    const r = await request(app).post(`/plush/${old._id}/catch`).set('Authorization', `Bearer ${tokenFor(dan._id, 'owner')}`).send(PARIS);
    expect(r.status).toBe(410);
    expect(r.body.code).toBe('EXPIRED');
  });

  test('réglage de la carte : la clé plush est gardée', () => {
    const { normalizeMapPrefs } = require('../src/controllers/mapPrefsController');
    expect(normalizeMapPrefs({}, { layers: { plush: false } }).layers).toEqual({ plush: false });
  });

  // ── barème du 02/10 : dorée, collection complète, série de 7 jours ──
  const fx = (pt, k) => ({ type: 'Point', coordinates: [pt.lng + k * 0.0001, pt.lat] });
  test('peluche dorée : +200 et 24 h de PawBoost offert', async () => {
    const eve = await makeOwner();
    const today = plush.dayKeyFor(PARIS.lng);
    const g = await PawPlush.create({ cityKey: 'goldtest', day: today, slot: 0, type: 'fox', golden: true, location: fx(PARIS, 0) });
    startWalk(eve, PARIS.lat, PARIS.lng);
    plush._resetForTests();
    const before = Date.now();
    const r = await request(app).post(`/plush/${g._id}/catch`).set('Authorization', `Bearer ${tokenFor(eve._id, 'owner')}`).send(PARIS);
    expect(r.status).toBe(200);
    expect(r.body.plush.golden).toBe(true);
    expect(r.body.points).toBe(200);
    const doc = await Owner.findById(eve._id).select('boostExpiry pawPoints').lean();
    expect(doc.pawPoints).toBe(200);
    const h = (new Date(doc.boostExpiry).getTime() - before) / 3600000;
    expect(h).toBeGreaterThan(23.9);
    expect(h).toBeLessThan(24.1);
  });

  test('collection complète (5 types) : +500 une seule fois + badge Collectionneur', async () => {
    const fay = await makeOwner();
    const tok = tokenFor(fay._id, 'owner');
    const pk = String(fay._id);
    const types = ['teddy', 'bunny', 'kitty', 'puppy'];
    for (let i = 0; i < 4; i += 1) {
      await PawPlush.create({ cityKey: 'coltest', day: `2026-01-0${i + 1}`, slot: 0, type: types[i], caughtByPerson: pk, caughtBy: { userId: pk, at: new Date() }, location: fx(PARIS, i) });
    }
    const today = plush.dayKeyFor(PARIS.lng);
    const last = await PawPlush.create({ cityKey: 'coltest', day: today, slot: 1, type: 'fox', location: fx(PARIS, 9) });
    startWalk(fay, PARIS.lat, PARIS.lng + 0.0009);
    plush._resetForTests();
    const r = await request(app).post(`/plush/${last._id}/catch`).set('Authorization', `Bearer ${tok}`).send({ lat: PARIS.lat, lng: PARIS.lng + 0.0009 });
    expect(r.status).toBe(200);
    expect(r.body.points).toBe(520);
    expect(r.body.bonuses).toEqual(expect.arrayContaining([expect.objectContaining({ kind: 'collector', points: 500, badge: 'collector' })]));
    expect((await Owner.findById(fay._id).select('pawPoints').lean()).pawPoints).toBe(520);
    const c = await request(app).get('/plush/collection').set('Authorization', `Bearer ${tok}`);
    expect(c.body.badges).toEqual(['collector']);
    const b = await request(app).get(`/plush/badges/${fay._id}`).set('Authorization', `Bearer ${tokA}`);
    expect(b.body).toEqual({ collector: true });
    // jamais deux fois : le bonus déjà accordé est refusé par l'index
    const { PawPlushBonus } = require('../src/models/PawPlush');
    expect(await PawPlushBonus.countDocuments({ personKey: pk, kind: 'collector' })).toBe(1);
  });

  test('7 jours de suite avec une capture : +200', async () => {
    const gus = await makeOwner();
    const tok = tokenFor(gus._id, 'owner');
    const pk = String(gus._id);
    const today = plush.dayKeyFor(PARIS.lng);
    let d = today;
    for (let i = 0; i < 6; i += 1) {
      d = new Date(Date.parse(`${d}T00:00:00Z`) - 86400000).toISOString().slice(0, 10);
      await PawPlush.create({ cityKey: 'streaktest', day: d, slot: 0, type: 'teddy', caughtByPerson: pk, caughtBy: { userId: pk, at: new Date() }, location: fx(PARIS, i) });
    }
    const p = await PawPlush.create({ cityKey: 'streaktest', day: today, slot: 0, type: 'teddy', location: fx(PARIS, 20) });
    startWalk(gus, PARIS.lat, PARIS.lng + 0.002);
    plush._resetForTests();
    const r = await request(app).post(`/plush/${p._id}/catch`).set('Authorization', `Bearer ${tok}`).send({ lat: PARIS.lat, lng: PARIS.lng + 0.002 });
    expect(r.status).toBe(200);
    expect(r.body.streak).toBe(7);
    expect(r.body.points).toBe(220);
    expect(r.body.bonuses).toEqual([expect.objectContaining({ kind: 'streak7', points: 200, days: 7 })]);
  });

  test('dorée : exactement 1 jour par semaine et par ville', () => {
    for (const city of ['paris', 'dallas', 'lyon']) {
      let n = 0;
      for (let i = 0; i < 7; i += 1) {
        const day = new Date(Date.parse('2026-10-05T00:00:00Z') + i * 86400000).toISOString().slice(0, 10);
        if (plush.isGoldenDay(city, day)) n += 1;
      }
      expect(n).toBe(1);
    }
  });

  test('barème public', async () => {
    const r = await request(app).get('/plush/rules');
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ perPlush: 20, golden: { points: 200, boostHours: 24 }, collector: { points: 500 }, streak: { days: 7, points: 200 } });
  });
});
