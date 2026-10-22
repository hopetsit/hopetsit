// 22/10/2026 (BOB) — les quartiers de New York ne partent plus à l'autre bout du monde.
// Mesuré sur Photon le 22/10 : Manhattan → Kansas, Brooklyn → Ohio, Queens → Nouvelle-Zélande,
// Staten Island → Nebraska. Ces noms sont résolus sans réseau, même si une mauvaise
// position a été gardée en base (CityAnchor) avant le correctif.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const geo = require('../src/utils/geocodeCity');
const { haversineKm } = require('../src/utils/searchRadius');

let mongo;
const realFetch = global.fetch;
const NYC = { lat: 40.7128, lng: -74.006 };

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  await require('../src/models/CityAnchor').init();
}, 60000);

afterAll(async () => {
  global.fetch = realFetch;
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

beforeEach(() => geo._resetForTest());

test('les 5 quartiers (et leurs variantes) tombent à New York, sans appel réseau', async () => {
  let calls = 0;
  global.fetch = async () => { calls += 1; throw new Error('le réseau ne doit pas être appelé'); };
  for (const c of ['Manhattan', 'Brooklyn', 'Queens', 'Bronx', 'The Bronx', 'Bronx County',
    'Staten Island', 'brooklyn, NY', 'Queens NY', 'Brooklyn New York']) {
    const p = await geo.geocodeCity(c);
    expect(p).not.toBeNull();
    expect(haversineKm(p.lat, p.lng, NYC.lat, NYC.lng)).toBeLessThan(30);
    expect(geo.peekCity(c)).toEqual(p);
  }
  expect(calls).toBe(0);
});

test('une mauvaise position gardée en base avant le correctif est ignorée', async () => {
  await require('../src/models/CityAnchor').create({ key: 'queens', lat: -45.03, lng: 168.66, at: new Date() });
  global.fetch = async () => { throw new Error('réseau coupé'); };
  await geo.ensureAnchorsLoaded();
  const p = await geo.geocodeCity('Queens');
  expect(haversineKm(p.lat, p.lng, NYC.lat, NYC.lng)).toBeLessThan(30);
});

test('les autres villes passent toujours par Photon', async () => {
  global.fetch = async () => ({ ok: true, json: async () => ({ features: [{ geometry: { coordinates: [-96.797, 32.7767] } }] }) });
  expect(await geo.geocodeCity('Dallas')).toEqual({ lat: 32.7767, lng: -96.797 });
});
