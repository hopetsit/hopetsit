// v583 (lot A du chantier du 24/09) — « Daniel C » en conversation avec
// lui-même (deux profils du MÊME compte) sur la capture du 23/09 : validé par
// Daniel, cette conversation est MASQUÉE de la liste, côté serveur. Rien n'est
// supprimé en base : le filtre agit sur la réponse seulement.
//
// 1 personne = jusqu'à 3 documents (Owner / Sitter / Walker) reliés par
// l'e-mail. `selfIdSet(req)` renvoie les 3 ids du spectateur ;
// `excludeSelfConversations` retire les conversations dont l'autre participant
// est l'un de ces ids, et garde toutes les autres. Aucun accès réseau, aucune
// base.

process.env.NODE_ENV = 'test';

const PEOPLE = {
  owner1: { _id: 'owner1', email: 'daniel@example.test' },
  sitter1: { _id: 'sitter1', email: 'daniel@example.test' },
  walker1: { _id: 'walker1', email: 'daniel@example.test' },
  sitter2: { _id: 'sitter2', email: 'lea@example.test' },
  owner2: { _id: 'owner2', email: 'marc@example.test' },
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

const {
  selfIdSet,
  isSelfConversation,
  excludeSelfConversations,
} = require('../src/utils/identityGroup');

const conv = (id, otherId) => ({ _id: id, otherParty: { id: otherId, name: otherId } });

describe('isSelfConversation', () => {
  const self = new Set(['owner1', 'sitter1', 'walker1']);

  test('mon profil gardien = moi-même', () => {
    expect(isSelfConversation('sitter1', self)).toBe(true);
    expect(isSelfConversation('walker1', self)).toBe(true);
  });

  test('une autre personne = pas moi', () => {
    expect(isSelfConversation('sitter2', self)).toBe(false);
  });

  test('id manquant ou Set absent → jamais masqué (sûreté)', () => {
    expect(isSelfConversation('', self)).toBe(false);
    expect(isSelfConversation(null, self)).toBe(false);
    expect(isSelfConversation('sitter1', null)).toBe(false);
    expect(isSelfConversation('sitter1', new Set())).toBe(false);
  });
});

describe('excludeSelfConversations', () => {
  const self = new Set(['owner1', 'sitter1', 'walker1']);

  test('retire la conversation avec moi-même, garde les vraies, ordre conservé', () => {
    const list = [
      conv('c_self_sitter', 'sitter1'),
      conv('c_lea', 'sitter2'),
      conv('c_self_walker', 'walker1'),
      conv('c_marc', 'owner2'),
    ];
    const out = excludeSelfConversations(list, self);
    expect(out.map((c) => c._id)).toEqual(['c_lea', 'c_marc']);
    // Rien n'est supprimé : la liste d'entrée est intacte.
    expect(list).toHaveLength(4);
  });

  test('compte anonyme (Set vide) → toutes les conversations restent', () => {
    const list = [conv('a', 'sitter1'), conv('b', 'sitter2')];
    expect(excludeSelfConversations(list, new Set())).toHaveLength(2);
  });

  test('entrée sans otherParty → laissée au filtre « compte supprimé »', () => {
    const list = [{ _id: 'x' }, conv('b', 'sitter2')];
    expect(excludeSelfConversations(list, self)).toHaveLength(2);
    expect(excludeSelfConversations(null, self)).toEqual([]);
  });
});

describe('avec selfIdSet (3 documents reliés par l\'e-mail)', () => {
  test('propriétaire connecté : sa conversation avec son profil gardien disparaît, celle avec Léa reste', async () => {
    const self = await selfIdSet({ user: { id: 'owner1', role: 'owner' } });
    expect([...self].sort()).toEqual(['owner1', 'sitter1', 'walker1']);
    const out = excludeSelfConversations(
      [conv('daniel_avec_daniel', 'sitter1'), conv('daniel_avec_lea', 'sitter2')],
      self,
    );
    expect(out.map((c) => c._id)).toEqual(['daniel_avec_lea']);
  });

  test('promeneur connecté : même règle depuis n\'importe lequel de ses profils', async () => {
    const self = await selfIdSet({ user: { id: 'walker1', role: 'walker' } });
    const out = excludeSelfConversations(
      [conv('moi_owner', 'owner1'), conv('marc', 'owner2')],
      self,
    );
    expect(out.map((c) => c._id)).toEqual(['marc']);
  });
});
