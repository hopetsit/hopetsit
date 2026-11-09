// 1011 (BOB, constat de ZOE du 09/11) — « Choisir et payer » ne ferme plus les autres candidats AVANT le paiement.
// Vraies routes POST /applications et /applications/:id/respond, Mongo en mémoire, comptes fictifs.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
delete process.env.SIBLINGS_KEEP_1011;

jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({ sendEachForMulticast: jest.fn(async (m) => ({ successCount: m.tokens.length, failureCount: 0, responses: [] })) }),
}));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async () => ({ messageId: 'capté' })) };
});

const request = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const NYC = { lat: 40.7128, lng: -74.006 };
const BRONX = [-73.9097, 40.8361];
let mongo; let app; let Application; let Post; let Sitter; let Booking; let siblings;
let owner; let pet;
const tok = (id, role) => `Bearer ${jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '1h' })}`;
const mkSitter = async (name) => (await Sitter.collection.insertOne({
  name, email: `${name.toLowerCase()}-sib1011@example.test`, status: 'active', verified: true, currency: 'USD', country: 'US',
  dailyRate: 40, location: { type: 'Point', coordinates: BRONX, city: 'New York' },
})).insertedId;
const mkPost = async () => String((await Post.collection.insertOne({
  ownerId: owner, postType: 'request', status: 'open', hidden: false, body: 'Garde de 3 jours', serviceTypes: ['pet_sitting'], petIds: [pet],
  location: { city: 'New York', ...NYC }, startDate: new Date('2026-12-05T15:00:00Z'), endDate: new Date('2026-12-08T00:00:00Z'),
  reservedBy: { bookingId: null }, createdAt: new Date(),
})).insertedId);
const applyTo = (postId, sitterId) => request(app).post(`/api/v1/applications?ownerId=${owner}`)
  .set('Authorization', tok(sitterId, 'sitter'))
  .send({ petIds: [String(pet)], serviceType: 'pet_sitting', serviceDate: '2026-12-05T15:00:00.000Z',
    startDate: '2026-12-05T15:00:00.000Z', endDate: '2026-12-08T00:00:00.000Z', timeSlot: '15:00', basePrice: 40, duration: 3, postId });
const respond = (appId, action = 'accept') => request(app).post(`/api/v1/applications/${appId}/respond`).set('Authorization', tok(owner, 'owner')).send({ action });
const idOf = (r) => String(r.body.application.id || r.body.application._id);
const statusOf = async (id) => (await Application.findById(id).lean()).status;
const three = async (tag) => {
  const postId = await mkPost();
  const out = { postId };
  for (const n of ['A', 'B', 'C']) {
    const r = await applyTo(postId, await mkSitter(`${tag}${n}`));
    if (r.status >= 300) throw new Error(`candidature ${n} → ${r.status} ${JSON.stringify(r.body)}`);
    out[n] = idOf(r);
  }
  return out;
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  app = require('../src/app');
  Application = require('../src/models/Application'); Post = require('../src/models/Post'); Sitter = require('../src/models/Sitter'); Booking = require('../src/models/Booking');
  siblings = require('../src/services/siblings1011');
  const Owner = require('../src/models/Owner'); const Pet = require('../src/models/Pet');
  owner = (await Owner.collection.insertOne({ name: 'Abraham', email: 'abraham-sib1011@example.test', status: 'active', verified: true, currency: 'USD', country: 'US', city: 'New York', appLocale: 'en' })).insertedId;
  pet = (await Pet.collection.insertOne({ ownerId: owner, petName: 'Milo', category: 'cat' })).insertedId;
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
afterEach(() => { delete process.env.SIBLINGS_KEEP_1011; });

describe('candidats gardés jusqu’au paiement', () => {
  let k;
  test('au choix : le gardien choisi est accepté, les deux autres RESTENT en attente', async () => {
    k = await three('un');
    const r = await respond(k.A);
    expect(r.status).toBe(200);
    expect(await statusOf(k.A)).toBe('accepted');
    expect(await statusOf(k.B)).toBe('pending');
    expect(await statusOf(k.C)).toBe('pending');
    // rien n'est payé : le balayage ne ferme personne
    const rep = await siblings.closeSiblingsOfPaid({ notify: jest.fn() });
    expect(rep.closed).toBe(0);
    expect(await statusOf(k.B)).toBe('pending');
  }, 60000);

  test('le propriétaire change d’avis avant de payer : l’ancien choix est libéré, sa réservation annulée', async () => {
    const before = await Application.findById(k.A).lean();
    const r = await respond(k.B);
    expect(r.status).toBe(200);
    expect(await statusOf(k.B)).toBe('accepted');
    expect(await statusOf(k.A)).toBe('rejected');
    expect(await statusOf(k.C)).toBe('pending');
    const oldBooking = await Booking.findById(before.bookingId).lean();
    expect(oldBooking.status).toBe('cancelled');
    const post = await Post.findById(k.postId).lean();
    const b = await Application.findById(k.B).lean();
    expect(String(post.reservedBy.bookingId)).toBe(String(b.bookingId));
  }, 60000);

  test('une fois PAYÉ : le balayage ferme et prévient le candidat restant, une seule fois', async () => {
    const b = await Application.findById(k.B).lean();
    await Booking.updateOne({ _id: b.bookingId }, { $set: { paymentStatus: 'paid', status: 'paid', paidAt: new Date() } });
    const notify = jest.fn(async () => ({ ok: true }));
    const dry = await siblings.closeSiblingsOfPaid({ notify, dryRun: true });
    expect(dry).toMatchObject({ dryRun: true, paidRequests: 1, closed: 1 });
    expect(await statusOf(k.C)).toBe('pending');
    const rep = await siblings.closeSiblingsOfPaid({ notify });
    expect(rep).toMatchObject({ paidRequests: 1, closed: 1 });
    expect(await statusOf(k.C)).toBe('rejected');
    expect(notify).toHaveBeenCalledTimes(1);
    expect(notify.mock.calls[0][0]).toMatchObject({ type: 'application_rejected_other_accepted', role: 'sitter' });
    const again = await siblings.closeSiblingsOfPaid({ notify });
    expect(again.closed).toBe(0);
    expect(notify).toHaveBeenCalledTimes(1);
    // le gardien payé n'est jamais touché
    expect(await statusOf(k.B)).toBe('accepted');
    expect((await Booking.findById(b.bookingId).lean()).paymentStatus).toBe('paid');
  }, 60000);

  test('demande déjà payée : impossible de choisir quelqu’un d’autre (409 ALREADY_PAID), le payé reste intact', async () => {
    const late = await Application.findById(k.C).lean();
    const { _id, ...copy } = late;
    const ins = await Application.collection.insertOne({ ...copy, sitterId: await mkSitter('unD'), status: 'pending', bookingId: null, createdAt: new Date(), updatedAt: new Date() });
    const r = await respond(String(ins.insertedId));
    expect(r.status).toBe(409);
    expect(r.body.code).toBe('ALREADY_PAID');
    expect(await statusOf(String(ins.insertedId))).toBe('pending');
    expect(await statusOf(k.B)).toBe('accepted');
    const b = await Application.findById(k.B).lean();
    expect((await Booking.findById(b.bookingId).lean()).status).toBe('paid');
  }, 60000);
});

describe('interrupteur', () => {
  test('SIBLINGS_KEEP_1011=off : ancien comportement, les autres sont refusés dès le choix', async () => {
    process.env.SIBLINGS_KEEP_1011 = 'off';
    expect(siblings.enabled()).toBe(false);
    const k = await three('off');
    const r = await respond(k.A);
    expect(r.status).toBe(200);
    expect(await statusOf(k.A)).toBe('accepted');
    expect(await statusOf(k.B)).toBe('rejected');
    expect(await statusOf(k.C)).toBe('rejected');
  }, 60000);
});
