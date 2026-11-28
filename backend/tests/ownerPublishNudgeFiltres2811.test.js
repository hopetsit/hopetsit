// 28/11/2026 (BOB) — filtres d'envoi de « publie ta demande » : pays par pays (envoi en journée chez eux) et build minimum
// (cloche corrigée dans le 648). Un filtre fourni mais vide ou illisible ne laisse passer PERSONNE (null = rien envoyé).
const { narrow } = require('../src/services/ownerPublishNudge2711');

const T = [
  { ownerId: 'a', country: 'FR', appBuild: 648 },
  { ownerId: 'b', country: 'FR', appBuild: 646 },
  { ownerId: 'c', country: 'US', appBuild: 648 },
  { ownerId: 'd', country: '?', appBuild: null },
];
const ids = (l) => l.map((x) => x.ownerId).join('');

describe('ownerPublishNudge2711.narrow', () => {
  test('sans filtre : tout le monde', () => { expect(ids(narrow(T, {}))).toBe('abcd'); });
  test('pays : seulement les pays demandés, casse et espaces tolérés', () => {
    expect(ids(narrow(T, { countries: ['fr'] }))).toBe('ab');
    expect(ids(narrow(T, { countries: [' US ', 'FR'] }))).toBe('abc');
  });
  test('build minimum : appareil inconnu ou plus ancien écarté', () => {
    expect(ids(narrow(T, { minBuild: 648 }))).toBe('ac');
    expect(ids(narrow(T, { countries: ['FR'], minBuild: 648 }))).toBe('a');
  });
  test('filtre fourni mais vide ou illisible : null, rien ne part', () => {
    expect(narrow(T, { countries: [] })).toBeNull();
    expect(narrow(T, { countries: 'FR' })).toBeNull();
    expect(narrow(T, { countries: ['France'] })).toBeNull();
    expect(narrow(T, { minBuild: 0 })).toBeNull();
    expect(narrow(T, { minBuild: 'abc' })).toBeNull();
  });
});
