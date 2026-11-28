// 27/11/2026 (BOB, accord de Daniel « oui fais les 5 points ») — « PUBLIE TA DEMANDE DEPUIS L'APP ».
// VRAI routeur admin, VRAIE base Mongo en mémoire, VRAI sendNotification (Firebase et e-mail simulés).
// Prouve que : seuls les propriétaires VÉRIFIÉS, qui ont l'APP (jeton push sur la personne) et AUCUNE demande en ligne
// sont retenus ; jamais un compte de test, de l'équipe ou interne ; interrupteur éteint (défaut) = rien ne part ;
// allumé = UN push par personne, cloche créée, route /posts, AUCUN e-mail ; un deuxième envoi ne renvoie rien.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  requireVerifiedEmail: (req, res, next) => next(),
  attachUserFromToken: (req, res, next) => next(),
  attachOwnerFromToken: (req, res, next) => next(),
  optionalAuth: (req, res, next) => next(),
}));
const MAILS = [];
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async (to, subject) => { MAILS.push({ to, subject }); return { messageId: 'mock' }; }), sendTemplateEmail: jest.fn(async () => ({})) };
});
const PUSHES = [];
jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({
    send: jest.fn(),
    sendEachForMulticast: jest.fn(async (m) => { PUSHES.push(m); return { successCount: m.tokens.length, failureCount: 0, responses: m.tokens.map(() => ({ success: true })) }; }),
  }),
}));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0), emitToConversation: jest.fn(), emitChatMessage: jest.fn(),
  isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false), touchConversationOpen: jest.fn(async () => {}),
  buildPresenceIndex: jest.fn(async () => new Map()), isIdentityOnline: jest.fn(() => false),
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const ADMIN = { 'x-test-user': 'admin1', 'x-test-role': 'admin' };
const PASS = 'MotDePasseTest2711!';
const NOW = Date.now(); // les routes admin lisent l'heure réelle
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
let mongo; let app; let Owner; let Sitter; let Post; let Notification; let svc;
const S = {};
const dev = (token, platform = 'ios', appBuild = 648) => ({ fcmTokens: [token], fcmDevices: [{ token, platform, appBuild, at: new Date(NOW - 3600000) }] });

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); require('../src/models/Walker');
  Post = require('../src/models/Post'); Notification = require('../src/models/Notification');
  await Promise.all([Owner.init(), Sitter.init(), Post.init()]);
  const base = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, appLocale: 'fr', acceptedTerms: true };
  // 1) la cible : vérifiée, a l'app, aucune demande.
  S.ok = await Owner.create({ ...base, name: 'Claire Cible', email: 'bob2711-claire@example.test', ...dev('tok-claire') });
  // 2) vérifiée, en anglais, l'app est sur son profil GARDIEN (même e-mail) : la personne a l'app.
  S.viaSitter = await Owner.create({ ...base, name: 'Nancy Deux', email: 'bob2711-nancy@example.test', country: 'US', appLocale: 'en' });
  await Sitter.create({ ...base, name: 'Nancy Deux', email: 'bob2711-nancy@example.test', country: 'US', ...dev('tok-nancy', 'android') });
  // 3) sans app → écartée.
  S.noApp = await Owner.create({ ...base, name: 'Meela Sansapp', email: 'bob2711-meela@example.test' });
  // 4) e-mail non vérifié → écartée.
  S.unverified = await Owner.create({ ...base, verified: false, name: 'Paul Nonverif', email: 'bob2711-paul@example.test', ...dev('tok-paul') });
  // 5) a une demande EN LIGNE → écartée.
  S.hasPost = await Owner.create({ ...base, name: 'Andrea Demande', email: 'bob2711-andrea@example.test', ...dev('tok-andrea') });
  // 6) n'a qu'une demande PASSÉE → retenue.
  S.oldPost = await Owner.create({ ...base, name: 'Carol Passee', email: 'bob2711-carol@example.test', ...dev('tok-carol') });
  // 7-9) test, équipe, interne → jamais.
  S.test = await Owner.create({ ...base, name: 'Camille Test', email: 'bob2711+test@example.test', ...dev('tok-test') });
  S.staff = await Owner.create({ ...base, isStaff: true, name: 'Equipe', email: 'bob2711-staff@example.test', ...dev('tok-staff') });
  S.internal = await Owner.create({ ...base, name: 'Interne', email: 'hopetsit@example.test', ...dev('tok-interne') });
  // 10) compte suspendu → jamais.
  S.banned = await Owner.create({ ...base, status: 'banned', name: 'Banni', email: 'bob2711-banni@example.test', ...dev('tok-banni') });
  const d = (n) => new Date(NOW + n * 86400000);
  const post = (ownerId, start, end) => Post.collection.insertOne({ ownerId, postType: 'request', body: 'Zone test', startDate: start, endDate: end, hidden: false, status: 'open', createdAt: new Date(NOW - 86400000), updatedAt: new Date(NOW - 86400000) });
  await post(S.hasPost._id, d(10), d(12));
  await post(S.oldPost._id, d(-20), d(-18));
  svc = require('../src/services/ownerPublishNudge2711');
  app = express();
  app.use(express.json());
  app.use('/admin', require('../src/routes/adminRoutes'));
}, 180000);
afterAll(async () => {
  delete process.env.OWNER_PUBLISH_NUDGE_2711;
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
}, 60000);

describe('2711 — notification « publie ta demande » (push seul)', () => {
  test('routes réservées à l\'admin', async () => {
    await request(app).get('/admin/owner-publish-nudge-2711/preview').expect(401);
    await request(app).get('/admin/owner-publish-nudge-2711/preview').set({ 'x-test-user': 'u', 'x-test-role': 'owner' }).expect(403);
    await request(app).post('/admin/owner-publish-nudge-2711/send').set({ 'x-test-user': 'u', 'x-test-role': 'owner' }).send({ confirm: true }).expect(403);
  });

  test('aperçu : 3 personnes retenues (cible, app sur le profil gardien, demande passée), les autres écartées avec la raison', async () => {
    const r = await request(app).get('/admin/owner-publish-nudge-2711/preview').set(ADMIN).expect(200);
    expect(r.body.enabled).toBe(false);
    expect(r.body.count).toBe(3);
    expect(r.body.items.map((x) => x.ownerId).sort()).toEqual([S.ok, S.viaSitter, S.oldPost].map((x) => String(x._id)).sort());
    expect(r.body.byCountry).toEqual({ FR: 2, US: 1 });
    expect(r.body.byLang).toEqual({ fr: 2, en: 1 });
    expect(r.body.byPlatform).toEqual({ ios: 2, android: 1 });
    expect(r.body.skipped).toMatchObject({ test_ou_equipe: 3, sans_app: 1, demande_en_ligne: 1 });
    expect(JSON.stringify(r.body)).not.toMatch(/example\.test/); // aucune adresse e-mail dans l'aperçu
    expect(PUSHES).toHaveLength(0);
    expect(await Owner.countDocuments({ publishNudge2711At: { $ne: null } })).toBe(0);
  }, 60000);

  test('interrupteur éteint (défaut) : sans confirm 400, avec confirm 409, rien ne part, rien n\'est marqué', async () => {
    delete process.env.OWNER_PUBLISH_NUDGE_2711;
    await request(app).post('/admin/owner-publish-nudge-2711/send').set(ADMIN).send({}).expect(400);
    const r = await request(app).post('/admin/owner-publish-nudge-2711/send').set(ADMIN).send({ confirm: true }).expect(409);
    expect(r.body).toMatchObject({ code: 'NUDGE_OFF', sent: 0 });
    expect(await svc.sendAll({ now: NOW })).toMatchObject({ sent: 0, reason: 'off' });
    await wait(200);
    expect(PUSHES).toHaveLength(0);
    expect(MAILS).toHaveLength(0);
    expect(await Owner.countDocuments({ publishNudge2711At: { $ne: null } })).toBe(0);
    expect(await Notification.countDocuments({})).toBe(0);
  }, 60000);

  test('allumé : limit 1 = un seul envoi, puis le reste ; push dans la langue, route /posts, cloche, AUCUN e-mail', async () => {
    process.env.OWNER_PUBLISH_NUDGE_2711 = 'on';
    const a = await request(app).post('/admin/owner-publish-nudge-2711/send').set(ADMIN).send({ confirm: true, limit: 1 }).expect(200);
    expect(a.body).toMatchObject({ sent: 1, noToken: 0, failed: 0, remaining: 2 });
    const b = await request(app).post('/admin/owner-publish-nudge-2711/send').set(ADMIN).send({ confirm: true }).expect(200);
    expect(b.body).toMatchObject({ sent: 2, noToken: 0, failed: 0, remaining: 0, alreadySent: 1 });
    await wait(500);
    expect(PUSHES).toHaveLength(3);
    const byTok = Object.fromEntries(PUSHES.map((p) => [p.tokens[0], p]));
    expect(Object.keys(byTok).sort()).toEqual(['tok-carol', 'tok-claire', 'tok-nancy']);
    const fr = byTok['tok-claire'];
    expect(JSON.stringify(fr)).toContain('Besoin de faire garder ton animal');
    expect(fr.data.route).toBe('/posts');
    expect(fr.data.type).toBe('owner_publish_nudge_2711');
    expect(JSON.stringify(byTok['tok-nancy'])).toContain('Need someone to look after your pet');
    expect(MAILS).toHaveLength(0);
    expect(await Notification.countDocuments({ type: 'owner_publish_nudge_2711' })).toBe(3);
    expect(await Owner.countDocuments({ publishNudge2711At: { $ne: null } })).toBe(3);
    for (const k of ['noApp', 'unverified', 'hasPost', 'test', 'staff', 'internal', 'banned']) {
      // eslint-disable-next-line no-await-in-loop
      expect((await Owner.findById(S[k]._id).lean()).publishNudge2711At).toBeNull();
    }
  }, 60000);

  test('jamais deux fois : un nouvel envoi ne part chez personne, l\'aperçu est vide', async () => {
    const r = await request(app).post('/admin/owner-publish-nudge-2711/send').set(ADMIN).send({ confirm: true }).expect(200);
    expect(r.body).toMatchObject({ sent: 0, alreadySent: 3, remaining: 0 });
    await wait(300);
    expect(PUSHES).toHaveLength(3);
    expect(MAILS).toHaveLength(0);
    const p = await request(app).get('/admin/owner-publish-nudge-2711/preview').set(ADMIN).expect(200);
    expect(p.body).toMatchObject({ enabled: true, count: 0 });
    expect(p.body.skipped.deja_envoye).toBe(3);
  }, 60000);
});
