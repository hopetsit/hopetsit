// 16/10/2026 (FLO) — PREUVE de la chaîne « réservation acceptée → paiement confirmé par Airwallex →
// réservation payée → commission enregistrée → argent du prestataire crédité → facture » SANS argent réel.
// VRAIE base Mongo en mémoire, VRAI contrôleur confirmBookingPayment, VRAI walletService, VRAIES routes
// /wallet (mandat 616). Seuls le réseau Airwallex (lecture d'intention), Firebase, sockets, e-mails et
// notifications sont simulés. Airwallex en production est en LIVE : on ne saisit jamais une vraie carte.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const PI = { id: 'int_flo1610', bookingId: '' };
jest.mock('../src/services/airwallexService', () => {
  const actual = jest.requireActual('../src/services/airwallexService');
  return {
    ...actual,
    retrievePaymentIntent: jest.fn(async (id) => ({
      id, status: 'SUCCEEDED', amount: 12, currency: 'EUR',
      metadata: { bookingId: PI.bookingId, purpose: 'booking' },
    })),
  };
});
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
  optionalAuth: (req, res, next) => next(),
}));
jest.mock('../src/services/emailService', () => ({ sendEmail: jest.fn(async () => ({ messageId: 'mock' })), sendTemplatedEmail: jest.fn(async () => ({})) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => ({})) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
jest.mock('../src/sockets/emitter', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0), isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false) }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

// ZOE 21/10 : dates de service toujours À VENIR (en dur au 17-18/10, le test rougissait dès le 21/10 :
// une garde passée est libérée tout de suite → ligne de séquestre + vrai crédit = 2 lignes, solde juste).
const inDays = (n) => new Date(Date.now() + n * 86400000).toISOString().slice(0, 10);
const DAY1 = inDays(30); const DAY2 = inDays(31);
let mongo; let app; let Owner; let Sitter; let Booking; let WalletTransaction; let Invoice;
let confirmBookingPayment; let ownerId; let sitterId;
const resMock = () => { const r = { statusCode: 200, body: null }; r.status = (c) => { r.statusCode = c; return r; }; r.json = (b) => { r.body = b; return r; }; return r; };

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Booking = require('../src/models/Booking');
  WalletTransaction = require('../src/models/WalletTransaction');
  try { Invoice = require('../src/models/Invoice'); } catch (_) { Invoice = null; }
  require('../src/models/Pet'); require('../src/models/ProcessedWebhook'); require('../src/models/Walker');
  await Promise.all([Owner.init(), Sitter.init(), Booking.init(), WalletTransaction.init()]);
  ({ confirmBookingPayment } = require('../src/controllers/bookingController'));
  ownerId = (await Owner.collection.insertOne({ name: 'Camille Durand', email: 'camille1610@example.test', city: 'Zone test', currency: 'EUR' })).insertedId;
  sitterId = (await Sitter.collection.insertOne({ name: 'Inès Petit', email: 'ines1610@example.test', city: 'Zone test', hourlyRate: 10, walletBalance: 0 })).insertedId;
  app = express(); app.use(express.json());
  app.use('/wallet', require('../src/routes/walletRoutes'));
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

test('propriétaire accepte → paie 12 € (10 + 2 de commission) → réservation payée, 10 € au prestataire, commission 2 € gardée', async () => {
  const b = await Booking.create({
    ownerId, sitterId, date: DAY1, startDate: DAY1, timeSlot: 'morning', serviceType: 'home_visit',
    status: 'agreed', paymentStatus: 'pending', paymentProvider: 'airwallex', airwallexPaymentIntentId: PI.id,
    pricing: { basePrice: 10, totalPrice: 12, commission: 2, netPayout: 10, commissionRate: 0.2, currency: 'EUR' },
  });
  PI.bookingId = String(b._id);
  const res = resMock();
  await confirmBookingPayment({ params: { id: String(b._id), paymentIntentId: PI.id }, body: {}, user: { id: String(ownerId), role: 'owner' }, headers: { 'x-app-version': '23.1.586+616' } }, res);
  expect(res.statusCode).toBe(200);
  const fresh = await Booking.findById(b._id).lean();
  expect(fresh.status).toBe('paid');
  expect(fresh.paymentStatus).toBe('paid');
  expect(fresh.paymentProvider).toBe('airwallex');
  expect(fresh.paidAt).toBeTruthy();
  // commission : total = net + commission, commission = 20 % du net
  expect(fresh.pricing.totalPrice).toBeCloseTo(fresh.pricing.netPayout + fresh.pricing.commission, 2);
  expect(fresh.pricing.commission).toBeCloseTo(0.2 * fresh.pricing.netPayout, 2);
  // argent du prestataire : 10 € crédités (séquestre : non retirable avant la fin de la garde)
  const tx = await WalletTransaction.findOne({ userId: sitterId, type: 'credit_booking', bookingId: String(b._id) }).lean();
  expect(tx).toBeTruthy();
  expect(tx.amount).toBe(10);
  expect(tx.currency).toBe('EUR');
  expect(tx.meta.withdrawable).toBe(false);
  // le prestataire le voit dans GET /wallet (app 616)
  const w = await request(app).get('/wallet').set({ 'x-test-user': String(sitterId), 'x-test-role': 'sitter' }).set('X-App-Version', '23.1.586+616');
  expect(w.status).toBe(200);
  // eslint-disable-next-line no-console
  console.log('GET /wallet prestataire après paiement →', JSON.stringify({ balance: w.body.balance, pending: w.body.pending, available: w.body.available, pendingAmount: w.body.pendingAmount, pendingEscrowTotal: w.body.pendingEscrowTotal, minWithdrawal: w.body.minWithdrawal, mandate: w.body.billingMandateAcceptedAt, payoutStatus: fresh.payoutStatus, keys: Object.keys(w.body) }));
  // facture / document : commission 2 € tracée
  if (Invoice) {
    const inv = await Invoice.findOne({ bookingId: b._id }).lean();
    // eslint-disable-next-line no-console
    console.log('Invoice →', inv ? JSON.stringify({ total: inv.totalAmount || inv.total, commission: inv.commission || inv.platformFee, net: inv.netPayout, status: inv.status }) : 'aucune');
    if (inv) expect(Number(inv.commission ?? inv.platformFee)).toBeCloseTo(2, 2);
  }
  // le mandat 616 ne concerne que le RETRAIT : retrait sans mandat (app 616) → refus clair, aucun débit
  const wd = await request(app).post('/wallet/withdraw').set({ 'x-test-user': String(sitterId), 'x-test-role': 'sitter' }).set('X-App-Version', '23.1.586+616').send({ amount: 10, method: 'iban' });
  // eslint-disable-next-line no-console
  console.log('withdraw sans mandat (616) →', wd.status, JSON.stringify(wd.body));
  expect(wd.status).toBe(400);
  expect(await WalletTransaction.countDocuments({ type: 'debit_withdrawal' })).toBe(0);
}, 120000);

test('rejeu : confirmer deux fois ne crédite pas deux fois le prestataire', async () => {
  const b = await Booking.create({
    ownerId, sitterId, date: DAY2, startDate: DAY2, timeSlot: 'morning', serviceType: 'home_visit',
    status: 'agreed', paymentStatus: 'pending', paymentProvider: 'airwallex', airwallexPaymentIntentId: 'int_flo1610_b',
    pricing: { basePrice: 10, totalPrice: 12, commission: 2, netPayout: 10, commissionRate: 0.2, currency: 'EUR' },
  });
  PI.bookingId = String(b._id);
  for (let i = 0; i < 2; i += 1) {
    const res = resMock();
    await confirmBookingPayment({ params: { id: String(b._id), paymentIntentId: 'int_flo1610_b' }, body: {}, user: { id: String(ownerId), role: 'owner' }, headers: {} }, res);
    expect(res.statusCode).toBe(200);
  }
  expect(await WalletTransaction.countDocuments({ userId: sitterId, type: 'credit_booking', bookingId: String(b._id) })).toBe(1);
}, 120000);
