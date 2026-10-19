// 618 (ZOE, 19/10/2026) — PINS (décision de Daniel du 19/10) :
//   · podium OR/ARGENT/BRONZE = top 3 du classement général (une personne =
//     une ligne, ni staff ni test), même règle que /pawspots/leaderboard ;
//   · « 1er Chef de meute » = premier passage des 3 000 points, UNE fois,
//     jamais staff/test, index unique.
// Contrat : ~/hopetsit-social/PROCHAIN_BUILD_618.md §B.
// Vraie base en mémoire, vraies routes. Zone fictive (-35 / -30).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mongoose = require('mongoose');
const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let Walker; let PawFirstPackLeader; let pins; let pp; let app;
const tok = (u, role = 'owner') => `Bearer ${jwt.sign({ id: String(u._id), role }, process.env.JWT_SECRET)}`;
const LAT = -35.2; const LNG = -30.4;
const loc = (dx = 0) => ({ type: 'Point', coordinates: [LNG + dx, LAT], city: 'Zonefictive618', updatedAt: new Date() });

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  PawFirstPackLeader = require('../src/models/PawFirstPackLeader');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), PawFirstPackLeader.init()]);
  pins = require('../src/services/pins618');
  pp = require('../src/services/pawPointsService');
  app = express();
  app.use(express.json());
  app.use('/pawpoints', require('../src/routes/pawPointsRoutes'));
  app.use('/pawspots', require('../src/routes/pawSpotRoutes'));
  app.use('/friends', require('../src/routes/friendRoutes'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

let n = 0;
const base = (over = {}) => {
  n += 1;
  return { name: `Membre${n} Test`, email: `pin618_${n}@example.org`, password: 'MotDePasse618!', location: loc(n * 0.001), ...over };
};

describe('podium (classement général)', () => {
  let gold; let goldSitter; let silver; let bronze; let fourth; let staff; let tester;
  beforeAll(async () => {
    await Promise.all([Owner, Sitter, Walker].map((M) => M.deleteMany({})));
    pins._resetForTests();
    gold = await Owner.create(base({ name: 'Alice Or', email: 'alice618@example.org', pawPoints: 900 }));
    // même personne, profil gardien : ne doit PAS prendre une 2e marche
    goldSitter = await Sitter.create(base({ name: 'Alice Or', email: 'alice618@example.org', pawPoints: 900 }));
    silver = await Walker.create(base({ name: 'Bruno Argent', pawPoints: 700 }));
    bronze = await Sitter.create(base({ name: 'Chloé Bronze', pawPoints: 500 }));
    fourth = await Owner.create(base({ name: 'David Quatre', pawPoints: 400 }));
    staff = await Owner.create(base({ name: 'Staff Equipe', pawPoints: 5000, isStaff: true }));
    tester = await Owner.create(base({ name: 'Compte Test', email: 'dadaciao84+test618@gmail.com', pawPoints: 9000 }));
  });

  test('top 3 dédoublonné, sans staff ni test', async () => {
    const r = await request(app).get('/pawpoints/pins');
    expect(r.status).toBe(200);
    expect(r.headers['cache-control']).toMatch(/max-age=60/);
    expect(r.body.podium.map((p) => p.points)).toEqual([900, 700, 500]);
    expect(r.body.podium[0].name).toBe('Alice O.');
    expect(Object.keys(r.body.podium[0]).sort()).toEqual(['name', 'points', 'role', 'userId']);
    expect(r.body.podium.map((p) => p.userId)).not.toContain(String(staff._id));
    expect(r.body.podium.map((p) => p.userId)).not.toContain(String(tester._id));
    expect(r.body.firstPackLeader).toBeNull();
  });

  test('leaderboard : chaque ligne + me portent pins (même forme)', async () => {
    const r = await request(app).get('/pawspots/leaderboard?scope=europe').set('Authorization', tok(fourth));
    expect(r.status).toBe(200);
    const byName = Object.fromEntries(r.body.leaderboard.map((x) => [x.name, x.pins]));
    expect(byName['Alice O.']).toEqual({ podium: 1, firstPackLeader: false });
    expect(byName['Bruno A.']).toEqual({ podium: 2, firstPackLeader: false });
    expect(byName['Chloé B.']).toEqual({ podium: 3, firstPackLeader: false });
    expect(byName['David Q.']).toEqual({ podium: null, firstPackLeader: false });
    // ordre du classement = ordre du podium
    expect(r.body.leaderboard.slice(0, 3).map((x) => x.pins.podium)).toEqual([1, 2, 3]);
    expect(r.body.me.pins).toEqual({ podium: null, firstPackLeader: false });
    // Alice connectée sur son profil GARDIEN : son pin d'or la suit
    const me2 = await request(app).get('/pawspots/leaderboard?scope=europe').set('Authorization', tok(goldSitter, 'sitter'));
    expect(me2.body.me.pins).toEqual({ podium: 1, firstPackLeader: false });
  });

  test('/pawpoints/me : pins de la personne', async () => {
    const r = await request(app).get('/pawpoints/me').set('Authorization', tok(silver, 'walker'));
    expect(r.status).toBe(200);
    expect(r.body.pins).toEqual({ podium: 2, firstPackLeader: false });
    const s = await request(app).get('/pawpoints/me').set('Authorization', tok(staff));
    expect(s.body.pins).toEqual({ podium: null, firstPackLeader: false });
  });

  test('instantané de 60 s : une seule construction, puis le podium change de main', async () => {
    pins._resetForTests();
    const spy = jest.spyOn(Owner, 'find');
    await Promise.all([pins.getSnapshot(), pins.getSnapshot(), pins.getSnapshot()]);
    await pins.getSnapshot();
    const calls = spy.mock.calls.filter((c) => c[0] && c[0].pawPoints).length;
    spy.mockRestore();
    expect(calls).toBe(1);
    // David passe devant tout le monde : après expiration du cache il a l'or
    await Owner.updateOne({ _id: fourth._id }, { $set: { pawPoints: 1200 } });
    expect((await pins.publicPins()).podium[0].points).toBe(900); // encore en cache
    pins._resetForTests();
    const after = await pins.publicPins();
    expect(after.podium.map((p) => p.points)).toEqual([1200, 900, 700]);
    expect(pins.pinsFromSnapshot(await pins.getSnapshot(), [String(bronze._id)])).toEqual({ podium: null, firstPackLeader: false });
    expect(pins.pinsFromSnapshot(await pins.getSnapshot(), [String(gold._id)]).podium).toBe(2);
  });

  test('membres de la carte (nearby + world) : pins par membre', async () => {
    pins._resetForTests();
    // la couche « autour de moi » ne montre que les membres actifs : PawSpot actif
    const boost = { mapBoostExpiry: new Date(Date.now() + 864e5) };
    await Owner.updateOne({ _id: fourth._id }, { $set: boost });
    await Walker.updateOne({ _id: silver._id }, { $set: boost });
    const viewer = await Owner.create(base({ name: 'Lecteur Carte', pawPoints: 0 }));
    const near = await request(app)
      .get(`/friends/members/nearby?lat=${LAT}&lng=${LNG}&radiusInMeters=50000`)
      .set('Authorization', tok(viewer));
    expect(near.status).toBe(200);
    const nm = Object.fromEntries(near.body.members.map((m) => [m.name, m.pins]));
    expect(nm['David Q.']).toEqual({ podium: 1, firstPackLeader: false });
    expect(nm['Bruno A.']).toEqual({ podium: 3, firstPackLeader: false });
    for (const m of near.body.members) expect(m.pins).toEqual(expect.objectContaining({ firstPackLeader: false }));
    const world = await request(app).get('/friends/members/world').set('Authorization', tok(viewer));
    expect(world.status).toBe(200);
    const wm = Object.fromEntries(world.body.members.map((m) => [m.name, m.pins]));
    expect(wm['David Q.']).toEqual({ podium: 1, firstPackLeader: false });
    expect(wm['Alice O.']).toEqual({ podium: 2, firstPackLeader: false });
    expect(wm['Lecteur C.']).toBeUndefined(); // soi-même retiré
    for (const m of world.body.members) expect(m.pins).toBeDefined();
  });
});

describe('1er Chef de meute (3 000 points, une seule fois)', () => {
  beforeAll(async () => {
    await Promise.all([Owner, Sitter, Walker, PawFirstPackLeader].map((M) => M.deleteMany({})));
    pins._resetForTests();
  });

  test('staff et compte de test passent le seuil : rien enregistré', async () => {
    const st = await Owner.create(base({ name: 'Equipe Staff', pawPoints: 2990, isStaff: true }));
    const te = await Owner.create(base({ name: 'Test Compte', email: 'dadaciao84+testpl618@gmail.com', pawPoints: 2990 }));
    await pp.awardPointsDetailed({ userId: st._id, role: 'owner', points: 50, reason: 'test' });
    await pp.awardPointsDetailed({ userId: te._id, role: 'owner', points: 50, reason: 'test' });
    expect((await Owner.findById(st._id).lean()).pawPoints).toBeGreaterThanOrEqual(3000);
    expect(await PawFirstPackLeader.countDocuments()).toBe(0);
  });

  test('staff sur UN de ses profils seulement : toujours exclu', async () => {
    const em = 'mixte618@example.org';
    const o = await Owner.create(base({ name: 'Mixte Profil', email: em, pawPoints: 2990 }));
    await Sitter.create(base({ name: 'Mixte Profil', email: em, pawPoints: 2990, isStaff: true }));
    await pp.awardPointsDetailed({ userId: o._id, role: 'owner', points: 20, reason: 'test' });
    expect(await PawFirstPackLeader.countDocuments()).toBe(0);
  });

  test('déjà au-dessus avant (pas de passage) : jamais attribué rétroactivement', async () => {
    const old = await Owner.create(base({ name: 'Ancien Haut', pawPoints: 3500 }));
    await pp.awardPointsDetailed({ userId: old._id, role: 'owner', points: 10, reason: 'test' });
    expect(await PawFirstPackLeader.countDocuments()).toBe(0);
  });

  test('sous le seuil : rien', async () => {
    const low = await Walker.create(base({ name: 'Petit Pas', pawPoints: 100 }));
    await pp.awardPointsDetailed({ userId: low._id, role: 'walker', points: 20, reason: 'test' });
    expect(await PawFirstPackLeader.countDocuments()).toBe(0);
  });

  let first;
  test('premier passage réel : pin posé, visible partout', async () => {
    first = await Sitter.create(base({ name: 'Emma Meute', pawPoints: 2995 }));
    const r = await pp.awardPointsDetailed({ userId: first._id, role: 'sitter', points: 20, reason: 'test' });
    expect(r.lifetime).toBe(3015);
    const rec = await PawFirstPackLeader.findOne({ key: 'pack_leader' }).lean();
    expect(rec.userId).toBe(String(first._id));
    expect(rec.role).toBe('sitter');
    const pub = await request(app).get('/pawpoints/pins');
    expect(pub.body.firstPackLeader).toEqual({ userId: String(first._id), role: 'sitter', name: 'Emma M.', at: expect.any(String) });
    const me = await request(app).get('/pawpoints/me').set('Authorization', tok(first, 'sitter'));
    expect(me.body.pins.firstPackLeader).toBe(true);
    const lb = await request(app).get('/pawspots/leaderboard?scope=europe').set('Authorization', tok(first, 'sitter'));
    expect(lb.body.me.pins.firstPackLeader).toBe(true);
    // « Ancien Haut » (3 510, sans passage de seuil) reste devant : Emma = argent + pin Chef de meute
    expect(lb.body.leaderboard[1].name).toBe('Emma M.');
    expect(lb.body.leaderboard[1].pins).toEqual({ podium: 2, firstPackLeader: true });
    expect(lb.body.leaderboard[0].pins).toEqual({ podium: 1, firstPackLeader: false });
  });

  test('le suivant ne le reprend jamais (unique et définitif)', async () => {
    const second = await Owner.create(base({ name: 'Felix Second', pawPoints: 2999 }));
    await pp.awardPointsDetailed({ userId: second._id, role: 'owner', points: 5, reason: 'test' });
    // même une reprise de points chez Emma ne libère pas le pin
    await pp.revokePoints({ userId: first._id, role: 'sitter', points: 1000, reason: 'test' });
    expect(await PawFirstPackLeader.countDocuments()).toBe(1);
    pins._resetForTests();
    expect((await pins.publicPins()).firstPackLeader.userId).toBe(String(first._id));
    const me = await request(app).get('/pawpoints/me').set('Authorization', tok(second));
    expect(me.body.pins.firstPackLeader).toBe(false);
  });

  test('deux passages simultanés sur une base vierge : exactement un gagnant', async () => {
    await PawFirstPackLeader.deleteMany({});
    const a = await Owner.create(base({ name: 'Course Un', pawPoints: 2990 }));
    const b = await Walker.create(base({ name: 'Course Deux', pawPoints: 2990 }));
    const res = await Promise.all([
      pins.maybeRecordFirstPackLeader({ userId: a._id, role: 'owner', before: 2990, after: 3010 }),
      pins.maybeRecordFirstPackLeader({ userId: b._id, role: 'walker', before: 2990, after: 3010 }),
    ]);
    expect(res.filter(Boolean)).toHaveLength(1);
    expect(await PawFirstPackLeader.countDocuments()).toBe(1);
  });

  test('un échec du pin ne casse jamais le gain de points', async () => {
    const spy = jest.spyOn(PawFirstPackLeader, 'exists').mockImplementation(() => { throw new Error('boom'); });
    const c = await Owner.create(base({ name: 'Gain Sûr', pawPoints: 2990 }));
    const r = await pp.awardPointsDetailed({ userId: c._id, role: 'owner', points: 20, reason: 'test' });
    spy.mockRestore();
    expect(r.credited).toBe(20);
    expect(r.lifetime).toBe(3010);
  });
});
