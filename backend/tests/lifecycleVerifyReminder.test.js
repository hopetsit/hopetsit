/**
 * v574 — relance de vérification d'e-mail (`verify_email_d2`).
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
const subjects = () => sendEmail.mock.calls.map((c) => c[1]);

beforeEach(() => {
  jest.clearAllMocks();
  DOCS = [];
  mockSent = [];
  delete process.env.LIFECYCLE_DRY_RUN;
});

describe('verify_email_d2 — sélection des comptes', () => {
  test('un compte non vérifié de 3 jours reçoit la relance de vérification', async () => {
    DOCS = [doc({ email: 'lena@example.test', verified: false, ageDays: 3 })];
    const r = await runLifecycleOnce();
    expect(r.sent).toBe(1);
    expect(stepsSent()).toEqual(['verify_email_d2']);
    expect(sendEmail).toHaveBeenCalledTimes(1);
    expect(sendEmail.mock.calls[0][0]).toBe('lena@example.test');
    expect(subjects()[0]).toContain('confirme ton e-mail');
    // Le corps renvoie vers l'app, sans code ni lien magique.
    const html = sendEmail.mock.calls[0][3];
    expect(html).toContain('https://www.hopetsit.com/pawmap');
    expect(html).toMatch(/Renvoyer le code/);
    expect(html).not.toMatch(/verify-link|code=|\bOTP\b/);
  });

  test('la vérification passe AVANT « bienvenue » (un seul e-mail par passage)', async () => {
    DOCS = [doc({ role: 'owner', email: 'nouveau@example.test', verified: false, ageDays: 2.5 })];
    await runLifecycleOnce();
    expect(stepsSent()).toEqual(['verify_email_d2']);
    expect(stepsSent()).not.toContain('welcome_owner_d1');
  });

  test('un compte déjà vérifié ne reçoit rien de cette étape', async () => {
    DOCS = [doc({ email: 'ok@example.test', verified: true, ageDays: 3 })];
    await runLifecycleOnce();
    expect(stepsSent()).not.toContain('verify_email_d2');
    // le compte EST bien passé dans le planificateur (sinon le test ne prouve rien)
    expect(stepsSent()).toContain('welcome_provider_d1');
  });

  test('un profil frère vérifié (même e-mail) suffit : aucune relance', async () => {
    // « un compte, trois profils » (v565) : l'e-mail est vérifié pour la personne.
    DOCS = [
      doc({ role: 'walker', email: 'daniel@example.test', verified: false, ageDays: 4 }),
      { ...doc({ role: 'owner', email: 'daniel@example.test', verified: true, ageDays: 4 }), isStaff: true },
    ];
    await runLifecycleOnce();
    expect(stepsSent()).not.toContain('verify_email_d2');
    expect(stepsSent()).toContain('welcome_provider_d1');
  });

  test('jamais deux fois : le deuxième passage ne renvoie rien', async () => {
    DOCS = [doc({ email: 'once@example.test', verified: false, ageDays: 3 })];
    const first = await runLifecycleOnce();
    expect(first.sent).toBe(1);
    sendEmail.mockClear();
    const second = await runLifecycleOnce();
    expect(second.sent).toBe(0);
    expect(sendEmail).not.toHaveBeenCalled();
    expect(stepsSent().filter((s) => s === 'verify_email_d2')).toHaveLength(1);
  });

  test('un compte créé avant le 10/09/2026 (LIFECYCLE_SINCE) est exclu', async () => {
    DOCS = [doc({ email: 'ancien@example.test', verified: false, ageDays: 400 })];
    const r = await runLifecycleOnce();
    expect(r.sent).toBe(0);
    expect(sendEmail).not.toHaveBeenCalled();
  });

  test('un compte de moins de 48 h est hors fenêtre', async () => {
    DOCS = [doc({ email: 'trop-tot@example.test', verified: false, ageDays: 1 })];
    await runLifecycleOnce();
    expect(stepsSent()).not.toContain('verify_email_d2');
  });

  test('au-delà de 21 jours la fenêtre est fermée', async () => {
    // LIFECYCLE_SINCE reculé : sinon aucun compte ne peut atteindre 21 jours
    // (mise en service le 10/09/2026), et la borne haute ne serait pas testée.
    DOCS = [doc({ email: 'trop-tard@example.test', verified: false, ageDays: 25 })];
    process.env.LIFECYCLE_SINCE = '2026-01-01T00:00:00Z';
    let run;
    jest.isolateModules(() => {
      ({ runLifecycleOnce: run } = require('../src/services/lifecycleEmailScheduler'));
    });
    await run();
    delete process.env.LIFECYCLE_SINCE;
    expect(stepsSent()).not.toContain('verify_email_d2');
  });

  test('un compte +test est exclu (aucun e-mail envoyé)', async () => {
    DOCS = [doc({ email: 'dadaciao84+testsitter@gmail.com', verified: false, ageDays: 3 })];
    const r = await runLifecycleOnce();
    expect(r.sent).toBe(0);
    expect(sendEmail).not.toHaveBeenCalled();
  });

  test('la langue du compte est respectée (pl)', async () => {
    DOCS = [doc({ email: 'ola@example.test', verified: false, ageDays: 3, appLocale: 'pl' })];
    await runLifecycleOnce();
    expect(subjects()[0]).toContain('potwierdź swój e-mail');
  });
});

describe('verify_email_d2 — catalogues', () => {
  const LOCALES = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

  test('les 9 langues portent la clé avec subject/title/paragraphs/cta/ctaUrl', () => {
    const dir = path.join(__dirname, '..', 'src', 'locales');
    expect(fs.readdirSync(dir).filter((d) => fs.statSync(path.join(dir, d)).isDirectory()).sort())
      .toEqual([...LOCALES].sort());
    for (const lang of LOCALES) {
      const cat = JSON.parse(fs.readFileSync(path.join(dir, lang, 'lifecycle.json'), 'utf8'));
      const tpl = cat.verify_email_d2;
      expect(tpl).toBeDefined();
      expect(typeof tpl.subject).toBe('string');
      expect(tpl.subject.length).toBeGreaterThan(0);
      expect(typeof tpl.title).toBe('string');
      expect(Array.isArray(tpl.paragraphs)).toBe(true);
      expect(tpl.paragraphs.length).toBeGreaterThanOrEqual(2);
      expect(typeof tpl.cta).toBe('string');
      expect(tpl.ctaUrl).toMatch(/^https:\/\/www\.hopetsit\.com\//);
      // pas de code ni de lien magique dans le texte
      const all = [tpl.subject, tpl.title, ...tpl.paragraphs].join(' ');
      expect(all).not.toMatch(/verify-link|\{\{code\}\}/);
    }
  });

  test('chaque langue a son propre texte (pas d\'anglais recopié)', () => {
    const dir = path.join(__dirname, '..', 'src', 'locales');
    const read = (l) => JSON.parse(fs.readFileSync(path.join(dir, l, 'lifecycle.json'), 'utf8')).verify_email_d2;
    const en = read('en');
    for (const lang of LOCALES.filter((l) => l !== 'en')) {
      expect(read(lang).subject).not.toBe(en.subject);
      expect(read(lang).paragraphs[0]).not.toBe(en.paragraphs[0]);
    }
  });
});
