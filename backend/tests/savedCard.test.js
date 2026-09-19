// v568 — Carte bancaire enregistrée : un seul client Airwallex par PERSONNE
// (les 3 profils owner / sitter / walker le partagent), cartes normalisées
// sans aucune donnée sensible, carte par défaut, et page de paiement qui
// reçoit bien `customer_id` (sans quoi Airwallex ne propose jamais la carte
// déjà enregistrée).
//
// Aucun appel réseau : le service Airwallex et les modèles Mongoose sont
// simulés.

process.env.NODE_ENV = 'test';
process.env.PAYMENT_PROVIDER = 'airwallex';

// ── Base de données simulée : 3 profils du même humain ─────────────────────
const mockDb = {
  Owner: [],
  Sitter: [],
  Walker: [],
};

const mockQuery = (result) => ({
  select: () => mockQuery(result),
  lean: () => mockQuery(result),
  then: (ok, ko) => Promise.resolve(result).then(ok, ko),
});

const makeModel = (name) => ({
  modelName: name,
  findById: (id) => mockQuery(mockDb[name].find((d) => String(d._id) === String(id)) || null),
  updateOne: async (filter, update) => {
    const doc = mockDb[name].find((d) => String(d._id) === String(filter._id));
    if (doc) Object.assign(doc, update.$set || {});
    return { matchedCount: doc ? 1 : 0, modifiedCount: doc ? 1 : 0 };
  },
});

jest.mock('../src/models/Owner', () => makeModel('Owner'), { virtual: false });
jest.mock('../src/models/Sitter', () => makeModel('Sitter'), { virtual: false });
jest.mock('../src/models/Walker', () => makeModel('Walker'), { virtual: false });

// identityGroup : les 3 documents du même email.
jest.mock('../src/utils/identityGroup', () => ({
  identityGroup: async () => ({
    ids: ['own_1', 'sit_1', 'wal_1'],
    docs: [
      { id: 'own_1', model: 'Owner' },
      { id: 'sit_1', model: 'Sitter' },
      { id: 'wal_1', model: 'Walker' },
    ],
    set: new Set(['own_1', 'sit_1', 'wal_1']),
  }),
}));

// Airwallex simulé : on compte les créations pour prouver qu'on n'ouvre
// qu'UN client par personne.
const awx = {
  customers: [],
  createdCount: 0,
  consents: [],
};

jest.mock('../src/services/airwallexService', () => ({
  findCustomerByMerchantId: async (merchantId) =>
    awx.customers.find((c) => c.merchant_customer_id === merchantId) || null,
  findOrCreateCustomer: async ({ userId, email }) => {
    const existing = awx.customers.find((c) => c.merchant_customer_id === userId);
    if (existing) return existing;
    awx.createdCount += 1;
    const created = { id: `cus_${awx.createdCount}`, merchant_customer_id: userId, email };
    awx.customers.push(created);
    return created;
  },
  listPaymentMethods: async () => ({ items: awx.consents }),
}));

const {
  ensureAirwallexCustomer,
  intentCustomerFields,
  listSavedCards,
  normalizeConsent,
  isExpiredCard,
  setDefaultConsentId,
} = require('../src/utils/airwallexCustomer');

const resetDb = () => {
  mockDb.Owner = [{ _id: 'own_1', email: 'daniel@hopetsit.com', name: 'Daniel Cardelli' }];
  mockDb.Sitter = [{ _id: 'sit_1', email: 'daniel@hopetsit.com', name: 'Daniel Cardelli' }];
  mockDb.Walker = [{ _id: 'wal_1', email: 'daniel@hopetsit.com', name: 'Daniel Cardelli' }];
  awx.customers = [];
  awx.createdCount = 0;
  awx.consents = [];
};

beforeEach(resetDb);

// ───────────────────────────────────────────────────────────────────────────
describe('un seul client Airwallex par personne (3 profils)', () => {
  test('crée le client une seule fois et le mémorise sur les 3 profils', async () => {
    const first = await ensureAirwallexCustomer({ userId: 'own_1', role: 'owner' });
    expect(first.customerId).toBe('cus_1');
    expect(awx.createdCount).toBe(1);
    expect(mockDb.Owner[0].airwallexCustomerId).toBe('cus_1');
    expect(mockDb.Sitter[0].airwallexCustomerId).toBe('cus_1');
    expect(mockDb.Walker[0].airwallexCustomerId).toBe('cus_1');
  });

  test('le profil gardien retrouve la carte du profil propriétaire', async () => {
    await ensureAirwallexCustomer({ userId: 'own_1', role: 'owner' });
    const asSitter = await ensureAirwallexCustomer({ userId: 'sit_1', role: 'sitter' });
    expect(asSitter.customerId).toBe('cus_1');
    // Aucun second client : c'était la cause de « ma carte a disparu »
    // après un changement de rôle.
    expect(awx.createdCount).toBe(1);
  });

  test('récupère un client créé par une version précédente (clé = id de rôle)', async () => {
    // Historique : client créé sous l'_id du profil gardien.
    awx.customers.push({ id: 'cus_legacy', merchant_customer_id: 'sit_1' });
    const r = await ensureAirwallexCustomer({ userId: 'own_1', role: 'owner' });
    expect(r.customerId).toBe('cus_legacy');
    expect(awx.createdCount).toBe(0);
    expect(mockDb.Owner[0].airwallexCustomerId).toBe('cus_legacy');
  });

  test('chemin rapide : id déjà porté par le document appelant', async () => {
    const r = await ensureAirwallexCustomer({
      userId: 'own_1',
      role: 'owner',
      userDoc: {
        email: 'daniel@hopetsit.com',
        airwallexCustomerId: 'cus_deja',
        defaultCardConsentId: 'cst_7',
      },
    });
    expect(r.customerId).toBe('cus_deja');
    expect(r.defaultConsentId).toBe('cst_7');
    expect(awx.createdCount).toBe(0);
  });

  test('ne lève jamais : un échec Airwallex renvoie customerId null', async () => {
    const airwallex = require('../src/services/airwallexService');
    const backup = airwallex.findOrCreateCustomer;
    airwallex.findOrCreateCustomer = async () => { throw new Error('502 Airwallex'); };
    const r = await ensureAirwallexCustomer({ userId: 'own_1', role: 'owner' });
    expect(r.customerId).toBeNull();
    airwallex.findOrCreateCustomer = backup;
  });
});

// ───────────────────────────────────────────────────────────────────────────
describe('champs client sur une intention de paiement', () => {
  test('sans client : aucun champ (paiement invité inchangé)', () => {
    expect(intentCustomerFields({ customerId: null })).toEqual({});
  });

  test('avec client : customer_id SEUL (pas de bloc payment_consent)', () => {
    // Ajouter un bloc `payment_consent` sur chaque paiement affichait une
    // page Airwallex vide (régression v23.1 part 60).
    const f = intentCustomerFields({ customerId: 'cus_1' });
    expect(f).toEqual({ customer_id: 'cus_1' });
  });

  test('« enregistrer ma carte » ajoute un consentement réutilisable', () => {
    const f = intentCustomerFields({ customerId: 'cus_1', saveCard: true });
    expect(f.customer_id).toBe('cus_1');
    expect(f.payment_consent).toEqual({
      type: 'recurring',
      next_triggered_by: 'customer',
      merchant_trigger_reason: 'unscheduled',
    });
  });

  test('carte déjà enregistrée choisie : pas de nouveau consentement', () => {
    const f = intentCustomerFields({ customerId: 'cus_1', saveCard: true, consentId: 'cst_9' });
    expect(f.payment_consent).toBeUndefined();
  });
});

// ───────────────────────────────────────────────────────────────────────────
describe('liste des cartes', () => {
  const consent = (id, last4, month, year) => ({
    id,
    status: 'VERIFIED',
    created_at: '2026-01-01',
    payment_method: {
      card: { brand: 'visa', last4, expiry_month: month, expiry_year: year, name: 'D CARDELLI' },
    },
  });

  test('ne renvoie ni numéro complet ni CVC', () => {
    const c = normalizeConsent(consent('cst_1', '4242', 4, 2030), null);
    expect(c.last4).toBe('4242');
    expect(JSON.stringify(c)).not.toMatch(/cvc|number|pan/i);
  });

  test('carte expirée signalée', () => {
    expect(isExpiredCard({ expiryMonth: 1, expiryYear: 2020 })).toBe(true);
    expect(isExpiredCard({ expiryMonth: 12, expiryYear: 2099 })).toBe(false);
    expect(isExpiredCard({ expiryMonth: null, expiryYear: null })).toBe(false);
  });

  test('la carte par défaut est en tête', async () => {
    awx.consents = [consent('cst_1', '4242', 4, 2030), consent('cst_2', '8571', 9, 2031)];
    const { cards, defaultId } = await listSavedCards({
      customerId: 'cus_1',
      defaultConsentId: 'cst_2',
    });
    expect(defaultId).toBe('cst_2');
    expect(cards[0].id).toBe('cst_2');
    expect(cards[0].isDefault).toBe(true);
  });

  test('défaut supprimé → repli sur une carte valide', async () => {
    awx.consents = [consent('cst_1', '4242', 1, 2020), consent('cst_2', '8571', 9, 2031)];
    const { defaultId, cards } = await listSavedCards({
      customerId: 'cus_1',
      defaultConsentId: 'cst_disparue',
    });
    expect(defaultId).toBe('cst_2'); // cst_1 est expirée
    expect(cards.find((c) => c.id === 'cst_1').isExpired).toBe(true);
  });

  test('le choix de la carte par défaut est écrit sur les 3 profils', async () => {
    await setDefaultConsentId({ userId: 'own_1', consentId: 'cst_2' });
    expect(mockDb.Owner[0].defaultCardConsentId).toBe('cst_2');
    expect(mockDb.Sitter[0].defaultCardConsentId).toBe('cst_2');
    expect(mockDb.Walker[0].defaultCardConsentId).toBe('cst_2');
  });
});

// ───────────────────────────────────────────────────────────────────────────
describe('page de paiement (pont Airwallex)', () => {
  const buildApp = () => {
    const express = require('express');
    const app = express();
    app.use('/api/v1/airwallex', require('../src/routes/airwallexBridgeRoutes'));
    return app;
  };

  test('avec ?customer= : customer_id transmis à redirectToCheckout', async () => {
    const request = require('supertest');
    const res = await request(buildApp())
      .get('/api/v1/airwallex/checkout')
      .query({ intent: 'int_1', secret: 'sec_1', currency: 'EUR', customer: 'cus_1' });
    expect(res.status).toBe(200);
    expect(res.text).toContain('cus_1');
    expect(res.text).toContain('opts.customer_id = CUSTOMER');
    expect(res.text).toContain('autoSaveCardForFuturePayments');
  });

  test('sans client : la page reste fonctionnelle (paiement invité)', async () => {
    const request = require('supertest');
    const res = await request(buildApp())
      .get('/api/v1/airwallex/checkout')
      .query({ intent: 'int_1', secret: 'sec_1', currency: 'EUR' });
    expect(res.status).toBe(200);
    expect(res.text).toContain('var CUSTOMER = ""');
  });

  test('paramètres manquants : refus explicite', async () => {
    const request = require('supertest');
    const res = await request(buildApp()).get('/api/v1/airwallex/checkout');
    expect(res.status).toBe(400);
  });
});
