// v566 — comptabilité boutique à montants RÉELS : prix réel App Store
// (milli-unités → décimal, devise, pays, environnement, Sandbox exclu,
// REFUND daté) et montant réellement débité par Airwallex + plateforme
// (ios|android|web), PawSpot compris. Aucune base, aucun appel réseau.

process.env.NODE_ENV = 'test';

const mockStores = { UserSubscription: [], ProcessedWebhook: [], Owner: [] };
const mockSeq = { n: 1 };
const mockMatches = (doc, filter) => Object.entries(filter || {}).every(([k, v]) => String(doc[k]) === String(v));
const mockDoc = (name, data) => {
  const d = { _id: `${name}_${mockSeq.n++}`, ...data };
  Object.defineProperty(d, 'save', { enumerable: false, value: async function save() { return this; } });
  return d;
};
const mockQuery = (r) => ({ select: () => mockQuery(r), lean: () => mockQuery(r), then: (ok, ko) => Promise.resolve(r).then(ok, ko) });
const mockModel = (name) => ({
  findOne: (f) => mockQuery(mockStores[name].find((d) => mockMatches(d, f)) || null),
  findById: (id) => mockQuery(mockStores[name].find((d) => String(d._id) === String(id)) || null),
  updateOne: async (f, u) => { const d = mockStores[name].find((x) => mockMatches(x, f)); if (d) Object.assign(d, u.$set || {}); return { modifiedCount: d ? 1 : 0 }; },
  create: async (data) => {
    if (name === 'ProcessedWebhook' && mockStores[name].some((x) => x.eventId === data.eventId)) {
      const e = new Error('dup'); e.code = 11000; throw e;
    }
    const d = mockDoc(name, data); mockStores[name].push(d); return d;
  },
});

jest.mock('../src/models/ProcessedWebhook', () => mockModel('ProcessedWebhook'));
jest.mock('../src/models/Owner', () => mockModel('Owner'));
jest.mock('../src/models/Sitter', () => mockModel('Owner'));
jest.mock('../src/models/Walker', () => mockModel('Owner'));
jest.mock('../src/models/UserSubscription', () => {
  function UserSubscription(data) {
    const d = mockDoc('UserSubscription', { payments: [], history: [], pawspotHistory: [], ...data });
    mockStores.UserSubscription.push(d);
    return d;
  }
  Object.assign(UserSubscription, mockModel('UserSubscription'), {
    isFamilyPlan: () => false,
    isPremiumPlan: () => false,
    migrateLegacyFamily: () => {},
    syncSubscriptionAcrossRoles: async () => {},
  });
  return UserSubscription;
});
jest.mock('../src/utils/logger', () => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => {}) }));
// Faux vérificateur Apple : le « JWS » est du JSON ; chaque vérificateur
// n'accepte que SON environnement (comme la vraie bibliothèque).
jest.mock('fs', () => ({
  ...jest.requireActual('fs'),
  readdirSync: (dir, ...rest) => (String(dir).endsWith('certs/apple') ? ['root.cer'] : jest.requireActual('fs').readdirSync(dir, ...rest)),
  readFileSync: (file, ...rest) => (String(file).endsWith('root.cer') ? Buffer.from('x') : jest.requireActual('fs').readFileSync(file, ...rest)),
}));
jest.mock('@apple/app-store-server-library', () => {
  class SignedDataVerifier {
    constructor(_c, _o, env) { this.env = env; }
    async verifyAndDecodeTransaction(jws) {
      const p = JSON.parse(jws);
      if (p.environment !== this.env) throw new Error('wrong environment');
      return p;
    }
    async verifyAndDecodeNotification(jws) {
      const p = JSON.parse(jws);
      if ((p.data?.environment || 'Production') !== this.env) throw new Error('wrong environment');
      return p;
    }
  }
  return { SignedDataVerifier, Environment: { PRODUCTION: 'Production', SANDBOX: 'Sandbox' } };
}, { virtual: false });

const apple = require('../src/services/appleIapService');
const {
  activateSubscriptionFromWebhook,
  activatePawSpotFromWebhook,
} = require('../src/controllers/purchaseActivationController');
const { platformFromRequest } = require('../src/utils/purchasePlatform');
const revenue = require('../src/services/shopRevenueService');

const tx = (over = {}) => ({
  productId: 'hopetsit_pawfollow_monthly', transactionId: 'tx_1', originalTransactionId: 'otx_1',
  price: 5490, currency: 'USD', storefront: 'USA', environment: 'Production', ...over,
});
const credit = (payload, environment) => apple.creditForTransaction({
  userId: 'user_1', role: 'owner', productId: payload.productId,
  transactionId: payload.transactionId, originalTransactionId: payload.originalTransactionId,
  store: apple.storeInfoFromPayload(payload, environment),
});

beforeEach(() => { Object.values(mockStores).forEach((s) => { s.length = 0; }); });

describe('Apple IAP — prix réel du store', () => {
  test('milli-unités → décimal, devise, pays, environnement', () => {
    expect(apple.storeInfoFromPayload(tx(), 'Production')).toEqual({
      amount: 5.49, currency: 'USD', storefront: 'USA', environment: 'Production',
    });
    expect(apple.storeInfoFromPayload({ productId: 'x' }, 'Production').amount).toBeNull();
  });

  test('Production : ligne au prix RÉEL, amountSource store, reconnue non estimée', async () => {
    await credit(tx(), 'Production');
    const line = mockStores.UserSubscription[0].payments[0];
    expect(line).toMatchObject({
      amount: 5.49, currency: 'USD', paymentProvider: 'apple_iap', amountSource: 'store',
      platform: 'ios', storefront: 'USA', environment: 'Production',
      transactionId: 'tx_1', originalTransactionId: 'otx_1', paymentIntentId: 'tx_1',
    });
    expect(line.excludedFromRevenue).toBeUndefined();
    const enriched = revenue.enrichPurchase({ ...line, product: 'premium', tier: 'monthly' }, {});
    expect(enriched.channel).toBe('apple');
    expect(enriched.estimated).toBe(false);

    await credit(tx(), 'Production'); // restauration / double POST
    expect(mockStores.UserSubscription[0].payments).toHaveLength(1);
  });

  test('Sandbox : enregistré mais marqué exclu des revenus', async () => {
    await credit(tx({ environment: 'Sandbox', transactionId: 'tx_sb' }), 'Sandbox');
    const line = mockStores.UserSubscription[0].payments[0];
    expect(line.environment).toBe('Sandbox');
    expect(line.excludedFromRevenue).toBe(true);
  });

  test('sans prix dans la transaction : prix catalogue, pas de amountSource', async () => {
    await credit(tx({ price: undefined, currency: undefined }), 'Production');
    const line = mockStores.UserSubscription[0].payments[0];
    expect(line.amount).toBe(4.99);
    expect(line.currency).toBe('EUR');
    expect(line.amountSource).toBeUndefined();
  });

  test('notification REFUND : refundedAt posé une seule fois, accès coupé', async () => {
    await credit(tx(), 'Production');
    const notif = (date) => JSON.stringify({
      notificationType: 'REFUND',
      data: { environment: 'Production', signedTransactionInfo: JSON.stringify(tx({ revocationDate: date })) },
    });
    const r = await apple.handleNotification(notif(1789000000000));
    expect(r.revoked).toBe(true);
    const line = mockStores.UserSubscription[0].payments[0];
    expect(line.refundedAt.getTime()).toBe(1789000000000);
    await apple.handleNotification(notif(1799000000000));
    expect(line.refundedAt.getTime()).toBe(1789000000000);
  });
});

describe('Airwallex / wallet — montant réellement débité + plateforme', () => {
  test('en-têtes → plateforme', () => {
    expect(platformFromRequest({ headers: { 'x-app-platform': 'iOS' } })).toBe('ios');
    expect(platformFromRequest({ headers: { 'x-app-platform': 'android' } })).toBe('android');
    expect(platformFromRequest({ headers: { 'x-app-version': 'web' } })).toBe('web');
    expect(platformFromRequest({ headers: {} })).toBe('');
  });

  test('webhook abonnement : montant de l’événement, psp, android ; idempotent', async () => {
    const metadata = {
      userId: 'user_1', role: 'owner', plan: 'monthly', intervalDays: '30', currency: 'EUR',
      paidAmount: '5.59', platform: 'android', providerAmount: '5.59', providerCurrency: 'EUR',
    };
    await activateSubscriptionFromWebhook({ piId: 'int_1', metadata });
    await activateSubscriptionFromWebhook({ piId: 'int_1', metadata });
    const sub = mockStores.UserSubscription[0];
    expect(sub.payments).toHaveLength(1);
    expect(sub.payments[0]).toMatchObject({
      amount: 5.59, currency: 'EUR', paymentProvider: 'airwallex', amountSource: 'psp', platform: 'android',
    });
  });

  test('PawSpot par carte : laisse enfin un montant (et une seule ligne)', async () => {
    const metadata = {
      userId: 'user_1', role: 'owner', plan: 'yearly', days: '365', currency: 'USD',
      providerAmount: '43.99', providerCurrency: 'USD', platform: 'web',
    };
    await activatePawSpotFromWebhook({ piId: 'int_ps', metadata, alreadyClaimed: true });
    await activatePawSpotFromWebhook({ piId: 'int_ps', metadata, alreadyClaimed: true });
    const sub = mockStores.UserSubscription[0];
    expect(sub.pawspotHistory).toHaveLength(1);
    expect(sub.payments).toHaveLength(1);
    expect(sub.payments[0]).toMatchObject({
      plan: 'pawspot_yearly', amount: 43.99, currency: 'USD',
      paymentProvider: 'airwallex', amountSource: 'psp', platform: 'web',
    });
  });

  test('PawSpot payé au portefeuille : prestataire wallet, montant débité', async () => {
    await activatePawSpotFromWebhook({
      piId: 'wallet_1_pawspot',
      metadata: { userId: 'user_1', role: 'sitter', plan: 'monthly', days: '30', currency: 'EUR', provider: 'wallet', paidAmount: '4.99', platform: 'ios' },
    });
    expect(mockStores.UserSubscription[0].payments[0]).toMatchObject({
      plan: 'pawspot_monthly', amount: 4.99, paymentProvider: 'wallet', platform: 'ios',
    });
  });
});
