// 607 (ADA, 02/10/2026) — GET /admin/pawpoints-insights : lecture seule, admin
// seulement, comptes de test à part, aucune donnée sensible (e-mail, ville non
// publiable). Vraie base Mongo en mémoire, vraie route ; seule l'authentification
// est simulée (en-têtes x-test-user / x-test-role).
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
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let Walker; let PawPointsEvent; let PawPlush; let PawRewardRedemption;
const ADMIN = { 'x-test-user': 'admin1', 'x-test-role': 'admin' };
const today = () => new Date().toISOString().slice(0, 10);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  PawPointsEvent = require('../src/models/PawPointsEvent');
  PawPlush = require('../src/models/PawPlush');
  PawRewardRedemption = require('../src/models/PawRewardRedemption');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), PawPointsEvent.init(), PawPlush.init()]);
  app = express();
  app.use(express.json());
  app.use('/admin/pawpoints-insights', require('../src/routes/adminPawPointsInsights607'));
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

let n = 0;
async function mk(M, extra = {}) {
  n += 1;
  return M.create({ name: `Personne${n}`, email: `ada607_${n}@example.org`, password: 'MotDePasse607!', ...extra });
}
let plushSlot = 0;
async function plush(extra = {}) {
  plushSlot += 1;
  return PawPlush.create({
    cityKey: extra.cityKey || 'paris', cityLabel: extra.cityLabel || 'Paris', day: extra.day || today(),
    slot: plushSlot % 4, type: 'teddy', location: { type: 'Point', coordinates: [2.35, 48.86] }, ...extra,
  });
}

describe('GET /admin/pawpoints-insights', () => {
  test('401 sans jeton, 403 pour un non-admin', async () => {
    await request(app).get('/admin/pawpoints-insights').expect(401);
    await request(app).get('/admin/pawpoints-insights').set({ 'x-test-user': 'u1', 'x-test-role': 'owner' }).expect(403);
  });

  test('base vide : 200 et structure complète à zéro', async () => {
    const r = await request(app).get('/admin/pawpoints-insights').set(ADMIN).expect(200);
    expect(r.body.kpis).toMatchObject({ points7: 0, points30: 0, activeUsers30: 0, redemptions30: 0, plush7: 0, plush7Test: 0 });
    expect(r.body.plush).toMatchObject({ available: true, draws: [], goldenWeek: [], recent: [] });
    expect(r.body.pioneers).toMatchObject({ count: 0, list: [] });
    expect(r.body.links).toMatchObject({ total: 0, providers: 0, noCityCount: 0 });
  });

  test('chiffres réels, test à part, tirages par ville, dorée, Pionniers, liens /s', async () => {
    const real = await mk(Sitter, { city: 'Paris', publicSlug: 'personne-p-paris' });
    const test = await mk(Walker, { email: 'dadaciao84+testwalker@gmail.com', city: 'Paris' });
    const leak = await mk(Sitter, { city: 'quelquun@gmail.com' }); // « ville » = e-mail : jamais publiée
    await mk(Walker, { city: '' }); // prestataire sans ville
    const now = new Date();
    await PawPointsEvent.create([
      { personKey: 'p1', userId: String(real._id), role: 'sitter', key: 'pioneer', points: 200, credited: 200, dedupeKey: 'a', at: now },
      { personKey: 'p1', userId: String(real._id), role: 'sitter', key: 'profileComplete', points: 100, credited: 100, dedupeKey: 'b', at: new Date(Date.now() - 10 * 86400000) },
      { personKey: 'p2', userId: String(test._id), role: 'walker', key: 'pioneer', points: 200, credited: 200, dedupeKey: 'c', at: now },
    ]);
    // Tirage du jour à Paris : 3 peluches dont 1 dorée, 1 attrapée par un vrai compte.
    await plush({ golden: true });
    await plush({ caughtByPerson: 'k-real', caughtBy: { userId: String(real._id), role: 'sitter', at: now } });
    const orig = await plush();
    // Copie d'un compte de test : comptée à part, pas dans le tirage.
    await plush({ slot: 4, copyOf: orig._id, testCopy: true, caughtByPerson: 'k-test',
      caughtBy: { userId: String(test._id), role: 'walker', at: now } });
    await PawRewardRedemption.create({ userId: real._id, userModel: 'Sitter', role: 'sitter', title: 'x', cost: 500, status: 'fulfilled' });
    await PawRewardRedemption.create({ userId: test._id, userModel: 'Walker', role: 'walker', title: 'y', cost: 500, status: 'fulfilled' });

    const r = await request(app).get('/admin/pawpoints-insights').set(ADMIN).expect(200);
    const b = r.body;
    // 7 j : pionnier réel 200 + peluche réelle 20 ; 30 j : + profil 100.
    expect(b.kpis.points7).toBe(220);
    expect(b.kpis.points30).toBe(320);
    expect(b.kpis.activeUsers30).toBe(1);
    expect(b.kpis.plush7).toBe(1);
    expect(b.kpis.plush7Test).toBe(1);
    expect(b.kpis.redemptions30).toBe(1); // l'échange du compte +test est à part
    expect(b.kpis.redemptions30Test).toBe(1);
    const paris = b.plush.draws.find((d) => d.city === 'Paris');
    expect(paris).toMatchObject({ total: 3, golden: 1, caught: 1 });
    expect(b.plush.goldenWeek).toHaveLength(1);
    expect(b.plush.goldenWeek[0]).toMatchObject({ city: 'Paris', caught: false });
    expect(b.plush.recent.filter((p) => p.test)).toHaveLength(1);
    expect(b.pioneers.count).toBe(1);
    expect(b.pioneers.testCount).toBe(1);
    expect(b.links.total).toBe(1);
    expect(b.links.providers).toBe(3); // le compte +test n'est pas compté
    expect(b.links.noCityCount).toBe(2);
    expect(b.links.noCity.map((x) => x.reason).sort()).toEqual(['empty', 'unsafe']);
    // Jamais d'e-mail ni de « ville » non publiable dans la réponse.
    const raw = JSON.stringify(b);
    expect(raw).not.toMatch(/@/);
    expect(raw).not.toMatch(/gmail/);
    expect(raw).not.toContain(String(leak._id)); // identifiants courts seulement
  });
});
