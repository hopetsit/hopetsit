// 3110 (ADA, demande de BOB) — POST /admin/support-reply : envoi OK (mailer simulé, expéditeur SMTP_FROM,
// Reply-To contact@hopetsit.com, signature), refus (adresse invalide, +test, texte vide ou > 4 000),
// journal SupportReply3110, bug signalé → in_progress sans écraser un bug déjà fixed.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
const SENT = [];
jest.mock('../src/services/emailService', () => ({
  sendEmail: jest.fn(async (to, subject, text, html, opts) => { SENT.push({ to, subject, text, html, opts }); return { messageId: 'mid-' + SENT.length }; }),
}));
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

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { validateSupportReply } = require('../src/routes/adminSupportReply3110');

let mongo; let app; let BugReport; let SupportReply;
const ADMIN = { 'x-test-user': 'admin42', 'x-test-role': 'admin' };
const post = (body, h = ADMIN) => request(app).post('/admin/support-reply').set(h).send(body);
const mkBug = (status) => BugReport.create({ userId: new mongoose.Types.ObjectId(), userRole: 'owner', description: 'bug de test', status });

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  BugReport = require('../src/models/BugReport'); SupportReply = require('../src/models/SupportReply3110');
  await Promise.all([BugReport.init(), SupportReply.init()]);
  app = express(); app.use(express.json());
  app.use('/admin/support-reply', require('../src/routes/adminSupportReply3110'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });
beforeEach(() => { SENT.length = 0; });

test('validation pure : invalide, +test, vide, trop long, bugReportId mal formé', () => {
  expect(validateSupportReply({ to: 'pas-un-mail', subject: 's', text: 't' }).error).toMatch(/invalide/);
  expect(validateSupportReply({ to: 'dadaciao84+testowner@gmail.com', subject: 's', text: 't' }).error).toMatch(/\+test/);
  expect(validateSupportReply({ to: 'a@b.fr', subject: '', text: 't' }).error).toMatch(/Sujet/);
  expect(validateSupportReply({ to: 'a@b.fr', subject: 's', text: '   ' }).error).toMatch(/Texte vide/);
  expect(validateSupportReply({ to: 'a@b.fr', subject: 's', text: 'x'.repeat(4001) }).error).toMatch(/trop long/);
  expect(validateSupportReply({ to: 'a@b.fr', subject: 's', text: 't', bugReportId: 'nope' }).error).toMatch(/bugReportId/);
  expect(validateSupportReply({ to: ' A@B.fr ', subject: 's', text: 'x'.repeat(4000) })).toEqual({ to: 'a@b.fr', subject: 's', text: 'x'.repeat(4000), bugReportId: null });
});

test('envoi OK : mailer appelé une fois, Reply-To contact@hopetsit.com, signature, journal écrit', async () => {
  const r = await post({ to: 'isabelle@example.org', subject: 'Votre signalement', text: 'Bonjour,\nmerci pour votre message.' });
  expect(r.status).toBe(200);
  expect(r.body.ok).toBe(true); expect(r.body.sent).toBe(true); expect(r.body.bugReportId).toBeNull();
  expect(SENT).toHaveLength(1);
  expect(SENT[0].to).toBe('isabelle@example.org');
  expect(SENT[0].html).toBeNull();
  expect(SENT[0].opts).toEqual({ replyTo: 'contact@hopetsit.com' });
  expect(SENT[0].text.startsWith('Bonjour,\nmerci pour votre message.')).toBe(true);
  expect(SENT[0].text).toMatch(/L'équipe HoPetSit/);
  const rows = await SupportReply.find({ to: 'isabelle@example.org' }).lean();
  expect(rows).toHaveLength(1);
  expect(rows[0]).toMatchObject({ subject: 'Votre signalement', adminId: 'admin42', bugReportId: null, messageId: 'mid-1' });
});

test('refus 400 (invalide, +test, vide, trop long) : aucun e-mail, aucun journal ; 403 sans admin', async () => {
  expect((await post({ to: 'nope', subject: 's', text: 't' })).status).toBe(400);
  expect((await post({ to: 'x+test@example.org', subject: 's', text: 't' })).status).toBe(400);
  expect((await post({ to: 'a@example.org', subject: 's', text: '' })).status).toBe(400);
  expect((await post({ to: 'a@example.org', subject: 's', text: 'y'.repeat(4001) })).status).toBe(400);
  expect((await post({ to: 'a@example.org', subject: 's', text: 't' }, { 'x-test-user': 'u1', 'x-test-role': 'owner' })).status).toBe(403);
  expect(SENT).toHaveLength(0);
  expect(await SupportReply.countDocuments({})).toBe(1);
});

test('bug signalé : open → in_progress ; fixed reste fixed ; id inconnu = envoi quand même, bugFound=false', async () => {
  const open = await mkBug('open'); const fixed = await mkBug('fixed');
  const r1 = await post({ to: 'a@example.org', subject: 's', text: 'réponse', bugReportId: String(open._id) });
  expect(r1.status).toBe(200); expect(r1.body.bugStatus).toBe('in_progress');
  expect((await BugReport.findById(open._id)).status).toBe('in_progress');
  const r2 = await post({ to: 'a@example.org', subject: 's', text: 'réponse', bugReportId: String(fixed._id) });
  expect(r2.status).toBe(200); expect(r2.body.bugStatus).toBe('fixed');
  expect((await BugReport.findById(fixed._id)).status).toBe('fixed');
  const r3 = await post({ to: 'a@example.org', subject: 's', text: 'réponse', bugReportId: String(new mongoose.Types.ObjectId()) });
  expect(r3.status).toBe(200); expect(r3.body.bugFound).toBe(false); expect(r3.body.sent).toBe(true);
  expect(SENT).toHaveLength(3);
  const row = await SupportReply.findOne({ bugReportId: open._id }).lean();
  expect(row).toMatchObject({ bugStatusBefore: 'open', bugStatusAfter: 'in_progress' });
});

// 1011 (BOB) — les 15 e-mails du 09/11 portaient un lien « /application/<id>?choose=1 » NON signé : le
// propriétaire tombait sur la page de connexion. La route signe désormais ces liens quand le destinataire
// est bien le propriétaire de la candidature ; le journal garde le texte SANS la clé.
test('lien « mes candidats » : signé pour le propriétaire de la candidature, jamais pour un autre, journal sans clé', async () => {
  const Owner = require('../src/models/Owner'); const Application = require('../src/models/Application');
  const { verifyApplicationLink } = require('../src/utils/applicationLink3110');
  const owner = await Owner.create({ name: 'Jeanne Test', email: 'jeanne.lien1011@example.org', password: 'x'.repeat(24), acceptedTerms: true });
  const autre = await Owner.create({ name: 'Autre Test', email: 'autre.lien1011@example.org', password: 'x'.repeat(24), acceptedTerms: true });
  const a = await Application.create({ ownerId: owner._id, sitterId: new mongoose.Types.ObjectId() });
  const lien = `https://hopetsit.com/application/${a._id}?choose=1`;
  const texte = `Bonjour Jeanne,\nvoici votre gardienne : ${lien}.\nÀ bientôt`;

  const r = await post({ to: 'jeanne.lien1011@example.org', subject: 'Votre gardienne', text: texte });
  expect(r.status).toBe(200); expect(r.body.signedLinks).toBe(1);
  const m = SENT[0].text.match(/application\/[a-f0-9]{24}\?choose=1&k=([A-Za-z0-9_.-]+)/);
  expect(m).not.toBeNull();
  expect(SENT[0].text).toMatch(/&k=[A-Za-z0-9_.-]+\.\nÀ bientôt/); // le point final de la phrase reste après le lien
  const v = verifyApplicationLink(m[1].replace(/\.$/, ''));
  expect(v).toMatchObject({ ok: true, ownerId: String(owner._id), applicationId: String(a._id) });
  const row = await SupportReply.findOne({ to: 'jeanne.lien1011@example.org' }).lean();
  expect(row.text).toContain(lien); expect(row.text).not.toMatch(/[?&]k=/);

  // Même lien envoyé à un AUTRE propriétaire, ou à une adresse sans compte : jamais de clé.
  SENT.length = 0;
  const r2 = await post({ to: 'autre.lien1011@example.org', subject: 's', text: texte });
  expect(r2.body.signedLinks).toBe(0); expect(SENT[0].text).not.toMatch(/[?&]k=/);
  SENT.length = 0;
  const r3 = await post({ to: 'inconnu.lien1011@example.org', subject: 's', text: texte });
  expect(r3.body.signedLinks).toBe(0); expect(SENT[0].text).not.toMatch(/[?&]k=/);
  expect(String(autre._id)).not.toBe(String(owner._id));
});
