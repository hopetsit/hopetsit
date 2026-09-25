// v585 (lot D, 25/09/2026) — CURSEUR DE DISTANCE (demande de Daniel) : la
// règle unique du rayon (`utils/searchRadius`) et la VRAIE route
// `/walkers/nearby` (gestionnaire réel, modèle simulé qui applique
// `maxDistance` avec le même haversine que Mongo $geoNear) :
//   · un promeneur à 4 km apparaît à 5 km et disparaît à 3 km (borne inclusive) ;
//   · la valeur envoyée par l'app (`radiusInMeters`) est celle appliquée, sans
//     plafond à 200 km : 500 km reste 500 km (c'était le décalage affiché /
//     appliqué sur les grands rayons) ;
//   · `radius` (km), `maxDistance` (km) et `radiusInMeters` (m) donnent le même
//     résultat ; garbage → défaut.
// Aucun réseau, aucune base.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mockSearchRadius = require('../src/utils/searchRadius');
const {
  haversineKm, parseRadiusKm, withinRadiusKm, filterByRadius, MAX_RADIUS_KM,
} = mockSearchRadius;

// Centre fictif hors de toute vraie ville (zone -35 / -30, règle du dépôt).
const LAT = -35.2;
const LNG = -30.4;
/** Un point à `km` km à l'est du centre (1° de longitude ≈ 111,32·cos(lat) km). */
const eastKm = (km) => ({ lat: LAT, lng: LNG + km / (111.32 * Math.cos((LAT * Math.PI) / 180)) });

describe('règles pures — utils/searchRadius', () => {
  test('haversine : Notre-Dame → Tour Eiffel ≈ 4,1 km ; même point = 0', () => {
    const d = haversineKm(48.8530, 2.3499, 48.8584, 2.2945);
    expect(d).toBeGreaterThan(4.0);
    expect(d).toBeLessThan(4.2);
    expect(haversineKm(LAT, LNG, LAT, LNG)).toBe(0);
    // Le point construit « à 4 km » est bien à 4 km.
    const p = eastKm(4);
    expect(Math.abs(haversineKm(LAT, LNG, p.lat, p.lng) - 4)).toBeLessThan(0.01);
  });

  test('lecture du rayon : mètres, km, maxDistance ; défaut ; plafond 500 km ; plancher', () => {
    expect(parseRadiusKm({ radiusInMeters: '50000' })).toBe(50);
    expect(parseRadiusKm({ radius: '50' })).toBe(50);
    expect(parseRadiusKm({ maxDistance: '50' })).toBe(50);
    expect(parseRadiusKm({}, { defaultKm: 25 })).toBe(25);
    expect(parseRadiusKm({ radiusInMeters: 'abc' }, { defaultKm: 10 })).toBe(10);
    expect(parseRadiusKm({ radiusInMeters: '-5' }, { defaultKm: 10 })).toBe(10);
    expect(parseRadiusKm({ radiusInMeters: '500000' })).toBe(500);
    expect(parseRadiusKm({ radiusInMeters: '900000' })).toBe(MAX_RADIUS_KM);
    expect(parseRadiusKm({ radius: '0.01' })).toBe(0.1);
  });

  test('borne inclusive : 4 km reste dans 4 km ; 4,002 km non', () => {
    expect(withinRadiusKm(4, 4)).toBe(true);
    expect(withinRadiusKm(4.0005, 4)).toBe(true); // tolérance 1 m (arrondis)
    expect(withinRadiusKm(4.002, 4)).toBe(false);
    expect(withinRadiusKm(NaN, 4)).toBe(false);
  });

  test('filtre pur : à 5 km je vois le prestataire à 4 km, à 3 km non ; trié du plus proche', () => {
    const items = [
      { id: 'loin', ...eastKm(4) },
      { id: 'pres', ...eastKm(1) },
      { id: 'sans', lat: null, lng: null },
    ];
    const get = (i) => ({ lat: i.lat, lng: i.lng });
    const at5 = filterByRadius(items, { lat: LAT, lng: LNG }, 5, get).map((x) => x.item.id);
    expect(at5).toEqual(['pres', 'loin']);
    const at3 = filterByRadius(items, { lat: LAT, lng: LNG }, 3, get).map((x) => x.item.id);
    expect(at3).toEqual(['pres']);
    const keep = filterByRadius(items, { lat: LAT, lng: LNG }, 3, get, { keepWithoutCoords: true }).map((x) => x.item.id);
    expect(keep).toEqual(['pres', 'sans']);
  });
});

// ─── La vraie route /walkers/nearby ─────────────────────────────────────────
const mockWalkers = [
  { _id: 'w4', email: 'w4@example.test', name: 'À 4 km', location: { type: 'Point', coordinates: [eastKm(4).lng, eastKm(4).lat] }, preferences: {}, status: 'active' },
  { _id: 'w1', email: 'w1@example.test', name: 'À 1 km', location: { type: 'Point', coordinates: [eastKm(1).lng, eastKm(1).lat] }, preferences: {}, status: 'active' },
  { _id: 'w300', email: 'w300@example.test', name: 'À 300 km', location: { type: 'Point', coordinates: [eastKm(300).lng, eastKm(300).lat] }, preferences: {}, status: 'active' },
];

/** Simule $geoNear : distance haversine + maxDistance (inclusif, comme Mongo). */
function mockGeoNear(docs, pipeline) {
  const stage = pipeline[0].$geoNear;
  const [lng, lat] = stage.near.coordinates;
  const key = stage.key || 'location';
  const out = [];
  for (const d of docs) {
    const coords = d[key] && d[key].coordinates;
    if (!Array.isArray(coords)) continue;
    const dist = mockSearchRadius.haversineKm(lat, lng, coords[1], coords[0]) * 1000;
    if (stage.maxDistance !== undefined && dist > stage.maxDistance) continue;
    out.push({ ...d, [stage.distanceField]: dist });
  }
  return out.sort((a, b) => a[stage.distanceField] - b[stage.distanceField]);
}

const mockChain = (result) => {
  const c = { select: () => c, limit: () => c, sort: () => c, lean: () => Promise.resolve(result),
    then: (ok, ko) => Promise.resolve(result).then(ok, ko), catch: () => c };
  return c;
};
const mockPerson = () => ({ find: jest.fn(() => mockChain([])), findById: jest.fn(() => mockChain(null)), exists: jest.fn(() => Promise.resolve(false)), aggregate: jest.fn(async () => []) });
jest.mock('../src/models/Owner', () => mockPerson());
jest.mock('../src/models/Sitter', () => mockPerson());
jest.mock('../src/models/Walker', () => ({
  find: jest.fn(() => mockChain([])),
  findById: jest.fn(() => mockChain(null)),
  exists: jest.fn(() => Promise.resolve(false)),
  aggregate: jest.fn(async (pipeline) => mockGeoNear(mockWalkers, pipeline)),
}));
jest.mock('../src/models/UserSubscription', () => ({ find: jest.fn(() => mockChain([])), findOne: jest.fn(() => mockChain(null)) }));
jest.mock('../src/models/Friendship', () => ({ find: jest.fn(() => mockChain([])) }));
jest.mock('../src/sockets/emitter', () => ({ buildPresenceIndex: jest.fn(() => Promise.resolve(null)), isIdentityOnline: jest.fn(() => false) }));
jest.mock('../src/utils/personScope', () => ({
  personIds: jest.fn((id) => Promise.resolve([String(id)])),
  personIndex: jest.fn((ids) => Promise.resolve(new Map(ids.map((i) => [String(i), { ids: [String(i)] }])))),
}));
jest.mock('../src/utils/logger', () => ({ warn: jest.fn(), error: jest.fn(), info: jest.fn(), debug: jest.fn() }));

const { findNearbyWalkers } = require('../src/controllers/walkerController');

const call = (query) => new Promise((resolve, reject) => {
  const req = { query, headers: {}, user: null };
  const res = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json(body) { resolve({ status: this.statusCode, body }); } };
  findNearbyWalkers(req, res).catch(reject);
});
const ids = (body) => (body.walkers || body || []).map((w) => String(w.id || w._id));

describe('/walkers/nearby — la valeur du curseur est celle appliquée', () => {
  test('à 5 km : le promeneur à 4 km apparaît ; à 3 km il disparaît', async () => {
    const r5 = await call({ lat: String(LAT), lng: String(LNG), radiusInMeters: '5000' });
    expect(r5.status).toBe(200);
    expect(ids(r5.body)).toEqual(['w1', 'w4']);
    const r3 = await call({ lat: String(LAT), lng: String(LNG), radiusInMeters: '3000' });
    expect(ids(r3.body)).toEqual(['w1']);
  });

  test('exactement 4 km (borne inclusive) : le promeneur à 4 km est là', async () => {
    const Walker = require('../src/models/Walker');
    // La distance réelle du point construit vaut 4 000 m à ±10 m : on demande 4 010 m.
    const r = await call({ lat: String(LAT), lng: String(LNG), radiusInMeters: '4010' });
    expect(ids(r.body)).toContain('w4');
    expect(Walker.aggregate).toHaveBeenCalled();
    const lastPipeline = Walker.aggregate.mock.calls.at(-1)[0];
    expect(lastPipeline[0].$geoNear.maxDistance).toBe(4010);
  });

  test('500 km : plus de plafond à 200 km, le promeneur à 300 km est là', async () => {
    const r = await call({ lat: String(LAT), lng: String(LNG), radiusInMeters: '500000' });
    expect(ids(r.body)).toEqual(['w1', 'w4', 'w300']);
    const Walker = require('../src/models/Walker');
    expect(Walker.aggregate.mock.calls.at(-1)[0][0].$geoNear.maxDistance).toBe(500000);
  });

  test('sans rayon : défaut 10 km ; rayon en km (`radius=5`) accepté aussi', async () => {
    const r = await call({ lat: String(LAT), lng: String(LNG) });
    expect(ids(r.body)).toEqual(['w1', 'w4']);
    const r2 = await call({ lat: String(LAT), lng: String(LNG), radius: '3' });
    expect(ids(r2.body)).toEqual(['w1']);
  });
});

// ─── Rayon retenu par rôle sur le compte (préférences de carte) ─────────────
describe('normalizeMapPrefs — homeRadiusKm par rôle (curseur retenu)', () => {
  const { normalizeMapPrefs } = require('../src/controllers/mapPrefsController');

  test('chaque rôle garde le sien ; fusion clé par clé ; borné 10–500 et entier', () => {
    const a = normalizeMapPrefs({}, { homeRadiusKm: { owner: 30 } });
    expect(a.homeRadiusKm).toEqual({ owner: 30 });
    const b = normalizeMapPrefs(a, { homeRadiusKm: { sitter: 70.4 } });
    expect(b.homeRadiusKm).toEqual({ owner: 30, sitter: 70 });
    const c = normalizeMapPrefs(b, { homeRadiusKm: { walker: 900, owner: 3 } });
    expect(c.homeRadiusKm).toEqual({ owner: 10, sitter: 70, walker: 500 });
    const d = normalizeMapPrefs({}, { homeRadiusKm: { owner: 'abc', admin: 50 } });
    expect(d.homeRadiusKm).toBeUndefined();
  });
});
