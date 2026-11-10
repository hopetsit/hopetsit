// 639 (ZOE, complément demandé par BOB le 10/11/2026) — point vert
// « Disponible aujourd'hui » sur les routes PUBLIQUES de la carte du site :
//   GET /sitters/nearby   et   GET /walkers/nearby   (sans compte).
//
// LEO a relevé que ces deux réponses ne portaient pas `availableDot` : la
// carte publique du site n'affichait donc jamais le point vert, alors que la
// carte connectée (/friends/members/*) et l'app l'ont.
//
// MÊME règle que la carte (utils/mapVisibility.isAvailableDot) :
//   gardien ou promeneur (jamais un propriétaire)
//   ET disponibilité DÉCLARÉE aujourd'hui
//   ET vu il y a moins de N heures (PAWMAP_AVAILABLE_DOT_HOURS, 48 par défaut ;
//      jamais vu = faux)
//   ET coupe-circuit PAWMAP_AVAILABLE_DOT !== 'off'.
// `lastSeenAt` sert au calcul et ne doit PAS sortir de la réponse des gardiens.
//
// Vraie base Mongo en mémoire + vraie application Express, appelée comme un
// inconnu sur Internet. Zone FICTIVE (lat −35 / lng −30), jamais une vraie ville.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/config/firebaseAdmin', () => ({
  auth: () => ({ verifyIdToken: async () => { throw new Error('no firebase in tests'); } }),
  messaging: () => ({ send: async () => 'x', sendEachForMulticast: async () => ({ responses: [] }) }),
}));
jest.mock('../src/config/swagger', () => ({ openapi: '3.0.0', info: { title: 't', version: '0' }, paths: {} }));

const mongoose = require('mongoose');
const request = require('supertest');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { isAvailableDot } = require('../src/utils/mapVisibility');

const LAT = -35;
const LNG = -30;
const H = 3600 * 1000;
const ago = (hours) => new Date(Date.now() - hours * H);
const TODAY = [new Date()];
const loc = (dx) => ({ type: 'Point', coordinates: [LNG + dx, LAT], city: 'Zone test' });

const SITTERS_URL = `/api/v1/sitters/nearby?lat=${LAT}&lng=${LNG}&radiusInMeters=50000`;
const WALKERS_URL = `/api/v1/walkers/nearby?lat=${LAT}&lng=${LNG}&radiusInMeters=50000`;

// Les 4 cas, identiques pour les deux rôles.
const CASES = [
  // [prénom, champs, point vert attendu]
  ['Dispo', { availableDates: TODAY, lastSeenAt: ago(2) }, true], // dispo + vu il y a 2 h
  ['Vieux', { availableDates: TODAY, lastSeenAt: ago(72) }, false], // dispo, vu il y a 3 jours
  ['Jamais', { availableDates: TODAY }, false], // dispo, jamais vu
  ['Pasdispo', { lastSeenAt: ago(1) }, false], // vu, mais rien déclaré aujourd'hui
];

let mongo; let app; let Sitter; let Walker; let Owner;
const byName = (list) => Object.fromEntries(list.map((x) => [String(x.name).split(' ')[0], x]));
const keysDeep = (v, out = new Set()) => {
  if (Array.isArray(v)) v.forEach((x) => keysDeep(x, out));
  else if (v && typeof v === 'object') {
    for (const [k, x] of Object.entries(v)) { out.add(k); keysDeep(x, out); }
  }
  return out;
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Owner = require('../src/models/Owner');
  await Promise.all([Sitter.init(), Walker.init(), Owner.init()]);
  app = require('../src/app');
  let i = 0;
  for (const [name, extra] of CASES) {
    i += 1;
    await Sitter.create({
      name: `${name} Gardien`, email: `g${i}.dot639@example.org`, password: 'MotDePasse639!',
      location: loc(i * 0.001), service: ['house_sitting'], ...extra,
    });
    await Walker.create({
      name: `${name} Promeneur`, email: `p${i}.dot639@example.org`, password: 'MotDePasse639!',
      location: loc(-i * 0.001), ...extra,
    });
  }
  // Un propriétaire au même endroit, vu à l'instant : il ne doit apparaître
  // dans aucune des deux réponses (ces routes ne servent que les prestataires).
  await Owner.create({
    name: 'Proprio Dot', email: 'o.dot639@example.org', password: 'MotDePasse639!',
    location: loc(0.0005), lastSeenAt: ago(0.1),
  });
}, 60000);

afterEach(() => {
  delete process.env.PAWMAP_AVAILABLE_DOT;
  delete process.env.PAWMAP_AVAILABLE_DOT_HOURS;
});

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

describe.each([
  ['GET /sitters/nearby', SITTERS_URL, 'sitters'],
  ['GET /walkers/nearby', WALKERS_URL, 'walkers'],
])('%s (sans compte) — availableDot', (_label, url, field) => {
  test('vrai / faux : même règle que la carte, toujours un booléen', async () => {
    const r = await request(app).get(url);
    expect(r.status).toBe(200);
    const got = byName(r.body[field]);
    expect(Object.keys(got).sort()).toEqual(['Dispo', 'Jamais', 'Pasdispo', 'Vieux']);
    for (const [name, , expected] of CASES) {
      expect(typeof got[name].availableDot).toBe('boolean');
      expect([name, got[name].availableDot]).toEqual([name, expected]);
    }
  });

  test('coupe-circuit PAWMAP_AVAILABLE_DOT=off : plus aucun point vert, le reste de la réponse identique', async () => {
    const on = await request(app).get(url);
    process.env.PAWMAP_AVAILABLE_DOT = 'off';
    const off = await request(app).get(url);
    expect(off.status).toBe(200);
    expect(off.body[field]).toHaveLength(4);
    expect(off.body[field].every((x) => x.availableDot === false)).toBe(true);
    // Mêmes personnes, mêmes clés : seul le drapeau change.
    expect(off.body[field].map((x) => x.id || x._id).sort()).toEqual(on.body[field].map((x) => x.id || x._id).sort());
    expect([...keysDeep(off.body)].sort()).toEqual([...keysDeep(on.body)].sort());
  });

  test('PAWMAP_AVAILABLE_DOT_HOURS=100 : celui vu il y a 3 jours passe au vert, « jamais vu » reste faux', async () => {
    process.env.PAWMAP_AVAILABLE_DOT_HOURS = '100';
    const r = await request(app).get(url);
    const got = byName(r.body[field]);
    expect(got.Vieux.availableDot).toBe(true);
    expect(got.Jamais.availableDot).toBe(false);
    expect(got.Pasdispo.availableDot).toBe(false);
  });

  test('le propriétaire voisin ne sort pas de cette route', async () => {
    const r = await request(app).get(url);
    expect(r.body[field].some((x) => /Proprio/.test(String(x.name)))).toBe(false);
  });
});

describe('aucune donnée de présence nouvelle', () => {
  test('GET /sitters/nearby ne renvoie ni lastSeenAt ni isOnline', async () => {
    const r = await request(app).get(SITTERS_URL);
    const keys = keysDeep(r.body);
    expect(keys.has('lastSeenAt')).toBe(false);
    expect(keys.has('isOnline')).toBe(false);
  });
});

describe('rôle propriétaire : jamais de point vert (règle commune)', () => {
  test('mêmes données qu\'un gardien au vert, rôle owner ou rôle absent → faux', () => {
    const doc = { availableDates: TODAY, lastSeenAt: ago(0.1) };
    expect(isAvailableDot(doc, new Date(), { role: 'sitter' })).toBe(true);
    expect(isAvailableDot(doc, new Date(), { role: 'walker' })).toBe(true);
    expect(isAvailableDot(doc, new Date(), { role: 'owner' })).toBe(false);
    expect(isAvailableDot(doc, new Date(), {})).toBe(false);
    expect(isAvailableDot(doc, new Date())).toBe(false);
  });
});
