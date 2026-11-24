// 24/11/2026 (BOB, ordre de Daniel « oui fais les 3 ») — « LE PROPRIÉTAIRE A REGARDÉ TA PROPOSITION : ÉCRIS-LUI ».
// VRAIS routeurs, VRAIE base Mongo en mémoire, zone fictive lat -35 / lng -30. Prouve que : 20 minutes après la
// consultation des candidats par un vrai propriétaire, le prestataire en attente qui n'a pas écrit reçoit UNE notification
// (e-mail dans sa langue, lien vers la demande) ; celui qui a déjà écrit ne reçoit rien ; jamais deux fois ; rien la nuit,
// rien avant 20 minutes, rien pour une consultation par un script, rien si l'interrupteur est coupé ; la simulation n'envoie rien.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

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
  return { ...actual, sendEmail: jest.fn(async (to, subject, text, html) => { MAILS.push({ to, subject, text: String(text || ''), html: String(html || '') }); return { messageId: 'mock' }; }), sendTemplatedEmail: jest.fn(async () => ({})) };
});
const PUSHES = [];
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async (m) => { PUSHES.push(m); return { successCount: m.tokens.length, failureCount: 0, responses: m.tokens.map(() => ({ success: true })) }; }) }) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0), emitToConversation: jest.fn(), emitChatMessage: jest.fn(),
  isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false), touchConversationOpen: jest.fn(async () => {}),
  buildPresenceIndex: jest.fn(async () => new Map()), isIdentityOnline: jest.fn(() => false),
}));
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/services/paymentAlert0410', () => new Proxy({}, { get: () => jest.fn(async () => null) }));
jest.mock('../src/utils/geocodeCity', () => ({
  baseCityName: (c) => String(c || ''), geocodeCity: jest.fn(async () => null), peekCity: () => undefined, warmCities: () => {}, ensureAnchorsLoaded: async () => {},
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');


const MIN = 60 * 1000;
const PASS = 'MotDePasseTest2411!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': 'web' });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
// Un mardi à 15 h, heure de Paris (jour), et le même jour à 3 h (nuit).
const DAY = new Date('2027-03-02T14:00:00.000Z').getTime();
const NIGHT = new Date('2027-03-02T02:00:00.000Z').getTime();
let mongo; let app; let Owner; let Sitter; let Pet; let Post; let Application; let CandidatesView; let Nudge; let svc;
const S = {};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); require('../src/models/Walker');
  Pet = require('../src/models/Pet'); Post = require('../src/models/Post'); Application = require('../src/models/Application');
  CandidatesView = require('../src/models/CandidatesView2610'); Nudge = require('../src/models/OwnerViewedNudge2411');
  require('../src/models/Conversation'); require('../src/models/Message'); require('../src/models/Booking'); require('../src/models/Block'); require('../src/models/Notification');
  await Promise.all([Owner.init(), Sitter.init(), Pet.init(), Post.init(), Application.init(), CandidatesView.init(), Nudge.init()]);
  const fr = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  S.owner = await Owner.create({ ...fr, name: 'Marie Site', email: 'bob2411v+owner@example.test', acceptedTerms: true });
  S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Nana', petType: 'cat' });
  S.quiet = await Sitter.create({ ...fr, name: 'Isabelle Test', email: 'bob2411v+isabelle@example.test', dailyRate: 15 });
  S.wrote = await Sitter.create({ ...fr, name: 'Lilia Test', email: 'bob2411v+lilia@example.test', dailyRate: 16 });
  svc = require('../src/services/ownerViewedNudge2411');
  app = express();
  app.use(express.json());
  app.use('/posts', require('../src/routes/postRoutes'));
  app.use('/applications', require('../src/routes/applicationRoutes'));
  app.use('/conversations', require('../src/routes/conversationRoutes'));
  const d = (n) => `${new Date(DAY + n * 86400000).toISOString().slice(0, 10)}T00:00:00.000Z`;
  const p = await request(app).post('/posts').set(hdr(S.owner._id, 'owner')).send({
    body: 'Garde de Nana, zone test.', language: 'fr', animalCount: 1, location: LOC, petIds: [String(S.pet._id)],
    serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', startDate: d(40), endDate: d(45), animalTypes: ['cat'],
  });
  expect(p.status).toBe(201);
  S.post = p.body.post;
  for (const who of [S.quiet, S.wrote]) {
    const r = await request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(who._id, 'sitter')).send({ postId: S.post.id, description: 'Disponible.', timeSlot: 'morning', serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: d(40) });
    if (r.status !== 201) console.log('apply →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(201);
  }
  // Lilia a déjà écrit à la propriétaire.
  const c = await request(app).post(`/conversations/start-by-sitter?ownerId=${S.owner._id}`).set(hdr(S.wrote._id, 'sitter')).send({ message: 'Bonjour, je suis Lilia.' });
  expect(c.status).toBeLessThan(300);
  await Application.updateMany({ postId: S.post.id }, { $set: { createdAt: new Date(DAY - 3 * 3600 * 1000) } });
  await wait(500);
  MAILS.length = 0;
}, 180000);
afterAll(async () => {
  try { require('../src/services/applicationEmail2610').stopApplicationEmailScheduler(); } catch (_) { /* pas démarré */ }
  try { require('../src/services/chatUnreadEmailScheduler599').stopChatUnreadEmailScheduler(); } catch (_) { /* pas démarré */ }
  svc.stop();
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
}, 60000);

const view = (minutesAgo, origin = 'web') => CandidatesView.create({ postId: String(S.post.id), ownerId: String(S.owner._id), at: new Date(DAY - minutesAgo * MIN), channel: 'web', source: 'email', origin });

describe('2411 — « le propriétaire a regardé ta proposition »', () => {
  test('rien sans consultation, rien avant 20 minutes, rien pour une consultation par un script', async () => {
    expect((await svc.runOnce({ now: DAY })).sent).toBe(0);
    await view(5);
    await view(60, 'script');
    const r = await svc.runOnce({ now: DAY });
    expect(r.sent).toBe(0);
    expect(await Nudge.countDocuments({})).toBe(0);
  }, 60000);

  test('la nuit et interrupteur coupé : rien ; la simulation compte sans envoyer', async () => {
    await view(30);
    expect(await svc.runOnce({ now: NIGHT })).toMatchObject({ sent: 0, reason: 'night' });
    process.env.OWNER_VIEWED_2411 = 'off';
    expect(await svc.runOnce({ now: DAY })).toMatchObject({ sent: 0, reason: 'off' });
    delete process.env.OWNER_VIEWED_2411;
    const sim = await svc.runOnce({ now: DAY, dryRun: true });
    expect(sim).toMatchObject({ sent: 0, wouldSend: 1 });
    expect(sim.skipped.already_wrote).toBe(1);
    expect(await Nudge.countDocuments({})).toBe(0);
    expect(MAILS).toHaveLength(0);
  }, 60000);

  test('20 minutes après : la gardienne qui n\'a pas écrit reçoit UN e-mail en français avec le lien de la demande ; celle qui a écrit ne reçoit rien', async () => {
    const r = await svc.runOnce({ now: DAY });
    expect(r.sent).toBe(1);
    await wait(500);
    const m = MAILS.filter((x) => x.to === 'bob2411v+isabelle@example.test');
    expect(m).toHaveLength(1);
    expect(m[0].subject).toBe('Marie a regardé ta proposition : écris-lui maintenant');
    expect(m[0].html).toContain('Zone test');
    expect(m[0].html).toContain(`/post/${S.post.id}`);
    expect(m[0].html).not.toContain('{{');
    expect(MAILS.filter((x) => x.to === 'bob2411v+lilia@example.test')).toHaveLength(0);
    const rows = await Nudge.find({}).lean();
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ status: 'sent', providerId: String(S.quiet._id), providerRole: 'sitter' });
  }, 60000);

  test('jamais deux fois : une nouvelle consultation ne renvoie rien à la même candidature', async () => {
    MAILS.length = 0;
    await view(25);
    const r = await svc.runOnce({ now: DAY + 10 * MIN });
    expect(r.sent).toBe(0);
    expect(r.skipped.already_nudged).toBe(1);
    await wait(300);
    expect(MAILS).toHaveLength(0);
  }, 60000);

  test('demande masquée ou gardien déjà choisi : rien', async () => {
    await Nudge.deleteMany({});
    await Post.updateOne({ _id: S.post.id }, { $set: { hidden: true } });
    expect((await svc.runOnce({ now: DAY })).sent).toBe(0);
    await Post.updateOne({ _id: S.post.id }, { $set: { hidden: false } });
    await Application.updateOne({ postId: S.post.id, sitterId: S.wrote._id }, { $set: { status: 'accepted' } });
    const r = await svc.runOnce({ now: DAY });
    expect(r.sent).toBe(0);
    expect(r.skipped.already_chosen).toBe(1);
  }, 60000);
});
