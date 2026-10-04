// 612 (ADA, 04/10/2026) — Daniel : « je peux qu'appuyer sur le bouton Staff / Premium,
// je ne peux pas séparer ; si je la mets Premium, elle apparaîtra ? ».
// Deux actions distinctes dans l'admin :
//   · ⭐ Staff (POST /admin/users/:role/:id/staff) — l'équipe, inchangé ;
//   · 👑 Offrir Premium (POST / DELETE /admin/users/:role/:id/premium-gift) — Premium
//     SANS isStaff : la personne reste un vrai compte (classement public, statistiques).
// Vraie base Mongo en mémoire, vraies routes ; seule l'authentification est simulée.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role)
    ? next() : res.status(403).json({ error: 'forbidden' })),
  optionalAuth: (req, res, next) => next(),
}));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => ({ ok: true })) }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let Walker; let UserSubscription; let PawPlush;
const ADMIN = { 'x-test-user': 'admin1', 'x-test-role': 'admin' };
const DAY = 86400000;
let n = 0;
const mk = (M, extra = {}) => { n += 1; return M.create({ name: `Personne${n}`, email: `gift612_${n}@example.org`, password: 'MotDePasse612!', ...extra }); };
const gift = (role, id, months) => request(app).post(`/admin/users/${role}/${id}/premium-gift`).set(ADMIN)
  .send(months === undefined ? {} : { months });
const ungift = (role, id) => request(app).delete(`/admin/users/${role}/${id}/premium-gift`).set(ADMIN);
const subOf = (doc, model) => UserSubscription.findOne({ userId: doc._id, userModel: model }).lean();
const days = (d) => Math.round((new Date(d).getTime() - Date.now()) / DAY);

async function person(points = 0) {
  const o = await mk(Owner, { pawPoints: points });
  const s = await Sitter.create({ name: o.name, email: o.email, password: 'MotDePasse612!', pawPoints: points });
  const w = await Walker.create({ name: o.name, email: o.email, password: 'MotDePasse612!', pawPoints: points });
  return { o, s, w };
}

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  UserSubscription = require('../src/models/UserSubscription');
  PawPlush = require('../src/models/PawPlush');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), UserSubscription.init(), PawPlush.init()]);
  app = express();
  app.use(express.json());
  app.use('/admin/pawpoints-insights', require('../src/routes/adminPawPointsInsights607'));
  app.use('/admin', require('../src/routes/adminRoutes'));
  app.use('/pawspots', require('../src/routes/pawSpotRoutes'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });
beforeEach(async () => {
  await Promise.all([Owner.deleteMany({}), Sitter.deleteMany({}), Walker.deleteMany({}),
    UserSubscription.deleteMany({}), PawPlush.deleteMany({})]);
});

/** Aucun paiement : aucune ligne `payments`, aucune collection de paiement remplie. */
async function expectNoPayment() {
  const subs = await UserSubscription.find({}).lean();
  for (const s of subs) expect(s.payments || []).toHaveLength(0);
  const cols = await mongoose.connection.db.listCollections().toArray();
  for (const c of cols) {
    if (/payment|transaction|invoice|charge|payout/i.test(c.name)) {
      expect(await mongoose.connection.db.collection(c.name).countDocuments({})).toBe(0);
    }
  }
}

describe('POST /admin/users/:role/:id/premium-gift — 👑 Offrir Premium', () => {
  test('401 / 403 / 400 rôle ou durée invalide / 404 compte absent', async () => {
    const o = await mk(Owner);
    await request(app).post(`/admin/users/owner/${o._id}/premium-gift`).send({ months: 3 }).expect(401);
    await request(app).post(`/admin/users/owner/${o._id}/premium-gift`).set({ 'x-test-user': 'u', 'x-test-role': 'owner' })
      .send({ months: 3 }).expect(403);
    await gift('admin', o._id, 3).expect(400);
    await gift('owner', o._id, 2).expect(400);
    await gift('owner', new mongoose.Types.ObjectId(), 3).expect(404);
    expect(await UserSubscription.countDocuments({})).toBe(0);
  });

  test('offrir (défaut 3 mois) : 3 profils Premium, isStaff reste false, aucun paiement', async () => {
    const { o, s, w } = await person();
    const other = await mk(Owner);
    const r = await gift('sitter', s._id).expect(200);
    expect(r.body.days).toBe(90);
    expect(r.body.profiles).toHaveLength(3);
    for (const [d, m] of [[o, 'Owner'], [s, 'Sitter'], [w, 'Walker']]) {
      const sub = await subOf(d, m);
      expect(days(sub.premiumExpiry)).toBe(90);
      expect(days(sub.pawspotExpiry)).toBe(90);
      expect(sub.plan).toBe('premium_monthly');
      expect(sub.status).toBe('active');
      expect(sub.history.at(-1)).toMatchObject({ paymentProvider: 'admin_gift', intervalDays: 90, giftSource: 'admin_console' });
    }
    for (const [d, M] of [[o, Owner], [s, Sitter], [w, Walker]]) {
      expect((await M.findById(d._id).lean()).isStaff).toBe(false);
    }
    const { isStaffPerson } = require('../src/utils/staffAccess589');
    expect(await isStaffPerson(o._id)).toBe(false);
    const { hasActivePremiumAnyRole } = require('../src/services/pawPointsService');
    for (const [d, role] of [[o, 'owner'], [s, 'sitter'], [w, 'walker']]) {
      expect(await hasActivePremiumAnyRole(d._id, role)).toBe(true);
    }
    expect(await subOf(other, 'Owner')).toBeNull();
    await expectNoPayment();
  });

  test('durée au choix : 1 mois = 30 j, 1 an = 365 j (forfait annuel)', async () => {
    const a = await mk(Owner);
    const b = await mk(Walker);
    expect((await gift('owner', a._id, 1).expect(200)).body.days).toBe(30);
    expect(days((await subOf(a, 'Owner')).premiumExpiry)).toBe(30);
    expect((await gift('walker', b._id, 12).expect(200)).body.days).toBe(365);
    const sb = await subOf(b, 'Walker');
    expect(days(sb.premiumExpiry)).toBe(365);
    expect(sb.plan).toBe('premium_yearly');
    await expectNoPayment();
  });

  test('la personne reste dans le classement public et compte comme « vrai compte »', async () => {
    const { o } = await person(700);
    const viewer = await mk(Owner, { pawPoints: 10 });
    await gift('owner', o._id, 3).expect(200);
    const lb = await request(app).get('/pawspots/leaderboard?scope=europe')
      .set({ 'x-test-user': String(viewer._id), 'x-test-role': 'owner' }).expect(200);
    expect(lb.body.leaderboard.map((x) => x.userId)).toEqual(expect.arrayContaining([expect.any(String)]));
    expect(lb.body.leaderboard[0].points).toBe(700); // la personne Premium offert est bien classée (1re)
    // Témoin : la même personne passée en Staff sort du classement.
    await request(app).post(`/admin/users/owner/${o._id}/staff`).set(ADMIN).send({ isStaff: true }).expect(200);
    const lb2 = await request(app).get('/pawspots/leaderboard?scope=europe')
      .set({ 'x-test-user': String(viewer._id), 'x-test-role': 'owner' }).expect(200);
    expect(lb2.body.leaderboard.map((x) => x.points)).toEqual([10]);
    await request(app).post(`/admin/users/owner/${o._id}/staff`).set(ADMIN).send({ isStaff: false }).expect(200);

    // Statistiques « vrais comptes » (PawPoints / peluches) : sa capture compte en « vrai ».
    await PawPlush.create({ cityKey: 'alhama', cityLabel: 'Alhama', day: new Date().toISOString().slice(0, 10), type: 'bunny', slot: 0,
      location: { type: 'Point', coordinates: [-1.42, 37.85] }, caughtByPerson: 'k1',
      caughtBy: { userId: String(o._id), role: 'owner', at: new Date() } });
    const ins = await request(app).get('/admin/pawpoints-insights').set(ADMIN).expect(200);
    expect(ins.body.plush.recent.map((x) => x.kind)).toEqual(['real']);
  });

  test('déjà abonné payant : on prolonge à la suite, le forfait payé est gardé ; retirer rend exactement le temps payé', async () => {
    const o = await mk(Owner);
    const paidEnd = new Date(Date.now() + 20 * DAY);
    await UserSubscription.create({ userId: o._id, userModel: 'Owner', plan: 'premium_yearly', status: 'active',
      currentPeriodStart: new Date(Date.now() - 10 * DAY), currentPeriodEnd: paidEnd, pawspotExpiry: paidEnd, premiumExpiry: paidEnd,
      history: [{ plan: 'premium_yearly', paymentProvider: 'airwallex', paymentId: 'pay_612', activatedAt: new Date(), expiresAt: paidEnd }] });
    await gift('owner', o._id, 3).expect(200);
    let sub = await subOf(o, 'Owner');
    expect(days(sub.premiumExpiry)).toBe(110);
    expect(days(sub.currentPeriodEnd)).toBe(110);
    expect(sub.plan).toBe('premium_yearly');

    const r = await ungift('owner', o._id).expect(200);
    expect(r.body.removed).toBe(true);
    sub = await subOf(o, 'Owner');
    expect(new Date(sub.premiumExpiry).getTime()).toBe(paidEnd.getTime());
    expect(new Date(sub.currentPeriodEnd).getTime()).toBe(paidEnd.getTime());
    expect(sub.plan).toBe('premium_yearly');
    expect(sub.status).toBe('active');
    expect(sub.history.find((h) => h.paymentId === 'pay_612').revokedAt).toBeUndefined();
    await expectNoPayment();
  });

  test('retirer : fin du cadeau sur les 3 profils, plus de pastille, isStaff jamais touché', async () => {
    const { o, s, w } = await person();
    await gift('owner', o._id, 3).expect(200);
    let pills = (await request(app).get('/admin/premium-gifts').set(ADMIN).expect(200)).body.gifts;
    expect(pills.map((g) => g.role).sort()).toEqual(['owner', 'sitter', 'walker']);
    expect(days(pills[0].giftUntil)).toBe(90);
    expect(JSON.stringify(pills)).not.toMatch(/@/);

    await ungift('walker', w._id).expect(200);
    const { hasActivePremiumAnyRole } = require('../src/services/pawPointsService');
    for (const [d, m, role] of [[o, 'Owner', 'owner'], [s, 'Sitter', 'sitter'], [w, 'Walker', 'walker']]) {
      const sub = await subOf(d, m);
      expect(new Date(sub.premiumExpiry).getTime()).toBeLessThanOrEqual(Date.now());
      expect(sub.plan).toBe('none');
      expect(await hasActivePremiumAnyRole(d._id, role)).toBe(false);
    }
    pills = (await request(app).get('/admin/premium-gifts').set(ADMIN).expect(200)).body.gifts;
    expect(pills).toHaveLength(0);
    for (const [d, M] of [[o, Owner], [s, Sitter], [w, Walker]]) {
      expect((await M.findById(d._id).lean()).isStaff).toBe(false);
    }
    // Retirer une 2e fois : rien à retirer, pas d'erreur.
    expect((await ungift('owner', o._id).expect(200)).body.removed).toBe(false);
    await expectNoPayment();
  });

  test('payé APRÈS le cadeau : retirer garde les jours payés', async () => {
    const o = await mk(Owner);
    await gift('owner', o._id, 1).expect(200); // 30 j offerts
    // L'utilisateur achète 30 j à la suite (comme le fait l'activation : à partir de la fin en cours).
    const sub0 = await UserSubscription.findOne({ userId: o._id, userModel: 'Owner' });
    for (const f of ['premiumExpiry', 'pawspotExpiry', 'currentPeriodEnd']) sub0[f] = new Date(new Date(sub0[f]).getTime() + 30 * DAY);
    await sub0.save();
    await ungift('owner', o._id).expect(200);
    const sub = await subOf(o, 'Owner');
    expect(days(sub.premiumExpiry)).toBe(30);
    expect(sub.status).toBe('active');
  });

  test('les cadeaux d\'avant (sans point de départ) se retirent aussi', async () => {
    const o = await mk(Owner);
    const end = new Date(Date.now() + 25 * DAY);
    await UserSubscription.create({ userId: o._id, userModel: 'Owner', plan: 'premium_monthly', status: 'active',
      currentPeriodEnd: end, pawspotExpiry: end, premiumExpiry: end,
      history: [{ plan: 'premium_monthly', paymentProvider: 'admin_gift', paymentId: 'gift_old', activatedAt: new Date(Date.now() - 5 * DAY), expiresAt: end, intervalDays: 30 }] });
    await ungift('owner', o._id).expect(200);
    const sub = await subOf(o, 'Owner');
    expect(new Date(sub.premiumExpiry).getTime()).toBeLessThanOrEqual(Date.now());
    expect(sub.status).toBe('expired');
  });
});
