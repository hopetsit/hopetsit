// 0511 (BOB) — webhook Meta leadgen : vérification GET, contact créé à la seconde (AdLead + brouillon +
// e-mail « confirme »), jamais deux fois, formulaire inconnu ignoré, signature vérifiée quand un secret
// est configuré, admin protégé. Vraie base Mongo en mémoire, Graph et Nominatim simulés.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'a'.repeat(64);

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  optionalAuth: (req, res, next) => next(),
}));
jest.mock('../src/middleware/auditAdmin', () => ({ auditAdmin: (req, res, next) => next() }));
const MAILS = [];
jest.mock('../src/services/emailService', () => ({
  sendEmail: jest.fn(async (to, subject, text, html) => { MAILS.push({ to, subject, text, html }); return { messageId: 'mock' }; }),
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const crypto = require('crypto');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let routes; let AdLead;
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// le travail se fait APRÈS la réponse 200 (bcrypt du compte créé ≈ 200 ms) : on attend la condition, 8 s max
const waitFor = async (fn, ms = 8000) => { const t0 = Date.now(); for (;;) { if (await fn()) return true; if (Date.now() - t0 > ms) return false; await sleep(100); } };

const GRAPH_LEADS = {
  L1: { id: 'L1', form_id: '111', field_data: [{ name: 'first_name', values: ['léa durand'] }, { name: 'email', values: ['Lea.Test0511@Example.com'] }, { name: 'phone_number', values: ['+33600000000'] }, { name: 'post_code', values: ['75011'] }, { name: 'service', values: ['garde'] }, { name: 'animal', values: ['chien'] }, { name: 'quand', values: ['bientot'] }, { name: 'date_debut', values: ['20/12/2026'] }, { name: 'date_fin', values: ['27/12/2026'] }] },
  L2: { id: 'L2', form_id: '111', field_data: [{ name: 'email', values: ['pas-un-email'] }] },
};
const fakeFetch = jest.fn(async (url) => {
  const u = String(url);
  if (u.includes('graph.facebook.com')) {
    const id = u.split('/').pop().split('?')[0];
    return { ok: !!GRAPH_LEADS[id], status: GRAPH_LEADS[id] ? 200 : 404, json: async () => GRAPH_LEADS[id] || {} };
  }
  if (u.includes('nominatim')) return { ok: true, json: async () => [{ lat: '48.8590', lon: '2.3800', address: { city: 'Paris' } }] };
  return { ok: false, status: 500, json: async () => ({}) };
});

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  AdLead = require('../src/models/AdLead2210'); await AdLead.init();
  routes = require('../src/routes/metaLeadgen0511');
  routes.deps = { fetch: fakeFetch };
  app = express();
  app.use('/webhooks/meta-leadgen', express.json({ verify: (req, res, buf) => { req.rawBody = buf; } }), routes);
  app.use('/admin/meta-leadgen', express.json(), routes.adminRouter);
}, 60000);

afterAll(async () => { await mongoose.disconnect(); await mongo.stop(); });

const event = (leadgenId, formId = '111') => ({ object: 'page', entry: [{ id: '1106995342506270', changes: [{ field: 'leadgen', value: { leadgen_id: leadgenId, form_id: formId, page_id: '1106995342506270' } }] }] });

test('config admin (protégée), vérification GET, contact créé une seule fois avec brouillon + e-mail, formulaire inconnu ignoré', async () => {
  expect((await request(app).put('/admin/meta-leadgen/config').send({ pageToken: 'x' })).status).toBe(401);
  const c = await request(app).put('/admin/meta-leadgen/config').set(ADMIN).send({ pageToken: 'PAGE_TOKEN_TEST', verifyToken: 'verif-0511', forms: { 111: 'paris', 222: 'nyc', abc: 'paris', 333: 'lyon' } });
  expect(c.status).toBe(200); expect(c.body.configured).toBe(true); expect(c.body.forms).toEqual({ 111: 'paris', 222: 'nyc' });
  // le jeton est chiffré en base, jamais renvoyé
  const cfg = await routes.Config.findOne({ key: 'main' }).lean();
  expect(cfg.pageTokenEnc.startsWith('gcm:')).toBe(true); expect(JSON.stringify(c.body)).not.toContain('PAGE_TOKEN_TEST');
  // vérification Meta
  expect((await request(app).get('/webhooks/meta-leadgen?hub.mode=subscribe&hub.verify_token=mauvais&hub.challenge=42')).status).toBe(403);
  const v = await request(app).get('/webhooks/meta-leadgen?hub.mode=subscribe&hub.verify_token=verif-0511&hub.challenge=42');
  expect(v.status).toBe(200); expect(v.text).toBe('42');
  // contact L1 → créé, position par code postal, brouillon + e-mail « un clic pour publier »
  const p1 = await request(app).post('/webhooks/meta-leadgen').send(event('L1'));
  expect(p1.status).toBe(200);
  const ok1 = await waitFor(async () => (await AdLead.findOne({ metaLeadId: 'L1' }).lean() || {}).confirmEmailAt);
  if (!ok1) console.log('ÉVÉNEMENTS', JSON.stringify(await routes.Event.find({}).lean()), JSON.stringify(await AdLead.findOne({}).lean()));
  expect(ok1).toBe(true);
  const leads = await AdLead.find({}).lean();
  expect(leads).toHaveLength(1);
  expect(leads[0]).toMatchObject({ metaLeadId: 'L1', email: 'lea.test0511@example.com', firstName: 'Léa', city: 'Paris', country: 'FR', lang: 'fr', service: 'garde', animal: 'chien', quand: 'bientot', startText: '20/12/2026', endText: '27/12/2026', source: 'meta', pendingConfirm: true });
  expect(leads[0].lat).toBeCloseTo(48.859, 2);
  expect(leads[0].ownerId).toBeTruthy(); expect(leads[0].postId).toBeFalsy();
  expect(MAILS.filter((m) => m.to === 'lea.test0511@example.com')).toHaveLength(1);
  expect(MAILS[0].subject).toBe('Léa, un clic pour publier ta demande');
  // le même contact renvoyé par Meta (ou relu par le Mac) → rien de plus
  await request(app).post('/webhooks/meta-leadgen').send(event('L1'));
  expect(await waitFor(async () => (await routes.Event.countDocuments({ status: 'existing' })) === 1)).toBe(true);
  expect(await AdLead.countDocuments({})).toBe(1); expect(MAILS).toHaveLength(1);
  // e-mail invalide → ignoré ; formulaire inconnu → ignoré ; contact inconnu chez Meta → erreur notée
  await request(app).post('/webhooks/meta-leadgen').send(event('L2'));
  await request(app).post('/webhooks/meta-leadgen').send(event('L1', '999'));
  await request(app).post('/webhooks/meta-leadgen').send(event('L404'));
  expect(await waitFor(async () => (await routes.Event.countDocuments({})) === 5)).toBe(true);
  expect(await AdLead.countDocuments({})).toBe(1);
  const st = await request(app).get('/admin/meta-leadgen/status').set(ADMIN);
  expect(st.status).toBe(200); expect(st.body.configured).toBe(true);
  expect(st.body.counts7d).toEqual({ created: 1, existing: 1, ignored: 2, error: 1 });
  expect(JSON.stringify(st.body)).not.toContain('PAGE_TOKEN_TEST');
}, 40000);

test('signature X-Hub-Signature-256 exigée dès qu\'un secret d\'app est configuré', async () => {
  await request(app).put('/admin/meta-leadgen/config').set(ADMIN).send({ appSecret: 'app-secret-test' });
  const body = JSON.stringify(event('L1'));
  expect((await request(app).post('/webhooks/meta-leadgen').set('Content-Type', 'application/json').send(body)).status).toBe(403);
  const sig = 'sha256=' + crypto.createHmac('sha256', 'app-secret-test').update(body).digest('hex');
  expect((await request(app).post('/webhooks/meta-leadgen').set('Content-Type', 'application/json').set('X-Hub-Signature-256', sig).send(body)).status).toBe(200);
}, 20000);
