// ZOE (07/10/2026) — un propriétaire qui note son PROMENEUR recevait 404
// « Reviewee not found » : la fenêtre d'avis de l'app (submit_review_dialog.dart)
// n'envoie pas `revieweeRole`, et le serveur supposait « sitter ». Mesuré sur le
// banc local (même corps que l'app) : promeneur 404, gardien 201.
// Désormais le rôle est lu sur la réservation (ou sur le profil qui existe).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => ({})) }));
jest.mock('../src/services/loyaltyService', () => ({
  recomputeSitterStatus: jest.fn(async () => ({})),
  recomputeWalkerStatus: jest.fn(async () => ({})),
}));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let Walker; let Booking; let Review; let createReview;
let owner; let sitter; let walker;
beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Booking = require('../src/models/Booking');
  Review = require('../src/models/Review');
  ({ createReview } = require('../src/controllers/reviewController'));
  const base = { password: 'MotDePasse0710!', verified: true };
  owner = await Owner.create({ ...base, name: 'Camille Test', email: 'own0710@example.test' });
  sitter = await Sitter.create({ ...base, name: 'Sasha Test', email: 'sit0710@example.test' });
  walker = await Walker.create({ ...base, name: 'Paul Test', email: 'wal0710@example.test' });
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 30000);

async function paidBooking(role) {
  const r = await Booking.collection.insertOne({
    ownerId: owner._id, [`${role}Id`]: role === 'walker' ? walker._id : sitter._id,
    status: 'paid', paymentStatus: 'paid', createdAt: new Date(),
  });
  return String(r.insertedId);
}

async function call(user, body) {
  const res = { statusCode: 200, body: null };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  await createReview({ user, body }, res);
  return res;
}

const asOwner = () => ({ id: String(owner._id), role: 'owner' });

test('propriétaire → promeneur, corps de l’app (sans revieweeRole) : avis créé sur le Walker', async () => {
  const bookingId = await paidBooking('walker');
  const r = await call(asOwner(), { revieweeId: String(walker._id), bookingId, rating: 5, comment: 'Super balade' });
  expect(r.statusCode).toBe(201);
  const saved = await Review.findOne({ bookingId }).lean();
  expect(saved.revieweeModel).toBe('Walker');
  expect(String(saved.revieweeId)).toBe(String(walker._id));
});

test('propriétaire → promeneur sans bookingId : rôle déduit du profil existant', async () => {
  await Review.deleteMany({});
  await paidBooking('walker');
  const r = await call(asOwner(), { revieweeId: String(walker._id), rating: 4 });
  expect(r.statusCode).toBe(201);
  expect(r.body.review.revieweeModel).toBe('Walker');
});

test('propriétaire → gardien : inchangé', async () => {
  const bookingId = await paidBooking('sitter');
  const r = await call(asOwner(), { revieweeId: String(sitter._id), bookingId, rating: 5 });
  expect(r.statusCode).toBe(201);
  expect(r.body.review.revieweeModel).toBe('Sitter');
});

test('revieweeRole envoyé explicitement : toujours respecté', async () => {
  const bookingId = await paidBooking('walker');
  const r = await call(asOwner(), { revieweeId: String(walker._id), revieweeRole: 'walker', bookingId, rating: 3 });
  expect(r.statusCode).toBe(201);
  expect(r.body.review.revieweeModel).toBe('Walker');
});

test('sans réservation payée : toujours refusé (400)', async () => {
  const other = await Walker.create({ password: 'MotDePasse0710!', name: 'Autre', email: 'autre0710@example.test' });
  const r = await call(asOwner(), { revieweeId: String(other._id), rating: 5 });
  expect(r.statusCode).toBe(400);
});
