// v576 — « Aucun e-mail ajouté » alors que le compte A un e-mail (Daniel,
// 21/09/2026).
//
// L'écran « Modifier le profil » du GARDIEN se charge par `GET /sitters/:id`,
// qui est la fiche publique : depuis la v535 elle renvoie `email: ''`,
// `mobile: ''`, `address: ''` à TOUT LE MONDE, y compris au gardien lui-même.
// Ces tests vérifient que la personne se voit elle-même en entier, et que
// n'importe qui d'autre ne voit toujours rien de privé.
//
// Aucun accès réseau, aucune base : modèles mockés.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const {
  sitterSelfPrivateFields,
  isSelfProfile,
  SITTER_PRIVATE_FIELDS,
} = require('../src/utils/sitterSelfView');

describe('sitterSelfView — fonction pure', () => {
  const sitter = {
    email: 'daniel@example.test',
    mobile: '612345678',
    countryCode: '+33',
    address: '12 rue des Lilas',
    country: 'FR',
    postalCode: '75011',
  };

  test('la personne elle-même reçoit ses champs privés', () => {
    const out = sitterSelfPrivateFields(sitter, true);
    expect(out.email).toBe('daniel@example.test');
    expect(out.mobile).toBe('612345678');
    expect(out.countryCode).toBe('+33');
    expect(out.address).toBe('12 rue des Lilas');
  });

  test('un visiteur ne reçoit que des chaînes vides (forme identique)', () => {
    const out = sitterSelfPrivateFields(sitter, false);
    for (const f of SITTER_PRIVATE_FIELDS) {
      expect(out[f]).toBe('');
    }
    // La forme ne change pas : mêmes clés dans les deux cas.
    expect(Object.keys(out).sort()).toEqual(
      Object.keys(sitterSelfPrivateFields(sitter, true)).sort(),
    );
  });

  test('un document sans ces champs ne renvoie jamais null/undefined', () => {
    const out = sitterSelfPrivateFields({}, true);
    for (const f of SITTER_PRIVATE_FIELDS) {
      expect(out[f]).toBe('');
    }
  });

  test('isSelfProfile compare bien sur le GROUPE d’identité', () => {
    const group = new Set(['owner1', 'sitter1', 'walker1']);
    expect(isSelfProfile(group, 'sitter1')).toBe(true);
    expect(isSelfProfile(group, 'sitter2')).toBe(false);
    expect(isSelfProfile(null, 'sitter1')).toBe(false);
    expect(isSelfProfile(group, '')).toBe(false);
  });
});

// ─────────────────────────────────────────────────────────────────────────
// getSitterProfile de bout en bout (modèles mockés).
// ─────────────────────────────────────────────────────────────────────────

const SITTER_DOC = {
  _id: { toString: () => 'sitter1' },
  name: 'Daniel Cardelli',
  firstName: 'Daniel',
  lastName: 'Cardelli',
  email: 'daniel@example.test',
  mobile: '612345678',
  countryCode: '+33',
  address: '12 rue des Lilas',
  country: 'FR',
  postalCode: '75011',
  // Pas de GPS : la ville vit dans le champ PLAT `city` (modèle v565).
  city: 'Paris',
  location: null,
  bio: 'Je garde des chiens depuis dix ans.',
  service: ['sit_home'],
  acceptedPetTypes: ['dog'],
  avatar: { url: 'https://cdn/x.jpg', publicId: 'x' },
};

jest.mock('../src/models/Sitter', () => ({
  findById: jest.fn(() => Promise.resolve(global.__SITTER_DOC__)),
}));

jest.mock('../src/models/Review', () => ({
  find: jest.fn(() => ({
    sort: () => ({ populate: () => Promise.resolve([]) }),
  })),
}));

jest.mock('../src/models/Owner', () => ({ findOne: jest.fn() }));

jest.mock('../src/services/loyaltyService', () => ({
  recomputeSitterStatus: jest.fn(() => Promise.resolve(null)),
}));

jest.mock('../src/utils/avatarFallback', () => ({
  ensureAvatarFromSiblingRoles: jest.fn(() => Promise.resolve()),
}));

const mockFillSpy = jest.fn((account) => Promise.resolve(account));
jest.mock('../src/utils/sharedIdentity', () => ({
  propagateSharedIdentity: jest.fn(),
  fillMissingIdentityFromSiblings: (...args) => mockFillSpy(...args),
}));

// Un compte = jusqu'à 3 documents reliés par l'e-mail : `selfIdSet` renvoie
// les ids de la personne QUI LIT, pas de la fiche lue.
const mockGroups = {
  owner1: ['owner1', 'sitter1', 'walker1'],
  sitter1: ['owner1', 'sitter1', 'walker1'],
  walker1: ['owner1', 'sitter1', 'walker1'],
  sitter2: ['sitter2'],
};
jest.mock('../src/utils/identityGroup', () => ({
  identityGroup: jest.fn(),
  selfIdSet: jest.fn((req) =>
    Promise.resolve(new Set(mockGroups[req && req.user && req.user.id] || [])),
  ),
}));

const { getSitterProfile } = require('../src/controllers/sitterController');

const runRoute = async (req) => {
  let payload = null;
  let status = 200;
  const res = {
    json: (b) => {
      payload = b;
      return res;
    },
    status: (s) => {
      status = s;
      return res;
    },
  };
  await getSitterProfile(req, res);
  return { payload, status };
};

describe('GET /sitters/:id — la personne elle-même', () => {
  beforeEach(() => {
    global.__SITTER_DOC__ = { ...SITTER_DOC };
    mockFillSpy.mockClear();
  });

  test('le gardien voit son e-mail, son téléphone et son adresse', async () => {
    const { payload, status } = await runRoute({
      params: { id: 'sitter1' },
      user: { id: 'sitter1', role: 'sitter' },
    });
    expect(status).toBe(200);
    expect(payload.sitter.email).toBe('daniel@example.test');
    expect(payload.sitter.mobile).toBe('612345678');
    expect(payload.sitter.countryCode).toBe('+33');
    expect(payload.sitter.address).toBe('12 rue des Lilas');
  });

  test('depuis son profil PROPRIÉTAIRE (même personne, autre id) aussi', async () => {
    const { payload } = await runRoute({
      params: { id: 'sitter1' },
      user: { id: 'owner1', role: 'owner' },
    });
    expect(payload.sitter.email).toBe('daniel@example.test');
  });

  test('le rattrapage d’identité à la lecture est bien branché (comptes anciens)', async () => {
    await runRoute({
      params: { id: 'sitter1' },
      user: { id: 'sitter1', role: 'sitter' },
    });
    expect(mockFillSpy).toHaveBeenCalledTimes(1);
    expect(mockFillSpy.mock.calls[0][1]).toBe('sitter');
  });

  test('la ville PLATE est renvoyée même sans GPS', async () => {
    const { payload } = await runRoute({
      params: { id: 'sitter1' },
      user: { id: 'sitter1', role: 'sitter' },
    });
    expect(payload.sitter.city).toBe('Paris');
  });

  test('prénom et nom sont renvoyés (élément « Nom » de la complétion)', async () => {
    const { payload } = await runRoute({
      params: { id: 'sitter1' },
      user: { id: 'sitter1', role: 'sitter' },
    });
    expect(payload.sitter.firstName).toBe('Daniel');
    expect(payload.sitter.lastName).toBe('Cardelli');
  });
});

describe('GET /sitters/:id — un visiteur (fuite v535 toujours colmatée)', () => {
  beforeEach(() => {
    global.__SITTER_DOC__ = { ...SITTER_DOC };
    mockFillSpy.mockClear();
  });

  test('anonyme : aucun champ privé', async () => {
    const { payload } = await runRoute({ params: { id: 'sitter1' } });
    expect(payload.sitter.email).toBe('');
    expect(payload.sitter.mobile).toBe('');
    expect(payload.sitter.address).toBe('');
    expect(payload.sitter.countryCode).toBe('');
    // …mais la fiche publique reste complète.
    expect(payload.sitter.name).toBe('Daniel Cardelli');
    expect(payload.sitter.bio).toBe('Je garde des chiens depuis dix ans.');
    expect(mockFillSpy).not.toHaveBeenCalled();
  });

  test('connecté mais quelqu’un d’autre : aucun champ privé', async () => {
    const { payload } = await runRoute({
      params: { id: 'sitter1' },
      user: { id: 'sitter2', role: 'sitter' },
    });
    // selfIdSet est mocké sur le groupe de Daniel ; sitter2 n'en fait pas
    // partie du point de vue de la fiche lue (`isSelfProfile`).
    expect(payload.sitter.email).toBe('');
    expect(payload.sitter.mobile).toBe('');
  });
});
