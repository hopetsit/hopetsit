// 610 (ZOE, 04/10/2026) — règle B de Daniel sur les signalements de la PawMap
// (REGLES_610.md) : tout le monde voit tout ; signaler un DANGER est gratuit et
// illimité ; les signalements de CONFORT : 1 par 7 jours sans abonnement,
// illimités avec ; animal perdu / trouvé : règle inchangée ; « geste du bon
// Samaritain » : 24 h de Premium offert à l'auteur d'un danger confirmé par
// 3 autres membres (jamais l'auteur, 1 vote par personne, comptes +test exclus),
// au plus 1 fois par 7 jours, jamais deux fois pour le même signalement.
// Vraie base Mongo en mémoire, vraies routes ; seules l'authentification et
// l'envoi de notifications sont simulés.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  optionalAuth: (req, res, next) => next(),
}));
const mockNotifications = [];
jest.mock('../src/services/notificationSender', () => ({
  sendNotification: jest.fn(async (n) => { mockNotifications.push(n); return {}; }),
}));
// PawPoints : hors sujet ici (et il écrit en tâche de fond).
jest.mock('../src/services/pawPointsService', () => ({
  awardPoints: jest.fn(async () => null),
  POINTS: { correctReport: 1 },
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let MapReport; let UserSubscription;
let seq = 0;
const DAY = 24 * 3600 * 1000;
const PARIS_TEST = { lat: -35, lng: -30 }; // zone fictive (règle de l'équipe)

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  MapReport = require('../src/models/MapReport');
  UserSubscription = require('../src/models/UserSubscription');
  await Promise.all([Owner.init(), Sitter.init(), MapReport.init(), UserSubscription.init()]);
  app = express();
  app.use(express.json());
  app.use('/map-reports', require('../src/routes/mapReportRoutes'));
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

beforeEach(() => { mockNotifications.length = 0; });

async function member(opts = {}) {
  seq += 1;
  const email = opts.email || `membre610_${seq}_${Date.now()}@example.org`;
  const Model = opts.role === 'sitter' ? Sitter : Owner;
  const doc = await Model.create({ name: `Membre ${seq}`, email, password: 'MotDePasse610!' });
  if (opts.premium) {
    await UserSubscription.create({
      userId: doc._id,
      userModel: opts.role === 'sitter' ? 'Sitter' : 'Owner',
      plan: 'premium_monthly',
      status: 'active',
      premiumExpiry: new Date(Date.now() + 30 * DAY),
      currentPeriodEnd: new Date(Date.now() + 30 * DAY),
    });
  }
  return {
    doc,
    email,
    h: { 'x-test-user': String(doc._id), 'x-test-role': opts.role || 'owner' },
  };
}

const post = (who, type) => request(app).post('/map-reports').set(who.h)
  .send({ type, ...PARIS_TEST, city: 'Zone test' });
const confirm = (who, id) => request(app).post(`/map-reports/${id}/confirm`).set(who.h);

describe('VOIR — tout le monde voit tout', () => {
  test('un membre sans abonnement voit les signalements de confort et de danger des autres', async () => {
    const premiumAuthor = await member({ premium: true });
    const viewer = await member();
    await post(premiumAuthor, 'poop').expect(201);
    await post(premiumAuthor, 'poison').expect(201);
    await post(premiumAuthor, 'no_dogs_zone').expect(201);
    const r = await request(app).get('/map-reports/nearby')
      .query({ ...PARIS_TEST, radiusKm: 5 }).set(viewer.h).expect(200);
    const types = r.body.reports.map((x) => x.type);
    expect(types).toEqual(expect.arrayContaining(['poop', 'poison', 'no_dogs_zone']));
    // Filtre par type confort : plus de 402.
    const f = await request(app).get('/map-reports/nearby')
      .query({ ...PARIS_TEST, radiusKm: 5, type: 'poop,no_dogs_zone' }).set(viewer.h).expect(200);
    expect(f.body.reports.length).toBeGreaterThanOrEqual(2);
    expect(f.body.reports.every((x) => ['poop', 'no_dogs_zone'].includes(x.type))).toBe(true);
    // Diagnostic : plus jamais « réservé aux Premium ».
    const d = await request(app).get('/map-reports/diagnose-mine')
      .query(PARIS_TEST).set(viewer.h).expect(200);
    expect(JSON.stringify(d.body.allReportsLast7d)).not.toContain('PREMIUM_ONLY');
  });

  test('la fiche publique (lien partagé) existe pour tous les types', async () => {
    const premiumAuthor = await member({ premium: true });
    const c = await post(premiumAuthor, 'water_broken').expect(201);
    const r = await request(app).get(`/map-reports/public/${c.body.report._id}`).expect(200);
    expect(r.body.type).toBe('water_broken');
    expect(JSON.stringify(r.body)).not.toContain(String(premiumAuthor.doc._id));
  });
});

describe('CRÉER — danger gratuit et illimité', () => {
  test('sans abonnement : 13 types de danger + 4 infos utiles, tous acceptés, plusieurs fois', async () => {
    const free = await member();
    const danger = ['poison', 'trap', 'hazard', 'aggressive_dog', 'dead_animal', 'fire_smoke',
      'flood', 'busy_traffic', 'chemical', 'wildlife', 'fallen_tree', 'heat_hot_ground', 'tick_zone'];
    for (const t of danger) await post(free, t).expect(201);
    for (const t of ['poison', 'poison', 'trap', 'flood']) await post(free, t).expect(201);
    for (const t of ['water_active', 'food', 'trash', 'vet_open', 'food']) await post(free, t).expect(201);
    const types = (await request(app).get('/map-reports/types').expect(200)).body;
    expect(types.dangerTypes.sort()).toEqual([...danger].sort());
    expect(types.comfortTypes.sort()).toEqual(
      ['construction', 'leash_required', 'no_dogs_zone', 'other', 'pee', 'poop', 'stray_pet', 'water_broken'],
    );
    expect(types.comfortWeeklyLimit).toBe(1);
  });
});

describe('CRÉER — confort : 1 par 7 jours sans abonnement', () => {
  test('1er accepté, 2e refusé (429 + date + indice abonnement), accepté après 7 jours', async () => {
    const free = await member();
    let q = await request(app).get('/map-reports/quota').set(free.h).expect(200);
    expect(q.body.comfort).toMatchObject({ unlimited: false, limit: 1, used: 0, remaining: 1 });

    const first = await post(free, 'poop').expect(201);
    const refused = await post(free, 'pee').expect(429);
    expect(refused.body.code).toBe('COMFORT_WEEKLY_LIMIT');
    expect(refused.body.upgradeUrl).toBe('/subscriptions/plans');
    const next = new Date(refused.body.nextAvailableAt).getTime();
    const expected = new Date(first.body.report.createdAt).getTime() + 7 * DAY;
    expect(Math.abs(next - expected)).toBeLessThan(2000);
    q = await request(app).get('/map-reports/quota').set(free.h).expect(200);
    expect(q.body.comfort).toMatchObject({ used: 1, remaining: 0 });
    expect(q.body.comfort.nextAvailableAt).toBeTruthy();

    // Un danger reste possible pendant ce temps.
    await post(free, 'poison').expect(201);

    // 7 jours plus tard (on vieillit le 1er signalement de 7 j + 1 min).
    await MapReport.collection.updateOne(
      { _id: new mongoose.Types.ObjectId(first.body.report._id) },
      { $set: { createdAt: new Date(Date.now() - 7 * DAY - 60000) } },
    );
    await require('../src/models/ComfortReportLog').collection.updateMany(
      { reportId: new mongoose.Types.ObjectId(first.body.report._id) },
      { $set: { createdAt: new Date(Date.now() - 7 * DAY - 60000) } },
    );
    await post(free, 'pee').expect(201);
  });

  test('supprimer son confort ne rend pas le droit : 429 même date, accepté après 7 jours', async () => {
    const free = await member();
    const first = (await post(free, 'poop').expect(201)).body.report;
    const expected = new Date(first.createdAt).getTime() + 7 * DAY;
    await request(app).delete(`/map-reports/${first._id}`).set(free.h).expect(200);
    expect(await MapReport.countDocuments({ _id: first._id })).toBe(0);
    const q = await request(app).get('/map-reports/quota').set(free.h).expect(200);
    expect(q.body.comfort).toMatchObject({ used: 1, remaining: 0 });
    expect(Math.abs(new Date(q.body.comfort.nextAvailableAt).getTime() - expected)).toBeLessThan(2000);
    const refused = await post(free, 'pee').expect(429);
    expect(refused.body.code).toBe('COMFORT_WEEKLY_LIMIT');
    expect(Math.abs(new Date(refused.body.nextAvailableAt).getTime() - expected)).toBeLessThan(2000);
    // 7 jours plus tard (on vieillit la trace de 7 j + 1 min).
    const Log = require('../src/models/ComfortReportLog');
    await Log.collection.updateMany(
      { reporterId: free.doc._id },
      { $set: { createdAt: new Date(Date.now() - 7 * DAY - 60000) } },
    );
    await post(free, 'pee').expect(201);
  });

  test('le quota est par PERSONNE : le profil gardien de la même personne est refusé aussi', async () => {
    const asOwner = await member();
    const asSitter = await member({ role: 'sitter', email: asOwner.email });
    await post(asOwner, 'water_broken').expect(201);
    const r = await post(asSitter, 'other').expect(429);
    expect(r.body.code).toBe('COMFORT_WEEKLY_LIMIT');
  });

  test('avec un abonnement : illimité', async () => {
    const sub = await member({ premium: true });
    for (const t of ['poop', 'pee', 'water_broken', 'construction', 'other']) await post(sub, t).expect(201);
    const q = await request(app).get('/map-reports/quota').set(sub.h).expect(200);
    expect(q.body.comfort.unlimited).toBe(true);
  });

  test('animal perdu / trouvé : règle inchangée (abonnés seulement à la création)', async () => {
    const free = await member();
    const r = await post(free, 'lost_pet').expect(402);
    expect(r.body.code).toBe('PREMIUM_REQUIRED');
    await post(free, 'found_pet').expect(402);
    const sub = await member({ premium: true });
    await post(sub, 'lost_pet').expect(201);
  });
});

describe('Geste du bon Samaritain', () => {
  async function premiumState(who) {
    const s = await UserSubscription.findOne({ userId: who.doc._id }).lean();
    return s;
  }
  const gifts = (s) => ((s && s.history) || []).filter((h) => h.paymentProvider === 'admin_gift');

  test('danger : rien à la 2e confirmation, 24 h de Premium à la 3e, jamais deux fois', async () => {
    const author = await member();
    const [a, b, c, d] = await Promise.all([member(), member(), member(), member()]);
    const rep = (await post(author, 'poison').expect(201)).body.report;

    // Un membre SANS abonnement peut confirmer un danger.
    await confirm(a, rep._id).expect(200);
    const second = await confirm(b, rep._id).expect(200);
    expect(second.body.confirmationsCount).toBe(2);
    expect(second.body.samaritanGranted).toBeFalsy();
    expect(gifts(await premiumState(author))).toHaveLength(0);
    expect(mockNotifications.filter((n) => n.type === 'good_samaritan_premium')).toHaveLength(0);

    const before = Date.now();
    const third = await confirm(c, rep._id).expect(200);
    expect(third.body.samaritanGranted).toBe(true);
    const s = await premiumState(author);
    expect(gifts(s)).toHaveLength(1);
    const exp = new Date(s.premiumExpiry).getTime();
    expect(exp).toBeGreaterThanOrEqual(before + DAY - 5000);
    expect(exp).toBeLessThanOrEqual(Date.now() + DAY + 5000);
    const notes = mockNotifications.filter((n) => n.type === 'good_samaritan_premium');
    expect(notes).toHaveLength(1);
    expect(String(notes[0].userId)).toBe(String(author.doc._id));
    expect(notes[0].data.reportId).toBe(String(rep._id));

    // L'abonnement offert débloque le confort illimité pour l'auteur.
    await post(author, 'poop').expect(201);
    await post(author, 'pee').expect(201);

    // 4e confirmation : rien de plus.
    await confirm(d, rep._id).expect(200);
    expect(gifts(await premiumState(author))).toHaveLength(1);
    expect(mockNotifications.filter((n) => n.type === 'good_samaritan_premium')).toHaveLength(1);
  });

  test("l'auteur ne compte jamais, un vote par personne (3 profils = 1), comptes +test exclus", async () => {
    const author = await member();
    const authorSitter = await member({ role: 'sitter', email: author.email });
    const a = await member();
    const aSitter = await member({ role: 'sitter', email: a.email });
    const t1 = await member({ email: `dadaciao84+test610a_${Date.now()}@gmail.com` });
    const t2 = await member({ email: `dadaciao84+test610b_${Date.now()}@gmail.com` });
    const rep = (await post(author, 'trap').expect(201)).body.report;

    await confirm(author, rep._id).expect(200);
    await confirm(authorSitter, rep._id).expect(200);
    await confirm(a, rep._id).expect(200);
    const dup = await confirm(aSitter, rep._id).expect(200); // même personne que a
    expect(dup.body.confirmationsCount).toBeLessThanOrEqual(3);
    await confirm(t1, rep._id).expect(200);
    await confirm(t2, rep._id).expect(200);
    expect(gifts(await premiumState(author))).toHaveLength(0);
    expect(mockNotifications.filter((n) => n.type === 'good_samaritan_premium')).toHaveLength(0);

    // Deux vrais membres de plus → 3 votes valides → offert.
    const [b, c] = await Promise.all([member(), member()]);
    await confirm(b, rep._id).expect(200);
    const last = await confirm(c, rep._id).expect(200);
    expect(last.body.samaritanGranted).toBe(true);
    expect(gifts(await premiumState(author))).toHaveLength(1);
  });

  test('un signalement de confort confirmé 3 fois ne donne rien', async () => {
    const author = await member({ premium: true });
    const voters = await Promise.all([member({ premium: true }), member({ premium: true }), member({ premium: true })]);
    const rep = (await post(author, 'poop').expect(201)).body.report;
    for (const v of voters) await confirm(v, rep._id).expect(200);
    expect(gifts(await premiumState(author))).toHaveLength(0);
    expect(mockNotifications.filter((n) => n.type === 'good_samaritan_premium')).toHaveLength(0);
    // Confirmer un confort reste réservé aux abonnés (inchangé).
    const free = await member();
    await confirm(free, rep._id).expect(402);
  });

  test('au plus 1 fois par 7 jours ; un signalement bloqué par la limite ne donne jamais plus tard', async () => {
    const author = await member();
    const voters = await Promise.all([1, 2, 3, 4, 5, 6, 7, 8, 9].map(() => member()));
    const r1 = (await post(author, 'flood').expect(201)).body.report;
    const r2 = (await post(author, 'fire_smoke').expect(201)).body.report;
    for (const v of voters.slice(0, 3)) await confirm(v, r1._id).expect(200);
    expect(gifts(await premiumState(author))).toHaveLength(1);

    // 2e danger confirmé 3 fois dans la même semaine : pas de 2e cadeau.
    for (const v of voters.slice(3, 6)) await confirm(v, r2._id).expect(200);
    expect(gifts(await premiumState(author))).toHaveLength(1);

    // 8 jours plus tard : r2 ne redonne pas (déjà jugé), un nouveau danger oui.
    await MapReport.collection.updateMany(
      { reporterId: author.doc._id, 'samaritan.at': { $ne: null } },
      { $set: { 'samaritan.at': new Date(Date.now() - 8 * DAY) } },
    );
    await confirm(voters[6], r2._id).expect(200);
    expect(gifts(await premiumState(author))).toHaveLength(1);
    const r3 = (await post(author, 'chemical').expect(201)).body.report;
    for (const v of voters.slice(6, 9)) await confirm(v, r3._id).expect(200);
    expect(gifts(await premiumState(author))).toHaveLength(2);
    expect(mockNotifications.filter((n) => n.type === 'good_samaritan_premium')).toHaveLength(2);
  });

  test('confirmations simultanées : un seul cadeau', async () => {
    const author = await member();
    const voters = await Promise.all([1, 2, 3, 4, 5].map(() => member()));
    const rep = (await post(author, 'aggressive_dog').expect(201)).body.report;
    await confirm(voters[0], rep._id).expect(200);
    await confirm(voters[1], rep._id).expect(200);
    await Promise.all(voters.slice(2).map((v) => confirm(v, rep._id)));
    expect(gifts(await premiumState(author))).toHaveLength(1);
  });
});
