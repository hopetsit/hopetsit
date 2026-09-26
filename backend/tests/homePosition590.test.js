// v590 — déménagement : position de profil qui suit la ville de vie.
const { shouldMoveHome } = require('../src/utils/homePosition590');
const { pickPersonPosition } = require('../src/utils/personMapPosition');

const DENIA = [-0.0294, 38.8810];
const MURCIA = [-1.3472, 37.7321];
const MURCIA_2 = [-1.30, 37.75];

test('déplacer la position de profil seulement au-delà de 50 km', () => {
  expect(shouldMoveHome(DENIA, MURCIA)).toBe(true);
  expect(shouldMoveHome(MURCIA, MURCIA_2)).toBe(false);
  expect(shouldMoveHome(null, MURCIA)).toBe(true);
  expect(shouldMoveHome(DENIA, [0, 0])).toBe(false);
});

test('frère : direct de ce matin à Murcia, inscrit à Dénia → Murcia (déménagement)', () => {
  const now = new Date('2026-09-26T12:00:00Z');
  const p = pickPersonPosition([
    { role: 'owner', d: { _id: 'o', updatedAt: now, location: { coordinates: MURCIA, updatedAt: new Date('2026-09-26T09:50:00Z') } } },
    { role: 'sitter', d: { _id: 's', updatedAt: now, location: { coordinates: DENIA } } },
  ], { now });
  expect(p.source).toBe('moved');
  expect(p.coordinates).toEqual(MURCIA);
});

test('vieux direct (2 jours) loin de l\'inscription → l\'inscription gagne', () => {
  const now = new Date('2026-09-26T12:00:00Z');
  const p = pickPersonPosition([
    { role: 'owner', d: { _id: 'o', location: { coordinates: DENIA, updatedAt: new Date('2026-09-24T09:00:00Z') } } },
    { role: 'sitter', d: { _id: 's', updatedAt: now, location: { coordinates: MURCIA } } },
  ], { now });
  expect(p.source).toBe('home');
  expect(p.coordinates).toEqual(MURCIA);
});
