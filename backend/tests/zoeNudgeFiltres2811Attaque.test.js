// 28/11/2026 (ZOE) — contrôle indépendant des FILTRES d'envoi de « publie ta demande » (countries, minBuild) et de
// l'exclusion des désabonnés, ajoutés par BOB le 28/11. VRAIE base en mémoire, VRAIE route admin, VRAI sendNotification.
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
const NOW = Date.now();
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
let mongo; let app; let Owner; let Sitter; let Walker; let Post; let Notification; let svc;
const base = { password: 'MotDePasseTest2711!', city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, appLocale: 'fr', acceptedTerms: true };
const dev = (token) => ({ fcmTokens: [token], fcmDevices: [{ token, platform: 'ios', appBuild: 646, at: new Date(NOW - 3600000) }] });
const pushesTo = (tok) => PUSHES.filter((p) => p.tokens.includes(tok)).length;
const reset = async () => {
  await Promise.all([Owner.deleteMany({}), Sitter.deleteMany({}), Walker.deleteMany({}), Post.deleteMany({}), Notification.deleteMany({})]);
  PUSHES.length = 0; MAILS.length = 0;
};
const post = (ownerId, fields) => Post.collection.insertOne({ ownerId, postType: 'request', body: 'Zone test', hidden: false, status: 'open', createdAt: new Date(NOW - 86400000), ...fields });

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Post = require('../src/models/Post'); Notification = require('../src/models/Notification');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Post.init()]);
  svc = require('../src/services/ownerPublishNudge2711');
  app = express();
  app.use(express.json());
  app.use('/admin', require('../src/routes/adminRoutes'));
  process.env.OWNER_PUBLISH_NUDGE_2711 = 'on';
}, 180000);
afterAll(async () => {
  delete process.env.OWNER_PUBLISH_NUDGE_2711;
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
}, 60000);


const SEND = (body) => request(app).post('/admin/owner-publish-nudge-2711/send').set(ADMIN).send({ confirm: true, ...body });
const devB = (token, appBuild, ageMs = 3600000) => ({ token, platform: 'ios', appBuild, at: new Date(NOW - ageMs) });
const marked = async (id) => !!(await Owner.findById(id).lean()).publishNudge2711At;

describe('ZOE — attaque des filtres du 28/11', () => {
  test('minBuild 648 par la route : 648 reçoit ; 646, build inconnu (0) et jeton sans appareil connu ne reçoivent pas ET ne sont pas marqués (renvoi possible plus tard)', async () => {
    await reset();
    const a = await Owner.create({ ...base, name: 'A', email: 'zf-a@example.test', fcmTokens: ['t-a'], fcmDevices: [devB('t-a', 648)] });
    const b = await Owner.create({ ...base, name: 'B', email: 'zf-b@example.test', fcmTokens: ['t-b'], fcmDevices: [devB('t-b', 646)] });
    const c = await Owner.create({ ...base, name: 'C', email: 'zf-c@example.test', fcmTokens: ['t-c'], fcmDevices: [devB('t-c', 0)] });
    const d = await Owner.create({ ...base, name: 'D', email: 'zf-d@example.test', fcmTokens: ['t-d'] });
    const r = await SEND({ minBuild: 648 });
    await wait(300);
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ sent: 1, remaining: 0, failed: 0 });
    expect(pushesTo('t-a')).toBe(1);
    for (const t of ['t-b', 't-c', 't-d']) expect(pushesTo(t)).toBe(0);
    expect(await marked(a._id)).toBe(true);
    for (const o of [b, c, d]) expect(await marked(o._id)).toBe(false); // eslint-disable-line no-await-in-loop
    expect(await Notification.countDocuments({})).toBe(1);
    expect(MAILS).toHaveLength(0);
    // Les écartés par le filtre restent dans l'aperçu.
    const p = await request(app).get('/admin/owner-publish-nudge-2711/preview').set(ADMIN);
    expect(p.body.count).toBe(3);
  }, 60000);

  test('plusieurs appareils : c\'est le PLUS RÉCENT qui décide ; ancien téléphone encore enregistré → il reçoit aussi le push (limite connue)', async () => {
    await reset();
    // Récent = 648, ancien = 640 : retenu, et les DEUX jetons reçoivent.
    await Owner.create({ ...base, name: 'Deux', email: 'zf-deux@example.test', fcmTokens: ['t-new', 't-old'], fcmDevices: [devB('t-old', 640, 30 * 86400000), devB('t-new', 648, 3600000)] });
    // Récent = 640 (ancienne tablette rouverte hier), 648 plus ancien : écarté.
    const inv = await Owner.create({ ...base, name: 'Inverse', email: 'zf-inv@example.test', fcmTokens: ['t-i648', 't-i640'], fcmDevices: [devB('t-i648', 648, 5 * 86400000), devB('t-i640', 640, 3600000)] });
    const r = await SEND({ minBuild: 648 });
    await wait(300);
    expect(r.body.sent).toBe(1);
    expect(pushesTo('t-new')).toBe(1);
    expect(pushesTo('t-old')).toBe(1); // ← l'ancien appareil reçoit : sur lui, la cloche ne mène nulle part
    expect(pushesTo('t-i648')).toBe(0);
    expect(pushesTo('t-i640')).toBe(0);
    expect(await marked(inv._id)).toBe(false);
  }, 60000);

  test('règle des 3 profils : app à jour sur le profil GARDIEN de la même personne → retenue, push envoyé pour le profil propriétaire', async () => {
    await reset();
    const o = await Owner.create({ ...base, name: 'Multi', email: 'zf-multi@example.test' });
    await Sitter.create({ ...base, name: 'Multi', email: 'zf-multi@example.test', fcmTokens: ['t-sit'], fcmDevices: [devB('t-sit', 648)] });
    const r = await SEND({ minBuild: 648 });
    await wait(300);
    expect(r.body.sent).toBe(1);
    expect(pushesTo('t-sit')).toBe(1);
    const push = PUSHES.find((p) => p.tokens.includes('t-sit'));
    expect(push.data.recipientRole).toBe('owner');
    expect(push.data.type).toBe('owner_publish_nudge_2711');
    expect(push.data.route).toBe('/posts');
    expect(await marked(o._id)).toBe(true);
  }, 60000);

  test('pays : FR seul ; pays inconnu (« ? ») jamais atteint par un filtre pays ; les autres ne sont pas marqués', async () => {
    await reset();
    const fr = await Owner.create({ ...base, name: 'FR', email: 'zf-fr@example.test', country: 'FR', fcmTokens: ['t-fr'], fcmDevices: [devB('t-fr', 648)] });
    const us = await Owner.create({ ...base, name: 'US', email: 'zf-us@example.test', country: 'US', fcmTokens: ['t-us'], fcmDevices: [devB('t-us', 648)] });
    const no = await Owner.create({ ...base, name: 'NO', email: 'zf-no@example.test', country: '', fcmTokens: ['t-no'], fcmDevices: [devB('t-no', 648)] });
    for (const bad of [['?'], [], 'FR', ['France'], [''], [null], {}, 0, false]) {
      // eslint-disable-next-line no-await-in-loop
      const r = await SEND({ countries: bad });
      expect(r.status).toBe(400);
      expect(r.body.code).toBe('BAD_FILTER');
    }
    await wait(150);
    expect(PUSHES).toHaveLength(0);
    expect(await Owner.countDocuments({ publishNudge2711At: { $ne: null } })).toBe(0);
    const r = await SEND({ countries: ['fr'], minBuild: '648' });
    await wait(300);
    expect(r.body.sent).toBe(1);
    expect(pushesTo('t-fr')).toBe(1);
    expect(pushesTo('t-us')).toBe(0);
    expect(pushesTo('t-no')).toBe(0);
    expect(await marked(fr._id)).toBe(true);
    expect(await marked(us._id)).toBe(false);
    expect(await marked(no._id)).toBe(false);
  }, 60000);

  test('un code pays illisible MÉLANGÉ à un bon (« FR », « Etats-Unis ») : rien ne part (faute de frappe = pas d\'envoi partiel)', async () => {
    await reset();
    await Owner.create({ ...base, name: 'FR', email: 'zf-fr@example.test', country: 'FR', fcmTokens: ['t-fr'], fcmDevices: [devB('t-fr', 648)] });
    const r = await SEND({ countries: ['FR', 'Etats-Unis'] });
    await wait(150);
    expect(r.status).toBe(400);
    expect(PUSHES).toHaveLength(0);
  }, 60000);

  test('minBuild et limit illisibles (true, [648], {}, 648.5, « 648abc », 0, -1, « ») : 400, rien ne part, personne marqué', async () => {
    await reset();
    await Owner.create({ ...base, name: 'A', email: 'zf-a@example.test', fcmTokens: ['t-a'], fcmDevices: [devB('t-a', 648)] });
    for (const bad of [true, false, [648], {}, 648.5, '648abc', 0, -1, '', ' ']) {
      // eslint-disable-next-line no-await-in-loop
      const r = await SEND({ minBuild: bad });
      expect([bad, r.status]).toEqual([bad, 400]);
    }
    for (const bad of [true, [5], {}]) {
      // eslint-disable-next-line no-await-in-loop
      const r = await SEND({ limit: bad });
      expect([bad, r.status]).toEqual([bad, 400]);
    }
    await wait(150);
    expect(PUSHES).toHaveLength(0);
    expect(await Owner.countDocuments({ publishNudge2711At: { $ne: null } })).toBe(0);
  }, 60000);

  test('désabonné des messages marketing : écarté, y compris quand le désabonnement est posé sur son profil GARDIEN ou PROMENEUR (même personne)', async () => {
    await reset();
    await Owner.create({ ...base, name: 'Direct', email: 'zf-direct@example.test', marketingOptOut: true, fcmTokens: ['t-direct'], fcmDevices: [devB('t-direct', 648)] });
    await Owner.create({ ...base, name: 'ViaSit', email: 'zf-viasit@example.test', fcmTokens: ['t-viasit'], fcmDevices: [devB('t-viasit', 648)] });
    await Sitter.create({ ...base, name: 'ViaSit', email: 'zf-viasit@example.test', marketingOptOut: true });
    await Owner.create({ ...base, name: 'ViaWalk', email: 'zf-viawalk@example.test', fcmTokens: ['t-viawalk'], fcmDevices: [devB('t-viawalk', 648)] });
    await Walker.create({ ...base, name: 'ViaWalk', email: 'zf-viawalk@example.test', marketingOptOut: true });
    await Owner.create({ ...base, name: 'Libre', email: 'zf-libre@example.test', fcmTokens: ['t-libre'], fcmDevices: [devB('t-libre', 648)] });
    const p = await request(app).get('/admin/owner-publish-nudge-2711/preview').set(ADMIN);
    expect(p.body.count).toBe(1);
    const r = await SEND({});
    await wait(300);
    expect(r.body.sent).toBe(1);
    expect(pushesTo('t-libre')).toBe(1);
    for (const t of ['t-direct', 't-viasit', 't-viawalk']) expect(pushesTo(t)).toBe(0);
    expect(await Notification.countDocuments({})).toBe(1);
  }, 60000);

  test('limit + filtres : la limite compte les personnes APRÈS filtre, « remaining » aussi', async () => {
    await reset();
    for (const k of ['a', 'b', 'c']) {
      // eslint-disable-next-line no-await-in-loop
      await Owner.create({ ...base, name: k, email: `zf-${k}@example.test`, country: 'FR', fcmTokens: [`t-${k}`], fcmDevices: [devB(`t-${k}`, 648)] });
    }
    await Owner.create({ ...base, name: 'vieux', email: 'zf-vieux@example.test', country: 'FR', fcmTokens: ['t-vieux'], fcmDevices: [devB('t-vieux', 600)] });
    const r = await SEND({ countries: ['FR'], minBuild: 648, limit: 2 });
    await wait(300);
    expect(r.body).toMatchObject({ sent: 2, remaining: 1 });
    const r2 = await SEND({ countries: ['FR'], minBuild: 648, limit: 2 });
    await wait(300);
    expect(r2.body).toMatchObject({ sent: 1, remaining: 0 });
    expect(pushesTo('t-vieux')).toBe(0);
    expect(PUSHES).toHaveLength(3);
  }, 60000);
  test('PLANCHER 648 : sans minBuild, un appareil 647 ou inconnu ne reçoit rien ; minBuild plus bas que 648 → 400 ; l\'aperçu dit combien partiraient vraiment', async () => {
    await reset();
    const neuf = await Owner.create({ ...base, name: 'Neuf', email: 'zf-neuf@example.test', fcmTokens: ['t-neuf'], fcmDevices: [devB('t-neuf', 648)] });
    const vieux = await Owner.create({ ...base, name: 'Vieux', email: 'zf-vieux@example.test', fcmTokens: ['t-vieux'], fcmDevices: [devB('t-vieux', 647)] });
    const inconnu = await Owner.create({ ...base, name: 'Inconnu', email: 'zf-inconnu@example.test', fcmTokens: ['t-inconnu'] });
    const p = await request(app).get('/admin/owner-publish-nudge-2711/preview').set(ADMIN);
    expect(p.body).toMatchObject({ count: 3, sendable: 1, minBuildFloor: 648 });
    for (const low of [1, 600, 647, '647']) {
      // eslint-disable-next-line no-await-in-loop
      const r = await SEND({ minBuild: low });
      expect([low, r.status, r.body.code]).toEqual([low, 400, 'BAD_FILTER']);
    }
    expect(await svc.sendAll({ now: NOW, minBuild: 647 })).toMatchObject({ sent: 0, reason: 'bad_filter' });
    await wait(150);
    expect(PUSHES).toHaveLength(0);
    const r = await SEND({});
    await wait(300);
    expect(r.body).toMatchObject({ sent: 1, remaining: 0 });
    expect(pushesTo('t-neuf')).toBe(1);
    expect(pushesTo('t-vieux')).toBe(0);
    expect(pushesTo('t-inconnu')).toBe(0);
    expect(await marked(neuf._id)).toBe(true);
    expect(await marked(vieux._id)).toBe(false);
    expect(await marked(inconnu._id)).toBe(false);
    // Plus tard, une fois l'app mise à jour : la personne redevient atteignable (elle n'a pas été marquée).
    await Owner.updateOne({ _id: vieux._id }, { $set: { fcmDevices: [devB('t-vieux', 649, 1000)] } });
    const r2 = await SEND({ minBuild: 649 });
    await wait(300);
    expect(r2.body.sent).toBe(1);
    expect(pushesTo('t-vieux')).toBe(1);
  }, 60000);
  test('ownerProfileOnly : app ouverte en GARDIEN (dernier appareil enregistré sous ce profil) → comptée dans l\'aperçu, écartée de l\'envoi et NON marquée ; valeur illisible → 400', async () => {
    await reset();
    // A : seulement propriétaire. B : même personne, dernier enregistrement sous le profil gardien. C : l'inverse (revenue en propriétaire).
    const a = await Owner.create({ ...base, name: 'A', email: 'zp-a@example.test', fcmTokens: ['t-a'], fcmDevices: [devB('t-a', 648)] });
    const b = await Owner.create({ ...base, name: 'B', email: 'zp-b@example.test', fcmTokens: ['t-b-o'], fcmDevices: [devB('t-b-o', 648, 5 * 86400000)] });
    await Sitter.create({ ...base, name: 'B', email: 'zp-b@example.test', fcmTokens: ['t-b-s'], fcmDevices: [devB('t-b-s', 648, 3600000)] });
    const c = await Owner.create({ ...base, name: 'C', email: 'zp-c@example.test', fcmTokens: ['t-c-o'], fcmDevices: [devB('t-c-o', 648, 3600000)] });
    await Walker.create({ ...base, name: 'C', email: 'zp-c@example.test', fcmTokens: ['t-c-w'], fcmDevices: [devB('t-c-w', 648, 5 * 86400000)] });
    const p = await request(app).get('/admin/owner-publish-nudge-2711/preview').set(ADMIN);
    expect(p.body.count).toBe(3);
    expect(p.body.byLastDeviceRole).toEqual({ owner: 2, sitter: 1 });
    for (const bad of ['true', 1, 'oui', [], {}]) {
      // eslint-disable-next-line no-await-in-loop
      const r = await SEND({ ownerProfileOnly: bad });
      expect([bad, r.status, r.body.code]).toEqual([bad, 400, 'BAD_FILTER']);
    }
    await wait(150);
    expect(PUSHES).toHaveLength(0);
    const r = await SEND({ ownerProfileOnly: true });
    await wait(300);
    expect(r.body).toMatchObject({ sent: 2, remaining: 0 });
    expect(pushesTo('t-a')).toBe(1);
    expect(pushesTo('t-c-o')).toBe(1);
    expect(pushesTo('t-b-o') + pushesTo('t-b-s')).toBe(0);
    expect(await marked(a._id)).toBe(true);
    expect(await marked(c._id)).toBe(true);
    expect(await marked(b._id)).toBe(false);
    // Sans le filtre (ou false), B part aussi : choix laissé à l'envoyeur.
    const r2 = await SEND({ ownerProfileOnly: false });
    await wait(300);
    expect(r2.body.sent).toBe(1);
    expect(await marked(b._id)).toBe(true);
  }, 60000);
});
