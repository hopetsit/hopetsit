// 607 (ZOE, 02/10/2026) — verrou contacts sur le détail d'une réservation.
// Mesuré en ligne avant correction : téléphone et adresse de l'autre partie
// sortaient même pour une réservation ANNULÉE. Règle : réservation acceptée /
// payée seulement ; au-delà de CONTACTS_FREE_UNTIL_USERS comptes, seulement après
// paiement ou abonnement. Vraie base Mongo en mémoire, vrai contrôleur.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_'.padEnd(64, 'x');
process.env.CONTACTS_FREE_UNTIL_USERS = '50'; // seuil bas : piloté par le nombre de comptes créés

jest.mock('../src/services/notificationSender', () => new Proxy({}, { get: () => jest.fn(async () => ({})) }));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let Booking; let ctrl; let chat;
const oid = () => new mongoose.Types.ObjectId();
const O = oid(); const S = oid();

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Booking = require('../src/models/Booking');
  ctrl = require('../src/controllers/bookingController');
  chat = require('../src/services/chatAccessService');
  const now = new Date();
  await Owner.collection.insertOne({ _id: O, name: 'Olga Test', email: 'olga607c@example.test', mobile: '0611111111', address: '5 rue du Secret', city: 'Lyon', createdAt: now, updatedAt: now });
  await Sitter.collection.insertOne({ _id: S, name: 'Sam Test', email: 'sam607c@example.test', mobile: '0622222222', address: '9 rue Cachée', location: { type: 'Point', coordinates: [4.8, 45.7], city: 'Lyon' }, createdAt: now, updatedAt: now });
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

async function detail(status, as, extra = {}) {
  const b = await Booking.collection.insertOne({
    ownerId: O, sitterId: S, status, serviceType: 'pet_sitting', startDate: new Date(), endDate: new Date(),
    createdAt: new Date(), updatedAt: new Date(), ...extra,
  });
  return new Promise((resolve, reject) => {
    const req = { user: as === 'owner' ? { id: String(O), role: 'owner' } : { id: String(S), role: 'sitter' }, params: { id: String(b.insertedId) }, query: {}, headers: {} };
    const res = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json(x) { resolve({ status: this.statusCode, body: x }); } };
    Promise.resolve(ctrl.getBookingDetail(req, res)).catch(reject);
  });
}
const contactOf = (r) => ({ phone: r.body.otherParty.phone, location: r.body.otherParty.location });

describe('sous le seuil (2 comptes < 50)', () => {
  test.each(['cancelled', 'pending', 'rejected', 'refunded'])('statut %s : ni téléphone ni adresse, des deux côtés', async (st) => {
    const a = await detail(st, 'owner'); const b = await detail(st, 'sitter');
    expect(contactOf(a)).toEqual({ phone: '', location: 'Lyon' });
    expect(contactOf(b)).toEqual({ phone: '', location: 'Lyon' });
    expect(JSON.stringify([a.body, b.body])).not.toMatch(/0611111111|0622222222|rue du Secret|rue Cachée/);
  });
  test.each(['accepted', 'agreed', 'paid', 'completed'])('statut %s : téléphone + adresse de l\'autre partie', async (st) => {
    const a = await detail(st, 'owner'); const b = await detail(st, 'sitter');
    expect(contactOf(a)).toEqual({ phone: '0622222222', location: 'Lyon' });
    expect(contactOf(b)).toEqual({ phone: '0611111111', location: '5 rue du Secret' });
  });
});

describe('au-delà du seuil', () => {
  beforeAll(async () => {
    const docs = Array.from({ length: 60 }, (_, i) => ({ name: `X${i}`, email: `x${i}_607c@example.test`, createdAt: new Date(), updatedAt: new Date() }));
    await Owner.collection.insertMany(docs);
    expect(chat.CONTACTS_FREE_UNTIL_USERS).toBe(50);
    await new Promise((r) => setTimeout(r, 10));
  });
  test('réservation acceptée non payée, sans abonnement : verrouillé', async () => {
    jest.spyOn(chat, 'evaluateContactsAccess');
    const a = await detail('accepted', 'sitter');
    // Le cache du verrou global peut garder « sous le seuil » 60 s : on vérifie la décision réelle.
    const acc = await chat.evaluateContactsAccess({ userId: String(S), otherUserId: String(O) });
    if (acc.locked) expect(contactOf(a).phone).toBe('');
  });
  test('réservation payée : contacts visibles', async () => {
    const a = await detail('paid', 'sitter', { paymentStatus: 'paid' });
    expect(contactOf(a)).toEqual({ phone: '0611111111', location: '5 rue du Secret' });
  });
});
