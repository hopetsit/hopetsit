// 22/09/2026 — « la fiche publique d'un prestataire ne doit pas donner son
// domicile ni sa date de naissance ».
//
// Découvert en préparant le lien de profil partageable : GET /sitters/:id
// (route publique, sans compte) renvoyait `dateOfBirth: "26/07/1966"` et les
// coordonnées EXACTES du prestataire, alors que la couche monde de la PawMap
// arrondit volontairement à ~1 km. Ce test verrouille la règle de floutage,
// qui est désormais partagée par la PawMap et les deux fiches publiques.
// Aucun réseau, aucune base.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const {
  blurLngLat, coarsenLocation, WORLD_APPROX_KM,
} = require('../src/utils/coarseLocation');
const { SITTER_PRIVATE_FIELDS, sitterSelfPrivateFields } = require('../src/utils/sitterSelfView');

const KM = (aLat, aLng, bLat, bLng) => {
  const R = 6371;
  const r = (x) => (x * Math.PI) / 180;
  const dLat = r(bLat - aLat);
  const dLng = r(bLng - aLng);
  const h = Math.sin(dLat / 2) ** 2
    + Math.cos(r(aLat)) * Math.cos(r(bLat)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
};

describe('floutage des positions des fiches publiques', () => {
  const LAT = 48.8594006;   // le gardien parisien réel qui a servi au constat
  const LNG = 2.2817453;

  test('la position publique bouge, mais reste dans le quartier (< 1 km)', () => {
    const [lng, lat] = blurLngLat(LAT, LNG, '6aad478e084af5de268cb3c9');
    expect(lat).not.toBeCloseTo(LAT, 4);
    expect(lng).not.toBeCloseTo(LNG, 4);
    expect(KM(LAT, LNG, lat, lng)).toBeLessThan(1);
  });

  test('deux lectures donnent le même résultat (pas de sautillement)', () => {
    const a = blurLngLat(LAT, LNG, 'abc');
    const b = blurLngLat(LAT, LNG, 'abc');
    expect(a).toEqual(b);
  });

  test('deux prestataires au même endroit ne se superposent pas', () => {
    expect(blurLngLat(LAT, LNG, 'aaa')).not.toEqual(blurLngLat(LAT, LNG, 'bbb'));
  });

  test('la personne elle-même garde sa position exacte', () => {
    const loc = { coordinates: [LNG, LAT], city: 'Paris' };
    expect(coarsenLocation(loc, 'x', true)).toBe(loc);
  });

  test('un lecteur tiers reçoit une position arrondie et annoncée comme telle', () => {
    const out = coarsenLocation({ coordinates: [LNG, LAT], city: 'Paris' }, 'x', false);
    expect(out.coordinates).not.toEqual([LNG, LAT]);
    expect(out.approxKm).toBe(WORLD_APPROX_KM);
    expect(out.city).toBe('Paris');
  });

  test('une fiche sans coordonnées passe sans casser', () => {
    expect(coarsenLocation(null, 'x', false)).toBeNull();
    expect(coarsenLocation({ city: 'Paris' }, 'x', false)).toEqual({ city: 'Paris' });
    expect(coarsenLocation({ coordinates: [0, 0] }, 'x', false).coordinates).toEqual([0, 0]);
  });
});

describe('champs privés du gardien', () => {
  const doc = {
    email: 'x@y.z', mobile: '0600000000', address: '1 rue X',
    postalCode: '75011', countryCode: '+33', country: 'FR',
  };

  test('un tiers ne reçoit aucun contact', () => {
    const out = sitterSelfPrivateFields(doc, false);
    for (const f of SITTER_PRIVATE_FIELDS) expect(out[f]).toBe('');
  });

  test('la personne elle-même les retrouve (écran « Modifier le profil »)', () => {
    expect(sitterSelfPrivateFields(doc, true).email).toBe('x@y.z');
  });
});
