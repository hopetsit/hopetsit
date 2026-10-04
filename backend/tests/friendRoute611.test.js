// 611 (PAM, décision BOB du 04/10) — Daniel : « as-tu vérifié qu'on peut se
// faire un itinéraire entre amis ? ». Itinéraire vers un AMI = gratuit ;
// destination vérifiée (position visible de l'ami, ~100 m) ; sans friendId,
// la règle d'abonnement reste. Vraie base en mémoire, réseau coupé (le tracé
// retombe sur la ligne droite, comme en prod si Valhalla/OSRM ne répondent pas).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: () => (req, res, next) => next(),
  optionalAuth: (req, res, next) => next(),
}));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => ({ ok: true })) }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Friendship; let UserSubscription;
const Z = { lat: -35.2, lng: -30.4 }; // zone test
const realFetch = global.fetch;

beforeAll(async () => {
  global.fetch = jest.fn(async () => { throw new Error('réseau coupé (test)'); });
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Friendship = require('../src/models/Friendship');
  UserSubscription = require('../src/models/UserSubscription');
  await Owner.init();
  app = express();
  app.use(express.json());
  app.use('/pawspots', require('../src/routes/pawSpotRoutes'));
}, 60000);
afterAll(async () => { global.fetch = realFetch; await mongoose.disconnect(); if (mongo) await mongo.stop(); });

let n = 0;
async function person(lat = Z.lat, lng = Z.lng) {
  n += 1;
  return Owner.create({ name: `Route ${n}`, email: `route611_${n}@example.test`, password: 'MotDePasse611!',
    location: { type: 'Point', coordinates: [lng, lat], city: 'Zone test', updatedAt: new Date() } });
}
const as = (u) => ({ 'x-test-user': String(u._id), 'x-test-role': 'owner' });
const url = (to, friendId) => `/pawspots/directions?fromLat=${Z.lat}&fromLng=${Z.lng}&toLat=${to.lat}&toLng=${to.lng}&mode=walk${friendId ? `&friendId=${friendId}` : ''}`;

let a; let b; let c; const bAt = { lat: Z.lat + 0.01, lng: Z.lng + 0.01 };
beforeAll(async () => {
  a = await person();
  b = await person(bAt.lat, bAt.lng);
  c = await person(Z.lat - 0.01, Z.lng);
  await Friendship.create({ requesterId: a._id, requesterModel: 'Owner', addresseeId: b._id, addresseeModel: 'Owner', status: 'accepted', acceptedAt: new Date() });
});

test('ami, sans abonnement : 200 avec un tracé', async () => {
  const r = await request(app).get(url(bAt, b._id)).set(as(a));
  expect(r.status).toBe(200);
  expect(r.body.points.length).toBeGreaterThanOrEqual(2);
});

test('ami, destination à 50 m de sa position : accepté ; à 1 km : 403', async () => {
  const near = { lat: bAt.lat + 0.00045, lng: bAt.lng };
  expect((await request(app).get(url(near, b._id)).set(as(a))).status).toBe(200);
  const far = { lat: bAt.lat + 0.009, lng: bAt.lng };
  const r = await request(app).get(url(far, b._id)).set(as(a));
  expect(r.status).toBe(403);
  expect(r.body.code).toBe('FRIEND_POSITION_MISMATCH');
});

test('friendId d\'un NON-ami : 403', async () => {
  const r = await request(app).get(url({ lat: Z.lat - 0.01, lng: Z.lng }, c._id)).set(as(a));
  expect(r.status).toBe(403);
  expect(r.body.code).toBe('NOT_A_FRIEND');
});

test('sans friendId ni abonnement (spot, lieu) : 402 comme avant', async () => {
  const r = await request(app).get(url({ lat: Z.lat + 0.02, lng: Z.lng })).set(as(c));
  expect(r.status).toBe(402);
  expect(r.body.code).toBe('PAWFOLLOW_REQUIRED');
});

test('abonné, sans friendId : inchangé (200)', async () => {
  await UserSubscription.create({ userId: c._id, userModel: 'Owner', pawspotExpiry: new Date(Date.now() + 864e5) });
  const r = await request(app).get(url({ lat: Z.lat + 0.02, lng: Z.lng })).set(as(c));
  expect(r.status).toBe(200);
});
