// 27/11/2026 (ZOE) — contrôle indépendant du lot « publie ta demande » (services/ownerPublishNudge2711).
// Cherche à le casser : double envoi (deux appels en même temps, deux serveurs), limite 0, préférences coupées,
// demande du jour, erreur au milieu, profils frères. VRAIE base en mémoire, VRAI sendNotification.
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
const dev = (token) => ({ fcmTokens: [token], fcmDevices: [{ token, platform: 'ios', appBuild: 648, at: new Date(NOW - 3600000) }] });
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

describe('ZOE — attaque du lot 2711', () => {
  test('interrupteur : seules les valeurs on/1/true/yes allument ; « off », « non », vide = éteint', () => {
    for (const v of ['off', 'OFF', '0', 'false', 'non', 'no', '', ' ', 'onn', 'oui']) { process.env.OWNER_PUBLISH_NUDGE_2711 = v; expect(svc.enabled()).toBe(false); }
    delete process.env.OWNER_PUBLISH_NUDGE_2711; expect(svc.enabled()).toBe(false);
    for (const v of ['on', 'ON', ' on ', '1', 'true', 'yes']) { process.env.OWNER_PUBLISH_NUDGE_2711 = v; expect(svc.enabled()).toBe(true); }
    process.env.OWNER_PUBLISH_NUDGE_2711 = 'on';
  });

  test('confirm doit être le booléen true : « true » en texte, 1, "oui" → 400, rien ne part', async () => {
    await reset();
    await Owner.create({ ...base, name: 'A', email: 'zoe2711-a@example.test', ...dev('tok-a') });
    for (const c of ['true', 1, 'oui', null]) {
      // eslint-disable-next-line no-await-in-loop
      await request(app).post('/admin/owner-publish-nudge-2711/send').set(ADMIN).send({ confirm: c }).expect(400);
    }
    await wait(150);
    expect(PUSHES).toHaveLength(0);
  }, 60000);

  test('limit 0, négative ou illisible : jamais « tout le monde » par surprise', async () => {
    await reset();
    await Owner.create({ ...base, name: 'A', email: 'zoe2711-a@example.test', ...dev('tok-a') });
    await Owner.create({ ...base, name: 'B', email: 'zoe2711-b@example.test', ...dev('tok-b') });
    await Owner.create({ ...base, name: 'C', email: 'zoe2711-c@example.test', ...dev('tok-c') });
    expect(await svc.sendAll({ now: NOW, limit: 0 })).toMatchObject({ sent: 0, reason: 'bad_limit' });
    for (const l of [0, -5, 'abc', '0', 1.5, '']) {
      // eslint-disable-next-line no-await-in-loop
      const r = await request(app).post('/admin/owner-publish-nudge-2711/send').set(ADMIN).send({ confirm: true, limit: l });
      expect(r.status).toBe(400);
    }
    await wait(150);
    expect(PUSHES).toHaveLength(0);
    expect(await Owner.countDocuments({ publishNudge2711At: { $ne: null } })).toBe(0);
  }, 60000);

  test('deux appels en même temps (même serveur) : une seule notification par personne', async () => {
    await reset();
    for (const k of ['a', 'b', 'c', 'd']) {
      // eslint-disable-next-line no-await-in-loop
      await Owner.create({ ...base, name: k, email: `zoe2711-${k}@example.test`, ...dev(`tok-${k}`) });
    }
    const [x, y, z] = await Promise.all([
      request(app).post('/admin/owner-publish-nudge-2711/send').set(ADMIN).send({ confirm: true }),
      request(app).post('/admin/owner-publish-nudge-2711/send').set(ADMIN).send({ confirm: true }),
      svc.sendAll({ now: NOW }),
    ]);
    await wait(400);
    for (const k of ['a', 'b', 'c', 'd']) expect(pushesTo(`tok-${k}`)).toBe(1);
    expect(await Notification.countDocuments({})).toBe(4);
    expect(MAILS).toHaveLength(0);
    expect([x.body.sent, y.body.sent, z.sent].reduce((s, n) => s + n, 0)).toBe(4);
  }, 60000);

  test('deux SERVEURS en même temps (deux copies du service, sans le verrou en mémoire) : une seule notification par personne', async () => {
    await reset();
    for (const k of ['a', 'b', 'c', 'd', 'e', 'f']) {
      // eslint-disable-next-line no-await-in-loop
      await Owner.create({ ...base, name: k, email: `zoe2711-${k}@example.test`, ...dev(`tok-${k}`) });
    }
    // Deuxième copie du module = deuxième processus : son propre « running », même base.
    let svc2;
    jest.isolateModules(() => {
      jest.doMock('mongoose', () => mongoose);
      jest.doMock('../src/models/Owner', () => Owner);
      jest.doMock('../src/models/Sitter', () => Sitter);
      jest.doMock('../src/models/Walker', () => Walker);
      jest.doMock('../src/models/Post', () => Post);
      svc2 = require('../src/services/ownerPublishNudge2711');
    });
    expect(svc2).not.toBe(svc);
    const real = require('../src/services/notificationSender').sendNotification;
    const [r1, r2] = await Promise.all([svc.sendAll({ now: NOW, send: real }), svc2.sendAll({ now: NOW, send: real })]);
    await wait(400);
    for (const k of ['a', 'b', 'c', 'd', 'e', 'f']) expect(pushesTo(`tok-${k}`)).toBe(1);
    expect(r1.sent + r2.sent).toBe(6);
    expect(await Notification.countDocuments({})).toBe(6);
  }, 60000);

  test('erreur au milieu : les autres partent, la personne en échec n\'est jamais renvoyée (pas de doublon)', async () => {
    await reset();
    const o = {};
    for (const k of ['a', 'b', 'c']) {
      // eslint-disable-next-line no-await-in-loop
      o[k] = await Owner.create({ ...base, name: k, email: `zoe2711-${k}@example.test`, ...dev(`tok-${k}`) });
    }
    const real = require('../src/services/notificationSender').sendNotification;
    let n = 0;
    const flaky = async (args) => { n += 1; if (n === 2) throw new Error('panne simulée'); return real(args); };
    const r = await svc.sendAll({ now: NOW, send: flaky });
    expect(r).toMatchObject({ sent: 2, failed: 1 });
    const again = await svc.sendAll({ now: NOW });
    expect(again.sent).toBe(0);
    await wait(300);
    expect(PUSHES).toHaveLength(2);
    expect(MAILS).toHaveLength(0);
  }, 60000);

  test('notifications « réservations » coupées dans l\'app : aucun push, aucun e-mail', async () => {
    await reset();
    const o = await Owner.create({ ...base, name: 'Coupe', email: 'zoe2711-coupe@example.test', ...dev('tok-coupe'), notificationPrefs: { sound: 'frog', categories: { bookings: false } } });
    const r = await svc.sendAll({ now: NOW });
    await wait(300);
    expect(pushesTo('tok-coupe')).toBe(0);
    expect(MAILS).toHaveLength(0);
    // Compté à part (pas un « échec »), cloche gardée, personne marquée : jamais relancée.
    expect(r).toMatchObject({ sent: 0, prefsOff: 1, failed: 0 });
    expect(await Notification.countDocuments({ recipientId: o._id })).toBe(1);
    expect((await Owner.findById(o._id).lean()).publishNudge2711At).toBeTruthy();
  }, 60000);

  test('demande POUR AUJOURD\'HUI (un seul jour, minuit passé) : encore en ligne pour le produit → pas de notification', async () => {
    await reset();
    const o = await Owner.create({ ...base, name: 'Jour J', email: 'zoe2711-jourj@example.test', ...dev('tok-jourj') });
    const midnight = new Date(NOW); midnight.setUTCHours(0, 0, 0, 0);
    await post(o._id, { startDate: midnight, endDate: midnight });
    expect(require('../src/utils/openRequest1111').isDateOpen({ startDate: midnight, endDate: midnight }, new Date(NOW + 1000))).toBe(true);
    const p = await svc.preview({ now: NOW + 1000 });
    expect(p.items.map((x) => x.ownerId)).not.toContain(String(o._id));
  }, 60000);

  test('demande sans dates (« dates à prévoir ») ou réservée : en ligne → pas de notification ; masquée / close / bannie → notification', async () => {
    await reset();
    const mk = async (k) => Owner.create({ ...base, name: k, email: `zoe2711-${k}@example.test`, ...dev(`tok-${k}`) });
    const sansDates = await mk('sansdates'); await post(sansDates._id, {});
    const future = await mk('future'); await post(future._id, { startDate: new Date(NOW + 5 * 86400000), endDate: new Date(NOW + 6 * 86400000) });
    const masquee = await mk('masquee'); await post(masquee._id, { hidden: true, startDate: new Date(NOW + 5 * 86400000) });
    const close = await mk('close'); await post(close._id, { status: 'closed', closedAt: new Date(NOW - 1000), startDate: new Date(NOW + 5 * 86400000) });
    const photo = await mk('photo'); await Post.collection.insertOne({ ownerId: photo._id, postType: 'media', body: 'photo', hidden: false, status: 'open' });
    const p = await svc.preview({ now: NOW });
    const ids = p.items.map((x) => x.ownerId);
    expect(ids).not.toContain(String(sansDates._id));
    expect(ids).not.toContain(String(future._id));
    expect(ids).toEqual(expect.arrayContaining([String(masquee._id), String(close._id), String(photo._id)]));
  }, 60000);

  test('3 profils de la même personne : une seule notification ; profil propriétaire suspendu ou non vérifié = rien, même si le profil gardien est sain', async () => {
    await reset();
    const trio = await Owner.create({ ...base, name: 'Trio', email: 'zoe2711-trio@example.test', ...dev('tok-trio-o') });
    await Sitter.create({ ...base, name: 'Trio', email: 'zoe2711-trio@example.test', ...dev('tok-trio-s') });
    await Walker.create({ ...base, name: 'Trio', email: 'zoe2711-trio@example.test', ...dev('tok-trio-w') });
    const susp = await Owner.create({ ...base, status: 'suspended', name: 'Susp', email: 'zoe2711-susp@example.test' });
    await Sitter.create({ ...base, name: 'Susp', email: 'zoe2711-susp@example.test', ...dev('tok-susp') });
    const nonv = await Owner.create({ ...base, verified: false, name: 'Nonv', email: 'zoe2711-nonv@example.test' });
    await Sitter.create({ ...base, name: 'Nonv', email: 'zoe2711-nonv@example.test', ...dev('tok-nonv') });
    const r = await svc.sendAll({ now: NOW });
    await wait(300);
    expect(r.sent).toBe(1);
    expect(await Notification.countDocuments({})).toBe(1);
    expect(await Notification.countDocuments({ recipientId: trio._id, recipientRole: 'owner' })).toBe(1);
    expect(PUSHES).toHaveLength(1); // un seul envoi multi-appareils
    expect(PUSHES[0].tokens.sort()).toEqual(['tok-trio-o', 'tok-trio-s', 'tok-trio-w']);
    expect(pushesTo('tok-susp') + pushesTo('tok-nonv')).toBe(0);
    expect((await Owner.findById(susp._id).lean()).publishNudge2711At).toBeNull();
    expect((await Owner.findById(nonv._id).lean()).publishNudge2711At).toBeNull();
    expect(MAILS).toHaveLength(0);
  }, 60000);

  test('règle des 3 profils : équipe ou compte banni sur le profil gardien de la même personne = jamais', async () => {
    await reset();
    const a = await Owner.create({ ...base, name: 'Frere staff', email: 'zoe2711-frerestaff@example.test', ...dev('tok-frerestaff') });
    await Sitter.create({ ...base, isStaff: true, name: 'Frere staff', email: 'zoe2711-frerestaff@example.test' });
    const b = await Owner.create({ ...base, name: 'Frere banni', email: 'zoe2711-frerebanni@example.test' });
    await Sitter.create({ ...base, status: 'banned', name: 'Frere banni', email: 'zoe2711-frerebanni@example.test', ...dev('tok-frerebanni') });
    const p = await svc.preview({ now: NOW });
    const ids = p.items.map((x) => x.ownerId);
    expect(ids).not.toContain(String(a._id));
    expect(ids).not.toContain(String(b._id));
    expect(p.skipped.profil_frere_equipe_ou_bloque).toBe(2);
  }, 60000);

  test('compte d\'AVANT le lot (champ publishNudge2711At absent en base) : prévenu une fois, puis plus jamais', async () => {
    await reset();
    const o = await Owner.create({ ...base, name: 'Ancien', email: 'zoe2711-ancien@example.test', ...dev('tok-ancien') });
    await Owner.collection.updateOne({ _id: o._id }, { $unset: { publishNudge2711At: '' } });
    expect(Object.keys(await Owner.collection.findOne({ _id: o._id }))).not.toContain('publishNudge2711At');
    expect((await svc.sendAll({ now: NOW })).sent).toBe(1);
    expect((await svc.sendAll({ now: NOW })).sent).toBe(0);
    await wait(200);
    expect(pushesTo('tok-ancien')).toBe(1);
  }, 60000);

  test('les 9 langues : gabarit présent, JSON valide, aucune variable, pas d\'e-mail possible même si le canal était oublié ?', async () => {
    const langs = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
    for (const l of langs) {
      // eslint-disable-next-line global-require, import/no-dynamic-require
      const t = require(`../src/locales/${l}/notifications.json`).owner_publish_nudge_2711;
      expect(t).toBeTruthy();
      for (const k of ['title', 'body', 'emailSubject', 'emailBody']) { expect(typeof t[k]).toBe('string'); expect(t[k]).not.toMatch(/\{\{|\}\}|@\w+\b(?!\.)/); }
      expect(t.title.length).toBeLessThanOrEqual(60);
      expect(t.body.length).toBeLessThanOrEqual(178);
    }
    // push réellement rendu dans chaque langue (pas de repli silencieux sur le français)
    await reset();
    for (const l of langs) {
      // eslint-disable-next-line no-await-in-loop
      await Owner.create({ ...base, appLocale: l, language: l, name: l, email: `zoe2711-${l}@example.test`, ...dev(`tok-${l}`) });
    }
    const r = await svc.sendAll({ now: NOW });
    await wait(400);
    expect(r.sent).toBe(9);
    for (const l of langs) {
      // eslint-disable-next-line global-require, import/no-dynamic-require
      const t = require(`../src/locales/${l}/notifications.json`).owner_publish_nudge_2711;
      const p = PUSHES.find((x) => x.tokens.includes(`tok-${l}`));
      expect(JSON.stringify(p)).toContain(JSON.stringify(t.title).slice(1, -1));
      expect(p.data.route).toBe('/posts');
      expect(p.data.recipientRole).toBe('owner');
    }
    expect(MAILS).toHaveLength(0);
  }, 60000);
});
