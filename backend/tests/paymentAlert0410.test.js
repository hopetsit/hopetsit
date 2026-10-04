// 04/10/2026 (FLO) — e-mail interne « 💰 Paiement reçu » à contact@hopetsit.com
// (demande de Daniel). VRAIE base Mongo en mémoire, VRAI contrôleur de webhook
// Airwallex, VRAI modèle Booking (crochet post-save), VRAI walletService,
// VRAI selfCancelWithRefund, VRAI appleIapService.creditForTransaction.
// Seuls sont simulés : l'envoi SMTP (sendEmail), le réseau Airwallex
// (signature, lecture d'intention, remboursement), Firebase et les sockets.
// Aucun paiement réel, aucun e-mail réel.
process.env.NODE_ENV = 'test';
process.env.PAYMENT_ALERTS_IN_TEST = '1';
process.env.PAYMENT_ALERT_EMAIL = 'contact@hopetsit.com';
delete process.env.PAYMENT_ALERTS;

const sentEmails = [];
const mailState = { fail: false };
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return {
    ...actual,
    sendEmail: jest.fn(async (to, subject, text, html) => {
      if (mailState.fail) throw new Error('SMTP en panne (simulé)');
      sentEmails.push({ to, subject, text, html });
      return { messageId: 'mock' };
    }),
  };
});
jest.mock('../src/services/airwallexService', () => {
  const actual = jest.requireActual('../src/services/airwallexService');
  return {
    ...actual,
    constructWebhookEvent: jest.fn((body) => JSON.parse(Buffer.isBuffer(body) ? body.toString('utf8') : body)),
    retrievePaymentIntent: jest.fn(async (id) => ({ id, status: 'SUCCEEDED', amount: 24, currency: 'EUR', metadata: {} })),
    createRefund: jest.fn(async ({ paymentIntentId }) => ({ id: `rfd_${paymentIntentId}`, amount: 24, currency: 'EUR', status: 'RECEIVED' })),
  };
});
jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({ sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }),
}));
jest.mock('../src/services/notificationSender', () => ({
  sendNotification: jest.fn(async () => ({})),
}));
jest.mock('../src/sockets', () => ({
  emitToUser: jest.fn(),
  emitToUsersAllRoles: jest.fn(() => 0),
}));
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn(),
  emitToUsersAllRoles: jest.fn(() => 0),
  isUserOnline: jest.fn(async () => false),
  isConversationOpenFor: jest.fn(async () => false),
}));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo;
let Owner; let Walker; let Sitter; let Booking; let PaymentAlert;
let handleAirwallexWebhook;
let alerts;
let ownerId; let walkerId; let testOwnerId; let sitterId;

const resMock = () => {
  const r = { statusCode: 200, body: null };
  r.status = (c) => { r.statusCode = c; return r; };
  r.json = (b) => { r.body = b; return r; };
  return r;
};

async function postWebhook(event) {
  const res = resMock();
  await handleAirwallexWebhook({ body: Buffer.from(JSON.stringify(event)), headers: {} }, res);
  return res;
}

async function settle() {
  await alerts.flushPaymentAlerts();
  // laisse aussi passer les callbacks setImmediate éventuels
  await new Promise((r) => setImmediate(r));
  await alerts.flushPaymentAlerts();
}

let seq = 0;
async function makeBooking({ owner = ownerId, walker = walkerId, intent } = {}) {
  seq += 1;
  return Booking.create({
    ownerId: owner,
    walkerId: walker,
    date: '2027-01-15',
    startDate: '2027-01-15',
    timeSlot: '10:00',
    serviceType: 'dog_walking',
    status: 'agreed',
    paymentStatus: 'pending',
    paymentProvider: 'airwallex',
    airwallexPaymentIntentId: intent || `int_booking_${seq}`,
    pricing: { basePrice: 20, totalPrice: 24, commission: 4, netPayout: 20, commissionRate: 0.2, currency: 'EUR' },
  });
}

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Walker = require('../src/models/Walker');
  Sitter = require('../src/models/Sitter');
  Booking = require('../src/models/Booking');
  PaymentAlert = require('../src/models/PaymentAlert0410');
  require('../src/models/Pet');
  require('../src/models/ProcessedWebhook');
  await Promise.all([Booking.init(), PaymentAlert.init(), require('../src/models/ProcessedWebhook').init()]);
  ({ handleAirwallexWebhook } = require('../src/controllers/airwallexWebhookController'));
  alerts = require('../src/services/paymentAlert0410');

  ownerId = (await Owner.collection.insertOne({ name: 'Camille Durand', email: 'camille0410@example.test', city: 'Paris' })).insertedId;
  walkerId = (await Walker.collection.insertOne({ name: 'Lucas Martin', email: 'lucas0410@example.test', city: 'Paris' })).insertedId;
  sitterId = (await Sitter.collection.insertOne({ name: 'Inès Petit', email: 'ines0410@example.test', city: 'Paris', walletBalance: 50 })).insertedId;
  testOwnerId = (await Owner.collection.insertOne({ name: 'Test Owner', email: 'dadaciao84+testowner@gmail.com', city: 'Paris' })).insertedId;
});

afterAll(async () => {
  await settle();
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

beforeEach(async () => {
  await settle();
  sentEmails.length = 0;
  mailState.fail = false;
});

describe('e-mail interne « Paiement reçu »', () => {
  test('réservation payée (webhook Airwallex) → 1 e-mail avec montant et commission', async () => {
    const b = await makeBooking();
    const res = await postWebhook({
      id: 'evt_paid_1', name: 'payment_intent.succeeded',
      data: { id: b.airwallexPaymentIntentId, amount: 24, currency: 'EUR', metadata: {} },
    });
    expect(res.statusCode).toBe(200);
    await settle();
    expect(sentEmails).toHaveLength(1);
    const m = sentEmails[0];
    expect(m.to).toBe('contact@hopetsit.com');
    expect(m.subject).toBe('💰 Paiement reçu : 24,00 € — réservation promenade (Paris)');
    expect(m.text).toContain('Montant payé : 24,00 €');
    expect(m.text).toContain('Commission HoPetSit : 4,00 €');
    expect(m.text).toContain('Pour le prestataire : 20,00 €');
    expect(m.text).toContain('Qui paie : Camille D. (propriétaire, Paris)');
    expect(m.text).toContain('Qui reçoit : Lucas M. (promeneur, Paris)');
    expect(m.text).toContain('Date de la prestation : 2027-01-15, 10:00');
    expect(m.text).toContain(`Réservation (id interne) : ${b._id}`);
    expect(m.text).toMatch(/Admin : https?:\/\/\S+\/admin/);
    expect(m.text).not.toMatch(/TEST|ÉQUIPE/);
    // jamais d'e-mail d'utilisateur ni de donnée de carte
    expect(m.text).not.toContain('camille0410@example.test');
    expect(m.html).toContain('24,00 €');
    const fresh = await Booking.findById(b._id).lean();
    expect(fresh.paymentStatus).toBe('paid');
  });

  test('webhook rejoué (même événement, puis autre événement du même paiement, puis /confirm) → toujours 1 e-mail', async () => {
    const b = await makeBooking();
    const ev = {
      id: 'evt_paid_2', name: 'payment_intent.succeeded',
      data: { id: b.airwallexPaymentIntentId, amount: 24, currency: 'EUR', metadata: {} },
    };
    await postWebhook(ev);
    await postWebhook(ev); // même eventId
    await postWebhook({ ...ev, id: 'evt_paid_2_bis' }); // relivraison sous un autre id
    // chemin synchrone : nouvelle sauvegarde « payée » de la même réservation
    const again = await Booking.findById(b._id);
    again.paymentStatus = 'paid';
    again.status = 'paid';
    await again.save();
    await settle();
    expect(sentEmails).toHaveLength(1);
    expect(await PaymentAlert.countDocuments({ key: `booking-paid:${b._id}` })).toBe(1);
  });

  test('paiement échoué → 0 e-mail', async () => {
    const b = await makeBooking();
    await postWebhook({
      id: 'evt_fail_1', name: 'payment_intent.failed',
      data: { id: b.airwallexPaymentIntentId, amount: 24, currency: 'EUR', metadata: {} },
    });
    await settle();
    expect(sentEmails).toHaveLength(0);
    const fresh = await Booking.findById(b._id).lean();
    expect(fresh.paymentStatus).toBe('failed');
    expect(await PaymentAlert.countDocuments({ key: `booking-paid:${b._id}` })).toBe(0);
  });

  test('abonnement payé par carte (webhook + /confirm) → 1 seul e-mail', async () => {
    const piId = 'int_sub_1';
    const metadata = {
      type: 'subscription_purchase', userId: String(ownerId), role: 'owner',
      plan: 'monthly', intervalDays: '30', currency: 'EUR', paidAmount: '4.99',
    };
    const res = await postWebhook({
      id: 'evt_sub_1', name: 'payment_intent.succeeded',
      data: { id: piId, amount: 4.99, currency: 'EUR', metadata },
    });
    expect(res.statusCode).toBe(200);
    // le /confirm de l'app arrive ensuite avec la même intention
    const airwallex = require('../src/services/airwallexService');
    airwallex.retrievePaymentIntent.mockResolvedValueOnce({ id: piId, status: 'SUCCEEDED', amount: 4.99, currency: 'EUR', metadata });
    const { assertPaidIntent } = require('../src/utils/assertPaidIntent');
    await assertPaidIntent({ paymentIntentId: piId, userId: String(ownerId), purpose: 'subscription' }).catch(() => {});
    await settle();
    expect(sentEmails).toHaveLength(1);
    expect(sentEmails[0].subject).toBe('💰 Paiement reçu : 4,99 € — abonnement PawFollow mensuel (Paris)');
    expect(sentEmails[0].text).toContain('Moyen de paiement : carte bancaire (Airwallex)');
    expect(sentEmails[0].text).toContain('Pour HoPetSit : 100 %');
  });

  test('achat boutique payé avec le portefeuille → 1 e-mail', async () => {
    const { payFromWallet } = require('../src/services/walletService');
    await payFromWallet({
      userId: String(sitterId), userRole: 'sitter', amount: 7.99, currency: 'EUR',
      type: 'debit_purchase', reference: 'pawspot', meta: { kind: 'pawspot', plan: 'pawspot_monthly' },
    });
    await settle();
    expect(sentEmails).toHaveLength(1);
    expect(sentEmails[0].subject).toBe('💰 Paiement reçu : 7,99 € — abonnement PawSpot (Paris)');
    expect(sentEmails[0].text).toContain('portefeuille HoPetSit');
  });

  test('achat Apple validé en Sandbox → 1 e-mail marqué TEST', async () => {
    const { creditForTransaction } = require('../src/services/appleIapService');
    await creditForTransaction({
      userId: String(walkerId), role: 'walker', productId: 'hopetsit_pawfollow_monthly',
      transactionId: '2000000999', originalTransactionId: '2000000999',
      store: { amount: 4.99, currency: 'EUR', storefront: 'FRA', environment: 'Sandbox' },
    });
    await settle();
    expect(sentEmails).toHaveLength(1);
    expect(sentEmails[0].subject).toBe('🧪 TEST — 💰 Paiement reçu : 4,99 € — abonnement PawFollow mensuel (Paris)');
    expect(sentEmails[0].text).toContain('Sandbox');
  });

  test('remboursement → 1 e-mail distinct « Remboursement »', async () => {
    const b = await makeBooking();
    await postWebhook({
      id: 'evt_paid_refund', name: 'payment_intent.succeeded',
      data: { id: b.airwallexPaymentIntentId, amount: 24, currency: 'EUR', metadata: {} },
    });
    await settle();
    expect(sentEmails).toHaveLength(1);
    const { selfCancelWithRefund } = require('../src/controllers/bookingController');
    const res = resMock();
    await selfCancelWithRefund({ params: { id: String(b._id) }, user: { id: String(ownerId), role: 'owner' }, body: {} }, res);
    expect(res.statusCode).toBe(200);
    await settle();
    expect(sentEmails).toHaveLength(2);
    expect(sentEmails[1].subject).toBe('↩️ Remboursement : 24,00 € — réservation promenade (Paris)');
    expect(sentEmails[1].text).toContain('Montant remboursé : 24,00 €');
    expect(sentEmails[1].text).toContain('Réf. remboursement : rfd_');
  });

  test('remboursement qui ÉCHOUE chez Airwallex → aucun e-mail « Remboursement »', async () => {
    const b = await makeBooking();
    await postWebhook({
      id: 'evt_paid_refund_ko', name: 'payment_intent.succeeded',
      data: { id: b.airwallexPaymentIntentId, amount: 24, currency: 'EUR', metadata: {} },
    });
    await settle();
    sentEmails.length = 0;
    const airwallex = require('../src/services/airwallexService');
    airwallex.createRefund.mockRejectedValueOnce(new Error('refus banque (simulé)'));
    const { selfCancelWithRefund } = require('../src/controllers/bookingController');
    await selfCancelWithRefund({ params: { id: String(b._id) }, user: { id: String(ownerId), role: 'owner' }, body: {} }, resMock());
    await settle();
    expect(sentEmails).toHaveLength(0);
    expect((await Booking.findById(b._id).lean()).paymentStatus).toBe('refund');
  });

  test('compte +test → mention « COMPTE DE TEST » bien visible', async () => {
    const b = await makeBooking({ owner: testOwnerId });
    await postWebhook({
      id: 'evt_paid_test', name: 'payment_intent.succeeded',
      data: { id: b.airwallexPaymentIntentId, amount: 24, currency: 'EUR', metadata: {} },
    });
    await settle();
    expect(sentEmails).toHaveLength(1);
    expect(sentEmails[0].subject.startsWith('🧪 TEST — 💰 Paiement reçu : 24,00 €')).toBe(true);
    expect(sentEmails[0].text).toContain("COMPTE DE TEST : ce paiement implique un compte +test. Ce n'est PAS une vraie vente.");
    expect(sentEmails[0].text).toContain('— COMPTE DE TEST');
    expect(sentEmails[0].html).toContain('COMPTE DE TEST');
  });

  test("panne d'e-mail → le paiement est quand même confirmé", async () => {
    mailState.fail = true;
    const b = await makeBooking();
    const res = await postWebhook({
      id: 'evt_paid_smtp_ko', name: 'payment_intent.succeeded',
      data: { id: b.airwallexPaymentIntentId, amount: 24, currency: 'EUR', metadata: {} },
    });
    await settle();
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ received: true });
    const fresh = await Booking.findById(b._id).lean();
    expect(fresh.paymentStatus).toBe('paid');
    expect(fresh.status).toBe('paid');
    expect(sentEmails).toHaveLength(0);
    const row = await PaymentAlert.findOne({ key: `booking-paid:${b._id}` }).lean();
    expect(row.status).toBe('failed');
    expect(row.error).toContain('SMTP en panne');
  });

  test('PAYMENT_ALERTS=off coupe tout', async () => {
    process.env.PAYMENT_ALERTS = 'off';
    try {
      const b = await makeBooking();
      await postWebhook({
        id: 'evt_paid_off', name: 'payment_intent.succeeded',
        data: { id: b.airwallexPaymentIntentId, amount: 24, currency: 'EUR', metadata: {} },
      });
      await settle();
      expect(sentEmails).toHaveLength(0);
    } finally {
      delete process.env.PAYMENT_ALERTS;
    }
  });

  test("e-mail d'essai (route admin) → objet marqué « ESSAI »", async () => {
    const r = await alerts.sendTestPaymentAlert();
    expect(r.to).toBe('contact@hopetsit.com');
    expect(sentEmails).toHaveLength(1);
    expect(sentEmails[0].subject).toBe('🧪 ESSAI — 💰 Paiement reçu : 24,00 € — réservation promenade (Paris)');
    expect(sentEmails[0].text).toContain("Aucun paiement n'a eu lieu");
    expect(await PaymentAlert.countDocuments({ key: /ESSAI/ })).toBe(0);
  });

  test('route POST /admin/payment-alert/test : admin = 200 + e-mail ESSAI, non-admin = 403', async () => {
    const express = require('express');
    const request = require('supertest');
    const jwt = require('jsonwebtoken');
    const app = express();
    app.use(express.json());
    app.use('/admin', require('../src/routes/adminRoutes'));
    const adminTok = `Bearer ${jwt.sign({ id: 'admin0410', role: 'admin' }, process.env.JWT_SECRET)}`;
    const ownerTok = `Bearer ${jwt.sign({ id: String(ownerId), role: 'owner' }, process.env.JWT_SECRET)}`;

    const denied = await request(app).post('/admin/payment-alert/test').set('Authorization', ownerTok);
    expect(denied.status).toBe(403);
    expect(sentEmails).toHaveLength(0);

    const ok = await request(app).post('/admin/payment-alert/test').set('Authorization', adminTok);
    expect(ok.status).toBe(200);
    expect(ok.body.ok).toBe(true);
    expect(ok.body.to).toBe('contact@hopetsit.com');
    expect(sentEmails).toHaveLength(1);
    expect(sentEmails[0].subject.startsWith('🧪 ESSAI — ')).toBe(true);
  });
});
