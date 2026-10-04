// 611 (ADA, 04/10/2026) — Daniel : « sur l'admin, pas à jour ». Tirage d'Alhama
// « 1 / 2 » attrapées mais liste « vrais comptes » vide : la capture venait d'un
// compte ÉQUIPE (isStaff). La route renvoie désormais le type de chaque capture
// (real / staff / test) et le détail du tirage ; les chiffres « vrais comptes »
// restent hors équipe et hors test. Vraie base Mongo en mémoire, vraie route ;
// seule l'authentification est simulée.
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

let mongo; let app; let Owner; let Walker; let PawPlush;
const ADMIN = { 'x-test-user': 'admin1', 'x-test-role': 'admin' };
const today = () => new Date().toISOString().slice(0, 10);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Walker = require('../src/models/Walker');
  PawPlush = require('../src/models/PawPlush');
  await Promise.all([Owner.init(), Walker.init(), PawPlush.init()]);
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
  return M.create({ name: `Personne${n}`, email: `ada611_${n}@example.org`, password: 'MotDePasse611!', ...extra });
}
const P = (extra) => PawPlush.create({
  cityKey: 'alhama', cityLabel: 'Alhama de Murcia', day: today(), type: 'bunny',
  location: { type: 'Point', coordinates: [-1.42, 37.85] }, ...extra,
});

describe('611 — captures de peluches : vrai compte / équipe / test', () => {
  let real; let staff; let tester; let b;

  beforeAll(async () => {
    real = await mk(Owner, { city: 'Murcia' });
    staff = await mk(Owner, { isStaff: true, city: 'Murcia' }); // compte équipe (Premium offert)
    tester = await mk(Walker, { email: 'dadaciao84+test611@gmail.com' });
    const now = new Date();
    // Tirage du jour : 4 peluches. 1 par un vrai compte, 1 par l'équipe, 2 libres.
    await P({ slot: 0, caughtByPerson: 'k-real', caughtBy: { userId: String(real._id), role: 'owner', at: now } });
    await P({ slot: 1, caughtByPerson: 'k-staff', caughtBy: { userId: String(staff._id), role: 'owner', at: new Date(now - 60000) } });
    const libre = await P({ slot: 2 });
    await P({ slot: 3 });
    // Essai d'un compte +test : une COPIE, l'original reste libre.
    await P({ cityKey: 'test:alhama:k-test', slot: 2, copyOf: libre._id, testCopy: true, caughtByPerson: 'k-test',
      caughtBy: { userId: String(tester._id), role: 'walker', at: new Date(now - 120000) } });
    b = (await request(app).get('/admin/pawpoints-insights').set(ADMIN).expect(200)).body;
  });

  test('la liste contient TOUTES les captures avec leur type', () => {
    const kinds = b.plush.recent.map((x) => x.kind).sort();
    expect(kinds).toEqual(['real', 'staff', 'test']);
    const staffRow = b.plush.recent.find((x) => x.kind === 'staff');
    expect(staffRow).toMatchObject({ city: 'Alhama de Murcia', role: 'owner', id: String(staff._id).slice(-6), test: false });
    expect(b.plush.recent.find((x) => x.kind === 'test').test).toBe(true);
  });

  test('le tirage dit qui a attrapé, les essais de test à part', () => {
    const d = b.plush.draws.find((x) => x.city === 'Alhama de Murcia');
    expect(d).toMatchObject({ total: 4, caught: 2, caughtReal: 1, caughtStaff: 1, caughtTest: 0, testCopies: 1 });
    expect(b.plush.draws).toHaveLength(1); // la copie de test n'est pas un tirage
  });

  test('statistiques « vrais comptes » inchangées : hors équipe et hors test', () => {
    expect(b.kpis.plush7).toBe(1);
    expect(b.kpis.plush30).toBe(1);
    expect(b.kpis.plush7Staff).toBe(1);
    expect(b.kpis.plush7Test).toBe(1);
    expect(b.kpis.points7).toBe(20); // seule la peluche du vrai compte
    expect(b.kpis.parts30.plush).toBe(20);
    expect(b.kpis.activeUsers30).toBe(1);
  });

  test('aucun e-mail dans la réponse', () => {
    expect(JSON.stringify(b)).not.toMatch(/@/);
  });
});
