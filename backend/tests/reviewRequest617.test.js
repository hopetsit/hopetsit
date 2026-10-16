// 617 (ADA, 16/10/2026) — DEMANDE D'AVIS à la fin d'une réservation (§B.3).
// VRAIE base Mongo en mémoire, vrai sendNotification ; Firebase et SMTP CAPTÉS.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mockPushes = [];
const mockMails = [];
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0),
  isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false),
}));
jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({
    sendEachForMulticast: jest.fn(async (m) => {
      mockPushes.push(m);
      return { successCount: m.tokens.length, failureCount: 0, responses: [] };
    }),
  }),
}));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async (to, subject) => { mockMails.push({ to, subject }); return { messageId: 'capté' }; }) };
});

const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let Walker; let Booking; let Review; let Notification; let Registry; let svc;
const O = {}; const S = {}; const W = {};
const oid = (v) => new mongoose.Types.ObjectId(v);
const ins = async (Model, doc) => String((await Model.collection.insertOne({ status: 'active', ...doc })).insertedId);
const mkBooking = async (ownerId, provider, extra = {}) => {
  const id = (await Booking.collection.insertOne({
    ownerId: oid(ownerId), ...provider, status: 'completed', paymentStatus: 'paid', date: '2026-10-15', timeSlot: 'morning',
    createdAt: new Date(), updatedAt: new Date(), ...extra,
  })).insertedId;
  return Booking.findById(id);
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Booking = require('../src/models/Booking'); Review = require('../src/models/Review'); Notification = require('../src/models/Notification');
  Registry = require('../src/models/ReviewRequest617');
  await Registry.init();
  svc = require('../src/services/reviewRequest617');
  O.nicola = await ins(Owner, { name: 'Nicola Rossi', email: 'nicola617r@example.test', appLocale: 'fr', fcmTokens: ['jeton-nicola'] });
  O.amy = await ins(Owner, { name: 'Amy Pond', email: 'amy617r@example.test', appLocale: 'en', fcmTokens: ['jeton-amy'] });
  O.test = await ins(Owner, { name: 'Camille Durand', email: 'dadaciao84+testowner617r@example.test', appLocale: 'fr', fcmTokens: ['jeton-testowner'] });
  S.sasha = await ins(Sitter, { name: 'Sasha Lee', email: 'sasha617r@example.test' });
  S.test = await ins(Sitter, { name: 'Léa Test', email: 'dadaciao84+testsitter617r@example.test' });
  W.paul = await ins(Walker, { name: 'Paul Martin', email: 'paul617r@example.test' });
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(async () => {
  mockPushes.length = 0; mockMails.length = 0;
  await Promise.all([Booking.deleteMany({}), Review.deleteMany({}), Notification.deleteMany({}), Registry.deleteMany({})]);
});

describe('demande d’avis au propriétaire quand la réservation est terminée', () => {
  test('garde terminée : push + cloche en français, type review_request_617, données complètes, AUCUN e-mail ; une seule fois', async () => {
    const b = await mkBooking(O.nicola, { sitterId: oid(S.sasha) });
    const r = await svc.requestReviewForBooking(b);
    expect(r).toEqual({ sent: true, why: 'sent' });
    expect(mockPushes).toHaveLength(1);
    expect(mockPushes[0].tokens).toEqual(['jeton-nicola']);
    expect(mockPushes[0].notification.title).toBe('Comment s’est passée la garde avec Sasha ?');
    expect(mockPushes[0].notification.body).toBe('Laisse-lui un avis, ça l’aide à trouver ses prochains clients.');
    expect(mockPushes[0].data.type).toBe('review_request_617');
    expect(mockPushes[0].data.bookingId).toBe(String(b._id));
    expect(mockPushes[0].data.revieweeRole).toBe('sitter');
    expect(mockPushes[0].data.revieweeId).toBe(S.sasha);
    expect(mockPushes[0].data.providerName).toBe('Sasha');
    expect(mockMails).toHaveLength(0);
    const bell = await Notification.find({ recipientId: oid(O.nicola), type: 'review_request_617' }).lean();
    expect(bell).toHaveLength(1);
    expect(bell[0].data.bookingId).toBe(String(b._id));
    // Deuxième appel (même réservation) : rien.
    expect(await svc.requestReviewForBooking(b)).toEqual({ sent: false, why: 'already' });
    expect(mockPushes).toHaveLength(1);
    expect(await Registry.countDocuments({})).toBe(1);
  });

  test('promenade terminée, propriétaire anglophone : revieweeRole walker, texte anglais', async () => {
    const b = await mkBooking(O.amy, { walkerId: oid(W.paul) });
    expect((await svc.requestReviewForBooking(b)).sent).toBe(true);
    expect(mockPushes[0].notification.title).toBe('How did it go with Paul?');
    expect(mockPushes[0].data.revieweeRole).toBe('walker');
    expect(mockPushes[0].data.revieweeId).toBe(W.paul);
  });

  test('un avis existe déjà sur cette réservation : rien', async () => {
    const b = await mkBooking(O.nicola, { sitterId: oid(S.sasha) });
    await Review.collection.insertOne({
      reviewerId: oid(O.nicola), reviewerModel: 'Owner', revieweeId: oid(S.sasha), revieweeModel: 'Sitter', rating: 5, bookingId: b._id, createdAt: new Date(),
    });
    expect(await svc.requestReviewForBooking(b)).toEqual({ sent: false, why: 'reviewed' });
    expect(mockPushes).toHaveLength(0);
    expect(await Registry.countDocuments({})).toBe(0);
  });

  test('réservation pas terminée : rien', async () => {
    const b = await mkBooking(O.nicola, { sitterId: oid(S.sasha) }, { status: 'paid' });
    expect(await svc.requestReviewForBooking(b)).toEqual({ sent: false, why: 'not_completed' });
    expect(mockPushes).toHaveLength(0);
  });

  test('comptes de test : propriétaire +test avec vrai gardien → rien ; vrai propriétaire avec gardien +test → rien ; test des deux côtés → part', async () => {
    expect(await svc.requestReviewForBooking(await mkBooking(O.test, { sitterId: oid(S.sasha) }))).toEqual({ sent: false, why: 'test' });
    expect(await svc.requestReviewForBooking(await mkBooking(O.nicola, { sitterId: oid(S.test) }))).toEqual({ sent: false, why: 'test' });
    expect(mockPushes).toHaveLength(0);
    expect((await svc.requestReviewForBooking(await mkBooking(O.test, { sitterId: oid(S.test) }))).sent).toBe(true);
    expect(mockPushes[0].tokens).toEqual(['jeton-testowner']);
    expect(mockPushes[0].notification.title).toBe('Comment s’est passée la garde avec Léa ?');
  });

  test('deux appels simultanés : un seul envoi', async () => {
    const b = await mkBooking(O.nicola, { sitterId: oid(S.sasha) });
    const [a, c] = await Promise.all([svc.requestReviewForBooking(b), svc.requestReviewForBooking(b)]);
    expect([a.sent, c.sent].filter(Boolean)).toHaveLength(1);
    expect(mockPushes).toHaveLength(1);
  });

  test('la route serveur de la notification ouvre la réservation (bookingId)', () => {
    const { buildPreciseRoute, buildAppRoute } = require('../src/utils/emailLinkBuilder');
    const data = { bookingId: '507f1f77bcf86cd799439011', revieweeRole: 'sitter', revieweeId: 'x', providerName: 'Sasha' };
    expect(buildPreciseRoute('review_request_617', data, 'owner')).toBe('/bookings/507f1f77bcf86cd799439011');
    expect(buildAppRoute('review_request_617', data)).toBe('/bookings/507f1f77bcf86cd799439011');
  });

  test('branchement : completeBooking est le seul endroit où status devient completed, et il appelle la demande d’avis', () => {
    const src = fs.readFileSync(path.join(__dirname, '..', 'src', 'controllers', 'bookingController.js'), 'utf8');
    expect(src).toContain("require('../services/reviewRequest617').requestReviewForBooking(booking)");
    const walk = (dir) => fs.readdirSync(dir).flatMap((f) => {
      const p = path.join(dir, f);
      return fs.statSync(p).isDirectory() ? walk(p) : [p];
    });
    const hits = [];
    for (const f of walk(path.join(__dirname, '..', 'src')).filter((f) => f.endsWith('.js'))) {
      const s = fs.readFileSync(f, 'utf8');
      const re = /(booking|b)\.status\s*=\s*'completed'/g;
      if (re.test(s)) hits.push(path.relative(path.join(__dirname, '..', 'src'), f));
    }
    expect(hits).toEqual(['controllers/bookingController.js']);
  });
});

describe('décision pure', () => {
  const bk = { status: 'completed', sitterId: 'a' };
  test('cas', () => {
    const d = (o) => svc.decideReviewRequest({ booking: bk, ownerEmail: 'o@x.test', providerEmail: 'p@x.test', reviewExists: false, alreadyAsked: false, ...o });
    expect(d({}).ok).toBe(true);
    expect(d({ booking: { ...bk, status: 'paid' } }).why).toBe('not_completed');
    expect(d({ booking: { status: 'completed' } }).why).toBe('no_provider');
    expect(d({ alreadyAsked: true }).why).toBe('already');
    expect(d({ reviewExists: true }).why).toBe('reviewed');
    expect(d({ ownerEmail: 'a+test@x.test' }).why).toBe('test');
    expect(d({ providerEmail: 'a+test@x.test' }).why).toBe('test');
    expect(d({ ownerEmail: 'a+test@x.test', providerEmail: 'b+test@x.test' }).ok).toBe(true);
    expect(d({ ownerEmail: 'probe-565@invalid.example' }).why).toBe('test');
  });
});
