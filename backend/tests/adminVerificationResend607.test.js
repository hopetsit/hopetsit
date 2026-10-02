// 607 (ADA, 02/10/2026) — renvoi groupé de l'e-mail de vérification depuis l'admin :
// exclusions, délai de 7 jours, une personne = un e-mail, plafond 50, simulation, journal,
// même flux que POST /auth/resend-code (code 24 h, langue du compte). AUCUN e-mail réel :
// sendVerificationEmail est remplacé par un espion.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.VERIF_RESEND_DELAY_MS = '0';

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
jest.mock('../src/config/firebaseAdmin', () => ({ auth: () => ({ verifyIdToken: jest.fn() }), messaging: () => ({}) }));
const mockSend = jest.fn(async () => {});
jest.mock('../src/services/emailService', () => ({
  ...jest.requireActual('../src/services/emailService'),
  sendVerificationEmail: (...a) => mockSend(...a),
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let Walker; let Log; let VerificationCode;
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
let n = 0;
const mk = (M, extra = {}) => { n += 1; return M.create({ name: `Personne${n}`, email: `verif607_${n}@example.org`, password: 'MotDePasse607!', verified: false, ...extra }); };
const ref = (role, d) => ({ role, id: String(d._id) });
const post = (body) => request(app).post('/admin/users/resend-verification').set(ADMIN).send(body);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Log = require('../src/models/VerificationEmailLog');
  VerificationCode = require('../src/models/VerificationCode');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Log.init(), VerificationCode.init()]);
  app = express();
  app.use(express.json());
  app.use('/admin/users/resend-verification', require('../src/routes/adminVerificationResend607'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });
beforeEach(async () => {
  mockSend.mockClear();
  await Promise.all([Owner.deleteMany({}), Sitter.deleteMany({}), Walker.deleteMany({}), Log.deleteMany({}), VerificationCode.deleteMany({}),
    Log.VerificationResendBatch.deleteMany({})]);
});

describe('POST /admin/users/resend-verification', () => {
  test('401 / 403 / 400', async () => {
    await request(app).post('/admin/users/resend-verification').send({ ids: [] }).expect(401);
    await request(app).post('/admin/users/resend-verification').set({ 'x-test-user': 'u', 'x-test-role': 'owner' }).send({ ids: [] }).expect(403);
    await post({ ids: [] }).expect(400);
  });

  test('exclusions : vérifié (même par un profil frère), test, bloqué, adresse invalide ; une personne = un envoi', async () => {
    const ok = await mk(Owner, { appLocale: 'es' });
    const okSitter = await mk(Sitter, { email: ok.email }); // même personne
    const verifiedOwner = await mk(Owner, { verified: true });
    const verifiedBySibling = await mk(Walker, { email: verifiedOwner.email }); // non vérifié, mais sa personne l'est
    const test = await mk(Owner, { email: 'dadaciao84+testxyz@gmail.com' });
    const banned = await mk(Sitter, { status: 'banned' });
    const bad = await mk(Walker, { email: 'quelquun@gmail.con' });
    const ids = [ref('owner', ok), ref('sitter', okSitter), ref('walker', verifiedBySibling), ref('owner', test), ref('sitter', banned), ref('walker', bad)];

    const dry = await post({ ids, dryRun: true }).expect(200);
    expect(dry.body).toMatchObject({ dryRun: true, requested: 6, toSend: 1, sent: 0 });
    expect(dry.body.skipped).toEqual({ same_person: 1, already_verified: 1, test_account: 1, blocked: 1, invalid_email: 1 });
    expect(mockSend).not.toHaveBeenCalled(); // simulation : rien ne part
    expect(JSON.stringify(dry.body)).not.toMatch(/@/);

    const real = await post({ ids }).expect(200);
    expect(real.body).toMatchObject({ dryRun: false, sent: 1, failed: 0 });
    expect(mockSend).toHaveBeenCalledTimes(1);
    const [email, code, lang] = mockSend.mock.calls[0];
    expect(email).toBe(ok.email);
    expect(code).toMatch(/^\d{4,8}$/);
    expect(lang).toBe('es'); // langue du compte, comme le flux de l'app
    const vc = await VerificationCode.findOne({ email: ok.email, purpose: 'email_verification' }).lean();
    expect(new Date(vc.expiresAt).getTime() - Date.now()).toBeGreaterThan(23 * 3600000); // valable 24 h
    expect(await Log.countDocuments({})).toBe(1);
    expect(await Log.VerificationResendBatch.countDocuments({})).toBe(2); // simulation + envoi journalisés
  });

  test('jamais deux envois en moins de 7 jours (toutes sources), mais oui après 7 jours', async () => {
    const recent = await mk(Owner);
    const old = await mk(Owner);
    const viaCode = await mk(Owner);
    await Log.touch(recent.email, 'vigie', new Date(Date.now() - 3 * 86400000));
    await Log.touch(old.email, 'vigie', new Date(Date.now() - 8 * 86400000));
    await VerificationCode.create({ email: viaCode.email, code: 'x', purpose: 'email_verification', expiresAt: new Date(Date.now() + 86400000) });
    const r = await post({ ids: [ref('owner', recent), ref('owner', old), ref('owner', viaCode)] }).expect(200);
    expect(r.body.sent).toBe(1);
    expect(r.body.skipped).toEqual({ sent_less_than_7_days: 2 });
    expect(mockSend.mock.calls[0][0]).toBe(old.email);
    // Deuxième clic juste après : plus rien ne part.
    const again = await post({ ids: [ref('owner', old)] }).expect(200);
    expect(again.body).toMatchObject({ sent: 0, skipped: { sent_less_than_7_days: 1 } });
  });

  test('plafond : 50 envois au plus par clic', async () => {
    const list = [];
    for (let i = 0; i < 53; i += 1) list.push(await mk(Owner));
    const r = await post({ ids: list.map((d) => ref('owner', d)), dryRun: true }).expect(200);
    expect(r.body.toSend).toBe(50);
    expect(r.body.skipped).toEqual({ cap_50: 3 });
  }, 30000);

  test('dernier rappel par profil et journal', async () => {
    const a = await mk(Owner);
    const s = await mk(Sitter, { email: a.email });
    await Log.touch(a.email, 'auth', new Date('2026-09-30T10:00:00Z'));
    const last = await request(app).get('/admin/users/resend-verification/last').set(ADMIN).expect(200);
    expect(new Date(last.body.last[`owner:${a._id}`]).toISOString()).toBe('2026-09-30T10:00:00.000Z');
    expect(last.body.last[`sitter:${s._id}`]).toBeTruthy(); // même personne
    await post({ ids: [ref('owner', a)], dryRun: true });
    const j = await request(app).get('/admin/users/resend-verification/journal').set(ADMIN).expect(200);
    expect(j.body.items[0]).toMatchObject({ dryRun: true, requested: 1 });
  });
});
