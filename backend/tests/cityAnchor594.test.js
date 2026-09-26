// v594 — la même personne ne doit plus changer de point après un redémarrage
// du serveur : les centres-villes du floutage sont gardés en base.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const geo = require('../src/utils/geocodeCity');
const { friendPositionOf } = require('../src/utils/friendPosition587');

let mongo;
const realFetch = global.fetch;

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

test('centre-ville gardé en base, relu après « redémarrage »', async () => {
  let calls = 0;
  global.fetch = async () => {
    calls += 1;
    return { ok: true, json: async () => ({ features: [{ geometry: { coordinates: [-1.4247, 37.8519] } }] }) };
  };
  expect(await geo.geocodeCity('Alhama de Murcia')).toEqual({ lat: 37.8519, lng: -1.4247 });
  // l'écriture en base est lancée sans attendre
  await new Promise((r) => setTimeout(r, 200));
  geo._resetForTest();
  expect(geo.peekCity('Alhama de Murcia')).toBeUndefined();
  global.fetch = async () => { throw new Error('réseau coupé'); };
  await geo.ensureAnchorsLoaded();
  expect(geo.peekCity('Alhama de Murcia')).toEqual({ lat: 37.8519, lng: -1.4247 });
  expect(calls).toBe(1);
});

test('même ami → même point, avant et après redémarrage', async () => {
  const entries = [{
    role: 'sitter',
    d: {
      _id: 'aaaaaaaaaaaaaaaaaaaaaaaa',
      city: 'Alhama de Murcia',
      location: { type: 'Point', coordinates: [-1.43, 37.86], city: 'Alhama de Murcia' },
      preferences: { mapVisibility: 'friends' },
    },
  }];
  const a = friendPositionOf(entries).location;
  geo._resetForTest();
  await geo.ensureAnchorsLoaded();
  const b = friendPositionOf(entries).location;
  expect(b).toEqual(a);
});
