// 607 (ZOE, 02/10/2026) — catalogue PawPoints UNIQUE (app / site / admin).
// Vraie base Mongo en mémoire, vraies routes /pawpoints, vrais services.
// Seule l'authentification est simulée (en-têtes x-test-user / x-test-role).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
}));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => ({ ok: true })) }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let Walker; let UserSubscription; let PawReward;
let PawRewardRedemption; let PawPointsEvent; let act; let catalog; let svc;
let n = 0;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  UserSubscription = require('../src/models/UserSubscription');
  PawReward = require('../src/models/PawReward');
  PawRewardRedemption = require('../src/models/PawRewardRedemption');
  PawPointsEvent = require('../src/models/PawPointsEvent');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), PawPointsEvent.init(),
    PawPointsEvent.PawPointsStreak.init()]);
  act = require('../src/services/pawPointsActivity607');
  catalog = require('../src/services/pawPointsCatalog607');
  svc = require('../src/services/pawPointsService');
  app = express();
  app.use(express.json());
  app.use('/pawpoints', require('../src/routes/pawPointsRoutes'));
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

async function person({ points = 0, role = 'owner', extra = {} } = {}) {
  n += 1;
  const M = role === 'sitter' ? Sitter : role === 'walker' ? Walker : Owner;
  const u = await M.create({ name: `Test Personne${n}`, email: `pp607_${n}@example.test`, password: 'MotDePasse607!', ...extra });
  await M.collection.updateOne({ _id: u._id }, { $set: { pawPoints: points, pawPointsSpendable: points } });
  return u;
}
const as = (u, role = 'owner') => ({ 'x-test-user': String(u._id), 'x-test-role': role });

describe('catalogue 607', () => {
  test('GET /catalog : 15 gains, 10 récompenses, 9 langues partout, aucune réduction', async () => {
    const r = await request(app).get('/pawpoints/catalog');
    expect(r.status).toBe(200);
    const c = r.body.catalog607;
    expect(c.version).toBe(607);
    expect(c.earn).toHaveLength(15);
    expect(c.rewards).toHaveLength(10);
    // petites récompenses atteignables (BOB 02/10)
    expect(c.rewards.slice(0, 4).map((x) => [x.id, x.cost])).toEqual([['perk_boost_24h', 500], ['perk_gold_frame', 1000], ['sub_days_pf_3', 1500], ['sub_days_ps_7', 4000]]);
    const langs = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
    for (const it of [...c.earn, ...c.rewards, ...c.levels]) {
      for (const l of langs) expect(String(it.texts[l] || '').length).toBeGreaterThan(1);
    }
    for (const k of ['title', 'detail']) for (const l of langs) expect(c.collection.texts[k][l]).toBeTruthy();
    for (const k of Object.keys(c.notes)) for (const l of langs) expect(c.notes[k][l]).toBeTruthy();
    expect(c.rewards.map((x) => x.kind).sort()).not.toContain('discount');
    expect(JSON.stringify(c)).not.toMatch(/sub_disc|"percent"/);
    expect(c.rules).toEqual({ activityOnly: true, money: false, percentDiscounts: false, premiumDoubles: true });
    // Apps ≤ 606 : seulement 30 / 30 / 90 jours (elles savent les afficher).
    expect(r.body.subscriptionRewards.map((x) => [x.id, x.kind, x.days]))
      .toEqual([['sub_free_pf_1m', 'free_month', 30], ['sub_free_pp_1m', 'free_month', 30], ['sub_free_pp_3m', 'free_month', 90]]);
    // Avantages de niveau : uniquement ce que le serveur tient.
    for (const l of r.body.levels) for (const p of l.perks) expect(['badge', 'bonus_5', 'bonus_10']).toContain(p);
  });

  test('gains demandés par Daniel présents avec le bon barème', () => {
    const p = svc.POINTS;
    expect(p).toMatchObject({ spotCreated: 10, photoAdded: 5, spotValidated: 10, usefulComment: 2, correctReport: 1,
      spotPopular: 25, plushCaught: 20, plushGolden: 200, plushCollector: 500, plushStreak7: 200, walkCompleted: 15, firstReviewReceived: 50, profileComplete: 100, pioneer: 200, streak7: 50 });
  });

  test('récompense admin de type « réduction » : masquée et non échangeable', async () => {
    const disc = await PawReward.create({ title: '-10 %', cost: 10, kind: 'discount', isActive: true });
    const boost = await PawReward.create({ title: 'Boost', cost: 10, kind: 'boost', isActive: true, intervalDays: 1 });
    const r = await request(app).get('/pawpoints/catalog');
    const ids = r.body.rewards.map((x) => x.id);
    expect(ids).toContain(String(boost._id));
    expect(ids).not.toContain(String(disc._id));
    const u = await person({ points: 100 });
    const x = await request(app).post(`/pawpoints/redeem/${disc._id}`).set(as(u));
    expect(x.status).toBe(404);
    expect((await Owner.findById(u._id).lean()).pawPointsSpendable).toBe(100);
  });

  test('/me : barème complet en 607, 6 gains pour une app 606 (textes qu\'elle sait traduire)', async () => {
    const u = await person();
    const a = await request(app).get('/pawpoints/me').set(as(u)).set('x-app-version', '23.1.580+607');
    expect(a.body.earnRules).toHaveLength(15);
    expect(a.body.catalogVersion).toBe(607);
    const b = await request(app).get('/pawpoints/me').set(as(u)).set('x-app-version', '23.1.580+606');
    expect(b.body.earnRules.map((e) => e.key))
      .toEqual(['spotCreated', 'photoAdded', 'spotValidated', 'usefulComment', 'correctReport', 'spotPopular']);
  });
});

describe('échanges 607', () => {
  test('ancienne réduction -10 % → 410, aucun point débité', async () => {
    const u = await person({ points: 30000 });
    const r = await request(app).post('/pawpoints/redeem/sub_disc_10').set(as(u));
    expect(r.status).toBe(410);
    expect(r.body.code).toBe('REWARD_RETIRED');
    expect((await Owner.findById(u._id).lean()).pawPointsSpendable).toBe(30000);
  });

  test('1 500 pts → 3 jours de PawFollow, répétable ; 4 000 pts → 7 jours de PawSpot', async () => {
    const u = await person({ points: 7000 });
    const t0 = Date.now();
    const r = await request(app).post('/pawpoints/redeem/sub_days_pf_3').set(as(u));
    expect(r.status).toBe(200);
    expect(r.body.newBalance).toBe(5500);
    let sub = await UserSubscription.findOne({ userId: u._id }).lean();
    expect(sub.plan).toBe('monthly');
    expect(Math.round((new Date(sub.currentPeriodEnd).getTime() - t0) / 86400000)).toBe(3);
    expect((await request(app).post('/pawpoints/redeem/sub_days_pf_3').set(as(u))).status).toBe(200);
    sub = await UserSubscription.findOne({ userId: u._id }).lean();
    expect(Math.round((new Date(sub.currentPeriodEnd).getTime() - t0) / 86400000)).toBe(6);
    const ps = await request(app).post('/pawpoints/redeem/sub_days_ps_7').set(as(u));
    expect(ps.status).toBe(200);
    expect(ps.body.newBalance).toBe(0);
    sub = await UserSubscription.findOne({ userId: u._id }).lean();
    expect(Math.round((new Date(sub.pawspotExpiry).getTime() - t0) / 86400000)).toBe(7);
  });

  test('500 pts → 24 h de PawBoost', async () => {
    const u = await person({ points: 500 });
    const t0 = Date.now();
    expect((await request(app).post('/pawpoints/redeem/perk_boost_24h').set(as(u))).status).toBe(200);
    const d = await Owner.findById(u._id).lean();
    expect(Math.round((new Date(d.boostExpiry).getTime() - t0) / 3600000)).toBe(24);
    expect(d.pawPointsSpendable).toBe(0);
  });

  test('grande récompense : une seule fois par personne (même depuis un autre profil)', async () => {
    const u = await person({ points: 120000 });
    await Sitter.create({ name: u.name, email: u.email, password: 'MotDePasse607!' });
    expect((await request(app).post('/pawpoints/redeem/sub_days_pp_7').set(as(u))).status).toBe(200);
    const s2 = await Sitter.findOne({ email: u.email }).lean();
    const again = await request(app).post('/pawpoints/redeem/sub_days_pp_7').set(as(s2, 'sitter'));
    expect(again.status).toBe(409);
  });

  test('50 000 pts → 7 jours de Paw Premium', async () => {
    const u = await person({ points: 50000 });
    const t0 = Date.now();
    const r = await request(app).post('/pawpoints/redeem/sub_days_pp_7').set(as(u));
    expect(r.status).toBe(200);
    expect(r.body.newBalance).toBe(0);
    const sub = await UserSubscription.findOne({ userId: u._id }).lean();
    const days = (new Date(sub.premiumExpiry).getTime() - t0) / 86400000;
    expect(Math.round(days)).toBe(7);
  });

  test('PawBoost 3 jours : accordé, répétable (s\'ajoute)', async () => {
    const u = await person({ points: 10000 });
    const t0 = Date.now();
    expect((await request(app).post('/pawpoints/redeem/perk_boost_3d').set(as(u))).status).toBe(200);
    expect((await request(app).post('/pawpoints/redeem/perk_boost_3d').set(as(u))).status).toBe(200);
    const d = await Owner.findById(u._id).lean();
    expect(Math.round((new Date(d.boostExpiry).getTime() - t0) / 86400000)).toBe(6);
    expect(d.boostTier).toBe('bronze');
    expect(d.pawPointsSpendable).toBe(0);
    expect((await request(app).post('/pawpoints/redeem/perk_boost_3d').set(as(u))).status).toBe(400);
  });

  test('cadre doré : posé sur les 3 profils, puis 409', async () => {
    const u = await person({ points: 2500 });
    const sib = await Sitter.create({ name: u.name, email: u.email, password: 'MotDePasse607!' });
    const r = await request(app).post('/pawpoints/redeem/perk_gold_frame').set(as(u));
    expect(r.status).toBe(200);
    expect((await Owner.findById(u._id).lean()).pawGoldFrame).toBe(true);
    expect((await Sitter.findById(sib._id).lean()).pawGoldFrame).toBe(true);
    expect((await request(app).post('/pawpoints/redeem/perk_gold_frame').set(as(u))).status).toBe(409);
    const me = await request(app).get('/pawpoints/me').set(as(u));
    expect(me.body.claimedRewardKeys).toContain('perk_gold_frame');
  });

  test('migration douce : une réduction -25 % échangée avant le 607 s\'applique encore à l\'achat', async () => {
    const u = await person();
    await PawRewardRedemption.create({
      rewardKey: 'sub_disc_25', title: '-25% Paw Premium', cost: 50000, userId: u._id, userModel: 'Owner',
      role: 'owner', userEmail: u.email, status: 'pending',
      snapshot: { id: 'sub_disc_25', kind: 'discount', percent: 25, plans: ['premium_monthly', 'premium_yearly'] },
    });
    const { pickDiscounts } = require('../src/services/discountReservationService');
    const r = await pickDiscounts({ userId: u._id, plan: 'premium_monthly', baseAmount: 10 });
    expect(r.amount).toBe(7.5);
    expect(r.applied[0]).toMatchObject({ kind: 'paw', percent: 25 });
  });
});

describe('gains d\'activité 607', () => {
  test('premier avis reçu : +50 une seule fois, même en parallèle', async () => {
    const s = await person({ role: 'sitter' });
    const res = await Promise.all([1, 2, 3].map(() => act.onReviewCreated({ revieweeId: s._id, revieweeRole: 'sitter' })));
    expect(res.filter(Boolean)).toHaveLength(1);
    expect((await Sitter.findById(s._id).lean()).pawPoints).toBe(50);
    expect(await act.onReviewCreated({ revieweeId: s._id, revieweeRole: 'sitter' })).toBeNull();
    expect(await PawPointsEvent.countDocuments({ userId: String(s._id), key: 'firstReviewReceived' })).toBe(1);
  });

  test('Balade : comptée à 10 min et 300 m, pas en dessous, 1 fois par jour', async () => {
    const now = Date.now();
    const line = (m) => [[48.85, 2.35, now - 1], [48.85 + m / 111320, 2.35, now]];
    expect(act.baladeQualifies({ startedAt: now - 9 * 60000, trail: line(1000) }, now)).toBe(false);
    expect(act.baladeQualifies({ startedAt: now - 11 * 60000, trail: line(250) }, now)).toBe(false);
    expect(act.baladeQualifies({ startedAt: now - 11 * 60000, trail: line(320) }, now)).toBe(true);
    const u = await person();
    const sess = { userId: String(u._id), role: 'owner', startedAt: now - 15 * 60000, trail: line(500) };
    expect(await act.onBaladeEnded({ userId: u._id, role: 'owner', session: sess })).toMatchObject({ key: 'walkCompleted', credited: 15 });
    expect(await act.onBaladeEnded({ userId: u._id, role: 'owner', session: sess })).toBeNull();
    const tomorrow = new Date(Date.now() + 86400000);
    expect(await act.onBaladeEnded({ userId: u._id, role: 'owner', session: { ...sess, startedAt: tomorrow.getTime() - 15 * 60000 }, now: tomorrow }))
      .toMatchObject({ credited: 15 });
    expect((await Owner.findById(u._id).lean()).pawPoints).toBe(30);
  });

  test('arrêt réel de la Balade (stopEverywhere) crédite +15', async () => {
    const u = await person();
    const map = require('../src/sockets/mapSocket');
    const t0 = Date.now() - 12 * 60000;
    map.touchLiveSession({ userId: String(u._id), role: 'owner', lat: 48.85, lng: 2.35 });
    const s = map.getLiveSession(String(u._id));
    s.startedAt = t0;
    s.trail = [[48.85, 2.35, t0], [48.854, 2.35, t0 + 1000]]; // ~445 m
    await require('../src/utils/liveDevices589').stopEverywhere(String(u._id), { notifyFriends: false });
    await new Promise((r) => setTimeout(r, 300));
    expect(map.getLiveSession(String(u._id))).toBeNull();
    expect((await Owner.findById(u._id).lean()).pawPoints).toBe(15);
  });

  test('série : +50 au 7e jour de suite, rien avant, un trou remet à zéro', async () => {
    const u = await person();
    const d = (i) => new Date(Date.UTC(2026, 9, 1 + i, 10));
    for (let i = 0; i < 6; i += 1) await act.checkIn({ userId: u._id, role: 'owner', now: d(i) });
    await act.checkIn({ userId: u._id, role: 'owner', now: d(5) }); // même jour : rien
    expect((await Owner.findById(u._id).lean()).pawPoints).toBe(0);
    const g = await act.checkIn({ userId: u._id, role: 'owner', now: d(6) });
    expect(g.map((x) => x.key)).toContain('streak7');
    expect((await Owner.findById(u._id).lean()).pawPoints).toBe(50);
    // trou d'un jour puis 6 jours : pas de nouveau gain
    for (let i = 8; i < 14; i += 1) await act.checkIn({ userId: u._id, role: 'owner', now: d(i) });
    expect((await Owner.findById(u._id).lean()).pawPoints).toBe(50);
  });

  test('profil complet à 100 % : +100 une fois ; incomplet : rien', async () => {
    const full = {
      firstName: 'Jeanne', lastName: 'Martin', avatar: { url: 'https://x/y.jpg' }, mobile: '0600000000',
      address: '1 rue X', city: 'Lyon', bio: 'Je garde les chats depuis dix ans.', service: ['pet_sitting'],
      acceptedPetTypes: ['cat'],
    };
    const s = await person({ role: 'sitter', extra: full });
    await act.checkIn({ userId: s._id, role: 'sitter' });
    await act.checkIn({ userId: s._id, role: 'sitter', now: new Date(Date.now() + 86400000) });
    expect(await PawPointsEvent.countDocuments({ userId: String(s._id), key: 'profileComplete' })).toBe(1);
    // Seule gardienne de la base à Lyon → Pionnier (+200, calcul de NEO) en plus.
    expect(await PawPointsEvent.countDocuments({ userId: String(s._id), key: 'pioneer' })).toBe(1);
    expect((await Sitter.findById(s._id).lean()).pawPoints).toBe(300);
    const half = await person({ role: 'sitter', extra: { ...full, bio: 'court' } });
    await act.checkIn({ userId: half._id, role: 'sitter' });
    expect(await PawPointsEvent.countDocuments({ userId: String(half._id), key: 'profileComplete' })).toBe(0);
    expect(act.isProfileComplete({ ...full }, 'owner', 0)).toBe(false);
    expect(act.isProfileComplete({ ...full }, 'owner', 1)).toBe(true);
  });

  test('peluche (appel de PAM) : +20, puis rien le même jour', async () => {
    const u = await person({ role: 'walker' });
    expect(await act.awardActivity({ userId: u._id, role: 'walker', key: 'plushCaught', refId: 'p1' })).toMatchObject({ credited: 20 });
    expect(await act.awardActivity({ userId: u._id, role: 'walker', key: 'plushCaught', refId: 'p2' })).toBeNull();
  });

  test('/me renvoie l\'historique des gains', async () => {
    const u = await person();
    await act.awardActivity({ userId: u._id, role: 'owner', key: 'pioneer' });
    const me = await request(app).get('/pawpoints/me').set(as(u));
    expect(me.body.history[0]).toMatchObject({ key: 'pioneer', points: 200, credited: 200 });
  });

  test('POST /checkin répond la liste des gains', async () => {
    const u = await person();
    const r = await request(app).post('/pawpoints/checkin').set(as(u));
    expect(r.status).toBe(200);
    expect(Array.isArray(r.body.awarded)).toBe(true);
  });
});
