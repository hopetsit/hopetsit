// 25/11/2026 (BOB, ordre de Daniel « cette communication, ce n'est pas à nous : entre eux, par le site ou l'app ») —
// RÉPONDRE AU MAIL « <Prénom> peut garder votre chat » = ÉCRIRE À CE CANDIDAT.
// Trois propriétaires ont répondu à cet e-mail en croyant écrire à la gardienne. Ce test prouve, sur une vraie base en mémoire :
//   1. boîte de réponses pas relevée → l'e-mail part comme avant (réponse vers l'équipe, aucun fil créé) ;
//   2. boîte relevée → Reply-To signé + phrase « votre message arrive directement à <prénom> » + fil vide ouvert ;
//   3. la réponse par e-mail du propriétaire est postée dans le fil avec la gardienne, même après le seuil des
//      1 000 comptes (CHAT_FREE_UNTIL_USERS forcé à 1 : c'est la candidature qui ouvre le chat) ;
//   4. coupe-circuit CANDIDATE_REPLY_2511=off → comme avant.
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
  return { ...actual, sendEmail: jest.fn(async (to, subject, text, html, opts) => { MAILS.push({ to, subject, text: String(text || ''), html: String(html || ''), opts: opts || {} }); return { messageId: 'mock' }; }), sendTemplatedEmail: jest.fn(async () => ({})) };
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

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

process.env.IMAP_HOST = 'imap.example.test';
process.env.IMAP_USER = 'boite@example.test';
process.env.IMAP_PASS = 'x';
const PASS = 'MotDePasseTest2511!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const OWNER_MAIL = 'bob2511c+owner@example.test';
let mongo; let Owner; let Sitter; let Application; let Conversation; let Message; let inbound; let appEmail; let addr;
const S = {};
const last = () => MAILS[MAILS.length - 1];

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); require('../src/models/Walker');
  Application = require('../src/models/Application'); Conversation = require('../src/models/Conversation'); Message = require('../src/models/Message');
  require('../src/models/Booking'); require('../src/models/Block'); require('../src/models/Notification'); require('../src/models/InboundReply2411');
  inbound = require('../src/services/inboundReply2411'); appEmail = require('../src/services/applicationEmail2610'); addr = require('../src/utils/replyAddress2411');
  const fr = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  S.owner = await Owner.create({ ...fr, name: 'Marie Site', email: OWNER_MAIL, acceptedTerms: true });
  S.isa = await Sitter.create({ ...fr, name: 'Isabelle Test', email: 'bob2511c+isa@example.test', dailyRate: 15 });
  S.eli = await Sitter.create({ ...fr, name: 'Elisabeth Test', email: 'bob2511c+eli@example.test', dailyRate: 15 });
  S.post = { _id: new mongoose.Types.ObjectId(), ownerId: S.owner._id, serviceTypes: ['house_sitting'], animalTypes: ['cat'], location: { city: 'Zone test', lat: -35, lng: -30 }, startDate: new Date(Date.now() + 40 * 864e5), endDate: new Date(Date.now() + 45 * 864e5), dateMode: 'exact', status: 'open' };
  const pricing = { basePrice: 75, totalPrice: 90, currency: 'EUR', unit: 'day', quantity: 6, appliedRate: 15 };
  S.appIsa = (await Application.create({ ownerId: S.owner._id, sitterId: S.isa._id, postId: S.post._id, status: 'pending', pricing })).toObject();
  S.appEli = (await Application.create({ ownerId: S.owner._id, sitterId: S.eli._id, postId: S.post._id, status: 'pending', pricing })).toObject();
}, 180000);
afterAll(async () => {
  try { require('../src/services/chatUnreadEmailScheduler599').stopChatUnreadEmailScheduler(); } catch (_) { /* pas démarré */ }
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
}, 60000);

describe('25/11 — répondre au mail « candidat » = écrire au candidat', () => {
  test('1. boîte pas relevée : e-mail comme avant, aucun fil créé', async () => {
    inbound._setReadyForTest(false);
    const r = await appEmail.sendFor({ post: S.post, ownerId: S.owner._id, apps: [S.appIsa] });
    expect(r.sent).toBe(true);
    expect(last().to).toBe(OWNER_MAIL);
    expect(String(last().opts.replyTo || '')).not.toMatch(/\+r[a-f0-9]{24}/);
    expect(last().html).not.toContain('data-reply-2511');
    expect(await Conversation.countDocuments({})).toBe(0);
  });

  test('2. boîte relevée : adresse de réponse signée, phrase claire, fil ouvert (vide)', async () => {
    inbound._setReadyForTest(true);
    const r = await appEmail.sendFor({ post: S.post, ownerId: S.owner._id, apps: [S.appIsa] });
    expect(r.sent).toBe(true);
    const m = last();
    const parsed = addr.parseReplyAddress(m.opts.replyTo);
    expect(parsed).toBeTruthy();
    expect(parsed.role).toBe('owner');
    expect(m.html).toContain('data-reply-2511');
    expect(m.html).toContain('arrive directement à Isabelle');
    expect(m.html).not.toContain("c'est l'équipe HoPetSit qui vous lit");
    const conv = await Conversation.findById(parsed.conversationId).lean();
    expect(String(conv.ownerId)).toBe(String(S.owner._id));
    expect(String(conv.sitterId)).toBe(String(S.isa._id));
    expect(await Message.countDocuments({ conversationId: conv._id })).toBe(0);
    S.replyTo = m.opts.replyTo; S.convId = String(conv._id);
    // Un 2e e-mail pour la même candidate retrouve le même fil.
    await appEmail.sendFor({ post: S.post, ownerId: S.owner._id, apps: [S.appIsa] });
    expect(addr.parseReplyAddress(last().opts.replyTo).conversationId).toBe(S.convId);
    expect(await Conversation.countDocuments({})).toBe(1);
  });

  test('3. la réponse du propriétaire arrive dans le fil avec la gardienne (après le seuil des 1 000 comptes)', async () => {
    expect(await require('../src/services/chatAccessService').isLaunchPhase()).toBe(false);
    const out = await inbound.processParsed({
      messageId: '<reponse-2511c-1@example.test>', to: S.replyTo, from: `Marie <${OWNER_MAIL}>`, date: new Date(), headers: {},
      text: "A préciser, mon chat est diabétique, 2 piqûres par jour. Quelle est votre expérience ?\n\nLe mar. 24 nov. 2026 à 17:40, HoPetSit <contact@hopetsit.com> a écrit :\n> Isabelle peut garder votre chat",
    });
    expect(out.status).toBe('posted');
    const msgs = await Message.find({ conversationId: S.convId }).lean();
    expect(msgs.length).toBe(1);
    expect(msgs[0].senderRole).toBe('owner');
    expect(msgs[0].body).toContain('diabétique');
    expect(msgs[0].body).not.toContain('a écrit');
    // Une autre personne ne peut pas se servir de cette adresse.
    const bad = await inbound.processParsed({ messageId: '<reponse-2511c-2@example.test>', to: S.replyTo, from: 'x@example.test', date: new Date(), headers: {}, text: 'Bonjour' });
    expect(bad.status).toBe('rejected');
  });

  test('4. coupe-circuit CANDIDATE_REPLY_2511=off : comme avant', async () => {
    process.env.CANDIDATE_REPLY_2511 = 'off';
    try {
      const r = await appEmail.sendFor({ post: S.post, ownerId: S.owner._id, apps: [S.appEli] });
      expect(r.sent).toBe(true);
      expect(String(last().opts.replyTo || '')).not.toMatch(/\+r[a-f0-9]{24}/);
      expect(last().html).not.toContain('data-reply-2511');
      expect(await Conversation.countDocuments({})).toBe(1);
    } finally { delete process.env.CANDIDATE_REPLY_2511; }
  });
});
