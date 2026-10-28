process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

jest.mock('../src/services/airwallexService', () => {
  const actual = jest.requireActual('../src/services/airwallexService');
  return {
    ...actual,
    findOrCreateCustomer: jest.fn(async ({ userId }) => ({ id: `cus_test_${userId}` })),
    findCustomerByMerchantId: jest.fn(async () => null),
    retrieveCustomer: jest.fn(async (id) => ({ id })),
    listAllPaymentConsents: jest.fn(async () => []),
    listPaymentMethods: jest.fn(async () => []),
    createPlatformPaymentIntent: jest.fn(async (body) => ({ id: 'int_620', client_secret: 'cs', status: 'REQUIRES_PAYMENT_METHOD', amount: body.amount / 100, currency: body.currency })),
    retrievePaymentIntent: jest.fn(async (id) => ({ id })),
    cancelPaymentIntent: jest.fn(async (id) => ({ id, status: 'CANCELLED' })),
  };
});
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  requireVerifiedEmail: (req, res, next) => next(),
  attachUserFromToken: (req, res, next) => next(),
  attachOwnerFromToken: (req, res, next) => next(),
  optionalAuth: (req, res, next) => next(),
}));
const MAILS = [];
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async (to, subject, text) => { MAILS.push({ to, subject, text: String(text || '') }); return { messageId: 'mock' }; }), sendTemplatedEmail: jest.fn(async () => ({})) };
});
const PUSHES = [];
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async (m) => { PUSHES.push(m); return { successCount: m.tokens.length, failureCount: 0, responses: [] }; }) }) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
jest.mock('../src/sockets/emitter', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0), isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false) }));
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/services/paymentAlert0410', () => new Proxy({}, { get: () => jest.fn(async () => null) }));
jest.mock('../src/utils/geocodeCity', () => ({
  baseCityName: (c) => String(c || ''), geocodeCity: jest.fn(async () => null), peekCity: () => undefined, warmCities: () => {}, ensureAnchorsLoaded: async () => {},
}));



// 2810 (BOB) — relance « candidats non consultés » : e1 (+2 h), e2 (J+2), e3 (J+5), arrêt dès
// l'ouverture des candidats, jamais plus de 3, jamais un compte +test, rien tant que ce n'est pas activé.
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let Pet; let Post; let Application; let CandidatesView; let Reminder;
const PASS = 'MotDePasseTest2810!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const S = {};
const T0 = new Date('2026-11-02T09:00:00.000Z'); // 10 h à Paris
const at = (h) => new Date(T0.getTime() + h * 3600000);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Pet = require('../src/models/Pet');
  Post = require('../src/models/Post'); Application = require('../src/models/Application');
  CandidatesView = require('../src/models/CandidatesView2610'); Reminder = require('../src/models/CandidatesReminder2810');
  await Promise.all([Owner.init(), Sitter.init(), Pet.init(), Post.init(), Application.init(), Reminder.init()]);
  const mk = async (email) => {
    const o = await Owner.create({ name: 'Camille Durand', email, password: PASS, city: 'Paris', country: 'FR', currency: 'EUR', verified: true, location: { type: 'Point', coordinates: [2.35, 48.85] }, acceptedTerms: true, appLocale: 'fr' });
    const pet = await Pet.create({ ownerId: o._id, petName: 'Rex', petType: 'dog' });
    const post = await Post.collection.insertOne({ ownerId: o._id, postType: 'request', status: 'open', dateMode: 'tbd', serviceTypes: ['house_sitting'], city: 'Paris', body: 'Garde', petIds: [pet._id], createdAt: at(-1), location: { type: 'Point', coordinates: [2.35, 48.85] } });
    return { owner: o, pet, postId: post.insertedId };
  };
  S.real = await mk('camille.relance2810@example.org');
  S.test = await mk('camille+test2810@example.org');
  S.sitter = await Sitter.create({ name: 'Inès Petit', email: 'ines.relance2810@example.org', password: PASS, city: 'Paris', country: 'FR', currency: 'EUR', dailyRate: 18, verified: true, location: ZONE });
  for (const x of [S.real, S.test]) {
    // eslint-disable-next-line no-await-in-loop
    await Application.collection.insertOne({ ownerId: x.owner._id, sitterId: S.sitter._id, postId: x.postId, petIds: [x.pet._id], serviceType: 'house_sitting', status: 'pending', createdAt: T0, updatedAt: T0, pricing: { indicative: true, appliedRate: 18, unit: 'day', currency: 'EUR', commissionRate: 0.2 } });
  }
}, 180000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

const svc = () => require('../src/services/candidatesReminder2810');
const SENT = [];
const send = jest.fn(async (m) => { SENT.push(m); return { sent: true }; });
const run = (h, extra = {}) => svc().runCandidatesReminders({ now: at(h), send, ...extra });

describe('relance « candidats non consultés » 2810', () => {
  test('désactivée par défaut : rien n’est envoyé ni écrit ; la simulation dit ce qui partirait (compte +test exclu)', async () => {
    delete process.env.CANDIDATES_REMINDER_2810;
    const r = await run(3);
    expect(r.enabled).toBe(false);
    expect(r.sent).toHaveLength(0);
    expect(send).not.toHaveBeenCalled();
    const sim = await run(3, { dryRun: true });
    expect(sim.wouldSend).toEqual([expect.objectContaining({ postId: String(S.real.postId), slot: 'e1', candidates: 1 })]);
    expect(sim.skipped.test).toBe(1);
    expect(await Reminder.countDocuments({})).toBe(0);
  });

  test('activée : rien avant 2 h ; e1 à +2 h (carte du candidat, demande, propriétaire) ; jamais deux fois', async () => {
    process.env.CANDIDATES_REMINDER_2810 = 'on';
    expect((await run(1)).sent).toHaveLength(0);
    const r = await run(3);
    expect(r.sent).toEqual([expect.objectContaining({ postId: String(S.real.postId), slot: 'e1' })]);
    expect(SENT).toHaveLength(1);
    expect(SENT[0]).toMatchObject({ userId: String(S.real.owner._id), role: 'owner', templateType: 'application_new_2610' });
    expect(SENT[0].data.postId).toBe(String(S.real.postId));
    expect((await run(4)).sent).toHaveLength(0);
    expect(SENT).toHaveLength(1);
  });

  test('e2 à J+2 après e1, e3 à J+5, puis plus jamais (3 au maximum) ; jamais la nuit', async () => {
    expect((await run(3 + 47)).sent).toHaveLength(0);
    expect((await run(3 + 48)).sent).toEqual([expect.objectContaining({ slot: 'e2' })]);
    expect((await run(3 + 120 + 12)).skipped.night).toBe(1); // 22 h 00 à Paris le J+5
    expect((await run(3 + 120 + 24)).sent).toEqual([expect.objectContaining({ slot: 'e3' })]);
    const r = await run(3 + 400);
    expect(r.sent).toHaveLength(0);
    expect(r.skipped.max_3).toBe(1);
    expect(SENT).toHaveLength(3);
    expect(await Reminder.countDocuments({ postId: S.real.postId })).toBe(3);
  });

  test('arrêt dès que le propriétaire ouvre ses candidats (hors scripts) ; demande close ou réservée : rien', async () => {
    await Reminder.deleteMany({});
    await CandidatesView.create({ postId: String(S.real.postId), ownerId: String(S.real.owner._id), origin: 'script', channel: 'web' });
    expect((await run(3)).sent).toHaveLength(1); // une ouverture par nos scripts ne compte pas
    await Reminder.deleteMany({});
    await CandidatesView.create({ postId: String(S.real.postId), ownerId: String(S.real.owner._id), origin: 'web', channel: 'web' });
    const r = await run(3);
    expect(r.sent).toHaveLength(0);
    expect(r.skipped.owner_opened).toBe(1);
    await CandidatesView.deleteMany({});
    await Post.collection.updateOne({ _id: S.real.postId }, { $set: { status: 'closed' } });
    expect((await run(3)).sent).toHaveLength(0);
    await Post.collection.updateOne({ _id: S.real.postId }, { $set: { status: 'open', reservedBy: { bookingId: new mongoose.Types.ObjectId() } } });
    expect((await run(3)).sent).toHaveLength(0);
    delete process.env.CANDIDATES_REMINDER_2810;
  });
});
