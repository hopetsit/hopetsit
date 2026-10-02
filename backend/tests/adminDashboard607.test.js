// 607 (ADA, 02/10/2026) — (1) GET /admin/dashboard607 : tuiles du tableau de bord, lecture
// seule, comptes de test à part. (2) Les vérifications d'identité (3 €) donnent le MÊME
// total sur les 4 écrans : Paiements (/admin/payments), Mes revenus et Comptabilité
// (/admin/payouts), Tableau de bord et Boutique (/admin/shop-revenue, /admin/boosts).
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

let mongo; let app; let Owner; let Sitter; let Walker; let Post; let PawPointsEvent;
const ADMIN = { 'x-test-user': 'admin1', 'x-test-role': 'admin' };
let n = 0;
async function mk(M, extra = {}) {
  n += 1;
  return M.create({ name: `Personne${n}`, email: `dash607_${n}@example.org`, password: 'MotDePasse607!', ...extra });
}

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Post = require('../src/models/Post');
  PawPointsEvent = require('../src/models/PawPointsEvent');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), PawPointsEvent.init()]);
  app = express();
  app.use(express.json());
  app.use('/admin/dashboard607', require('../src/routes/adminDashboard607'));
  app.use('/admin', require('../src/routes/adminRoutes'));
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

function findKey(obj, key) {
  if (!obj || typeof obj !== 'object') return undefined;
  if (Object.prototype.hasOwnProperty.call(obj, key)) return obj[key];
  for (const v of Object.values(obj)) {
    const r = findKey(v, key);
    if (r !== undefined) return r;
  }
  return undefined;
}

describe('GET /admin/dashboard607', () => {
  test('401 sans jeton, 403 pour un non-admin', async () => {
    await request(app).get('/admin/dashboard607').expect(401);
    await request(app).get('/admin/dashboard607').set({ 'x-test-user': 'u', 'x-test-role': 'owner' }).expect(403);
  });

  test('tuiles : comptes réels comptés, comptes de test à part, aucune adresse e-mail', async () => {
    const owner = await mk(Owner, { verified: true, city: 'Paris' });
    await mk(Owner, { email: 'quelquun+test@gmail.com' });
    const sitter = await mk(Sitter, { kycStatus: 'verified', kycVerifiedAt: new Date(), kycPaidAt: new Date(), city: 'Paris' });
    await mk(Walker, { kycPaidAt: new Date(Date.now() - 3 * 86400000) }); // payé, pas vérifié
    await Post.collection.insertOne({ ownerId: owner._id, postType: 'request', createdAt: new Date(), body: 'x' });
    await PawPointsEvent.create({ personKey: 'p', userId: String(sitter._id), role: 'sitter', key: 'walkCompleted', points: 15, credited: 15, dedupeKey: 'w1', at: new Date() });

    const r = await request(app).get('/admin/dashboard607').set(ADMIN).expect(200);
    const t = r.body.tiles;
    expect(r.body.days).toHaveLength(14);
    expect(t.signups.value7).toBe(3);
    expect(t.signups.test7d).toBe(1);
    expect(t.signups.byRole7d).toEqual({ owner: 1, sitter: 1, walker: 1 });
    expect(t.signups.series).toHaveLength(14);
    expect(t.emailVerified.total).toBe(1);
    expect(t.identity.verified).toBe(1);
    expect(t.identity.paidUnverified).toBe(1);
    expect(t.identity.oldestPaidUnverifiedH).toBeGreaterThanOrEqual(71);
    expect(t.requests.value7).toBe(1);
    expect(t.walks.today).toBe(1);
    expect(t.pawpoints.value7).toBe(15);
    expect(JSON.stringify(r.body)).not.toMatch(/@/);
  });
});

describe('vérifications d\'identité : même total sur les 4 écrans', () => {
  test('Paiements = Mes revenus = Comptabilité = Tableau de bord / Boutique', async () => {
    await Promise.all([Sitter.deleteMany({}), Walker.deleteMany({}), Owner.deleteMany({})]);
    await mk(Sitter, { kycPaidAt: new Date('2026-09-18T10:56:50Z'), kycStatus: 'pending_verification' });
    await mk(Walker, { kycPaidAt: new Date(), kycStatus: 'verified', kycVerifiedAt: new Date() });

    const pay = await request(app).get('/admin/payments?limit=1000').set(ADMIN).expect(200);
    const rev = await request(app).get('/admin/payouts').set(ADMIN).expect(200); // Mes revenus + Comptabilité
    const shop = await request(app).get('/admin/shop-revenue').set(ADMIN).expect(200); // Tableau de bord
    const boosts = await request(app).get('/admin/boosts?limit=1000').set(ADMIN).expect(200); // Boutique

    const paiements = pay.body.summary.kycTotal;
    const revenus = rev.body.summary.boutiqueBreakdown.kyc.total;
    const kycShop = findKey(shop.body.periods.allTime, 'kyc');
    const tableau = kycShop && kycShop.gross;
    const boutique = (boosts.body.purchases || []).filter((p) => p.shopProduct === 'kyc')
      .reduce((a, p) => a + Number(p.gross || p.amount || 0), 0);

    expect(paiements).toBe(6);
    expect(revenus).toBe(6);
    expect(tableau).toBe(6);
    expect(boutique).toBe(6);
    // Une ligne datée par paiement dans la liste des paiements (dont celle du 18/09).
    const lignes = pay.body.payments.filter((p) => p.type === 'kyc');
    expect(lignes).toHaveLength(2);
    expect(lignes.some((p) => String(p.paidAt).startsWith('2026-09-18'))).toBe(true);
  });
});
