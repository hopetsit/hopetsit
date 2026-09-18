// v566 — réductions boutique : RÉSERVÉES à la création du paiement,
// CONSOMMÉES à sa réussite (une seule fois, quel que soit le chemin).
// Aucune base réelle, aucun appel Airwallex : modèles et service simulés.

process.env.NODE_ENV = 'test';
process.env.PAYMENT_PROVIDER = 'airwallex';

// ── Magasin en mémoire ─────────────────────────────────────────────────────
const mockStores = {
  PromoCodeRedemption: [], PawRewardRedemption: [], Referral: [],
  ProcessedWebhook: [], UserSubscription: [], Owner: [],
};
const mockIntents = {};
const mockSeq = { n: 1 };

const mockGet = (doc, path) => path.split('.').reduce((o, k) => (o == null ? o : o[k]), doc);
const mockMatches = (doc, filter) => Object.entries(filter || {}).every(([k, v]) => {
  const val = mockGet(doc, k);
  if (v && typeof v === 'object' && !(v instanceof Date)) {
    if ('$ne' in v) return val !== v.$ne;
    if ('$regex' in v) return new RegExp(v.$regex).test(String(val || ''));
  }
  if (v === null) return val === null || val === undefined;
  return String(val) === String(v);
});
const mockDoc = (name, data) => {
  const d = { _id: `${name}_${mockSeq.n++}`, createdAt: new Date(), ...data };
  Object.defineProperty(d, 'save', { enumerable: false, value: async function save() { return this; } });
  return d;
};
const mockQuery = (result) => ({
  sort: () => mockQuery(result),
  select: () => mockQuery(result),
  lean: () => mockQuery(result),
  then: (ok, ko) => Promise.resolve(result).then(ok, ko),
});
const mockModel = (name) => {
  const store = mockStores[name];
  return {
    find: (f) => mockQuery(store.filter((d) => mockMatches(d, f))),
    findOne: (f) => mockQuery(store.find((d) => mockMatches(d, f)) || null),
    findById: (id) => mockQuery(store.find((d) => String(d._id) === String(id)) || null),
    updateOne: async (f, u) => {
      const d = store.find((x) => mockMatches(x, f));
      if (d) Object.assign(d, u.$set || {});
      return { matchedCount: d ? 1 : 0, modifiedCount: d ? 1 : 0 };
    },
    findOneAndUpdate: async (f, u) => {
      const d = store.find((x) => mockMatches(x, f));
      if (!d) return null;
      Object.assign(d, u.$set || {});
      return d;
    },
    create: async (data) => {
      if (name === 'ProcessedWebhook' && store.some((x) => x.eventId === data.eventId)) {
        const e = new Error('duplicate key'); e.code = 11000; throw e;
      }
      const d = mockDoc(name, data); store.push(d); return d;
    },
  };
};

jest.mock('../src/models/PromoCodeRedemption', () => mockModel('PromoCodeRedemption'));
jest.mock('../src/models/PawRewardRedemption', () => mockModel('PawRewardRedemption'));
jest.mock('../src/models/Referral', () => mockModel('Referral'));
jest.mock('../src/models/ProcessedWebhook', () => mockModel('ProcessedWebhook'));
jest.mock('../src/models/Owner', () => mockModel('Owner'));
jest.mock('../src/models/Sitter', () => mockModel('Owner'));
jest.mock('../src/models/Walker', () => mockModel('Owner'));
jest.mock('../src/models/UserSubscription', () => {
  const base = mockModel('UserSubscription');
  function UserSubscription(data) {
    const d = mockDoc('UserSubscription', { payments: [], history: [], ...data });
    mockStores.UserSubscription.push(d);
    return d;
  }
  Object.assign(UserSubscription, base, {
    PREMIUM_PLAN_INTERVALS: { monthly: 30, yearly: 365 },
    PREMIUM_PRICING: { EUR: {} },
    PREMIUM_FEATURES_DEFAULT: {},
    getPlanPricing: (plan, currency) => (plan === 'monthly'
      ? { amount: 6.99, currency: currency || 'EUR', intervalDays: 30, label: 'Monthly' }
      : plan === 'yearly'
        ? { amount: 49.99, currency: currency || 'EUR', intervalDays: 365, label: 'Yearly' }
        : null),
    isFamilyPlan: () => false,
    isPremiumPlan: () => false,
    migrateLegacyFamily: () => {},
    syncSubscriptionAcrossRoles: async () => {},
  });
  return UserSubscription;
});
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, _res, next) => { req.user = { id: 'user_1', role: 'owner' }; next(); },
}));
jest.mock('../src/utils/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));
jest.mock('../src/utils/currency', () => ({ normalizeCurrency: (c) => String(c || 'EUR').toUpperCase() }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => {}) }));
jest.mock('../src/services/airwallexService', () => ({
  findOrCreateCustomer: jest.fn(async () => ({ id: 'cus_1' })),
  createPlatformPaymentIntent: jest.fn(async ({ amount, currency, metadata }) => {
    const id = `int_${Object.keys(mockIntents).length + 1}`;
    mockIntents[id] = { id, client_secret: `sec_${id}`, status: 'REQUIRES_PAYMENT_METHOD', amount: amount / 100, currency, metadata };
    return mockIntents[id];
  }),
  retrievePaymentIntent: jest.fn(async (id) => mockIntents[id]),
}));

const express = require('express');
const request = require('supertest');
const discounts = require('../src/services/discountReservationService');
const { activateSubscriptionFromWebhook } = require('../src/controllers/purchaseActivationController');

const app = express();
app.use(express.json());
app.use('/subscriptions', require('../src/routes/subscriptionRoutes'));

const pay = (id) => { mockIntents[id].status = 'SUCCEEDED'; };
const promo = () => mockStores.PromoCodeRedemption[0];

beforeEach(() => {
  Object.values(mockStores).forEach((s) => { s.length = 0; });
  Object.keys(mockIntents).forEach((k) => delete mockIntents[k]);
  mockStores.Owner.push(mockDoc('Owner', { _id: 'user_1', email: 'a@b.c', name: 'Ada Test', isStaff: false }));
  mockStores.PromoCodeRedemption.push(mockDoc('PromoCodeRedemption', {
    userId: 'user_1', code: 'MOINS20', discountConsumedAt: null,
    reward: { kind: 'percent_discount', discountPercent: 20, plan: '' },
  }));
});

describe('réductions boutique — réservées puis consommées', () => {
  test('création → abandon : la réduction reste disponible', async () => {
    const r1 = await request(app).post('/subscriptions/subscribe').send({ plan: 'monthly' });
    expect(r1.status).toBe(200);
    expect(r1.body.amount).toBeCloseTo(5.59, 2); // 6,99 € − 20 %
    expect(r1.body.fullAmount).toBeCloseTo(6.99, 2);
    // Réservée sur l'intention (30 min), PAS consommée.
    expect(promo().discountConsumedAt).toBeNull();
    expect(promo().discountReservedIntentId).toBe(r1.body.paymentIntentId);
    const ttl = promo().discountReservedUntil.getTime() - Date.now();
    expect(ttl).toBeGreaterThan(29 * 60 * 1000);
    expect(ttl).toBeLessThanOrEqual(discounts.RESERVATION_TTL_MS);

    // L'utilisateur ferme la feuille puis réessaie : même prix réduit.
    const r2 = await request(app).post('/subscriptions/subscribe').send({ plan: 'monthly' });
    expect(r2.body.amount).toBeCloseTo(5.59, 2);
    expect(promo().discountConsumedAt).toBeNull();
    expect(promo().discountReservedIntentId).toBe(r2.body.paymentIntentId);
  });

  test('création → confirm : consommée une fois, vrai montant + airwallex enregistrés', async () => {
    const r = await request(app).post('/subscriptions/subscribe').send({ plan: 'monthly' });
    const piId = r.body.paymentIntentId;
    pay(piId);
    const c = await request(app).post('/subscriptions/confirm').send({ plan: 'monthly', paymentIntentId: piId });
    expect(c.status).toBe(200);
    expect(promo().discountConsumedAt).toBeInstanceOf(Date);
    expect(promo().discountConsumedIntentId).toBe(piId);

    const sub = mockStores.UserSubscription[0];
    expect(sub.payments).toHaveLength(1);
    expect(sub.payments[0].amount).toBeCloseTo(5.59, 2); // pas 6,99
    expect(sub.payments[0].currency).toBe('EUR');
    expect(sub.payments[0].paymentProvider).toBe('airwallex'); // jamais 'stripe'

    // Achat suivant : plus de réduction.
    const next = await request(app).post('/subscriptions/subscribe').send({ plan: 'monthly' });
    expect(next.body.amount).toBeCloseTo(6.99, 2);
  });

  test('confirm + webhook : une seule consommation, une seule activation', async () => {
    const r = await request(app).post('/subscriptions/subscribe').send({ plan: 'monthly' });
    const piId = r.body.paymentIntentId;
    pay(piId);
    await request(app).post('/subscriptions/confirm').send({ plan: 'monthly', paymentIntentId: piId });
    const firstConsumedAt = promo().discountConsumedAt;

    const hook = await activateSubscriptionFromWebhook({ piId, metadata: mockIntents[piId].metadata });
    expect(hook.skipped).toBe(true);
    expect(promo().discountConsumedAt).toBe(firstConsumedAt);
    expect(await discounts.consumeDiscounts({ refs: mockIntents[piId].metadata.discountRefs, piId })).toBe(0);
    expect(mockStores.UserSubscription).toHaveLength(1);
    expect(mockStores.UserSubscription[0].payments).toHaveLength(1);
  });

  test('webhook seul puis confirm : consommée une fois, montant réel enregistré', async () => {
    const r = await request(app).post('/subscriptions/subscribe').send({ plan: 'monthly' });
    const piId = r.body.paymentIntentId;
    pay(piId);
    const hook = await activateSubscriptionFromWebhook({ piId, metadata: mockIntents[piId].metadata });
    expect(hook.activated).toBe(true);
    expect(promo().discountConsumedIntentId).toBe(piId);
    const sub = mockStores.UserSubscription[0];
    expect(sub.payments[0].amount).toBeCloseTo(5.59, 2);
    expect(sub.payments[0].paymentProvider).toBe('airwallex');

    const c = await request(app).post('/subscriptions/confirm').send({ plan: 'monthly', paymentIntentId: piId });
    expect(c.body.alreadyActivated).toBe(true);
    expect(sub.payments).toHaveLength(1);
  });

  test('parrainage + PawPoints se cumulent, le code promo attend son tour', async () => {
    mockStores.Referral.push(mockDoc('Referral', {
      referrerId: 'user_1', status: 'completed', creditAwarded: true, rewardConsumed: false,
    }));
    mockStores.PawRewardRedemption.push(mockDoc('PawRewardRedemption', {
      userId: 'user_1', rewardKey: 'sub_disc_10', status: 'pending',
      snapshot: { percent: 10, plans: ['monthly'] },
    }));
    const r = await request(app).post('/subscriptions/subscribe').send({ plan: 'monthly' });
    expect(r.body.amount).toBeCloseTo(5.66, 2); // 6,99 × 0,9 × 0,9
    pay(r.body.paymentIntentId);
    await request(app).post('/subscriptions/confirm').send({ plan: 'monthly', paymentIntentId: r.body.paymentIntentId });
    expect(mockStores.Referral[0].rewardConsumed).toBe(true);
    expect(mockStores.PawRewardRedemption[0].status).toBe('fulfilled');
    expect(promo().discountConsumedAt).toBeNull(); // toujours disponible
  });
});
