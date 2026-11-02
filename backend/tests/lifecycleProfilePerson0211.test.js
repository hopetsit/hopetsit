/**
 * 02/11 (BOB) — `profile_incomplete_d3` raisonné par PERSONNE (cas Agnès D.).
 *
 * Bilan du 20/09/2026 : 45 % seulement des nouveaux inscrits confirment leur
 * e-mail. Daniel : « ok relance », mais « surtout pas harceler par mail » →
 * UNE SEULE relance par compte, jamais plus.
 *
 * Tout est simulé : aucun réseau, aucune base, aucun e-mail réel.
 */
const path = require('path');
const fs = require('fs');

// ---------------------------------------------------------------- faux modèles
const DAY = 24 * 60 * 60 * 1000;
const now = Date.now();

// Base de test : une ligne par document (rôle + e-mail + verified).
let DOCS = [];

const chain = (value) => {
  const c = {
    select: () => c,
    sort: () => c,
    limit: () => c,
    lean: async () => value,
  };
  return c;
};

const mkModel = (role) => ({
  modelName: role,
  find: jest.fn((q) => {
    const since = q.createdAt && q.createdAt.$gte ? new Date(q.createdAt.$gte).getTime() : 0;
    const before = q.createdAt && q.createdAt.$lte ? new Date(q.createdAt.$lte).getTime() : Infinity;
    return chain(
      DOCS.filter((d) => d.role === role
        && d.createdAt.getTime() >= since
        && d.createdAt.getTime() <= before
        && d.isStaff !== true
        && d.marketingOptOut !== true),
    );
  }),
  findById: jest.fn(() => chain(null)),
  exists: jest.fn(async (q) => {
    const emails = (q.email && q.email.$in) || [q.email];
    const hit = DOCS.find((d) => d.role === role
      && emails.includes(d.email)
      && (q.verified === undefined || d.verified === q.verified));
    return hit ? { _id: hit._id } : null;
  }),
});

const mockOwnerModel = mkModel('owner');
const mockSitterModel = mkModel('sitter');
const mockWalkerModel = mkModel('walker');

jest.mock('../src/models/Owner', () => mockOwnerModel);
jest.mock('../src/models/Sitter', () => mockSitterModel);
jest.mock('../src/models/Walker', () => mockWalkerModel);
jest.mock('../src/models/Booking', () => ({
  find: jest.fn(() => ({ select: () => ({ limit: () => ({ lean: async () => [] }) }) })),
  countDocuments: jest.fn(async () => 0),
}));
jest.mock('../src/models/Post', () => ({ countDocuments: jest.fn(async () => 0) }));

// Traçage : une entrée = une étape consommée (index unique en vrai).
let mockSent = [];
jest.mock('../src/models/LifecycleEmail', () => ({
  create: jest.fn(async (doc) => {
    const dup = mockSent.find((s) => String(s.userId) === String(doc.userId)
      && s.role === doc.role && s.step === doc.step && (s.refId || '') === (doc.refId || ''));
    if (dup) throw new Error('E11000 duplicate key');
    mockSent.push({ ...doc });
    return doc;
  }),
  exists: jest.fn(async (q) => {
    if (q.step) {
      return mockSent.find((s) => String(s.userId) === String(q.userId)
        && s.role === q.role && s.step === q.step && (s.refId || '') === (q.refId || '')) || null;
    }
    // garde-fou « 6 jours entre deux relances »
    return mockSent.find((s) => String(s.userId) === String(q.userId)
      && s.role === q.role && s.skipped === false
      && s.sentAt && s.sentAt.getTime() >= new Date(q.sentAt.$gte).getTime()) || null;
  }),
  updateOne: jest.fn(async (q, upd) => {
    const row = mockSent.find((s) => String(s.userId) === String(q.userId)
      && s.role === q.role && s.step === q.step && (s.refId || '') === (q.refId || ''));
    if (row) Object.assign(row, upd.$set);
    return { acknowledged: true };
  }),
}));

jest.mock('mongoose', () => ({ connection: { readyState: 1 } }));
jest.mock('../src/utils/encryption', () => ({ decrypt: (v) => v }));
jest.mock('../src/services/emailService', () => ({ sendEmail: jest.fn(async () => ({ messageId: 'mock' })) }));

const { sendEmail } = require('../src/services/emailService');
const { runLifecycleOnce } = require('../src/services/lifecycleEmailScheduler');

let seq = 0;
const doc = ({ role = 'sitter', email, verified = false, ageDays = 3, appLocale = 'fr' }) => {
  seq += 1;
  return {
    _id: `6400000000000000000000${String(seq).padStart(2, '0')}`,
    role,
    name: 'Camille Durand',
    email,
    appLocale,
    verified,
    isStaff: false,
    marketingOptOut: false,
    createdAt: new Date(now - ageDays * DAY),
    updatedAt: new Date(now - ageDays * DAY),
    avatar: { url: 'https://x/a.jpg' },
    bio: 'Je garde des chiens et des chats depuis dix ans, chez moi comme chez vous.',
    hourlyRate: 15,
  };
};

const stepsSent = () => mockSent.filter((s) => s.skipped === false).map((s) => s.step);

beforeEach(() => {
  jest.clearAllMocks();
  DOCS = [];
  mockSent = [];
  delete process.env.LIFECYCLE_DRY_RUN;
});

describe('profile_incomplete_d3 — par personne', () => {
  test('promeneur sans présentation mais profil gardien complet (même e-mail) : pas d\'e-mail', async () => {
    DOCS = [
      { ...doc({ role: 'walker', email: 'agnes@example.test', verified: true, ageDays: 8 }), bio: '', hourlyRate: undefined, walkRates: [{ minutes: 30, price: 10 }] },
      doc({ role: 'sitter', email: 'agnes@example.test', verified: true, ageDays: 8 }),
    ];
    await runLifecycleOnce();
    expect(stepsSent()).not.toContain('profile_incomplete_d3');
  });

  test('promeneur seul sans présentation : l\'e-mail part toujours', async () => {
    DOCS = [{ ...doc({ role: 'walker', email: 'seul@example.test', verified: true, ageDays: 8 }), bio: '', hourlyRate: undefined, walkRates: [{ minutes: 30, price: 10 }] }];
    await runLifecycleOnce();
    expect(stepsSent()).toContain('profile_incomplete_d3');
  });
});
