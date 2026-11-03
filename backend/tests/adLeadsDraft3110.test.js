// 3110 (ADA, ORDRE DE DANIEL 31/10 via BOB : « dans la pub, au moins l'e-mail vérifié ») — contact pub → compte NON
// vérifié + BROUILLON (rien publié, 0 gardien prévenu) + e-mail « confirme » ; le clic vérifie, publie et prévient
// UNE fois ; rappel unique à +24 h, jamais la nuit, langue du contact, +test exclu ; stats « en attente / confirmés ».
// Vraie base Mongo en mémoire, vrai createPost, zone fictive (−35/−30), aucun e-mail réel (emailService simulé).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.POSTAL_GEOCODE = 'off';
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => null), leadOwnerEmailLink: jest.fn(async (r, u, l) => l) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
const MAILS = [];
jest.mock('../src/services/emailService', () => ({
  sendEmail: jest.fn(async (to, subject, text, html) => { MAILS.push({ to, subject, text, html }); return { messageId: 'mock' }; }),
  sendTemplatedEmail: jest.fn(async () => ({})),
}));
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => { const id = req.headers['x-test-user']; if (!id) return res.status(401).json({ error: 'auth' }); req.user = { id, role: req.headers['x-test-role'] || 'owner' }; return next(); },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  optionalAuth: (req, res, next) => next(),
}));

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Post; let AdLead; let ns; let reminder;
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const BROWSER = { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Safari/604.1' };
const H = 3600 * 1000;
let n = 0;
const register = (extra = {}) => { n += 1; return request(app).post('/admin/ad-leads').set(ADMIN).send({ metaLeadId: `meta_draft_${n}`, email: `contact${n}.draft3110@example.test`, firstName: 'Léa', city: 'Zone test', lat: -35, lng: -30, country: 'FR', lang: 'fr', service: 'garde', animal: 'chien', quand: 'bientot', ...extra }).expect(200); };
const mailsTo = (email) => MAILS.filter((m) => m.to === email);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Post = require('../src/models/Post'); AdLead = require('../src/models/AdLead2210');
  await Promise.all([Owner.init(), Post.init(), AdLead.init()]);
  ns = require('../src/services/notificationSender');
  reminder = require('../src/services/adLeadConfirmReminder3110');
  const routes = require('../src/routes/adLeads2210');
  app = express(); app.use(express.json());
  app.use('/admin/ad-leads', routes.adminRouter);
  app.use('/ad-leads', routes);
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

test('brouillon : compte NON vérifié, AUCUNE demande, 0 gardien prévenu, 1 e-mail « un clic pour publier » (pas deux)', async () => {
  const r0 = await register();
  const id = r0.body.id;
  const email = `contact${n}.draft3110@example.test`;
  const postsBefore = await Post.countDocuments({});
  const notifBefore = ns.sendNotification.mock.calls.length;
  const r = await request(app).post(`/admin/ad-leads/${id}/draft`).set(ADMIN).send({}).expect(200);
  expect(r.body.pending).toBe(true);
  expect(r.body.emailSent).toBe(true);
  expect(r.body.postId).toBeNull();
  const owner = await Owner.findOne({ email });
  expect(owner).toBeTruthy();
  expect(owner.verified).toBe(false);
  expect(owner.adLeadAt).toBeTruthy();
  expect(await Post.countDocuments({})).toBe(postsBefore);
  expect(ns.sendNotification.mock.calls.length).toBe(notifBefore);
  const lead = await AdLead.findById(id).lean();
  expect(lead.pendingConfirm).toBe(true);
  expect(lead.postId == null).toBe(true);
  expect(lead.confirmEmailAt).toBeTruthy();
  const m = mailsTo(email);
  expect(m).toHaveLength(1);
  expect(m[0].subject).toBe('Léa, un clic pour publier ta demande');
  expect(m[0].text).toContain(`/posts/confirmer?l=${id}&utm_source=meta`);
  expect(m[0].text).not.toMatch(/\bvous\b/i);
  // 2e appel du suivi : idempotent, pas de 2e e-mail
  const r2 = await request(app).post(`/admin/ad-leads/${id}/draft`).set(ADMIN).send({}).expect(200);
  expect(r2.body.emailSent).toBe(false);
  expect(mailsTo(email)).toHaveLength(1);
  expect(await Owner.countDocuments({ email })).toBe(1);
  // GET public : pas confirmé, pas de postId
  const g = await request(app).get(`/ad-leads/${id}`).expect(200);
  expect(g.body.confirmed).toBe(false);
  expect(g.body.postId).toBeUndefined();
  // sans admin : 401
  await request(app).post(`/admin/ad-leads/${id}/draft`).send({}).expect(401);
});

test('clic dans la boîte (vrai navigateur) : e-mail vérifié + demande publiée + session ; 2e clic = même demande, rien de plus', async () => {
  const lead = await AdLead.findOne({ pendingConfirm: true, postId: null }).lean();
  const postsBefore = await Post.countDocuments({});
  const c = await request(app).post(`/ad-leads/${lead._id}/confirm`).set(BROWSER).send({}).expect(200);
  expect(c.body.postId).toMatch(/^[a-f0-9]{24}$/);
  expect(typeof c.body.notified === 'number' || c.body.notified === undefined).toBe(true);
  const owner = await Owner.findOne({ email: lead.email });
  expect(owner.verified).toBe(true);
  expect(jwt.verify(c.body.token, process.env.JWT_SECRET)).toMatchObject({ id: String(owner._id), role: 'owner' });
  expect(await Post.countDocuments({})).toBe(postsBefore + 1);
  const p = await Post.findById(c.body.postId).lean();
  expect(String(p.ownerId)).toBe(String(owner._id));
  expect(p.status).toBe('open');
  const after = await AdLead.findById(lead._id).lean();
  expect(after.pendingConfirm).toBe(false);
  expect(after.clickedAt).toBeTruthy();
  expect(String(after.postId)).toBe(c.body.postId);
  const notifAfterFirst = ns.sendNotification.mock.calls.length;
  const c2 = await request(app).post(`/ad-leads/${lead._id}/confirm`).set(BROWSER).send({}).expect(200);
  expect(c2.body.postId).toBe(c.body.postId);
  expect(await Post.countDocuments({})).toBe(postsBefore + 1);
  expect(ns.sendNotification.mock.calls.length).toBe(notifAfterFirst);
  // /draft après publication : alreadyPublished, rien ne change
  const d = await request(app).post(`/admin/ad-leads/${lead._id}/draft`).set(ADMIN).send({}).expect(200);
  expect(d.body.alreadyPublished).toBe(true);
  expect(mailsTo(lead.email)).toHaveLength(1);
});

test('+test : brouillon refusé (403), aucun compte, aucun e-mail', async () => {
  const r0 = await register({ email: 'dadaciao84+testlead3110@gmail.com' });
  const r = await request(app).post(`/admin/ad-leads/${r0.body.id}/draft`).set(ADMIN).send({}).expect(403);
  expect(r.body.code).toBe('TEST_ACCOUNT');
  expect(await Owner.countDocuments({ email: 'dadaciao84+testlead3110@gmail.com' })).toBe(0);
  expect(mailsTo('dadaciao84+testlead3110@gmail.com')).toHaveLength(0);
});

test('rappel +3 h : une seule fois, en journée seulement, langue du contact ; +test jamais', async () => {
  // Repère temporel du test : demain 15 h UTC (16 h Paris, 10-11 h New York) ; les âges sont relatifs à ce repère.
  const day = new Date(); day.setUTCHours(15, 0, 0, 0); day.setUTCDate(day.getUTCDate() + 1);
  const night = new Date(day.getTime() + 11 * H); // 02 h UTC le lendemain = 03 h Paris, 21-22 h New York : nuit des deux côtés
  const mk = async (extra, agoMs) => {
    const r0 = await register(extra);
    await request(app).post(`/admin/ad-leads/${r0.body.id}/draft`).set(ADMIN).send({}).expect(200);
    await AdLead.updateOne({ _id: r0.body.id }, { $set: { confirmEmailAt: new Date(day.getTime() - agoMs) } });
    return r0.body.id;
  };
  const fr = await mk({}, 25 * H);
  const en = await mk({ lang: 'en', country: 'US', city: 'Zone test' }, 26 * H);
  const tooSoon = await mk({}, 1 * H); // 03/11 : rappel à +3 h
  const r0t = await register({ email: 'dadaciao84+testrappel3110@gmail.com' });
  await AdLead.updateOne({ _id: r0t.body.id }, { $set: { pendingConfirm: true, confirmEmailAt: new Date(day.getTime() - 30 * H) } });
  const frEmail = (await AdLead.findById(fr).lean()).email; const enEmail = (await AdLead.findById(en).lean()).email;

  // Nuit à Paris (03 h) ET à New York (21 h → hors 9-20) : rien ne part
  const n1 = await reminder.runAdLeadConfirmReminders({ now: night });
  expect(n1.sent).toBe(0);
  expect(n1.skipped.night).toBeGreaterThanOrEqual(1);
  // Journée (13 h UTC = 14 h Paris, 9 h New York) : 2 rappels (fr + en), pas le trop récent, jamais le +test
  const dry = await reminder.runAdLeadConfirmReminders({ now: day, dryRun: true });
  expect(dry.wouldSend).toBe(2);
  expect(dry.sent).toBe(0);
  const d1 = await reminder.runAdLeadConfirmReminders({ now: day });
  expect(d1.sent).toBe(2);
  expect(d1.skipped.test).toBe(1);
  const mf = mailsTo(frEmail); const me = mailsTo(enEmail);
  expect(mf).toHaveLength(2); expect(me).toHaveLength(2);
  expect(mf[1].subject).toBe('Léa, ta demande attend ta confirmation');
  expect(mf[1].text).toContain(`/posts/confirmer?l=${fr}`);
  expect(me[1].subject).toBe('Léa, your request is waiting for your confirmation');
  expect((await AdLead.findById(fr).lean()).confirmReminderAt).toBeTruthy();
  expect(mailsTo((await AdLead.findById(tooSoon).lean()).email)).toHaveLength(1);
  expect(mailsTo('dadaciao84+testrappel3110@gmail.com')).toHaveLength(0);
  // 2e passage le lendemain : plus rien (une seule fois)
  const d2 = await reminder.runAdLeadConfirmReminders({ now: new Date(day.getTime() + 24 * H) });
  expect(d2.sent).toBe(1); // seul le « trop récent » d'hier est désormais dû ; fr et en ne sont PAS relancés
  expect(mailsTo(frEmail)).toHaveLength(2);
  expect(mailsTo(enEmail)).toHaveLength(2);
  expect((await reminder.runAdLeadConfirmReminders({ now: new Date(day.getTime() + 48 * H) })).sent).toBe(0);
  // règle pure
  expect(reminder.reminderDue({ pendingConfirm: true, confirmEmailAt: new Date(day.getTime() - 25 * H), country: 'FR' }, day).due).toBe(true);
  expect(reminder.reminderDue({ pendingConfirm: true, confirmEmailAt: new Date(day.getTime() - 25 * H), confirmReminderAt: new Date(), country: 'FR' }, day).why).toBe('already_reminded');
  expect(reminder.reminderDue({ pendingConfirm: true, postId: 'x', confirmEmailAt: new Date(day.getTime() - 25 * H) }, day).why).toBe('not_pending');
  expect(reminder.reminderDue({ pendingConfirm: true, confirmEmailAt: new Date(day.getTime() - 12 * 86400000), country: 'FR' }, day).why).toBe('too_old');
});

test('stats admin : « en attente de confirmation » et « confirmés (clic) » comptés, publiées séparées', async () => {
  const s = await request(app).get('/admin/ad-leads/stats?days=7').set(ADMIN).expect(200);
  expect(s.body.awaitingConfirm).toBeGreaterThanOrEqual(3);
  expect(s.body.confirmedClick).toBe(1);
  expect(s.body.published).toBe(1);
  expect(s.body.reminded).toBe(3);
  expect(s.body.awaitingConfirmTotal).toBe(s.body.awaitingConfirm);
});
