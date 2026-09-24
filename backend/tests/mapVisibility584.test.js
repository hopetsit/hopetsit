// v584 (lot C du chantier du 24/09) — règles de visibilité de la carte,
// partagées par la PawMap (/friends/members/*) et les routes publiques
// /sitters/nearby et /walkers/nearby (fuite remontée par le lot B) :
//   1. « visible par mes amis seulement » : un membre masqué n'apparaît que
//      pour ses amis (et lui-même) ;
//   2. position EXACTE pour un ami / soi-même, FLOUTÉE (~1 km) pour tout autre
//      lecteur, connecté ou non ;
//   3. comptes de test (+test), staff et masqués par la modération : jamais
//      dans une réponse publique.
// Plus les drapeaux d'épingle (PawBoost, identité vérifiée, disponible
// aujourd'hui) et la validation des préférences de carte enregistrées sur le
// compte. Aucun réseau, aucune base.

process.env.NODE_ENV = 'test';

const {
  isTestOrStaff, visibleToViewer, publicLocationFor, applyPublicPrivacy,
  isAvailableToday, isBoosted, isKycVerified, pinFlags,
} = require('../src/utils/mapVisibility');
const { normalizeMapPrefs } = require('../src/controllers/mapPrefsController');

// Zone FICTIVE (lat -35 / lng -30) : jamais une vraie ville.
const LAT = -35.1234;
const LNG = -30.5678;
const KM = (aLat, aLng, bLat, bLng) => {
  const R = 6371;
  const r = (x) => (x * Math.PI) / 180;
  const dLat = r(bLat - aLat);
  const dLng = r(bLng - aLng);
  const h = Math.sin(dLat / 2) ** 2
    + Math.cos(r(aLat)) * Math.cos(r(bLat)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
};

const hidden = {
  _id: 'sitterHidden', email: 'hidden@example.test', name: 'Léa',
  preferences: { hideFromMap: true },
  location: { coordinates: [LNG, LAT], city: 'Zone test' },
};
const open = {
  _id: 'sitterOpen', email: 'open@example.test', name: 'Marc',
  preferences: { hideFromMap: false },
  location: { coordinates: [LNG + 0.01, LAT], city: 'Zone test' },
};
const testAccount = {
  _id: 'sitterTest', email: 'dadaciao84+testsitter@gmail.com', name: 'Test Sitter',
  location: { coordinates: [LNG, LAT + 0.01] },
};
const staff = { _id: 'sitterStaff', email: 'staff@example.test', isStaff: true, location: { coordinates: [LNG, LAT] } };
const moderated = { _id: 'sitterMod', email: 'mod@example.test', hiddenFromPublic: true, location: { coordinates: [LNG, LAT] } };

const FRIEND = { friendIds: new Set(['sitterHidden', 'sitterOpen']), viewerIds: new Set(['friend1']) };
const STRANGER = { friendIds: new Set(), viewerIds: new Set(['stranger1']) };
const ANON = {};

describe('1. mode « visible par mes amis seulement »', () => {
  test("l'ami voit le membre masqué", () => {
    expect(visibleToViewer(hidden, FRIEND)).toBe(true);
  });
  test("l'inconnu ne le voit pas, l'anonyme non plus", () => {
    expect(visibleToViewer(hidden, STRANGER)).toBe(false);
    expect(visibleToViewer(hidden, ANON)).toBe(false);
  });
  test('la personne se voit toujours elle-même', () => {
    expect(visibleToViewer(hidden, { viewerIds: new Set(['sitterHidden']) })).toBe(true);
  });
  test('un membre non masqué est visible de tous', () => {
    expect(visibleToViewer(open, STRANGER)).toBe(true);
    expect(visibleToViewer(open, ANON)).toBe(true);
  });
});

describe('2. floutage de la position', () => {
  test("l'ami reçoit la position EXACTE", () => {
    const loc = publicLocationFor(open, FRIEND);
    expect(loc.coordinates).toEqual([LNG + 0.01, LAT]);
    expect(loc.approxKm).toBeUndefined();
  });
  test("l'inconnu reçoit une position floutée, annoncée, à moins de 1 km", () => {
    const loc = publicLocationFor(open, STRANGER);
    expect(loc.coordinates).not.toEqual([LNG + 0.01, LAT]);
    expect(loc.approxKm).toBe(1);
    expect(KM(LAT, LNG + 0.01, loc.coordinates[1], loc.coordinates[0])).toBeLessThan(1);
  });
  test("l'anonyme (sans compte) reçoit la même position floutée", () => {
    expect(publicLocationFor(open, ANON)).toEqual(publicLocationFor(open, STRANGER));
  });
});

describe('3. comptes de test, staff, masqués', () => {
  test('sont reconnus', () => {
    expect(isTestOrStaff(testAccount)).toBe(true);
    expect(isTestOrStaff(staff)).toBe(true);
    expect(isTestOrStaff(moderated)).toBe(true);
    expect(isTestOrStaff(open)).toBe(false);
    expect(isTestOrStaff({ email: 'Probe-565@invalid.example' })).toBe(true);
  });
});

describe('applyPublicPrivacy (les trois règles ensemble, comme /sitters/nearby)', () => {
  const all = [hidden, open, testAccount, staff, moderated];
  test("l'ami voit le masqué ET l'ouvert, en position exacte ; jamais test / staff", () => {
    const out = applyPublicPrivacy(all, FRIEND);
    expect(out.map((d) => d._id)).toEqual(['sitterHidden', 'sitterOpen']);
    expect(out[0].location.coordinates).toEqual([LNG, LAT]);
    expect(out[1].location.coordinates).toEqual([LNG + 0.01, LAT]);
  });
  test("l'inconnu ne voit que l'ouvert, flouté", () => {
    const out = applyPublicPrivacy(all, STRANGER);
    expect(out.map((d) => d._id)).toEqual(['sitterOpen']);
    expect(out[0].location.approxKm).toBe(1);
    expect(out[0].location.coordinates).not.toEqual([LNG + 0.01, LAT]);
  });
  test('le lecteur sans compte = comme un inconnu', () => {
    const out = applyPublicPrivacy(all, ANON);
    expect(out.map((d) => d._id)).toEqual(['sitterOpen']);
    expect(out[0].location.approxKm).toBe(1);
  });
  test('les documents d\'origine ne sont pas modifiés', () => {
    applyPublicPrivacy(all, STRANGER);
    expect(open.location.coordinates).toEqual([LNG + 0.01, LAT]);
  });
});

describe("drapeaux d'épingle", () => {
  const now = new Date('2026-09-24T21:00:00Z'); // jeudi
  test('PawBoost = boostExpiry dans le futur', () => {
    expect(isBoosted({ boostExpiry: '2026-12-01T00:00:00Z' }, now)).toBe(true);
    expect(isBoosted({ boostExpiry: '2026-01-01T00:00:00Z' }, now)).toBe(false);
    expect(isBoosted({}, now)).toBe(false);
  });
  test('identité vérifiée (KYC ou vérification manuelle)', () => {
    expect(isKycVerified({ kycStatus: 'verified' })).toBe(true);
    expect(isKycVerified({ identityVerification: { status: 'verified' } })).toBe(true);
    expect(isKycVerified({ kycStatus: 'pending_verification' })).toBe(false);
  });
  test("disponible aujourd'hui : calendrier, créneau hebdo, jour, indisponibilité", () => {
    expect(isAvailableToday({ availableDates: ['2026-09-24T00:00:00Z'] }, now)).toBe(true);
    expect(isAvailableToday({ availableDates: ['2026-09-25T00:00:00Z'] }, now)).toBe(false);
    expect(isAvailableToday({ availableTimeSlots: [{ day: 'thursday', startHour: 9, endHour: 18 }] }, now)).toBe(true);
    expect(isAvailableToday({ availableDays: ['Thursday'] }, now)).toBe(true);
    expect(isAvailableToday({ availableDays: ['monday'] }, now)).toBe(false);
    expect(isAvailableToday({
      availableDays: ['thursday'], unavailableDates: ['2026-09-24T00:00:00Z'],
    }, now)).toBe(false);
    expect(isAvailableToday({}, now)).toBe(false);
  });
  test('pinFlags regroupe les trois', () => {
    expect(pinFlags({ boostExpiry: '2026-12-01', kycStatus: 'verified', availableDays: ['thursday'] }, now))
      .toEqual({ isBoosted: true, kycVerified: true, availableToday: true });
  });
});

describe('normalizeMapPrefs (préférences de carte sur le compte)', () => {
  test('fusion partielle : les clés absentes du corps sont conservées', () => {
    const base = { camera: { lat: LAT, lng: LNG, zoom: 15 }, nightMode: true, rail: ['around', 'directions'] };
    const out = normalizeMapPrefs(base, { layers: { places: false } });
    expect(out.camera).toEqual({ lat: LAT, lng: LNG, zoom: 15 });
    expect(out.nightMode).toBe(true);
    expect(out.rail).toEqual(['around', 'directions']);
    expect(out.layers).toEqual({ places: false });
    expect(typeof out.updatedAt).toBe('string');
  });
  test('valeurs bornées et nettoyées, rien d\'inconnu ne passe', () => {
    const out = normalizeMapPrefs({}, {
      camera: { lat: 999, lng: LNG, zoom: 50 },
      layers: { places: 'yes', reports: true, hack: true },
      rail: ['around', 'around', 'DROP TABLE', 'sos', 42],
      lookingFor: 'aliens',
      aroundRadiusKm: 500,
      routeMode: 'plane',
      coachShown: 3.7,
      memberRoles: ['owner', 'admin', 'owner'],
    });
    expect(out.camera).toBeUndefined();
    expect(out.layers).toEqual({ reports: true });
    expect(out.rail).toEqual(['around', 'sos']);
    expect(out.lookingFor).toBeUndefined();
    expect(out.aroundRadiusKm).toBe(50);
    expect(out.routeMode).toBeUndefined();
    expect(out.coachShown).toBe(4);
    expect(out.memberRoles).toEqual(['owner']);
  });
  test('une caméra valide est gardée avec un zoom par défaut', () => {
    const out = normalizeMapPrefs(undefined, { camera: { lat: LAT, lng: LNG } });
    expect(out.camera).toEqual({ lat: LAT, lng: LNG, zoom: 14 });
  });
});
