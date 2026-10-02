// 607 (FLO, 02/10) — GET /sitters/:id doit porter identityVerified (badge app + site).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
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

describe('GET /sitters/:id — badge « Identité vérifiée »', () => {
  test.each([
    [{ kycStatus: 'verified' }, true],
    [{ kycStatus: 'verified', identityVerification: { status: 'verified', reviewedAt: new Date() } }, true],
    [{ identityVerification: { status: 'verified' } }, true],
    [{ kycStatus: 'pending_verification', verified: true }, false],
    [{ verified: true }, false],
  ])('%o → %s (lecteur anonyme)', async (extra, expected) => {
    global.__SITTER_DOC__ = { ...SITTER_DOC, ...extra };
    const { payload, status } = await runRoute({ params: { id: 'sitter1' } });
    expect(status).toBe(200);
    expect(payload.sitter.identityVerified).toBe(expected);
    expect(payload.sitter).not.toHaveProperty('kycStatus');
  });
});
