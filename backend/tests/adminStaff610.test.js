// 610 (ADA, 04/10/2026) — Daniel : « dans Utilisateurs et Inscriptions, je n'ai plus
// mettre en staff / premium / tout débloquer ». L'action de l'admin reste
// POST /admin/users/:role/:id/staff (badge staff = tout débloqué gratuitement :
// abonnements, boosts, PawBoost, chat). On vérifie, sur une vraie base Mongo en mémoire :
// donner puis retirer s'applique aux 3 profils de la personne (même e-mail), quel que soit
// le profil d'où l'on part, sans toucher aux autres personnes, sans créer aucun paiement ;
// et la lecture GET /admin/premium-gifts (pastille « Premium offert »). Seule
// l'authentification est simulée.
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

let mongo; let app; let Owner; let Sitter; let Walker; let UserSubscription;
const ADMIN = { 'x-test-user': 'admin1', 'x-test-role': 'admin' };
let n = 0;
const mk = (M, extra = {}) => { n += 1; return M.create({ name: `Personne${n}`, email: `staff610_${n}@example.org`, password: 'MotDePasse610!', ...extra }); };
const staffOf = async (doc, M) => (await M.findById(doc._id).select('isStaff').lean()).isStaff;
const setStaff = (role, id, isStaff) => request(app).post(`/admin/users/${role}/${id}/staff`).set(ADMIN).send({ isStaff });

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  UserSubscription = require('../src/models/UserSubscription');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), UserSubscription.init()]);
  app = express();
  app.use(express.json());
  app.use('/admin', require('../src/routes/adminRoutes'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });
beforeEach(async () => {
  await Promise.all([Owner.deleteMany({}), Sitter.deleteMany({}), Walker.deleteMany({}), UserSubscription.deleteMany({})]);
});

describe('POST /admin/users/:role/:id/staff — Staff / Premium : tout débloquer', () => {
  test('401 sans connexion, 403 pour un non-admin, 400 rôle inconnu, 404 compte absent', async () => {
    const o = await mk(Owner);
    await request(app).post(`/admin/users/owner/${o._id}/staff`).send({ isStaff: true }).expect(401);
    await request(app).post(`/admin/users/owner/${o._id}/staff`).set({ 'x-test-user': 'u1', 'x-test-role': 'owner' })
      .send({ isStaff: true }).expect(403);
    await setStaff('admin', o._id, true).expect(400);
    await setStaff('owner', new mongoose.Types.ObjectId(), true).expect(404);
    expect(await staffOf(o, Owner)).toBe(false);
  });

  for (const [from, M] of [['owner', 'Owner'], ['sitter', 'Sitter'], ['walker', 'Walker']]) {
    test(`donner puis retirer depuis le profil ${from} : les 3 profils suivent, les autres personnes non`, async () => {
      const o = await mk(Owner);
      const s = await Sitter.create({ name: o.name, email: o.email, password: 'MotDePasse610!' });
      const w = await Walker.create({ name: o.name, email: o.email, password: 'MotDePasse610!' });
      const other = await mk(Owner);
      const otherSitter = await mk(Sitter);
      const start = { Owner: o, Sitter: s, Walker: w }[M];

      const on = await setStaff(from, start._id, true).expect(200);
      expect(on.body.isStaff).toBe(true);
      expect(on.body.profiles).toEqual({ owner: 1, sitter: 1, walker: 1 });
      expect([await staffOf(o, Owner), await staffOf(s, Sitter), await staffOf(w, Walker)]).toEqual([true, true, true]);
      expect([await staffOf(other, Owner), await staffOf(otherSitter, Sitter)]).toEqual([false, false]);
      // « tout débloquer » : la porte utilisée par abonnements / boosts / PawBoost
      const { isStaffPerson } = require('../src/utils/staffAccess589');
      for (const d of [o, s, w]) expect(await isStaffPerson(d._id)).toBe(true);
      expect(await isStaffPerson(other._id)).toBe(false);
      // aucun paiement ni abonnement fabriqué
      expect(await UserSubscription.countDocuments({})).toBe(0);

      const off = await setStaff(from, start._id, false).expect(200);
      expect(off.body.isStaff).toBe(false);
      expect(off.body.profiles).toEqual({ owner: 1, sitter: 1, walker: 1 });
      expect([await staffOf(o, Owner), await staffOf(s, Sitter), await staffOf(w, Walker)]).toEqual([false, false, false]);
      for (const d of [o, s, w]) expect(await isStaffPerson(d._id)).toBe(false);
      expect(await UserSubscription.countDocuments({})).toBe(0);
    });
  }

  test('personne avec un seul profil : profiles = 1 / 0 / 0', async () => {
    const w = await mk(Walker);
    const r = await setStaff('walker', w._id, true).expect(200);
    expect(r.body.profiles).toEqual({ owner: 0, sitter: 0, walker: 1 });
    expect(await staffOf(w, Walker)).toBe(true);
  });
});

describe('GET /admin/premium-gifts — pastille « Premium offert »', () => {
  test('403 non-admin ; ne liste que les Premium offerts par l\'admin et encore en cours, sans e-mail', async () => {
    await request(app).get('/admin/premium-gifts').set({ 'x-test-user': 'u1', 'x-test-role': 'owner' }).expect(403);
    const o = await mk(Owner);
    const paid = await mk(Sitter);
    const expired = await mk(Walker);
    const future = new Date(Date.now() + 30 * 86400000);
    await UserSubscription.create({ userId: o._id, userModel: 'Owner', plan: 'premium_monthly', status: 'active', premiumExpiry: future,
      history: [{ plan: 'premium_monthly', paymentProvider: 'admin_gift', paymentId: 'gift_1', activatedAt: new Date(), expiresAt: future }] });
    await UserSubscription.create({ userId: paid._id, userModel: 'Sitter', plan: 'premium_monthly', status: 'active', premiumExpiry: future,
      history: [{ plan: 'premium_monthly', paymentProvider: 'airwallex', paymentId: 'pay_1', activatedAt: new Date(), expiresAt: future }] });
    await UserSubscription.create({ userId: expired._id, userModel: 'Walker', plan: 'premium_monthly', status: 'active', premiumExpiry: new Date(Date.now() - 86400000),
      history: [{ plan: 'premium_monthly', paymentProvider: 'admin_gift', paymentId: 'gift_2', activatedAt: new Date(), expiresAt: new Date() }] });
    const r = await request(app).get('/admin/premium-gifts').set(ADMIN).expect(200);
    expect(r.body.gifts).toHaveLength(1);
    expect(r.body.gifts[0]).toMatchObject({ userId: String(o._id), role: 'owner' });
    expect(JSON.stringify(r.body)).not.toMatch(/@/);
  });
});
