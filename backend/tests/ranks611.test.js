// 611 (PAM, 04/10/2026) — RANGS façon Waze (idée de Cam, décision BOB).
// Chiot → Jeune chien → Chien adulte → Chef de meute → Légende, calculés sur
// les PawPoints GAGNÉS DEPUIS TOUJOURS (`pawPoints`), jamais sur le solde
// dépensable (`pawPointsSpendable`). Vraie base Mongo en mémoire, vraies
// routes /pawpoints et /pawspots ; seule l'authentification est simulée.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

let mockCurrentUser = null;
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: () => (req, res, next) => next(),
  optionalAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (id) req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  authenticate: (req, res, next) => next(),
}));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => ({ ok: true })) }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let Walker; let ranks;
let n = 0;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init()]);
  ranks = require('../src/services/ranks611');
  app = express();
  app.use(express.json());
  app.use('/pawpoints', require('../src/routes/pawPointsRoutes'));
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

async function person({ lifetime = 0, spendable = lifetime, role = 'owner', email, name } = {}) {
  n += 1;
  const M = role === 'sitter' ? Sitter : role === 'walker' ? Walker : Owner;
  const u = await M.create({
    name: name || `Rang Personne${n}`,
    email: email || `rank611_${n}@example.test`,
    password: 'MotDePasse611!',
  });
  await M.collection.updateOne({ _id: u._id }, { $set: { pawPoints: lifetime, pawPointsSpendable: spendable } });
  return u;
}
const as = (u, role = 'owner') => ({ 'x-test-user': String(u._id), 'x-test-role': role });

describe('611 — barème des rangs', () => {
  test('5 rangs, seuils croissants, noms dans les 9 langues', () => {
    expect(ranks.RANKS.map((r) => [r.key, r.min])).toEqual([
      ['puppy', 0], ['young_dog', 150], ['adult_dog', 800], ['pack_leader', 3000], ['legend', 10000],
    ]);
    for (const r of ranks.RANKS) {
      for (const l of ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
        expect(String(r.texts[l] || '').length).toBeGreaterThan(1);
      }
    }
    expect(ranks.RANKS.map((r) => r.texts.fr)).toEqual(['Chiot', 'Jeune chien', 'Chien adulte', 'Chef de meute', 'Légende']);
  });

  test('rankFor : forme {key, level, pointsEarned, nextAt, nextKey} et bornes', () => {
    expect(ranks.rankFor(0)).toEqual({ key: 'puppy', level: 1, pointsEarned: 0, nextAt: 150, nextKey: 'young_dog' });
    expect(ranks.rankFor(149).key).toBe('puppy');
    expect(ranks.rankFor(150)).toMatchObject({ key: 'young_dog', level: 2, nextAt: 800 });
    expect(ranks.rankFor(799).level).toBe(2);
    expect(ranks.rankFor(800).key).toBe('adult_dog');
    expect(ranks.rankFor(3000).key).toBe('pack_leader');
    expect(ranks.rankFor(10000)).toEqual({ key: 'legend', level: 5, pointsEarned: 10000, nextAt: null, nextKey: null });
    expect(ranks.rankFor(undefined)).toMatchObject({ key: 'puppy', pointsEarned: 0 });
    expect(ranks.rankFor(-5)).toMatchObject({ key: 'puppy', pointsEarned: 0 });
    expect(ranks.rankFor('abc')).toMatchObject({ key: 'puppy', pointsEarned: 0 });
  });

  test('rankOfDocs : une personne à plusieurs profils = le plus haut total', () => {
    expect(ranks.rankOfDocs([{ pawPoints: 100 }, { pawPoints: 900 }, {}]).key).toBe('adult_dog');
    expect(ranks.rankOfDocs([]).key).toBe('puppy');
  });
});

describe('611 — GET /pawpoints/me', () => {
  test('rang calculé sur le total gagné, PAS sur le solde dépensable', async () => {
    const u = await person({ lifetime: 900, spendable: 20 });
    const r = await request(app).get('/pawpoints/me').set(as(u));
    expect(r.status).toBe(200);
    expect(r.body.rank).toEqual({ key: 'adult_dog', level: 3, pointsEarned: 900, nextAt: 3000, nextKey: 'pack_leader' });
    expect(r.body.spendable).toBe(20);
  });

  test('dépenser une récompense ne fait pas baisser le rang', async () => {
    const u = await person({ lifetime: 800, spendable: 800 });
    const red = await request(app).post('/pawpoints/redeem/perk_boost_24h').set(as(u)).send({});
    expect(red.status).toBe(200);
    const r = await request(app).get('/pawpoints/me').set(as(u));
    expect(r.body.spendable).toBe(300);
    expect(r.body.rank.key).toBe('adult_dog');
  });

  test('message de passage de rang : une seule fois, pour la personne (3 profils)', async () => {
    const email = `rank611_seen_${Date.now()}@example.test`;
    const o = await person({ lifetime: 200, email });
    const s = await person({ lifetime: 200, email, role: 'sitter' });
    let r = await request(app).get('/pawpoints/me').set(as(o));
    expect(r.body.rankSeenLevel).toBe(1); // jamais vu : Chiot
    // l'app montre « Tu passes Jeune chien », puis le note
    const seen = await request(app).post('/pawpoints/rank-seen').set(as(o)).send({ level: 2 });
    expect(seen.status).toBe(200);
    expect(seen.body.rankSeenLevel).toBe(2);
    r = await request(app).get('/pawpoints/me').set(as(o));
    expect(r.body.rankSeenLevel).toBe(2);
    // même personne sur son profil gardien : déjà vu
    r = await request(app).get('/pawpoints/me').set(as(s, 'sitter'));
    expect(r.body.rankSeenLevel).toBe(2);
    // jamais plus haut que le rang réel, jamais en arrière
    const tooHigh = await request(app).post('/pawpoints/rank-seen').set(as(o)).send({ level: 5 });
    expect(tooHigh.body.rankSeenLevel).toBe(2);
    const back = await request(app).post('/pawpoints/rank-seen').set(as(o)).send({ level: 1 });
    expect(back.body.rankSeenLevel).toBe(2);
    const bad = await request(app).post('/pawpoints/rank-seen').set(as(o)).send({ level: 'x' });
    expect(bad.status).toBe(400);
  });

  test('sans connexion : 401', async () => {
    const r = await request(app).post('/pawpoints/rank-seen').send({ level: 2 });
    expect(r.status).toBe(401);
  });

  test('catalogue public : les 5 rangs et leurs textes (pour le site)', async () => {
    const r = await request(app).get('/pawpoints/catalog');
    expect(r.status).toBe(200);
    const rk = r.body.ranks611;
    expect(rk.version).toBe(611);
    expect(rk.ranks.map((x) => x.min)).toEqual([0, 150, 800, 3000, 10000]);
    expect(rk.rules).toEqual({ basedOn: 'lifetimeEarned', money: false, paidPerks: false });
    for (const l of ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      expect(rk.texts.explainer[l]).toBeTruthy();
      expect(rk.texts.noMoney[l]).toBeTruthy();
    }
  });
});

describe('611 — profil et fiche publique (sanitizeUser)', () => {
  const { sanitizeUser } = require('../src/utils/sanitize');
  test('le rang suit pawPoints, sans exposer le solde dépensable en public', () => {
    const pub = sanitizeUser({ _id: 'a', name: 'Lucie Martin', email: 'l@x.io', pawPoints: 3100, pawPointsSpendable: 12 });
    expect(pub.rank).toMatchObject({ key: 'pack_leader', level: 4, pointsEarned: 3100, nextAt: 10000 });
    expect(pub.pawPointsSpendable).toBeUndefined();
    const mine = sanitizeUser({ _id: 'a', name: 'Lucie', email: 'l@x.io', pawPoints: 160, pawPointsSpendable: 12 }, { includeEmail: true });
    expect(mine.rank.key).toBe('young_dog');
    expect(mine.pawPointsSpendable).toBe(12);
  });
  test('pawPoints non lu (projection partielle) : pas de rang inventé', () => {
    // un objet sans `pawPoints` (participant de discussion, projection
    // partielle…) ne reçoit PAS un faux « Chiot » : l'app n'affiche rien.
    expect(sanitizeUser({ _id: 'b', name: 'Vieux' }).rank).toBeUndefined();
    expect(sanitizeUser({ _id: 'c', name: 'Zero', pawPoints: 0 }).rank).toMatchObject({ key: 'puppy', pointsEarned: 0 });
  });
  test('vieux profil complet SANS le champ pawPoints : lu comme 0 → Chiot', () => {
    const r = sanitizeUser({ _id: 'd', name: 'Ancien', createdAt: new Date('2025-01-01') }).rank;
    expect(r).toEqual({ key: 'puppy', level: 1, pointsEarned: 0, nextAt: 150, nextKey: 'young_dog' });
  });
});

describe('611 — profil SANS champ pawPoints en base (vieux compte), lu comme 0 partout', () => {
  test('/pawpoints/me, fiche (document réel), classement : Chiot, aucune erreur', async () => {
    const u = await person({ lifetime: 0 });
    await Owner.collection.updateOne({ _id: u._id }, { $unset: { pawPoints: '', pawPointsSpendable: '' } });
    const raw = await Owner.collection.findOne({ _id: u._id });
    expect(raw.pawPoints).toBeUndefined();
    const me = await request(app).get('/pawpoints/me').set(as(u));
    expect(me.status).toBe(200);
    expect(me.body.rank).toMatchObject({ key: 'puppy', pointsEarned: 0 });
    expect(me.body.level).toMatchObject({ key: 'puppy' });
    const { sanitizeUser } = require('../src/utils/sanitize');
    const lean = await Owner.findById(u._id).select('-password').lean();
    expect(sanitizeUser(lean).rank).toMatchObject({ key: 'puppy', pointsEarned: 0 });
    const lb = express();
    lb.use(express.json());
    lb.use('/pawspots', require('../src/routes/pawSpotRoutes'));
    const r = await request(lb).get('/pawspots/leaderboard?scope=europe').set(as(u));
    expect(r.status).toBe(200);
    const pts = await request(lb).get('/pawspots/me/points').set(as(u));
    expect(pts.status).toBe(200);
    expect(pts.body.badge).toBeNull();
  });
});

describe('611 — un seul système : plus aucun ancien niveau ni bonus', () => {
  const OLD = /Explorateur|Explorer|Contributeur|Ambassadeur|PawMaster|Légendaire|Paw Legend|bonus_5|bonus_10|bonus_15/;
  test('catalogue public, /me : seuls les 5 rangs, bonus 0', async () => {
    const c = await request(app).get('/pawpoints/catalog');
    expect(JSON.stringify(c.body)).not.toMatch(OLD);
    expect(c.body.catalog607.levels.map((l) => l.texts.fr)).toEqual(['Chiot', 'Jeune chien', 'Chien adulte', 'Chef de meute', 'Légende']);
    expect(c.body.levels.map((l) => l.bonusPct)).toEqual([0, 0, 0, 0, 0]);
    const u = await person({ lifetime: 25000 });
    const me = await request(app).get('/pawpoints/me').set(as(u));
    expect(JSON.stringify(me.body)).not.toMatch(OLD);
    expect(me.body.bonusPct).toBe(0);
    expect(me.body.level.key).toBe('legend');
  });
  test('gain à 25 000 points : aucun bonus de pourcentage', async () => {
    const svc = require('../src/services/pawPointsService');
    const u = await person({ lifetime: 25000 });
    const got = await svc.awardPointsDetailed({ userId: String(u._id), role: 'owner', points: 20 });
    expect(got.credited).toBe(20);
    expect(svc.badgeFor(25000)).toBeNull();
  });
});

describe('611 — classement public : rang sur chaque ligne, comptes +test exclus', () => {
  test('/pawspots/leaderboard', async () => {
    const lb = express();
    lb.use(express.json());
    lb.use('/pawspots', require('../src/routes/pawSpotRoutes'));
    const me = await person({ lifetime: 3200, name: 'Lucie Martin' });
    await person({ lifetime: 99999, name: 'Testeur Interne', email: `dadaciao84+testrank${Date.now()}@gmail.com` });
    const r = await request(lb).get('/pawspots/leaderboard?scope=europe').set(as(me));
    expect(r.status).toBe(200);
    const rows = r.body.leaderboard;
    expect(rows.some((x) => x.name.startsWith('Testeur'))).toBe(false);
    const lucie = rows.find((x) => x.name === 'Lucie M.');
    expect(lucie.rank).toMatchObject({ key: 'pack_leader', pointsEarned: 3200 });
  });
});

describe('611 (I) — classement : MA ligne toujours renvoyée (« Je suis OÙ ? »)', () => {
  let lb;
  beforeAll(() => {
    lb = express();
    lb.use(express.json());
    lb.use('/pawspots', require('../src/routes/pawSpotRoutes'));
  });
  test('membre normal hors des 50 affichés : position exacte, rang', async () => {
    const tag = `i611_${Date.now()}`;
    for (let i = 0; i < 55; i += 1) await person({ lifetime: 900000 + i, email: `${tag}_${i}@example.test` });
    const me = await person({ lifetime: 136 });
    // une PERSONNE (e-mail) = une place, même avec plusieurs profils
    const ahead = new Set((await Promise.all([Owner, Sitter, Walker].map((M) => M.find({ pawPoints: { $gt: 136 }, isStaff: { $ne: true }, email: { $not: /\+test/ } }).select('email').lean()))).flat().map((d) => d.email)).size;
    const r = await request(lb).get('/pawspots/leaderboard?scope=europe').set(as(me));
    expect(r.status).toBe(200);
    expect(r.body.leaderboard).toHaveLength(50);
    expect(r.body.me).toMatchObject({ position: ahead + 1, pointsEarned: 136, excludedReason: null });
    expect(r.body.me.rank).toMatchObject({ key: 'puppy', nextAt: 150 });
    expect(r.body.me.position).toBeGreaterThan(50);
  }, 60000);
  test('compte équipe (cas de Cam) : hors classement, raison donnée, absent de la liste', async () => {
    const cam = await person({ lifetime: 136, name: 'Cam Chetmou' });
    await Owner.collection.updateOne({ _id: cam._id }, { $set: { isStaff: true } });
    const r = await request(lb).get('/pawspots/leaderboard?scope=europe').set(as(cam));
    expect(r.body.me).toMatchObject({ position: null, pointsEarned: 136, excludedReason: 'staff' });
    expect(r.body.leaderboard.some((x) => x.name.startsWith('Cam'))).toBe(false);
  });
  test('onglet « Ma ville » sans ville : raison no_city', async () => {
    const u = await person({ lifetime: 40 });
    const r = await request(lb).get('/pawspots/leaderboard?scope=city').set(as(u));
    expect(r.body.me).toMatchObject({ position: null, excludedReason: 'no_city' });
  });
});
