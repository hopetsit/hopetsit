// v573 — « quand j'utilise les 3 rôles et que je publie une annonce, mon profil
// gardien et promeneur apparaissent comme proposition » (Daniel, 20/09/2026).
//
// 1 personne = jusqu'à 3 documents (Owner / Sitter / Walker) reliés par
// l'e-mail. `selfIdSet(req)` renvoie les 3 ids du spectateur ; `optionalAuth`
// renseigne `req.user` sur une route publique sans jamais bloquer.
// Aucun accès réseau, aucune base.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const jwt = require('jsonwebtoken');

const PEOPLE = {
  owner1: { _id: 'owner1', email: 'daniel@example.test' },
  sitter1: { _id: 'sitter1', email: 'daniel@example.test' },
  walker1: { _id: 'walker1', email: 'daniel@example.test' },
  sitter2: { _id: 'sitter2', email: 'autre@example.test' },
};

const mockChain = (result) => {
  const c = {
    select: () => c,
    lean: () => Promise.resolve(result),
    catch: () => c,
  };
  return c;
};

const mockModel = (prefix) => ({
  findById: jest.fn((id) => {
    const d = PEOPLE[id];
    return mockChain(d && id.startsWith(prefix) ? d : null);
  }),
  find: jest.fn((q) => {
    const emails = (q.$or || []).map((c) => c.email).filter(Boolean);
    return mockChain(
      Object.values(PEOPLE).filter(
        (d) => d._id.startsWith(prefix) && emails.includes(d.email),
      ),
    );
  }),
});

jest.mock('../src/models/Owner', () => mockModel('owner'));
jest.mock('../src/models/Sitter', () => mockModel('sitter'));
jest.mock('../src/models/Walker', () => mockModel('walker'));

const { selfIdSet } = require('../src/utils/identityGroup');
const { optionalAuth } = require('../src/middleware/auth');

describe('selfIdSet', () => {
  test('anonyme → Set vide', async () => {
    expect((await selfIdSet({})).size).toBe(0);
  });

  test('propriétaire connecté → ses 3 documents de rôle, pas ceux des autres', async () => {
    const set = await selfIdSet({ user: { id: 'owner1', role: 'owner' } });
    expect([...set].sort()).toEqual(['owner1', 'sitter1', 'walker1']);
    expect(set.has('sitter2')).toBe(false);
  });

  test('connecté en promeneur → retrouve son document propriétaire', async () => {
    const set = await selfIdSet({ user: { id: 'walker1', role: 'walker' } });
    expect(set.has('owner1')).toBe(true);
  });
});

describe('optionalAuth', () => {
  const run = (headers) =>
    new Promise((resolve) => {
      const req = { headers };
      optionalAuth(req, {}, () => resolve(req));
    });

  test('sans jeton → continue en anonyme', async () => {
    const req = await run({});
    expect(req.user).toBeUndefined();
  });

  test('jeton invalide → continue en anonyme, ne bloque pas', async () => {
    const req = await run({ authorization: 'Bearer nimportequoi' });
    expect(req.user).toBeUndefined();
  });

  test('jeton valide → req.user renseigné', async () => {
    const token = jwt.sign({ id: 'owner1', role: 'owner' }, process.env.JWT_SECRET);
    const req = await run({ authorization: `Bearer ${token}` });
    expect(req.user).toEqual({ id: 'owner1', role: 'owner' });
  });
});
