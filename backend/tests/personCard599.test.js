// v599 (29/09/2026) — nom + photo dans les positions en direct (rond vide
// « Po de la Isla » chez Daniel). Modèles simulés, aucun réseau.
process.env.NODE_ENV = 'test';
const mockChain = (result) => {
  const c = { select: () => c, lean: () => Promise.resolve(result) };
  return c;
};
const mockDocs = {
  Owner: { po: { _id: 'po', name: 'Po de la Isla', avatar: { url: 'https://cdn.test/po.jpg' } } },
  Sitter: { ka: { _id: 'ka', firstName: 'Kathy', lastName: 'Lemoine', profilePicture: 'https://cdn.test/ka.jpg' } },
  Walker: {},
};
const mockModel = (name) => ({ findById: jest.fn((id) => mockChain(mockDocs[name][String(id)] || null)) });
jest.mock('../src/models/Owner', () => mockModel('Owner'));
jest.mock('../src/models/Sitter', () => mockModel('Sitter'));
jest.mock('../src/models/Walker', () => mockModel('Walker'));

const card = require('../src/utils/personCard599');

describe('personCard599', () => {
  beforeEach(() => card._resetForTests());

  test('pickCard : nom direct + photo objet { url }', () => {
    expect(card.pickCard(mockDocs.Owner.po)).toEqual({ name: 'Po de la Isla', avatar: 'https://cdn.test/po.jpg' });
  });
  test('pickCard : prénom + nom, photo chaîne (profilePicture prioritaire)', () => {
    expect(card.pickCard(mockDocs.Sitter.ka)).toEqual({ name: 'Kathy Lemoine', avatar: 'https://cdn.test/ka.jpg' });
  });
  test('pickCard : document absent → carte vide, jamais d’erreur', () => {
    expect(card.pickCard(null)).toEqual({ name: '', avatar: '' });
  });
  test('cardFor : trouve la personne quel que soit son profil, puis répond du cache', async () => {
    const Sitter = require('../src/models/Sitter');
    expect(await card.cardFor('ka', 'owner')).toEqual({ name: 'Kathy Lemoine', avatar: 'https://cdn.test/ka.jpg' });
    const calls = Sitter.findById.mock.calls.length;
    expect(await card.cardFor('ka', 'owner')).toEqual({ name: 'Kathy Lemoine', avatar: 'https://cdn.test/ka.jpg' });
    expect(Sitter.findById.mock.calls.length).toBe(calls); // cache
  });
  test('cardFor : inconnu → carte vide', async () => {
    expect(await card.cardFor('zzz')).toEqual({ name: '', avatar: '' });
  });
});
