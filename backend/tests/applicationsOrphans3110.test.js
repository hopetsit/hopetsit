// 3110 (ADA, bug vu par ZOE au contrôle du 631) — GET /applications/my ne renvoie plus les candidatures dont la
// demande a été supprimée (ni masquée, ni fermée + restée pending) ; celles d'une demande existante restent ;
// la route admin de comptage est cohérente. Vraie base Mongo en mémoire, vrai contrôleur, vraie route.
process.env.NODE_ENV = 'test';
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => ({ ok: true })), sendEmailOnly: jest.fn(async () => ({ sent: true })) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
jest.mock('../src/middleware/auditAdmin', () => ({ auditAdmin: (req, res, next) => next() }));
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
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

test('ARCHIVAGE (ordre de Daniel 31/10) : simulation puis archivage des orphelines ; archivées = hors de tout ; rien supprimé', async () => {
  const total = await Application.countDocuments({});
  const dry = await request(app).post('/admin/applications-3110/archive-orphans').set(ADMIN).send({}).expect(200);
  expect(dry.body.dryRun).toBe(true);
  expect(dry.body.toArchive).toBe(3); // deletedPending + hiddenAccepted + celle du compte test (demande effacée)
  expect(dry.body.reasons).toEqual({ postMissing: 2, postHidden: 1 });
  expect(dry.body.archived).toBe(0);
  expect(await Application.countDocuments({ archivedAt: { $ne: null } })).toBe(0);
  const run = await request(app).post('/admin/applications-3110/archive-orphans').set(ADMIN).send({ dryRun: false }).expect(200);
  expect(run.body.archived).toBe(3);
  expect(await Application.countDocuments({})).toBe(total); // rien supprimé
  expect(await Application.countDocuments({ archivedAt: { $ne: null } })).toBe(3);
  expect((await Application.findById(A.deletedPending._id)).archivedReason).toBe('post_missing');
  expect((await Application.findById(A.hiddenAccepted._id)).archivedReason).toBe('post_hidden');
  // comptage : archivées à part, il ne reste que la « fermée + pending » hors app
  const r = await request(app).get('/admin/applications-3110/orphans').set(ADMIN).expect(200);
  expect(r.body.archived).toBe(3);
  expect(r.body.total).toBe(total - 3);
  expect(r.body.hidden.total).toBe(1);
  expect(r.body.hidden.reasons).toEqual({ postMissing: 0, postHidden: 0, closedPending: 1 });
  // 2e archivage : plus rien à faire
  expect((await request(app).post('/admin/applications-3110/archive-orphans').set(ADMIN).send({ dryRun: false }).expect(200)).body.archived).toBe(0);
  // l'app ne les voit toujours pas
  expect(ids(await list({ id: String(O._id), role: 'owner' }))).toEqual(K('openPending', 'noPost', 'closedAccepted'));
});

test('deletePost (propriétaire) : les candidatures de la demande sont archivées au moment de l\'effacement', async () => {
  const pc = require('../src/controllers/postController');
  const p = await Post.create({ ownerId: O._id, body: 'à effacer' });
  const a1 = await Application.create({ ownerId: O._id, sitterId: S._id, postId: p._id, status: 'pending' });
  const a2 = await Application.create({ ownerId: O._id, walkerId: W._id, postId: p._id, status: 'rejected' });
  expect(ids(await list({ id: String(O._id), role: 'owner' }))).toContain(String(a1._id));
  const res = await new Promise((resolve) => {
    const r = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json: (b) => resolve({ status: r.statusCode, body: b }) };
    pc.deletePost({ params: { id: String(p._id) }, user: { id: String(O._id), role: 'owner' } }, r);
  });
  expect(res.status).toBe(200);
  expect(res.body.archivedApplications).toBe(2);
  expect(await Post.findById(p._id)).toBeNull();
  for (const a of [a1, a2]) {
    // eslint-disable-next-line no-await-in-loop
    const d = await Application.findById(a._id);
    expect(d).toBeTruthy(); // jamais supprimée
    expect(d.archivedAt).toBeTruthy();
    expect(d.archivedReason).toBe('post_deleted');
  }
  const owner = await list({ id: String(O._id), role: 'owner' });
  expect(ids(owner)).not.toContain(String(a1._id));
  expect(ids(owner)).not.toContain(String(a2._id));
});
