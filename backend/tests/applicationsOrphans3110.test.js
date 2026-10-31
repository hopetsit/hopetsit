// 3110 (ADA, bug vu par ZOE au contrôle du 631) — GET /applications/my ne renvoie plus les candidatures dont la
// demande a été supprimée (ni masquée, ni fermée + restée pending) ; celles d'une demande existante restent ;
// la route admin de comptage est cohérente. Vraie base Mongo en mémoire, vrai contrôleur, vraie route.
process.env.NODE_ENV = 'test';
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => ({ ok: true })), sendEmailOnly: jest.fn(async () => ({ sent: true })) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
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
const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { isApplicationVisible } = require('../src/utils/applicationsVisible3110');

let mongo; let app; let Owner; let Sitter; let Walker; let Post; let Application; let ctl;
const PASS = 'MotDePasse3110!';
const ADMIN = { 'x-test-user': 'admin1', 'x-test-role': 'admin' };
const list = (user) => new Promise((resolve) => {
  const res = { status() { return this; }, json: (b) => resolve(b) };
  ctl.listApplications({ user, query: {} }, res);
});
const ids = (r) => r.applications.map((a) => String(a.id || a._id)).sort();

let O; let S; let W; let A = {};
beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Post = require('../src/models/Post'); Application = require('../src/models/Application');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Post.init(), Application.init()]);
  ctl = require('../src/controllers/applicationController');
  app = express(); app.use(express.json());
  app.use('/admin/applications-3110', require('../src/routes/adminApplicationsOrphans3110'));

  O = await Owner.create({ name: 'Olga', email: 'o3110@example.org', password: PASS });
  S = await Sitter.create({ name: 'Sam', email: 's3110@example.org', password: PASS });
  W = await Walker.create({ name: 'Wil', email: 'w3110@example.org', password: PASS });
  const pOpen = await Post.create({ ownerId: O._id, body: 'garde ouverte' });
  const pHidden = await Post.create({ ownerId: O._id, body: 'masquee', hidden: true });
  const pClosed = await Post.create({ ownerId: O._id, body: 'terminee', status: 'closed', closedAt: new Date() });
  const pDeleted = await Post.create({ ownerId: O._id, body: 'effacee' });
  const mk = async (k, extra) => { A[k] = await Application.create({ ownerId: O._id, status: 'pending', ...extra }); };
  await mk('openPending', { sitterId: S._id, postId: pOpen._id });
  await mk('deletedPending', { sitterId: S._id, postId: pDeleted._id });
  await mk('noPost', { walkerId: W._id, postId: null });
  await mk('hiddenAccepted', { sitterId: S._id, postId: pHidden._id, status: 'accepted' });
  await mk('closedPending', { walkerId: W._id, postId: pClosed._id });
  await mk('closedAccepted', { sitterId: S._id, postId: pClosed._id, status: 'accepted' });
  await Post.findByIdAndDelete(pDeleted._id); // comme postController.deletePost : suppression physique
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

const K = (...keys) => keys.map((k) => String(A[k]._id)).sort();

test('règle pure : demande absente / masquée / fermée+pending = invisible, le reste visible', () => {
  const pend = { postId: 'p1', status: 'pending' }; const acc = { postId: 'p1', status: 'accepted' };
  expect(isApplicationVisible(pend, undefined)).toBe(false);
  expect(isApplicationVisible(pend, { exists: true, hidden: true, status: 'open' })).toBe(false);
  expect(isApplicationVisible(pend, { exists: true, hidden: false, status: 'closed' })).toBe(false);
  expect(isApplicationVisible(acc, { exists: true, hidden: false, status: 'closed' })).toBe(true);
  expect(isApplicationVisible(pend, { exists: true, hidden: false, status: 'open' })).toBe(true);
  expect(isApplicationVisible({ postId: null, status: 'pending' }, undefined)).toBe(true);
});

test('propriétaire : la candidature de la demande supprimée a disparu, celle de la demande existante reste', async () => {
  const r = await list({ id: String(O._id), role: 'owner' });
  expect(ids(r)).toEqual(K('openPending', 'noPost', 'closedAccepted'));
  expect(r.applications.filter((a) => a.status === 'pending')).toHaveLength(2); // compteur « en attente » = 2, plus 4
  expect(ids(r)).not.toContain(String(A.deletedPending._id));
});

test('gardien et promeneur : même filtre de leur côté', async () => {
  expect(ids(await list({ id: String(S._id), role: 'sitter' }))).toEqual(K('openPending', 'closedAccepted'));
  expect(ids(await list({ id: String(W._id), role: 'walker' }))).toEqual(K('noPost'));
});

test('admin : comptage cohérent, comptes de test à part, aucune donnée personnelle', async () => {
  const T = await Owner.create({ name: 'Test', email: 'dadaciao84+testowner3110@example.org', password: PASS });
  const pT = await Post.create({ ownerId: T._id, body: 'test' });
  await Application.create({ ownerId: T._id, sitterId: S._id, postId: pT._id, status: 'pending' });
  await Post.findByIdAndDelete(pT._id);

  const r = await request(app).get('/admin/applications-3110/orphans').set(ADMIN);
  expect(r.status).toBe(200);
  expect(r.body.total).toBe(7);
  expect(r.body.visible).toBe(3);
  expect(r.body.hidden.total).toBe(4);
  expect(r.body.hidden.reasons).toEqual({ postMissing: 2, postHidden: 1, closedPending: 1 });
  expect(r.body.hidden.byStatus).toEqual({ pending: 3, accepted: 1, rejected: 0 });
  expect(r.body.postIdNull).toBe(1);
  expect(r.body.people).toEqual({ test: 1, real: 3, realPending: 2, realOwners: 1 });
  expect(r.body.examples).toHaveLength(3);
  expect(r.body.examples.map((e) => e.id)).not.toContain(undefined);
  expect(JSON.stringify(r.body)).not.toMatch(/example\.org|Olga|Sam|Wil/);
  expect(typeof r.body.oldestHiddenDays).toBe('number');
  expect((await request(app).get('/admin/applications-3110/orphans').set({ 'x-test-user': 'u', 'x-test-role': 'owner' })).status).toBe(403);
});
