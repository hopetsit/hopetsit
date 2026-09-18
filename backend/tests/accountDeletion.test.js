// v567 — motifs de désinscription (« Avant de partir… »). Vérifie la
// normalisation des raisons (liste blanche, max 3), la troncature du
// commentaire et surtout qu'AUCUN e-mail en clair n'est écrit : seul un
// sha256 de l'e-mail minuscule est stocké (RGPD).
//
// Le modèle Mongoose est remplacé par un faux `create` en mémoire, comme dans
// les autres tests du dossier — aucune base n'est requise.

const crypto = require('crypto');

const mockCreated = [];

jest.mock('mongoose', () => {
  const schema = function Schema() {
    return { index: jest.fn(), pre: jest.fn(), set: jest.fn() };
  };
  schema.Types = { ObjectId: String, Mixed: Object };
  return {
    Schema: schema,
    model: jest.fn(() => ({
      create: jest.fn(async (doc) => {
        mockCreated.push(doc);
        return doc;
      }),
    })),
  };
});

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const {
  ACCOUNT_DELETION_REASONS,
  MAX_REASONS,
  MAX_COMMENT,
  hashEmail,
  normalizeReasons,
  normalizeComment,
  buildAccountDeletionRecord,
  recordAccountDeletion,
} = require('../src/models/AccountDeletion');

const mockReq = (overrides = {}) => ({
  body: {},
  query: {},
  headers: {},
  ...overrides,
});

const mockDoc = {
  _id: 'owner_1',
  name: 'Daniel',
  email: 'chiffre_illisible',
  country: 'FR',
  city: 'Nice',
  appLocale: 'fr',
  createdAt: new Date('2026-01-05T10:00:00Z'),
};

beforeEach(() => {
  mockCreated.length = 0;
});

describe('normalizeReasons — liste blanche et plafond', () => {
  test('les identifiants inconnus sont filtrés', () => {
    expect(normalizeReasons(['bugs', 'pas_une_raison', 'privacy'])).toEqual(['bugs', 'privacy']);
    expect(normalizeReasons(['<script>alert(1)</script>'])).toEqual([]);
    expect(normalizeReasons(['BUGS'])).toEqual([]); // sensible à la casse : identifiants stables
  });

  test('maximum 3 raisons, même si le client en envoie plus', () => {
    const tooMany = ['bugs', 'privacy', 'too_expensive', 'no_clients', 'other'];
    const out = normalizeReasons(tooMany);
    expect(out).toHaveLength(MAX_REASONS);
    expect(out).toEqual(['bugs', 'privacy', 'too_expensive']);
  });

  test('les doublons ne consomment pas deux places', () => {
    expect(normalizeReasons(['bugs', 'bugs', 'privacy'])).toEqual(['bugs', 'privacy']);
  });

  test('chaîne « a,b,c » (query string) acceptée', () => {
    expect(normalizeReasons('bugs,privacy,nawak,other')).toEqual(['bugs', 'privacy', 'other']);
  });

  test('rien envoyé (anciennes apps) → tableau vide, jamais une erreur', () => {
    expect(normalizeReasons(undefined)).toEqual([]);
    expect(normalizeReasons(null)).toEqual([]);
    expect(normalizeReasons({})).toEqual([]);
    expect(normalizeReasons(42)).toEqual([]);
  });

  test('les 11 identifiants de la consigne sont tous acceptés', () => {
    expect(ACCOUNT_DELETION_REASONS).toHaveLength(11);
    for (const id of ACCOUNT_DELETION_REASONS) {
      expect(normalizeReasons([id])).toEqual([id]);
    }
  });
});

describe('normalizeComment — trim et troncature', () => {
  test('commentaire tronqué à 300 caractères', () => {
    const long = 'a'.repeat(500);
    expect(normalizeComment(long)).toHaveLength(MAX_COMMENT);
  });

  test('espaces retirés, valeurs absentes → chaîne vide', () => {
    expect(normalizeComment('  trop cher  ')).toBe('trop cher');
    expect(normalizeComment(undefined)).toBe('');
    expect(normalizeComment(null)).toBe('');
  });
});

describe('hashEmail — RGPD', () => {
  test('sha256 de l’e-mail en minuscules', () => {
    const expected = crypto.createHash('sha256').update('dan@example.com').digest('hex');
    expect(hashEmail('Dan@Example.com')).toBe(expected);
    expect(hashEmail('  dan@example.com ')).toBe(expected);
  });

  test('e-mail absent → chaîne vide (pas un hash de vide)', () => {
    expect(hashEmail('')).toBe('');
    expect(hashEmail(null)).toBe('');
  });
});

describe('buildAccountDeletionRecord — ligne écrite en base', () => {
  test('aucun e-mail en clair, seulement le hash', () => {
    const rec = buildAccountDeletionRecord({
      req: mockReq({ body: { reasons: ['bugs'], comment: 'ça plante' } }),
      role: 'owner',
      doc: mockDoc,
      email: 'Dan@Example.com',
    });
    const dump = JSON.stringify(rec);
    expect(dump).not.toContain('Dan@Example.com');
    expect(dump).not.toContain('dan@example.com');
    expect(dump).not.toContain('@');
    expect(rec.emailHash).toBe(hashEmail('dan@example.com'));
    expect(rec.email).toBeUndefined();
    expect(rec.name).toBeUndefined();
  });

  test('contexte repris du compte et des en-têtes', () => {
    const rec = buildAccountDeletionRecord({
      req: mockReq({
        body: { reasons: ['too_expensive', 'privacy'] },
        headers: { 'x-app-platform': 'ios', 'x-app-version': '567' },
      }),
      role: 'owner',
      doc: mockDoc,
      email: 'dan@example.com',
      stats: { hadPaidBooking: true, bookingsCount: 4 },
    });
    expect(rec.role).toBe('owner');
    expect(rec.userId).toBe('owner_1');
    expect(rec.country).toBe('FR');
    expect(rec.city).toBe('Nice');
    expect(rec.appLocale).toBe('fr');
    expect(rec.platform).toBe('ios');
    expect(rec.appVersion).toBe('567');
    expect(rec.hadPaidBooking).toBe(true);
    expect(rec.bookingsCount).toBe(4);
    expect(rec.accountCreatedAt).toEqual(mockDoc.createdAt);
    expect(rec.deletedAt).toBeInstanceOf(Date);
    expect(rec.reasons).toEqual(['too_expensive', 'privacy']);
  });

  test('repli sur la query quand le client n’envoie pas de corps sur DELETE', () => {
    const rec = buildAccountDeletionRecord({
      req: mockReq({ query: { reasons: 'bugs,other', comment: 'bof' } }),
      role: 'walker',
      doc: mockDoc,
      email: 'dan@example.com',
    });
    expect(rec.reasons).toEqual(['bugs', 'other']);
    expect(rec.comment).toBe('bof');
  });

  test('ancienne app : ni corps ni query → ligne quand même, reasons vides', () => {
    const rec = buildAccountDeletionRecord({ req: mockReq(), role: 'sitter', doc: mockDoc, email: '' });
    expect(rec.reasons).toEqual([]);
    expect(rec.comment).toBe('');
    expect(rec.platform).toBe('');
    expect(rec.emailHash).toBe('');
  });

  test('requête vide / paramètres absents → aucune exception', () => {
    expect(() => buildAccountDeletionRecord()).not.toThrow();
    expect(buildAccountDeletionRecord().reasons).toEqual([]);
  });
});

describe('recordAccountDeletion — best-effort', () => {
  test('écrit une ligne normalisée', async () => {
    await recordAccountDeletion({
      req: mockReq({
        body: { reasons: ['bugs', 'inconnu', 'privacy', 'other', 'no_clients'], comment: 'x'.repeat(400) },
      }),
      role: 'owner',
      doc: mockDoc,
      email: 'dan@example.com',
    });
    expect(mockCreated).toHaveLength(1);
    expect(mockCreated[0].reasons).toEqual(['bugs', 'privacy', 'other']);
    expect(mockCreated[0].comment).toHaveLength(MAX_COMMENT);
    expect(mockCreated[0].emailHash).toBe(hashEmail('dan@example.com'));
  });

  test('une erreur d’écriture n’est jamais propagée (la suppression continue)', async () => {
    const { AccountDeletion } = require('../src/models/AccountDeletion');
    AccountDeletion.create.mockRejectedValueOnce(new Error('mongo down'));
    await expect(
      recordAccountDeletion({ req: mockReq(), role: 'owner', doc: mockDoc, email: 'dan@example.com' }),
    ).resolves.toBeUndefined();
  });
});
