// 2410 (ZOE, 24/10/2026 — demande de BOB / ADA) — GET /admin/ad-leads/stats?days=7 : compteurs des
// contacts de la pub (AdLead2210) pour la ligne « Aujourd'hui » de l'admin. Jamais d'e-mail ni de
// téléphone dans la réponse. VRAIE base Mongo en mémoire, vrai routeur.
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

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let AdLead;
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const OWNER = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'owner' };
const H = 3600000; const DAY = 24 * H;
const NOW = Date.now();
let n = 0;
const lead = (extra = {}) => AdLead.collection.insertOne({
  _id: `${'0'.repeat(30)}${String(++n).padStart(2, '0')}`, metaLeadId: `meta-${n}`, email: `lead${n}@example.com`,
  firstName: 'Prénom', city: 'Paris', country: 'FR', lang: 'fr', service: 'garde', animal: 'chien', quand: 'plus_tard',
  startText: '', endText: '', createdAt: new Date(NOW), ...extra,
});

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  AdLead = require('../src/models/AdLead2210');
  await AdLead.init();
  // aujourd'hui (Paris) : 2 Paris (1 publiée, 1 avec dates du formulaire), 1 New York
  await lead({ city: 'Paris 11e', postId: new mongoose.Types.ObjectId(), confirmedAt: new Date(NOW) });
  await lead({ city: 'Paris', startText: '24/12/2026', endText: '28/12/2026' });
  await lead({ city: 'New York', country: 'US', lang: 'en' });
  // hier : 1 Brooklyn publiée
  await lead({ city: 'Brooklyn', country: 'US', lang: 'en', createdAt: new Date(NOW - DAY), postId: new mongoose.Types.ObjectId(), confirmedAt: new Date(NOW - DAY) });
  // il y a 5 jours : 1 Lyon (autre), dates du formulaire
  await lead({ city: 'Lyon', createdAt: new Date(NOW - 5 * DAY), startText: '1/11', endText: '3/11' });
  // il y a 20 jours : hors fenêtre 7 j (compte dans total seulement)
  await lead({ city: 'Paris', createdAt: new Date(NOW - 20 * DAY), postId: new mongoose.Types.ObjectId() });
  const routes = require('../src/routes/adLeads2210');
  app = express();
  app.use(express.json());
  app.use('/admin/ad-leads', routes.adminRouter);
  app.use('/ad-leads', routes);
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

test('admin seulement : 401 sans session, 403 pour un propriétaire', async () => {
  await request(app).get('/admin/ad-leads/stats?days=7').expect(401);
  await request(app).get('/admin/ad-leads/stats?days=7').set(OWNER).expect(403);
});

test('days=7 : aujourd hui / hier / 7 j, par ville, publiées, avec dates, confirmées, total — sans e-mail', async () => {
  const r = await request(app).get('/admin/ad-leads/stats?days=7').set(ADMIN).expect(200);
  expect(r.body).toMatchObject({
    days: 7, timeZone: 'Europe/Paris', today: 3, yesterday: 1, d7: 5,
    byCity: { paris: 2, nyc: 2, other: 1 }, published: 2, withDates: 2, confirmed: 2, total: 6,
  });
  const txt = JSON.stringify(r.body);
  expect(txt).not.toMatch(/@|Prénom|meta-|lead\d/);
});

test('days=30 englobe le contact de 20 jours ; days absurde ramené entre 1 et 90', async () => {
  const r = await request(app).get('/admin/ad-leads/stats?days=30').set(ADMIN).expect(200);
  expect(r.body).toMatchObject({ days: 30, d7: 6, byCity: { paris: 3, nyc: 2, other: 1 }, published: 3, today: 3 });
  const big = await request(app).get('/admin/ad-leads/stats?days=5000').set(ADMIN).expect(200);
  expect(big.body.days).toBe(90);
  const none = await request(app).get('/admin/ad-leads/stats').set(ADMIN).expect(200);
  expect(none.body.days).toBe(7);
});
