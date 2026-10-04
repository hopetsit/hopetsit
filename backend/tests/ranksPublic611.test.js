// 611 (PAM, demande LEO) — RANG sur les 3 fiches publiques construites à la
// main : GET /sitters/:id, GET /walkers/:id, GET /public/providers/:slug.
// Champ `pawPoints` absent en base = Chiot.
// Vraie base Mongo en mémoire + vraie application Express. Coordonnées en
// plein Atlantique sud (« Zone test ») : aucune donnée dans une vraie ville.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/config/firebaseAdmin', () => ({
  auth: () => ({ verifyIdToken: async () => { throw new Error('no firebase in tests'); } }),
  messaging: () => ({ send: async () => 'x', sendEachForMulticast: async () => ({ responses: [] }) }),
}));
// Aucun géocodage réseau (Photon) : une ville sans position reste sans centre.
jest.mock('../src/utils/geocodeCity', () => ({
  ...jest.requireActual('../src/utils/geocodeCity'),
  geocodeCity: async () => null,
}));
jest.mock('../src/config/swagger', () => ({ openapi: '3.0.0', info: { title: 't', version: '0' }, paths: {} }));

const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

const { slugBase, ensurePublicSlug } = require('../src/utils/publicSlug607');
const { _resetPioneerCache, computeIsPioneer } = require('../src/utils/pioneer607');
const { PUBLIC_PROVIDER_KEYS } = require('../src/utils/publicProvider607');
const { encodeQr } = require('../src/utils/qr607');
const { buildPosterPdf, extractPosterText, TXT } = require('../src/utils/posterPdf607');

let mongo; let app; let Sitter; let Walker; let Owner; let Booking;
const ZONE = [-30, -35]; // [lng, lat]
const at = (dLatKm) => ({ type: 'Point', coordinates: [ZONE[0], ZONE[1] + dLatKm / 111.2], city: 'Zone test' });
const tok = (doc, role) => jwt.sign({ id: String(doc._id), role }, process.env.JWT_SECRET);
let n = 0;
const mk = (Model, extra = {}) => {
  n += 1;
  return Model.create({
    name: `Personne Test${n}`, email: `neo607_${n}@example.org`, password: 'MotDePasse607!', ...extra,
  });
};

const SENSITIVE = [
  'email', 'mobile', 'phone', 'password', 'address', 'dateOfBirth', 'location', 'coordinates',
  'homeLocation', 'lat', 'lng', 'preferences', 'notificationPrefs', 'referralCode', 'referredBy',
  'fcmTokens', 'fcmDevices', 'walletBalance', 'ibanNumber', 'paypalEmail', 'lastName',
  'pendingEmail', 'twoFactorEnabled', 'marketingOptOut', 'card', 'kycStatus', 'firebaseUid',
];
const keysDeep = (v, out = new Set()) => {
  if (Array.isArray(v)) v.forEach((x) => keysDeep(x, out));
  else if (v && typeof v === 'object') for (const [k, x] of Object.entries(v)) { out.add(k); keysDeep(x, out); }
  return out;
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Owner = require('../src/models/Owner');
  Booking = require('../src/models/Booking');
  await Promise.all([Sitter.init(), Walker.init(), Owner.init()]);
  app = require('../src/app');
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

beforeEach(async () => {
  _resetPioneerCache();
  await Promise.all([Sitter.deleteMany({}), Walker.deleteMany({}), Owner.deleteMany({}), Booking.deleteMany({})]);
});


async function unsetPoints(Model, doc) {
  await Model.collection.updateOne({ _id: doc._id }, { $unset: { pawPoints: '', pawPointsSpendable: '' } });
}

describe('611 — rang sur les fiches publiques', () => {
  test('/public/providers/:slug (lien /s) : rang ; champ absent = Chiot', async () => {
    const s = await mk(Sitter, { firstName: 'Lea', lastName: 'Rang', location: at(0), city: 'Zone test', bio: 'Bio de test assez longue.', service: ['house_sitting'], dailyRate: 30 });
    await Sitter.collection.updateOne({ _id: s._id }, { $set: { pawPoints: 3100 } });
    const slug = await ensurePublicSlug(s, 'sitter');
    const r = await request(app).get(`/api/v1/public/providers/${slug}`);
    expect(r.status).toBe(200);
    expect(r.body.provider.rank).toEqual({ key: 'pack_leader', level: 4, pointsEarned: 3100, nextAt: 10000, nextKey: 'legend' });
    await unsetPoints(Sitter, s);
    const r2 = await request(app).get(`/api/v1/public/providers/${slug}`);
    expect(r2.body.provider.rank).toMatchObject({ key: 'puppy', pointsEarned: 0 });
  });

  test('GET /sitters/:id et GET /walkers/:id : rang ; champ absent = Chiot', async () => {
    const s = await mk(Sitter, { location: at(0), city: 'Zone test' });
    await Sitter.collection.updateOne({ _id: s._id }, { $set: { pawPoints: 820 } });
    const rs = await request(app).get(`/api/v1/sitters/${s._id}`);
    expect(rs.status).toBe(200);
    expect(rs.body.sitter.rank).toMatchObject({ key: 'adult_dog', pointsEarned: 820 });
    const w = await mk(Walker, { location: at(0), city: 'Zone test' });
    await unsetPoints(Walker, w);
    const rw = await request(app).get(`/api/v1/walkers/${w._id}`);
    expect(rw.status).toBe(200);
    expect(rw.body.walker.rank).toMatchObject({ key: 'puppy', pointsEarned: 0 });
    expect(JSON.stringify(rw.body)).not.toMatch(/pawPointsSpendable/);
  });
});
