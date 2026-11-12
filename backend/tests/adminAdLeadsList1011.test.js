// 10/11/2026 (BOB) — liste admin des demandes pub : étape par demande, jamais d'e-mail, tests à part.
// VRAIE base Mongo en mémoire, zone fictive pour les comptes de test, aucun réseau.
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
jest.mock('../src/middleware/auditAdmin', () => ({ auditAdmin: (req, res, next) => next() }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let AdLead;
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const lead = (o) => ({ metaLeadId: `m-${Math.random()}`, email: 'quelquun@domaine-reel.fr', firstName: 'Zoé', city: 'Ville réelle', lat: 10, lng: 10, country: 'FR', ...o });

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  AdLead = require('../src/models/AdLead2210');
  await AdLead.init();
  app = express();
  app.use(express.json());
  app.use('/admin/ad-leads-1011', require('../src/routes/adminAdLeadsList1011'));
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

test('réservé à l’admin', async () => {
  expect((await request(app).get('/admin/ad-leads-1011/list')).status).toBe(401);
  expect((await request(app).get('/admin/ad-leads-1011/list').set({ 'x-test-user': 'u', 'x-test-role': 'owner' })).status).toBe(403);
});

test('étapes avant publication, champs 1011, aucun e-mail, tests comptés à part', async () => {
  await AdLead.create([
    lead({ firstName: 'Recu' }),
    lead({ firstName: 'Mail', confirmEmailAt: new Date(), service: 'journee', timeFrom: '10:00', timeTo: '18:30', noCar: true, budget: 20, postalCode: '75015', source: 'site' }),
    lead({ firstName: 'Clic', confirmEmailAt: new Date(), clickedAt: new Date() }),
    lead({ firstName: 'Test', email: 'lea+test1011@example.com', lat: -35, lng: -30 }),
    lead({ firstName: 'Vieux', createdAt: new Date(Date.now() - 30 * 86400000) }),
  ]);
  const r = await request(app).get('/admin/ad-leads-1011/list?days=14').set(ADMIN);
  expect(r.status).toBe(200);
  expect(r.body.total).toBe(3);
  expect(r.body.excludedTest).toBe(1);
  expect(r.body.counters).toMatchObject({ recu: 1, email_envoye: 1, clique: 1, publiee: 0, paye: 0 });
  expect(r.body.extras).toEqual({ journee: 1, horaires: 1, sansVoiture: 1, budget: 1, codePostal: 1 });
  const mail = r.body.items.find((x) => x.firstName === 'Mail');
  expect(mail).toMatchObject({ step: 'email_envoye', source: 'site', service: 'journee', timeFrom: '10:00', timeTo: '18:30', noCar: true, budget: 20, postalCode: '75015' });
  expect(mail.blocked).toMatch(/cliqué/);
  expect(JSON.stringify(r.body)).not.toMatch(/@|domaine-reel/);
  r.body.items.forEach((x) => { expect(x).not.toHaveProperty('email'); expect(x).not.toHaveProperty('phone'); });
  const site = await request(app).get('/admin/ad-leads-1011/list?source=site').set(ADMIN);
  expect(site.body.items.map((x) => x.firstName)).toEqual(['Mail']);
  const meta = await request(app).get('/admin/ad-leads-1011/list?source=meta').set(ADMIN);
  expect(meta.body.total).toBe(2);
});

test('étapes après publication (calcul pur)', () => {
  const { _stepOf } = require('../src/routes/adminAdLeadsList1011');
  const j = (o) => ({ stages: { applications: { count: 0 }, decision: { state: 'none' }, payment: { state: 'none' }, ...o } });
  expect(_stepOf({ postId: 'x' }, null, 0)).toBe('publiee');
  expect(_stepOf({}, j({}), 0)).toBe('publiee');
  expect(_stepOf({}, j({ applications: { count: 2 } }), 0)).toBe('candidats');
  expect(_stepOf({}, j({ applications: { count: 2 } }), 3)).toBe('candidats_vus');
  expect(_stepOf({}, j({ applications: { count: 2 }, decision: { state: 'accepted' } }), 3)).toBe('choisi');
  expect(_stepOf({}, j({ decision: { state: 'accepted' }, payment: { state: 'paid' } }), 0)).toBe('paye');
});

// 12/11/2026 (BOB) — accords SMS : seuls ceux qui ont coché, sans STOP, avec une demande publiée.
describe('accords SMS (1211)', () => {
  const P = new mongoose.Types.ObjectId();
  let okId;
  beforeAll(async () => {
    const docs = await AdLead.create([
      lead({ firstName: 'Coche', country: 'US', lang: 'en', postId: P, smsPhone: '+12125550123', smsConsentAt: new Date() }),
      lead({ firstName: 'Stop', country: 'US', postId: P, smsPhone: '+12125550124', smsConsentAt: new Date(), smsOptOutAt: new Date() }),
      lead({ firstName: 'SansCase', country: 'US', postId: P, smsPhone: '+12125550125' }),
      lead({ firstName: 'SansDemande', country: 'US', smsPhone: '+12125550126', smsConsentAt: new Date() }),
      lead({ firstName: 'Test', email: 'lea+test1211@example.com', country: 'US', postId: P, smsPhone: '+12125550127', smsConsentAt: new Date() }),
    ]);
    okId = String(docs[0]._id);
  });

  test('réservé à l’admin', async () => {
    expect((await request(app).get('/admin/ad-leads-1011/sms-consents')).status).toBe(401);
    expect((await request(app).get('/admin/ad-leads-1011/sms-consents').set({ 'x-test-user': 'u', 'x-test-role': 'owner' })).status).toBe(403);
    expect((await request(app).post('/admin/ad-leads-1011/sms-optout').send({ id: okId })).status).toBe(401);
  });

  test('ne renvoie que la personne qui a coché, sans e-mail', async () => {
    const r = await request(app).get('/admin/ad-leads-1011/sms-consents').set(ADMIN);
    expect(r.status).toBe(200);
    expect(r.body.items.map((i) => i.firstName)).toEqual(['Coche']);
    expect(r.body.items[0]).toMatchObject({ id: okId, phone: '+12125550123', lang: 'en', country: 'US', postId: String(P) });
    expect(JSON.stringify(r.body)).not.toMatch(/@/);
  });

  test('STOP noté → la personne sort de la liste ; identifiant inconnu → 404', async () => {
    expect((await request(app).post('/admin/ad-leads-1011/sms-optout').set(ADMIN).send({ id: 'x' })).status).toBe(404);
    expect((await request(app).post('/admin/ad-leads-1011/sms-optout').set(ADMIN).send({ id: 'a'.repeat(32) })).status).toBe(404);
    expect((await request(app).post('/admin/ad-leads-1011/sms-optout').set(ADMIN).send({ id: okId })).status).toBe(200);
    const r = await request(app).get('/admin/ad-leads-1011/sms-consents').set(ADMIN);
    expect(r.body.total).toBe(0);
  });
});
