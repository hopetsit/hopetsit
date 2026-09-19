// v569 — `GET /bookings/:id/agreement` (écran « Accord de réservation »).
//
// BUG corrigé : une réservation de PROMENADE laisse `sitterId` à null et met
// le prestataire dans `walkerId` (createBooking : `sitterId: providerType ===
// 'sitter' ? sitterId : null`). Le contrôleur faisait
// `booking.sitterId._id.toString()` → TypeError → 500 sur TOUTES les
// réservations walker : l'écran restait vide côté promenade.
//
// Aucun accès réseau, aucune base : les modèles et utilitaires du contrôleur
// sont remplacés par des doubles en mémoire.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

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
}));
jest.mock('../src/models/Application', () => ({
  find: jest.fn(() => mockChain([])),
}));
jest.mock('../src/models/Owner', () => ({}));
jest.mock('../src/models/Sitter', () => ({}));
jest.mock('../src/models/Walker', () => ({}));
jest.mock('../src/models/Pet', () => ({}));
jest.mock('../src/models/Review', () => ({}));
jest.mock('../src/models/Conversation', () => ({}));
jest.mock('../src/services/airwallexService', () => ({}));
jest.mock('../src/services/paypalService', () => ({}));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn() }));
// Firebase Admin exige des variables d'environnement réelles au require.
jest.mock('../src/services/notificationSender', () => ({
  sendNotification: jest.fn(async () => ({})),
  sendPushToUser: jest.fn(async () => ({})),
}));

const OWNER_ID = '000000000000000000000001';
const WALKER_ID = '000000000000000000000002';
const SITTER_ID = '000000000000000000000003';

const makeRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (c) => {
    res.statusCode = c;
    return res;
  };
  res.json = (b) => {
    res.body = b;
    return res;
  };
  return res;
};

const baseBooking = ({ walker = false }) => {
  const provider = {
    _id: { toString: () => (walker ? WALKER_ID : SITTER_ID) },
    name: walker ? 'Walker Test' : 'Sitter Test',
    email: 'provider@example.test',
    avatar: { url: 'https://example.test/a.png' },
    stripeConnectAccountStatus: 'connected',
  };
  const doc = {
    _id: { toString: () => '000000000000000000000009' },
    ownerId: {
      _id: { toString: () => OWNER_ID },
      name: 'Owner Test',
      email: 'owner@example.test',
      avatar: { url: '' },
    },
    sitterId: walker ? null : provider,
    walkerId: walker ? provider : null,
    petIds: [],
    description: 'Balade du soir',
    date: '2026-09-04T09:00:00.000Z',
    startDate: '2026-09-04T09:00:00.000Z',
    endDate: '2026-09-04T09:30:00.000Z',
    timeSlot: '10:00',
    duration: 30,
    houseSittingVenue: null,
    status: 'agreed',
    pricing: {
      basePrice: 0.2,
      pricingTier: 'hourly',
      appliedRate: 0.4,
      totalHours: 0.5,
      totalDays: 1,
      totalPrice: 0.24,
      commission: 0.04,
      netPayout: 0.2,
      currency: 'EUR',
    },
    toObject: () => ({ serviceType: 'dog_walking' }),
  };
  return doc;
};

// `sanitizeBooking` réel est lourd (chiffrement, blocs légaux) : on le remplace
// par une projection minimale qui reproduit ses champs utiles, dont `walker`.
jest.mock('../src/utils/sanitize', () => ({
  sanitizeBooking: (b) => ({
    id: '000000000000000000000009',
    status: b.status,
    owner: { id: '000000000000000000000001', name: 'Owner Test', email: 'owner@example.test', avatar: { url: '' } },
    sitter: b.sitterId
      ? { id: '000000000000000000000003', name: 'Sitter Test', email: 'provider@example.test', avatar: { url: 'https://example.test/a.png' } }
      : undefined,
    walker: b.walkerId
      ? { id: '000000000000000000000002', name: 'Walker Test', email: 'provider@example.test', avatar: { url: 'https://example.test/a.png' } }
      : undefined,
    pricing: b.pricing,
    createdAt: '2026-09-01T00:00:00.000Z',
    updatedAt: '2026-09-01T00:00:00.000Z',
  }),
  sanitizeConversation: (c) => c,
}));

const { getBookingAgreement } = require('../src/controllers/bookingController');

describe('GET /bookings/:id/agreement', () => {
  test('réservation WALKER (sitterId null) : 200 et prestataire renseigné', async () => {
    mockBookingStore.doc = baseBooking({ walker: true });
    const res = makeRes();
    await getBookingAgreement(
      { params: { id: '000000000000000000000009' }, user: { id: OWNER_ID } },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.body.agreement).toBeDefined();
    expect(res.body.agreement.sitter.id).toBe(WALKER_ID);
    expect(res.body.agreement.sitter.name).toBe('Walker Test');
    expect(res.body.agreement.providerRole).toBe('walker');
  });

  test('le WALKER lui-même a le droit de lire son accord', async () => {
    mockBookingStore.doc = baseBooking({ walker: true });
    const res = makeRes();
    await getBookingAgreement(
      { params: { id: '000000000000000000000009' }, user: { id: WALKER_ID } },
      res,
    );
    expect(res.statusCode).toBe(200);
  });

  test('un tiers reste refusé (403)', async () => {
    mockBookingStore.doc = baseBooking({ walker: true });
    const res = makeRes();
    await getBookingAgreement(
      { params: { id: '000000000000000000000009' }, user: { id: '00000000000000000000000f' } },
      res,
    );
    expect(res.statusCode).toBe(403);
  });

  test('réservation SITTER : comportement inchangé + palier et net exposés', async () => {
    mockBookingStore.doc = baseBooking({ walker: false });
    const res = makeRes();
    await getBookingAgreement(
      { params: { id: '000000000000000000000009' }, user: { id: OWNER_ID } },
      res,
    );

    expect(res.statusCode).toBe(200);
    const a = res.body.agreement;
    expect(a.sitter.id).toBe(SITTER_ID);
    expect(a.providerRole).toBe('sitter');
    // L'app lit ces champs : palier traduit, total facturé et net prestataire.
    expect(a.pricing.pricingTier).toBe('hourly');
    expect(a.pricing.totalPrice).toBe(0.24);
    expect(a.pricing.netToSitter).toBe(0.2);
    expect(a.pricing.currency).toBe('EUR');
  });
});
