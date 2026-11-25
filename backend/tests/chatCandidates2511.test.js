// 25/11/2026 (BOB, accord de Daniel) — CHAT LIBRE ENTRE UN PROPRIÉTAIRE ET SES CANDIDATS, même APRÈS le seuil
// des 1 000 comptes (CHAT_FREE_UNTIL_USERS). Constat du 25/11 : 747 comptes, +347 profils en 30 jours → dans
// ~3 semaines, plus aucun propriétaire sans abonnement n'aurait pu écrire à un gardien avant de payer.
// Ce test force la fin de la phase de lancement (seuil = 1) et prouve, sur de VRAIES routes :
//   1. sans candidature : ouverture refusée (402 CHAT_ACCESS_REQUIRED) — la règle d'avant ne bouge pas ;
//   2. avec une candidature (gardien) : le propriétaire ouvre, écrit, le gardien lit et répond ;
//   3. avec une candidature (promeneur) : idem ;
//   4. le prestataire candidat peut ouvrir lui-même la conversation ;
//   5. coupe-circuit CHAT_CANDIDATES_FREE_2511=off : retour à la règle d'avant.
process.env.CHAT_FREE_UNTIL_USERS = '1';
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

const PASS = 'MotDePasseTest2511!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': 'web' });
let mongo; let app; let Owner; let Sitter; let Walker; let Application;
const S = {};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Application = require('../src/models/Application');
  require('../src/models/Conversation'); require('../src/models/Message'); require('../src/models/Booking'); require('../src/models/Block'); require('../src/models/Notification');
  const fr = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  S.owner = await Owner.create({ ...fr, name: 'Marie Site', email: 'bob2511+owner@example.test', acceptedTerms: true });
  S.cand = await Sitter.create({ ...fr, name: 'Isa Candidate', email: 'bob2511+cand@example.test', dailyRate: 15 });
  S.autre = await Sitter.create({ ...fr, name: 'Autre Gardien', email: 'bob2511+autre@example.test', dailyRate: 15 });
  S.walk = await Walker.create({ ...fr, name: 'Marc Promeneur', email: 'bob2511+walk@example.test' });
  S.walk2 = await Walker.create({ ...fr, name: 'Lea Promeneuse', email: 'bob2511+walk2@example.test' });
  await Application.create({ ownerId: S.owner._id, sitterId: S.cand._id, status: 'pending' });
  await Application.create({ ownerId: S.owner._id, walkerId: S.walk._id, status: 'pending' });
  await Application.create({ ownerId: S.owner._id, walkerId: S.walk2._id, status: 'pending' });
  app = express();
  app.use(express.json());
  app.use('/conversations', require('../src/routes/conversationRoutes'));
}, 180000);
afterAll(async () => {
  try { require('../src/services/chatUnreadEmailScheduler599').stopChatUnreadEmailScheduler(); } catch (_) { /* pas démarré */ }
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
}, 60000);

const startSitter = (sitter) => request(app).post(`/conversations/start?sitterId=${sitter._id}`).set(hdr(S.owner._id, 'owner')).send({});
const startWalker = (walker) => request(app).post('/conversations/start').set(hdr(S.owner._id, 'owner')).send({ walkerId: String(walker._id) });
const idOf = (r) => String(r.body.conversation.id || r.body.conversation._id);

describe('25/11 — chat libre propriétaire ↔ candidats après le seuil des 1 000 comptes', () => {
  test('la phase de lancement est bien terminée dans ce test', async () => {
    const { isLaunchPhase } = require('../src/services/chatAccessService');
    expect(await isLaunchPhase()).toBe(false);
  });

  test('1. sans candidature : ouverture refusée, comme avant', async () => {
    const r = await startSitter(S.autre);
    expect(r.status).toBe(402);
    expect(r.body.code).toBe('CHAT_ACCESS_REQUIRED');
  });

  test('2. gardien candidat : le propriétaire ouvre, écrit ; le gardien lit et répond', async () => {
    const start = await startSitter(S.cand);
    expect(start.status).toBe(201);
    const conv = idOf(start);
    const msg = await request(app).post(`/conversations/${conv}/messages`).set(hdr(S.owner._id, 'owner')).send({ body: 'Avez-vous déjà fait des piqûres à un chat diabétique ?' });
    expect(msg.status).toBe(201);
    const read = await request(app).get(`/conversations/${conv}/messages`).set(hdr(S.cand._id, 'sitter'));
    expect(read.status).toBe(200);
    expect((read.body.messages || []).length).toBe(1);
    const reply = await request(app).post(`/conversations/${conv}/messages`).set(hdr(S.cand._id, 'sitter')).send({ body: 'Oui, pendant deux ans pour ma propre chatte.' });
    expect(reply.status).toBe(201);
    const back = await request(app).get(`/conversations/${conv}/messages`).set(hdr(S.owner._id, 'owner'));
    expect(back.status).toBe(200);
    expect((back.body.messages || []).length).toBe(2);
  });

  test('3. promeneur candidat : idem', async () => {
    const start = await startWalker(S.walk);
    expect(start.status).toBe(201);
    const conv = idOf(start);
    const msg = await request(app).post(`/conversations/${conv}/messages`).set(hdr(S.owner._id, 'owner')).send({ body: 'Êtes-vous libre le matin ?' });
    expect(msg.status).toBe(201);
    const reply = await request(app).post(`/conversations/${conv}/messages`).set(hdr(S.walk._id, 'walker')).send({ body: 'Oui, dès 8 h.' });
    expect(reply.status).toBe(201);
  });

  test('4. le prestataire candidat peut ouvrir lui-même la conversation', async () => {
    const r = await request(app).post(`/conversations/start-by-walker?ownerId=${S.owner._id}`).set(hdr(S.walk2._id, 'walker')).send({ ownerId: String(S.owner._id) });
    expect(r.status).toBeLessThan(300);
    const refuse = await request(app).post(`/conversations/start-by-sitter?ownerId=${S.owner._id}`).set(hdr(S.autre._id, 'sitter')).send({ ownerId: String(S.owner._id) });
    expect(refuse.status).toBe(402);
  });

  test('5. coupe-circuit CHAT_CANDIDATES_FREE_2511=off : retour à la règle d’avant', async () => {
    process.env.CHAT_CANDIDATES_FREE_2511 = 'off';
    try {
      const { hasCandidateLink2511 } = require('../src/services/chatAccessService');
      expect(await hasCandidateLink2511({ ownerId: S.owner._id, sitterId: S.cand._id })).toBe(false);
      const conv = idOf(await startSitterAllowed());
      const msg = await request(app).post(`/conversations/${conv}/messages`).set(hdr(S.owner._id, 'owner')).send({ body: 'Encore une question.' });
      expect([402, 403]).toContain(msg.status);
    } finally {
      delete process.env.CHAT_CANDIDATES_FREE_2511;
    }
  });
});

// La conversation du test 2 existe déjà : on la retrouve sans repasser par le verrou d'ouverture.
async function startSitterAllowed() {
  const Conversation = require('../src/models/Conversation');
  const c = await Conversation.findOne({ ownerId: S.owner._id, sitterId: S.cand._id }).lean();
  return { body: { conversation: { id: String(c._id) } } };
}
