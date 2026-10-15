// 616 (FLO, 15/10/2026, demande Daniel du 10/10) — mandat de facturation accepté
// EXPLICITEMENT au premier retrait :
//   · POST /wallet/billing-mandate enregistre date + version (idempotent) ;
//   · POST /wallet/withdraw refuse (400 BILLING_MANDATE_REQUIRED) tant que rien
//     n'est accepté, puis passe une fois la case cochée ;
//   · GET /wallet expose l'état ; l'admin (fiche IBAN) le voit ; le document de
//     prestation rappelle « mandat accepté le … ».
// Vraie base Mongo en mémoire, vraies routes ; seule l'authentification est simulée.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role)
    ? next() : res.status(403).json({ error: 'forbidden' })),
  requireVerifiedEmail: (req, res, next) => next(),
  optionalAuth: (req, res, next) => next(),
}));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => ({ ok: true })) }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Sitter; let Walker; let Owner; let WalletTransaction;
const {
  BILLING_MANDATE_VERSION, BILLING_MANDATE_MIN_BUILD, TERMS_DART, readTermsVersionFromCode, appBuildOf,
} = require('../src/utils/billingMandate');
const fs = require('fs');

describe('version du mandat = version des CGU lue dans le code de l’app (jamais recopiée à la main)', () => {
  test('terms_of_service.dart existe et porte termsVersion', () => {
    expect(fs.existsSync(TERMS_DART)).toBe(true);
    const m = fs.readFileSync(TERMS_DART, 'utf8').match(/const\s+String\s+termsVersion\s*=\s*'(\d+\.\d+)'/);
    expect(m).toBeTruthy();
    expect(readTermsVersionFromCode()).toBe(m[1]);
    expect(BILLING_MANDATE_VERSION).toBe(m[1]);
  });
  test('seuil de build 616 et lecture de X-App-Version', () => {
    expect(BILLING_MANDATE_MIN_BUILD).toBe(616);
    expect(appBuildOf({ headers: { 'x-app-version': '23.1.586+616' } })).toBe(616);
    expect(appBuildOf({ headers: { 'x-app-version': '23.1.585+615' } })).toBe(615);
    expect(appBuildOf({ headers: { 'x-app-version': 'web' } })).toBeNull();
    expect(appBuildOf({ headers: {} })).toBeNull();
  });
});
const ADMIN = { 'x-test-user': 'admin1', 'x-test-role': 'admin' };
const as = (doc, role) => ({ 'x-test-user': String(doc._id), 'x-test-role': role });
let n = 0;
const mkProvider = (M, extra = {}) => { n += 1; return M.create({
  name: `Prestataire${n}`, email: `mandate616_${n}@example.org`, password: 'MotDePasse616!',
  ibanHolder: `Prestataire${n}`, ibanVerified: true, payoutMethod: 'iban', walletBalance: 50, ...extra,
}); };

beforeAll(async () => {
  // Mac chargé par les autres agents (charge > 9 le 15/10) : 10 s ne suffisent pas toujours au démarrage.
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  WalletTransaction = require('../src/models/WalletTransaction');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), WalletTransaction.init()]);
  app = express();
  app.use(express.json());
  app.use('/wallet', require('../src/routes/walletRoutes'));
  app.use('/admin', require('../src/routes/adminRoutes'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(async () => {
  await Promise.all([Sitter.deleteMany({}), Walker.deleteMany({}), WalletTransaction.deleteMany({})]);
});

describe.each([['sitter', () => Sitter], ['walker', () => Walker]])('%s — mandat de facturation', (role, model) => {
  test('GET /wallet : mandat absent au départ, version courante annoncée', async () => {
    const p = await mkProvider(model());
    const r = await request(app).get('/wallet').set(as(p, role));
    expect(r.status).toBe(200);
    expect(r.body.billingMandateAcceptedAt).toBeNull();
    expect(r.body.billingMandateVersion).toBe('');
    expect(r.body.billingMandateCurrentVersion).toBe(BILLING_MANDATE_VERSION);
  });

  test('app ≥ 616 : retrait REFUSÉ (400 BILLING_MANDATE_REQUIRED) tant que le mandat n’est pas accepté — aucun débit', async () => {
    const p = await mkProvider(model());
    const r = await request(app).post('/wallet/withdraw').set(as(p, role))
      .set('X-App-Version', `23.1.586+${BILLING_MANDATE_MIN_BUILD}`).send({ amount: 10, method: 'iban' });
    expect(r.status).toBe(400);
    expect(r.body.code).toBe('BILLING_MANDATE_REQUIRED');
    expect(r.body.billingMandateCurrentVersion).toBe(BILLING_MANDATE_VERSION);
    expect(await WalletTransaction.countDocuments({})).toBe(0);
    const fresh = await model().findById(p._id).lean();
    expect(fresh.walletBalance).toBe(50);
  });

  test('app ≥ 617 (futur build) : même refus sans mandat', async () => {
    const p = await mkProvider(model());
    const r = await request(app).post('/wallet/withdraw').set(as(p, role))
      .set('X-App-Version', '23.1.590+617').send({ amount: 10, method: 'iban' });
    expect(r.status).toBe(400);
    expect(r.body.code).toBe('BILLING_MANDATE_REQUIRED');
  });

  test('COMPATIBILITÉ — app ≤ 615 (pas de case) : le retrait PASSE sans mandat, rien n’est bloqué', async () => {
    const p = await mkProvider(model());
    const r = await request(app).post('/wallet/withdraw').set(as(p, role))
      .set('X-App-Version', '23.1.585+615').send({ amount: 10, method: 'iban' });
    expect(r.status).toBe(200);
    expect(r.body.ok).toBe(true);
    expect(r.body.newBalance).toBe(40);
    expect(await WalletTransaction.countDocuments({ type: 'debit_withdrawal', status: 'pending' })).toBe(1);
    // Aucune acceptation inventée : le mandat reste à accepter.
    const fresh = await model().findById(p._id).lean();
    expect(fresh.billingMandateAcceptedAt).toBeNull();
  });

  test('COMPATIBILITÉ — site (« web ») ou client sans en-tête : le retrait PASSE sans mandat', async () => {
    const p1 = await mkProvider(model());
    const web = await request(app).post('/wallet/withdraw').set(as(p1, role))
      .set('X-App-Version', 'web').send({ amount: 10, method: 'iban' });
    expect(web.status).toBe(200);
    const p2 = await mkProvider(model());
    const none = await request(app).post('/wallet/withdraw').set(as(p2, role)).send({ amount: 10, method: 'iban' });
    expect(none.status).toBe(200);
    expect(await WalletTransaction.countDocuments({ type: 'debit_withdrawal' })).toBe(2);
  });

  test('POST /wallet/billing-mandate enregistre date + version, puis le retrait passe', async () => {
    const p = await mkProvider(model());
    const before = Date.now();
    const a = await request(app).post('/wallet/billing-mandate').set(as(p, role)).send({});
    expect(a.status).toBe(200);
    expect(a.body.ok).toBe(true);
    expect(a.body.alreadyAccepted).toBe(false);
    expect(a.body.billingMandateVersion).toBe(BILLING_MANDATE_VERSION);
    const acceptedAt = new Date(a.body.billingMandateAcceptedAt).getTime();
    expect(acceptedAt).toBeGreaterThanOrEqual(before - 1000);
    expect(acceptedAt).toBeLessThanOrEqual(Date.now() + 1000);

    const fresh = await model().findById(p._id).lean();
    expect(fresh.billingMandateVersion).toBe(BILLING_MANDATE_VERSION);
    expect(new Date(fresh.billingMandateAcceptedAt).getTime()).toBe(acceptedAt);

    const w = await request(app).post('/wallet/withdraw').set(as(p, role)).send({ amount: 10, method: 'iban' });
    expect(w.status).toBe(200);
    expect(w.body.ok).toBe(true);
    expect(w.body.newBalance).toBe(40);
    expect(await WalletTransaction.countDocuments({ type: 'debit_withdrawal', status: 'pending' })).toBe(1);

    const g = await request(app).get('/wallet').set(as(p, role));
    expect(new Date(g.body.billingMandateAcceptedAt).getTime()).toBe(acceptedAt);
    expect(g.body.billingMandateVersion).toBe(BILLING_MANDATE_VERSION);
  });

  test('idempotent : un second appel ne change ni la date ni la version', async () => {
    const p = await mkProvider(model());
    const a = await request(app).post('/wallet/billing-mandate').set(as(p, role)).send({ version: '2.4' });
    await new Promise((r) => setTimeout(r, 20));
    const b = await request(app).post('/wallet/billing-mandate').set(as(p, role)).send({ version: '9.9' });
    expect(b.status).toBe(200);
    expect(b.body.alreadyAccepted).toBe(true);
    expect(b.body.billingMandateAcceptedAt).toBe(a.body.billingMandateAcceptedAt);
    expect(b.body.billingMandateVersion).toBe('2.4');
    expect((await model().findById(p._id).lean()).billingMandateVersion).toBe('2.4');
  });

  test('version non conforme dans le body → version courante des CGU', async () => {
    const p = await mkProvider(model());
    const a = await request(app).post('/wallet/billing-mandate').set(as(p, role)).send({ version: '<script>' });
    expect(a.body.billingMandateVersion).toBe(BILLING_MANDATE_VERSION);
  });

  test('un propriétaire ne peut pas accepter de mandat (403)', async () => {
    const o = await Owner.create({ name: 'Proprio', email: `owner616_${role}@example.org`, password: 'MotDePasse616!' });
    const a = await request(app).post('/wallet/billing-mandate').set(as(o, 'owner')).send({});
    expect(a.status).toBe(403);
  });

  test(`admin : GET /admin/${role}s/:id/iban montre le mandat (avant / après)`, async () => {
    const p = await mkProvider(model());
    const before = await request(app).get(`/admin/${role}s/${p._id}/iban`).set(ADMIN);
    expect(before.status).toBe(200);
    expect(before.body.billingMandateAcceptedAt).toBeNull();
    await request(app).post('/wallet/billing-mandate').set(as(p, role)).send({});
    const after = await request(app).get(`/admin/${role}s/${p._id}/iban`).set(ADMIN);
    expect(after.status).toBe(200);
    expect(after.body.billingMandateAcceptedAt).toBeTruthy();
    expect(after.body.billingMandateVersion).toBe(BILLING_MANDATE_VERSION);
  });
});

describe('document de prestation — rappel « mandat accepté le … »', () => {
  const inv = require('../src/controllers/invoiceController');
  const call = async (handler, req) => {
    const res = { statusCode: 200, body: undefined, headers: {} };
    res.status = (c) => { res.statusCode = c; return res; };
    res.json = (b) => { res.body = b; return res; };
    res.send = (b) => { res.body = b; return res; };
    res.set = (k, v) => { res.headers[k] = v; return res; };
    await handler({ query: {}, params: {}, headers: {}, body: {}, ...req }, res);
    return res;
  };
  const booking = (owner, sitter) => ({
    _id: new mongoose.Types.ObjectId(), ownerId: owner._id, sitterId: sitter._id, serviceType: 'pet_sitting',
    serviceDate: new Date('2026-10-10T10:00:00Z'),
    pricing: { totalPrice: 120, commission: 20, netPayout: 100, currency: 'eur' },
    petIds: [{ petName: 'Rex' }],
  });

  test('les 9 langues ont le libellé mandateAcceptedOn avec {date} et {version}', () => {
    for (const l of inv.INVOICE_LOCALES) {
      const t = inv.invoiceTexts(l).mandateAcceptedOn;
      expect(t).toContain('{date}');
      expect(t).toContain('{version}');
    }
  });

  test('sans mandat : pas de rappel ; avec mandat : date et version sur le document', async () => {
    const owner = await Owner.create({ name: 'Proprio', email: 'owner616_inv@example.org', password: 'MotDePasse616!' });
    const sitter = await mkProvider(Sitter);
    const created = await inv.createInvoiceForBooking(booking(owner, sitter));
    expect(created).toBeTruthy();
    const r1 = await call(inv.renderInvoiceHtml, { user: { id: String(owner._id), role: 'owner' }, params: { id: String(created._id) }, query: { lang: 'fr' } });
    expect(r1.statusCode).toBe(200);
    expect(String(r1.body)).not.toContain('Mandat de facturation accepté par le prestataire le');

    await request(app).post('/wallet/billing-mandate').set(as(sitter, 'sitter')).send({});
    const fresh = await Sitter.findById(sitter._id).lean();
    const day = new Date(fresh.billingMandateAcceptedAt).toISOString().slice(0, 10);
    const r2 = await call(inv.renderInvoiceHtml, { user: { id: String(owner._id), role: 'owner' }, params: { id: String(created._id) }, query: { lang: 'fr' } });
    expect(String(r2.body)).toContain(`Mandat de facturation accepté par le prestataire le ${day} (CGU version ${BILLING_MANDATE_VERSION}).`);
    const en = await call(inv.renderInvoiceHtml, { user: { id: String(owner._id), role: 'owner' }, params: { id: String(created._id) }, query: { lang: 'en' } });
    expect(String(en.body)).toContain(`Billing mandate accepted by the provider on ${day} (Terms version ${BILLING_MANDATE_VERSION}).`);
  });
});
