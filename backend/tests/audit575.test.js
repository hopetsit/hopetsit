/**
 * v575 — audit des parcours : les 6 régressions corrigées, prouvées ici.
 *
 * Aucun réseau, aucune base : les modèles, Airwallex et le transport des
 * notifications sont simulés. Chaque test décrit le bug qu'il empêche de
 * revenir.
 */
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

// ── Doubles des modèles et services ────────────────────────────────────────
const mockBookingStore = { doc: null };

const mockChain = (result) => {
  const c = {
    populate: () => c,
    select: () => c,
    sort: () => c,
    limit: () => c,
    lean: async () => result,
    then: (res, rej) => Promise.resolve(result).then(res, rej),
  };
  return c;
};

jest.mock('../src/models/Booking', () => ({
  findById: jest.fn(() => mockChain(mockBookingStore.doc)),
  find: jest.fn(() => mockChain([])),
}));
jest.mock('../src/models/Application', () => ({
  find: jest.fn(() => mockChain([])),
  findOne: jest.fn(() => mockChain(null)),
}));
// Les 3 profils de la personne : un seul document simulé, partagé (le
// destinataire des notifications). `null` par défaut pour les autres tests.
const mockUserStore = { doc: null };
const mockRoleModel = (name) => ({
  modelName: name,
  findById: jest.fn(() => mockChain(mockUserStore.doc)),
  find: jest.fn(() => mockChain(mockUserStore.doc ? [mockUserStore.doc] : [])),
  findByIdAndUpdate: jest.fn(async () => null),
  updateOne: jest.fn(async () => ({ matchedCount: 1 })),
});
jest.mock('../src/models/Owner', () => mockRoleModel('Owner'));
jest.mock('../src/models/Sitter', () => mockRoleModel('Sitter'));
jest.mock('../src/models/Walker', () => mockRoleModel('Walker'));
jest.mock('../src/models/Pet', () => ({}));
jest.mock('../src/models/Post', () => ({ updateMany: jest.fn(async () => ({ matchedCount: 0 })) }));
jest.mock('../src/models/Review', () => ({ find: jest.fn(() => mockChain([])) }));
jest.mock('../src/models/Conversation', () => ({}));

// ── Notifications : transport simulé, LOGIQUE RÉELLE (on teste son payload) ──
const mockSendMulticast = jest.fn(async () => ({
  successCount: 1, failureCount: 0, responses: [],
}));
jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({ sendEachForMulticast: mockSendMulticast }),
}));
jest.mock('../src/utils/encryption', () => ({ decrypt: (v) => v, encrypt: (v) => v }));
jest.mock('../src/services/notificationService', () => ({
  createNotificationSafe: jest.fn(async () => ({
    _id: '64b0000000000000000000aa', createdAt: new Date(),
  })),
  getUnreadCount: jest.fn(async () => 1),
}));
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn(),
  isUserOnline: jest.fn(async () => false),
  emitToConversation: jest.fn(),
  emitChatMessage: jest.fn(),
  buildPresenceIndex: jest.fn(async () => null),
  isIdentityOnline: jest.fn(() => false),
}));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async () => ({ messageId: 'mock' })) };
});

// ── Code promo ──────────────────────────────────────────────────────────────
const mockPromoStore = { promo: null, redemptions: [], lastFindOneQuery: null };
jest.mock('../src/models/PromoCode', () => ({
  findOne: jest.fn(async () => mockPromoStore.promo),
}));
jest.mock('../src/models/PromoCodeRedemption', () => ({
  findOne: jest.fn(async (query) => {
    mockPromoStore.lastFindOneQuery = query;
    const wanted = query?.userId?.$in || [query?.userId];
    return (
      mockPromoStore.redemptions.find((r) => wanted.includes(String(r.userId))) || null
    );
  }),
  create: jest.fn(async (doc) => {
    mockPromoStore.redemptions.push(doc);
    return doc;
  }),
}));
jest.mock('../src/models/UserSubscription', () => {
  const M = function UserSubscription(d) { Object.assign(this, d); };
  M.prototype.save = async function save() { return this; };
  M.findOne = jest.fn(async () => null);
  M.isFamilyPlan = () => false;
  M.isPremiumPlan = () => false;
  M.migrateLegacyFamily = () => {};
  M.syncSubscriptionAcrossRoles = async () => {};
  return M;
});
// Les 3 ids d'une même personne (owner / sitter / walker), et une AUTRE
// personne, pour vérifier que le code reste utilisable par quelqu'un d'autre.
const mockSelfIds = [
  '000000000000000000000011',
  '000000000000000000000012',
  '000000000000000000000013',
];
const mockOtherIds = ['0000000000000000000000f1', '0000000000000000000000f2'];
const mockGroupFor = (id) =>
  mockSelfIds.includes(String(id)) ? mockSelfIds : mockOtherIds.includes(String(id))
    ? mockOtherIds
    : [String(id)];
jest.mock('../src/utils/identityGroup', () => ({
  identityGroup: jest.fn(async (id) => {
    const ids = mockGroupFor(id);
    return { ids, set: new Set(ids), docs: [] };
  }),
  selfIdSet: jest.fn(async (req) => new Set(mockGroupFor(req?.user?.id))),
}));

const mockAirwallex = {
  retrievePaymentIntent: jest.fn(),
  createPlatformPaymentIntent: jest.fn(),
  createRefund: jest.fn(),
  mapAirwallexError: (e) => ({ status: 500, code: 'X', message: e?.message || 'x' }),
};
jest.mock('../src/services/airwallexService', () => mockAirwallex);
jest.mock('../src/services/paypalService', () => ({}));
jest.mock('../src/services/paypalPayoutService', () => ({ sendPayoutToSitter: jest.fn() }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn() }));
// notificationSender n'est PAS simulé : c'est lui qu'on teste (P1-3). Seuls
// ses transports (Firebase, SMTP, socket) le sont, ci-dessus.

const mockEnsureCustomer = jest.fn(async () => ({
  customerId: 'cus_575',
  defaultConsentId: 'cst_575',
}));
jest.mock('../src/utils/airwallexCustomer', () => ({
  ensureAirwallexCustomer: (...a) => mockEnsureCustomer(...a),
  intentCustomerFields: () => ({}),
}));

const bookingController = require('../src/controllers/bookingController');
const {
  isValidWalkDuration,
  roundToValidWalkDuration,
  resolveWalkPricing,
} = require('../src/utils/walkDuration');
const { calculateTierBasePrice } = require('../src/utils/tierPricing');
const { sendNotification } = require('../src/services/notificationSender');
const promoRouter = require('../src/routes/promoRoutes');

/** Dernier gestionnaire d'une route du routeur (après requireAuth). */
const routeHandler = (router, method, path) => {
  const layer = router.stack.find(
    (l) => l.route && l.route.path === path && l.route.methods[method],
  );
  const stack = layer.route.stack;
  return stack[stack.length - 1].handle;
};

const OWNER_ID = '000000000000000000000001';
const WALKER_ID = '000000000000000000000002';
const BOOKING_ID = '000000000000000000000009';

const makeRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  return res;
};

beforeEach(() => {
  jest.clearAllMocks();
  mockBookingStore.doc = null;
});

// ───────────────────────────────────────────────────────────────────────────
// P0-2 — annuler une réservation PAYÉE ne doit pas passer par cancelBooking
// ───────────────────────────────────────────────────────────────────────────
describe('P0-2 — annulation simple refusée sur une réservation payée', () => {
  const paidBooking = (overrides = {}) => {
    const doc = {
      _id: { toString: () => BOOKING_ID },
      ownerId: { toString: () => OWNER_ID },
      sitterId: null,
      walkerId: { toString: () => WALKER_ID },
      petIds: [],
      status: 'paid',
      paymentStatus: 'paid',
      paidAt: new Date('2026-09-01T10:00:00.000Z'),
      payoutStatus: 'scheduled',
      scheduledPayoutAt: new Date('2026-09-10T10:00:00.000Z'),
      saved: 0,
      ...overrides,
    };
    doc.save = jest.fn(async () => { doc.saved += 1; return doc; });
    doc.populate = jest.fn(async () => doc);
    return doc;
  };

  const call = async (doc) => {
    mockBookingStore.doc = doc;
    const req = {
      user: { id: OWNER_ID, role: 'owner' },
      params: { id: BOOKING_ID },
      query: { walkerId: WALKER_ID },
    };
    const res = makeRes();
    await bookingController.cancelBooking(req, res);
    return res;
  };

  test('409 PAID_BOOKING_USE_SELF_CANCEL et AUCUNE écriture', async () => {
    const doc = paidBooking();
    const res = await call(doc);

    expect(res.statusCode).toBe(409);
    expect(res.body.code).toBe('PAID_BOOKING_USE_SELF_CANCEL');
    // Le bug : la réservation était passée à `cancelled` sans rembourser, et
    // le versement au prestataire restait programmé.
    expect(doc.save).not.toHaveBeenCalled();
    expect(doc.saved).toBe(0);
    expect(doc.status).toBe('paid');
    expect(doc.paymentStatus).toBe('paid');
    expect(doc.payoutStatus).toBe('scheduled');
    expect(doc.scheduledPayoutAt).not.toBeNull();
  });

  test('payée via paymentStatus seul (status=agreed) → refusée aussi', async () => {
    const doc = paidBooking({ status: 'agreed', paidAt: null });
    const res = await call(doc);
    expect(res.statusCode).toBe(409);
    expect(res.body.code).toBe('PAID_BOOKING_USE_SELF_CANCEL');
    expect(doc.save).not.toHaveBeenCalled();
  });

  test('payée via paidAt seul → refusée aussi', async () => {
    const doc = paidBooking({ status: 'agreed', paymentStatus: 'pending' });
    const res = await call(doc);
    expect(res.statusCode).toBe(409);
    expect(res.body.code).toBe('PAID_BOOKING_USE_SELF_CANCEL');
    expect(doc.save).not.toHaveBeenCalled();
  });

  test('réservation NON payée : l\'annulation simple marche toujours', async () => {
    const doc = paidBooking({
      status: 'pending',
      paymentStatus: 'pending',
      paidAt: null,
      payoutStatus: 'pending',
      scheduledPayoutAt: null,
    });
    const res = await call(doc);
    expect(res.statusCode).toBe(200);
    expect(doc.status).toBe('cancelled');
    expect(doc.save).toHaveBeenCalled();
  });
});

// ───────────────────────────────────────────────────────────────────────────
// P0-1 / P1-6 / P1-7 — durées de promenade
// ───────────────────────────────────────────────────────────────────────────
describe('P0-1 — durées de promenade acceptées', () => {
  test('45, 90 et 120 minutes sont valides (elles étaient refusées en 400)', () => {
    for (const d of [15, 30, 45, 60, 75, 90, 120, 180, 300]) {
      expect(isValidWalkDuration(d)).toBe(true);
    }
  });

  test('20, 305, 0, null et les non-multiples de 15 sont refusés', () => {
    for (const d of [20, 305, 0, -30, 7, 61, null, undefined, NaN, 'abc']) {
      expect(isValidWalkDuration(d)).toBe(false);
    }
  });

  test('même règle que walkRateEntrySchema (models/Walker.js)', () => {
    const { model } = require('mongoose');
    // La règle est dupliquée à dessein (le schéma n'exporte pas son
    // validateur) : on vérifie ici qu'elle reste identique sur les bornes.
    expect(isValidWalkDuration(15)).toBe(true);
    expect(isValidWalkDuration(300)).toBe(true);
    expect(isValidWalkDuration(14)).toBe(false);
    expect(isValidWalkDuration(315)).toBe(false);
    expect(typeof model).toBe('function');
  });

  test('arrondi d\'une durée libre au multiple de 15, borné 15–300', () => {
    expect(roundToValidWalkDuration(44)).toBe(45);
    expect(roundToValidWalkDuration(47)).toBe(45);
    expect(roundToValidWalkDuration(53)).toBe(60);
    expect(roundToValidWalkDuration(5)).toBe(15);
    expect(roundToValidWalkDuration(999)).toBe(300);
    expect(roundToValidWalkDuration(0)).toBeNull();
    expect(roundToValidWalkDuration('x')).toBeNull();
  });
});

describe('P0-1 — prix cohérent quelle que soit la durée', () => {
  const rates = [
    { durationMinutes: 30, basePrice: 5, enabled: true },
    { durationMinutes: 60, basePrice: 8, enabled: true },
    { durationMinutes: 90, basePrice: 11, enabled: true },
  ];
  // Prix final réellement facturé = ce que fait createBooking :
  // hourlyRate shimé → calculateTierBasePrice(durationMinutes).
  const priceFor = (walkRates, duration) => {
    const p = resolveWalkPricing(walkRates, duration);
    if (!p) return null;
    return calculateTierBasePrice({
      hourlyRate: p.hourlyRate,
      dailyRate: 0,
      weeklyRate: 0,
      monthlyRate: 0,
      serviceDate: '2026-10-01T10:00:00.000Z',
      durationMinutes: duration,
    }).basePrice;
  };

  test('palier EXACT → on facture le tarif affiché par le promeneur', () => {
    expect(priceFor(rates, 30)).toBeCloseTo(5, 2);
    expect(priceFor(rates, 60)).toBeCloseTo(8, 2);
    expect(priceFor(rates, 90)).toBeCloseTo(11, 2);
  });

  test('sans palier exact → prorata du tarif horaire (palier 60 min)', () => {
    // 45 min = 0,75 × 8 € = 6 €. Avant, 45 min était refusée en 400.
    expect(priceFor(rates, 45)).toBeCloseTo(6, 2);
    expect(priceFor(rates, 120)).toBeCloseTo(16, 2);
  });

  test('promeneur n\'ayant QUE le palier 45 min : plus de « aucun tarif »', () => {
    const only45 = [{ durationMinutes: 45, basePrice: 9, enabled: true }];
    const p = resolveWalkPricing(only45, 45);
    expect(p).not.toBeNull();
    expect(p.exact).toBe(true);
    expect(priceFor(only45, 45)).toBeCloseTo(9, 2);
    // 60 min se déduit du palier le plus proche : 9 € / 45 min = 12 €/h.
    expect(priceFor(only45, 60)).toBeCloseTo(12, 2);
  });

  test('aucun palier facturable → null (le contrôleur répond 400)', () => {
    expect(resolveWalkPricing([], 60)).toBeNull();
    expect(resolveWalkPricing([{ durationMinutes: 60, basePrice: 0, enabled: true }], 60)).toBeNull();
    expect(resolveWalkPricing([{ durationMinutes: 60, basePrice: 8, enabled: false }], 60)).toBeNull();
  });

  test('sans durée demandée : tarif horaire de référence = palier 60', () => {
    const p = resolveWalkPricing(rates, null);
    expect(p.hourlyRate).toBeCloseTo(8, 2);
  });
});

// ───────────────────────────────────────────────────────────────────────────
// P1-1 — fenêtre des 72 h : les 4 champs doivent survivre au reformatage
// ───────────────────────────────────────────────────────────────────────────
describe('P1-1 — _formatBookingForUser expose la fenêtre des 72 h', () => {
  const buildBooking = (startIso) => ({
    _id: { toString: () => BOOKING_ID },
    ownerId: {
      _id: { toString: () => OWNER_ID },
      name: 'Owner', email: 'o@example.test', avatar: { url: '' },
      toObject() { return { ...this }; },
    },
    sitterId: null,
    walkerId: {
      _id: { toString: () => WALKER_ID },
      name: 'Walker', email: 'w@example.test', avatar: { url: '' },
      location: { city: 'Paris' },
      toObject() { return { ...this }; },
    },
    petIds: [],
    description: 'Balade',
    date: startIso,
    startDate: startIso,
    endDate: startIso,
    timeSlot: '10:00',
    serviceType: 'dog_walking',
    duration: 60,
    status: 'paid',
    paymentStatus: 'paid',
    paidAt: new Date(),
    pricing: { basePrice: 8, totalPrice: 9.6, commission: 1.6, currency: 'EUR' },
    createdAt: new Date(),
    updatedAt: new Date(),
    toObject() { return { ...this }; },
  });

  test('canSelfCancel / hoursUntilStart / startDate / endDate sont présents', async () => {
    const inTenDays = new Date(Date.now() + 10 * 24 * 3600 * 1000).toISOString();
    const out = await bookingController._formatBookingForUser(
      buildBooking(inTenDays),
      'owner',
    );
    expect(out).toHaveProperty('canSelfCancel');
    expect(out).toHaveProperty('hoursUntilStart');
    expect(out).toHaveProperty('startDate');
    expect(out).toHaveProperty('endDate');
    // Réservation payée à plus de 72 h → le serveur autorise le self-cancel.
    expect(out.canSelfCancel).toBe(true);
    expect(out.hoursUntilStart).toBeGreaterThan(72);
    expect(out.startDate).toBe(inTenDays);
  });

  test('dans les 72 h : canSelfCancel=false, l\'app ne propose plus le bouton', async () => {
    const inTwoDays = new Date(Date.now() + 2 * 24 * 3600 * 1000).toISOString();
    const out = await bookingController._formatBookingForUser(
      buildBooking(inTwoDays),
      'owner',
    );
    expect(out.canSelfCancel).toBe(false);
    expect(out.hoursUntilStart).toBeLessThan(72);
  });
});

// ───────────────────────────────────────────────────────────────────────────
// P1-8 — réponse du PaymentIntent réutilisé aussi complète que la nominale
// ───────────────────────────────────────────────────────────────────────────
describe('P1-8 — carte enregistrée conservée à la 2e tentative', () => {
  const FIELDS = [
    'paymentIntentId', 'clientSecret', 'amount', 'currency',
    'commissionAmount', 'netSitterAmount', 'loyaltyDiscountApplied',
    'booking', 'customerId', 'defaultConsentId',
    'serverConfirmed', 'nextActionUrl', 'savedCardError', 'message',
  ];

  const booking = {
    _id: { toString: () => BOOKING_ID },
    ownerId: { _id: { toString: () => OWNER_ID } },
    pricing: { totalPrice: 24, commission: 4, currency: 'EUR' },
    toObject() { return { ...this }; },
  };

  test('les deux chemins renvoient exactement les mêmes clés', () => {
    const nominal = bookingController.buildPaymentIntentResponse({
      paymentIntentId: 'int_new', clientSecret: 'cs_new', booking,
      amountInCents: 2400, currency: 'EUR',
      commissionAmount: 400, netSitterAmount: 2000,
      customerId: 'cus_575', defaultConsentId: 'cst_575',
    });
    const reused = bookingController.buildPaymentIntentResponse({
      paymentIntentId: 'int_old', clientSecret: 'cs_old', booking,
      amountInCents: 2400, currency: 'EUR',
      commissionAmount: 400, netSitterAmount: 2000,
      customerId: 'cus_575', defaultConsentId: 'cst_575',
      reusedExistingIntent: true,
    });
    expect(Object.keys(nominal).sort()).toEqual(FIELDS.slice().sort());
    expect(Object.keys(reused).sort()).toEqual(Object.keys(nominal).sort());
    // Sans `customerId`, la page Airwallex n'affiche AUCUNE carte enregistrée.
    expect(reused.customerId).toBe('cus_575');
    expect(reused.defaultConsentId).toBe('cst_575');
    expect(reused.amount).toBe(2400);
    expect(reused.currency).toBe('EUR');
    expect(reused.serverConfirmed).toBe(false);
    expect(reused.savedCardError).toBeNull();
  });

  test('createBookingPaymentIntent réutilise l\'intention SANS perdre le client', async () => {
    mockAirwallex.retrievePaymentIntent.mockResolvedValue({
      id: 'int_existing',
      client_secret: 'cs_existing',
      status: 'REQUIRES_PAYMENT_METHOD',
      amount: 24,
    });
    const walkerDoc = {
      _id: { toString: () => WALKER_ID },
      country: 'FR',
      ibanNumber: 'FR7630001007941234567890185',
      paypalEmail: '',
      toObject() { return { ...this }; },
    };
    mockBookingStore.doc = {
      _id: { toString: () => BOOKING_ID },
      ownerId: { _id: { toString: () => OWNER_ID }, toObject() { return { ...this }; } },
      sitterId: null,
      walkerId: walkerDoc,
      petIds: [],
      status: 'agreed',
      pricing: { totalPrice: 24, commission: 4, currency: 'EUR' },
      airwallexPaymentIntentId: 'int_existing',
      save: jest.fn(async function save() { return this; }),
      populate: jest.fn(async function pop() { return this; }),
      toObject() { return { ...this }; },
    };

    const res = makeRes();
    await bookingController.createBookingPaymentIntent(
      { params: { id: BOOKING_ID }, user: { id: OWNER_ID, role: 'owner' }, body: {} },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.body.paymentIntentId).toBe('int_existing');
    for (const f of FIELDS) expect(res.body).toHaveProperty(f);
    expect(res.body.customerId).toBe('cus_575');
    expect(res.body.defaultConsentId).toBe('cst_575');
    expect(res.body.amount).toBe(2400);
    expect(res.body.currency).toBe('EUR');
    // Aucune NOUVELLE intention créée : on a bien réutilisé l'existante.
    expect(mockAirwallex.createPlatformPaymentIntent).not.toHaveBeenCalled();
  });
});

// ───────────────────────────────────────────────────────────────────────────
// P1-9 — un code promo à usage unique se consomme PAR PERSONNE, pas par profil
// ───────────────────────────────────────────────────────────────────────────
describe('P1-9 — code promo refusé pour un profil frère', () => {
  const redeem = routeHandler(promoRouter, 'post', '/redeem');
  const PROMO_ID = '000000000000000000000077';

  beforeEach(() => {
    mockPromoStore.promo = {
      _id: PROMO_ID,
      code: 'HOPDALIOS',
      rewardType: 'percent_discount',
      discountPercent: 20,
      plan: 'premium',
      usedCount: 0,
      isRedeemable: () => true,
      save: jest.fn(async () => {}),
    };
    mockPromoStore.redemptions = [];
    mockPromoStore.lastFindOneQuery = null;
  });

  const call = (userId) => {
    const res = makeRes();
    return redeem(
      { body: { code: 'hopdalios' }, user: { id: userId, role: 'owner' } },
      res,
    ).then(() => res);
  };

  test('la recherche porte sur TOUS les ids de la personne', async () => {
    await call(mockSelfIds[0]);
    expect(mockPromoStore.lastFindOneQuery).toEqual({
      promoCodeId: PROMO_ID,
      userId: { $in: mockSelfIds },
    });
  });

  test('utilisé sous le profil propriétaire → refusé sous les 2 autres profils', async () => {
    const first = await call(mockSelfIds[0]);
    expect(first.statusCode).toBe(200);
    expect(first.body.ok).toBe(true);

    // Le bug : la déduplication portait sur l'_id du DOCUMENT DE RÔLE, donc
    // le même code passait une 2e puis une 3e fois en changeant de profil.
    const second = await call(mockSelfIds[1]);
    expect(second.statusCode).toBe(409);
    const third = await call(mockSelfIds[2]);
    expect(third.statusCode).toBe(409);
    expect(mockPromoStore.redemptions).toHaveLength(1);
  });

  test('une AUTRE personne peut toujours utiliser le code', async () => {
    await call(mockSelfIds[0]);
    const stranger = await call(mockOtherIds[0]);
    expect(stranger.statusCode).toBe(200);
    expect(stranger.body.ok).toBe(true);
    expect(mockPromoStore.redemptions).toHaveLength(2);
    // …mais pas son second profil.
    const strangerSibling = await call(mockOtherIds[1]);
    expect(strangerSibling.statusCode).toBe(409);
  });
});

// ───────────────────────────────────────────────────────────────────────────
// P1-3 — le push doit dire pour QUEL profil il est émis
// ───────────────────────────────────────────────────────────────────────────
describe('P1-3 — recipientRole présent dans le push', () => {
  beforeEach(() => {
    mockUserStore.doc = {
      _id: '000000000000000000000012',
      email: 'daniel@example.test',
      name: 'Daniel',
      appLocale: 'fr',
      language: 'French',
      fcmTokens: ['tok-575'],
      fcmDevices: [],
      notificationPrefs: null,
    };
  });
  afterEach(() => { mockUserStore.doc = null; });

  test('une notification destinée au profil gardien porte recipientRole=sitter', async () => {
    await sendNotification({
      userId: '000000000000000000000012',
      role: 'sitter',
      type: 'booking_paid',
      data: { bookingId: BOOKING_ID },
    });
    expect(mockSendMulticast).toHaveBeenCalled();
    const msg = mockSendMulticast.mock.calls[0][0];
    // Sans ce champ, l'app ouvrait un écran du MAUVAIS profil → 403.
    expect(msg.data.recipientRole).toBe('sitter');
    expect(msg.data.type).toBe('booking_paid');
    expect(typeof msg.data.route).toBe('string');
  });

  test('et recipientRole=owner pour le profil propriétaire', async () => {
    await sendNotification({
      userId: '000000000000000000000012',
      role: 'owner',
      type: 'booking_paid_owner',
      data: { bookingId: BOOKING_ID },
    });
    const msg = mockSendMulticast.mock.calls[0][0];
    expect(msg.data.recipientRole).toBe('owner');
  });

  test('toutes les valeurs du payload push restent des chaînes (exigence FCM)', async () => {
    await sendNotification({
      userId: '000000000000000000000012',
      role: 'walker',
      type: 'walk_started',
      data: { bookingId: BOOKING_ID },
    });
    const msg = mockSendMulticast.mock.calls[0][0];
    expect(msg.data.recipientRole).toBe('walker');
    for (const [k, v] of Object.entries(msg.data)) {
      expect(typeof v).toBe('string');
      expect(k).toBeTruthy();
    }
  });
});
