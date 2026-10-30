// 607 (FLO, 02/10/2026) — cas réel : gardien parisien, 3 € payés le 18/09,
// vérification jamais lancée (app iOS), invisible 14 jours, puis validé à la
// main par Daniel — mais le badge restait absent de sa fiche.
//
// 1. GET /sitters/:id porte `identityVerified` (app + site /p/sitter/:id le lisent).
// 2. sanitizeUser : `identityVerified` toujours booléen (fiche promeneur).
// 3. publicProvider607 : le badge « Identité vérifiée » ne vient plus du
//    drapeau `verified` (= e-mail vérifié).
// 4. utils/kycPeople607 + GET /admin/kyc-people : vérifiés, méthode,
//    payés-non-vérifiés, blocage, revenus KYC.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const { sanitizeUser } = require('../src/utils/sanitize');
const { toPublicProvider } = require('../src/utils/publicProvider607');
const { personRow, summarize, methodOf, groupByPerson } = require('../src/utils/kycPeople607');

const NOW = new Date('2026-10-02T08:00:00Z');
const PAID_18 = new Date('2026-09-18T10:56:50Z');

describe('badge public : identityVerified', () => {
  test('sanitizeUser renvoie un booléen même sans identityVerification', () => {
    const r = sanitizeUser({ _id: 'w1', name: 'A', kycStatus: 'none', verified: true });
    expect(r.identityVerified).toBe(false);
    expect(JSON.parse(JSON.stringify(r))).toHaveProperty('identityVerified', false);
  });
  test('validation manuelle admin = badge', () => {
    const r = sanitizeUser({ _id: 'w1', kycStatus: 'verified', identityVerification: { status: 'verified' } });
    expect(r.identityVerified).toBe(true);
  });
  test('publicProvider607 : e-mail vérifié seul ≠ identité vérifiée', () => {
    expect(toPublicProvider({ _id: 'x', name: 'Léa B', verified: true, kycStatus: 'none' }, 'sitter').verified).toBe(false);
    expect(toPublicProvider({ _id: 'x', name: 'Léa B', verified: true, kycStatus: 'verified' }, 'sitter').verified).toBe(true);
    expect(toPublicProvider({ _id: 'x', name: 'Léa B', identityVerification: { status: 'verified' } }, 'walker').verified).toBe(true);
  });
});

describe('kycPeople607 (pur)', () => {
  const stuck = {
    _id: 'aaa9cedba', name: 'Sasha B', city: 'Paris', kycStatus: 'pending_verification',
    kycPaidAt: PAID_18, kycPaymentIntentId: 'int_x', kycApplicantId: null,
    identityVerification: { status: 'none' },
  };
  test('payé, jamais de session, 14 jours → bloqué « session_jamais_creee »', () => {
    const r = personRow(stuck, 'sitter', { now: NOW });
    expect(r).toMatchObject({
      verified: false, paid: true, paidAmount: 3, paymentChannel: 'airwallex',
      blocked: 'session_jamais_creee', daysSincePayment: 13, providerSessionStarted: false, city: 'Paris',
    });
    expect(r).not.toHaveProperty('email');
  });
  test('après validation manuelle de Daniel → admin_manual, payé oui', () => {
    const d = { ...stuck, kycStatus: 'verified', kycVerifiedAt: NOW,
      identityVerification: { status: 'verified', reviewedAt: NOW } };
    const r = personRow(d, 'sitter', { now: NOW });
    expect(r).toMatchObject({ verified: true, method: 'admin_manual', paid: true, blocked: null });
  });
  test('méthodes prestataire', () => {
    expect(methodOf({ kycStatus: 'verified', kycApplicantId: 'd05413d6-uuid' })).toBe('didit');
    expect(methodOf({ kycStatus: 'verified', kycApplicantId: 'inq_123' })).toBe('persona');
    expect(personRow({ _id: 'z', kycPaidAt: NOW, kycPaymentIntentId: 'wallet_1' }, 'walker', { now: NOW }).paymentChannel).toBe('wallet');
  });
  test('paiement récent (< 1 h) = en cours, pas bloqué', () => {
    const r = personRow({ _id: 'n', kycStatus: 'pending_verification', kycPaidAt: new Date(NOW - 10 * 60000) }, 'sitter', { now: NOW });
    expect(r.blocked).toBe('en_cours');
  });
  test('résumé : test exclus, revenus par période', () => {
    const rows = [
      personRow(stuck, 'sitter', { now: NOW }),
      personRow({ _id: 't', kycPaidAt: NOW, email: 'x' }, 'walker', { now: NOW, isInternal: () => true }),
    ];
    const s = summarize(rows, { now: NOW });
    expect(s.paidUnverified).toBe(1);
    expect(s.blocked).toBe(1);
    expect(s.testAccounts).toBe(1);
    expect(s.revenue.allTime).toEqual({ count: 1, total: 3 });
    expect(s.revenue.last30d).toEqual({ count: 1, total: 3 });
    expect(s.revenue.last7d).toEqual({ count: 0, total: 0 });
  });
});

// ── Route admin, vraie base en mémoire ─────────────────────────────────────
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

describe('kycPeople607.groupByPerson — 3010 : une personne = une ligne sur les 3 profils', () => {
  const NOW = new Date('2026-10-30T12:00:00Z');
  const D1 = new Date('2026-10-20T10:00:00Z'); const D2 = new Date('2026-10-25T10:00:00Z');
  test('gardienne + promeneuse vérifiées = 1 ligne, verifiedAt la plus ancienne, 3 € une fois', () => {
    const rows = [
      { ...personRow({ _id: 's1', name: 'Agnès', kycStatus: 'verified', kycVerifiedAt: D2, kycApplicantId: 'x', kycPaidAt: D1, kycPaymentIntentId: 'i' }, 'sitter', { now: NOW }), personKey: 'agnes@x' },
      { ...personRow({ _id: 'w1', name: 'Agnès', kycStatus: 'verified', identityVerification: { status: 'verified', reviewedAt: D1 } }, 'walker', { now: NOW }), personKey: 'agnes@x' },
      { ...personRow({ _id: 's2', name: 'Bob', kycPaidAt: D1 }, 'sitter', { now: NOW }), personKey: 'bob@x' },
    ];
    const g = groupByPerson(rows, new Map([['agnes@x', ['sitter', 'walker', 'owner']], ['bob@x', ['sitter']]]));
    expect(g).toHaveLength(2);
    const a = g.find((r) => r.name === 'Agnès');
    expect(a).toMatchObject({ id: 'w1', roles: ['sitter', 'walker', 'owner'], rolesVerified: { sitter: true, walker: true }, verified: true, method: 'admin_manual', paid: true, paidAmount: 3, blocked: null, profiles: 2 });
    expect(new Date(a.verifiedAt).getTime()).toBe(D1.getTime());
    expect(a.personKey).toBeUndefined();
    const b = g.find((r) => r.name === 'Bob');
    expect(b).toMatchObject({ roles: ['sitter'], verified: false, paid: true, blocked: 'session_jamais_creee' });
    expect(summarize(g, { now: NOW })).toMatchObject({ verified: 1, paidUnverified: 1, blocked: 1 });
    expect(summarize(g, { now: NOW }).revenue.allTime).toEqual({ count: 2, total: 6 });
  });
  test('bloqué seulement si AUCUN profil n\'est vérifié', () => {
    const rows = [
      { ...personRow({ _id: 's1', name: 'Eli', kycPaidAt: D1 }, 'sitter', { now: NOW }), personKey: 'eli@x' },
      { ...personRow({ _id: 'w1', name: 'Eli', kycStatus: 'verified', kycVerifiedAt: D2, kycApplicantId: 'y' }, 'walker', { now: NOW }), personKey: 'eli@x' },
    ];
    const g = groupByPerson(rows);
    expect(g).toHaveLength(1);
    expect(g[0]).toMatchObject({ verified: true, blocked: null, paid: true, roles: ['sitter', 'walker'], rolesVerified: { sitter: false, walker: true } });
  });
});

describe('GET /admin/kyc-people', () => {
  const express = require('express');
  const request = require('supertest');
  const mongoose = require('mongoose');
  const { MongoMemoryServer } = require('mongodb-memory-server');
  let mongo; let app; let Sitter; let Walker;
  const ADMIN = { 'x-test-user': 'admin1', 'x-test-role': 'admin' };

  beforeAll(async () => {
    mongo = await MongoMemoryServer.create();
    await mongoose.connect(mongo.getUri());
    Sitter = require('../src/models/Sitter');
    Walker = require('../src/models/Walker');
    await Promise.all([Sitter.init(), Walker.init()]);
    await Sitter.collection.insertMany([
      { name: 'Sasha B', email: 'sasha@example.com', city: 'Paris', kycStatus: 'pending_verification',
        kycPaidAt: PAID_18, kycPaymentIntentId: 'int_secret', kycApplicantId: null },
      { name: 'Vera V', email: 'vera@example.com', city: 'Lyon', kycStatus: 'verified',
        kycVerifiedAt: NOW, kycApplicantId: 'uuid-didit', kycPaidAt: PAID_18, kycPaymentIntentId: 'int_2' },
      { name: 'Rien', email: 'rien@example.com', city: 'Nice', kycStatus: 'none', verified: true },
      { name: 'Test', email: 'dadaciao84+testsitter@gmail.com', kycStatus: 'pending_verification', kycPaidAt: PAID_18 },
    ]);
    await Walker.collection.insertMany([
      { name: 'Manu W', email: 'manu@example.com', kycStatus: 'verified',
        identityVerification: { status: 'verified', reviewedAt: NOW }, kycVerifiedAt: NOW },
    ]);
    // 3010 — Manu a aussi un profil gardien vérifié (même e-mail) et un profil propriétaire sans KYC → UNE ligne
    await Sitter.collection.insertOne({ name: 'Manu W', email: 'manu@example.com', kycStatus: 'verified', kycVerifiedAt: NOW, kycApplicantId: 'uuid-didit-2' });
    const Owner = require('../src/models/Owner'); await Owner.init();
    await Owner.collection.insertOne({ name: 'Manu W', email: 'manu@example.com' });
    app = express();
    app.use(express.json());
    app.use('/admin/kyc-people', require('../src/routes/adminKycRoutes607'));
  });
  afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

  test('admin seulement', async () => {
    expect((await request(app).get('/admin/kyc-people')).status).toBe(401);
    expect((await request(app).get('/admin/kyc-people').set({ 'x-test-user': 'u', 'x-test-role': 'sitter' })).status).toBe(403);
  });

  test('liste complète, sans e-mail ni identifiant de paiement', async () => {
    const r = await request(app).get('/admin/kyc-people').set(ADMIN);
    expect(r.status).toBe(200);
    const raw = JSON.stringify(r.body);
    expect(raw).not.toMatch(/@example\.com|int_secret|uuid-didit/);
    expect(r.body.people.map((p) => p.name).sort()).toEqual(['Manu W', 'Sasha B', 'Test', 'Vera V']);
    const manu = r.body.people.find((p) => p.name === 'Manu W');
    // 3010 — 2 profils vérifiés + 1 propriétaire = UNE personne, 3 rôles affichés, source = la plus ancienne vérification
    expect(manu).toMatchObject({ verified: true, paid: false, roles: ['sitter', 'walker', 'owner'], rolesVerified: { sitter: true, walker: true }, profiles: 2 });
    expect(['admin_manual', 'didit']).toContain(manu.method);
    const vera = r.body.people.find((p) => p.name === 'Vera V');
    expect(vera).toMatchObject({ method: 'didit', paid: true });
    expect(r.body.summary).toMatchObject({ verified: 2, paidUnverified: 1, blocked: 1, testAccounts: 1 });
    expect(r.body.summary.revenue.allTime).toEqual({ count: 2, total: 6 });
  });

  test('filtre paid_unverified', async () => {
    const r = await request(app).get('/admin/kyc-people?status=paid_unverified').set(ADMIN);
    expect(r.body.people.map((p) => p.name).sort()).toEqual(['Sasha B', 'Test']);
    expect(r.body.people.find((p) => p.name === 'Sasha B').blocked).toBe('session_jamais_creee');
    expect((await request(app).get('/admin/kyc-people?status=x').set(ADMIN)).status).toBe(400);
  });
});
