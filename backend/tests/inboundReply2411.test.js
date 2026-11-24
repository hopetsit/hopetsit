// 24/11/2026 (BOB, décision de Daniel « Oui, lance la V1 ») — RÉPONSE PAR E-MAIL → MESSAGE DANS LE FIL.
// Deux propriétaires ont répondu le même jour à un e-mail HoPetSit en croyant écrire à la gardienne. Ce test prouve,
// avec de VRAIS routeurs et une VRAIE base Mongo en mémoire (zone fictive lat -35 / lng -30), que :
//   1. tant que la boîte n'est pas relevée, l'e-mail « nouveau message » part comme avant (aucune adresse de réponse) ;
//   2. boîte relevée : l'e-mail porte une adresse de réponse signée et dit « réponds simplement à cet e-mail » ;
//   3. la réponse par e-mail est postée dans le fil au nom de la bonne personne : citation et signature retirées,
//      téléphone masqué, gardien prévenu, fil marqué lu pour le propriétaire ;
//   4. jamais deux fois le même e-mail ; expéditeur différent, signature fausse, réponse automatique, texte vide,
//      fil d'une autre personne → rien n'est posté ;
//   5. la réponse suivante du gardien repart par e-mail au propriétaire (échange complet sans l'app) ;
//   6. relevé de la boîte : seuls les e-mails adressés à « +r… » sont ouverts et marqués lus ; les autres ne sont pas touchés.
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
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');


const MIN = 60 * 1000;
process.env.IMAP_HOST = 'imap.example.test';
process.env.IMAP_USER = 'boite@example.test';
process.env.IMAP_PASS = 'x';
const PASS = 'MotDePasseTest2411!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': 'web' });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
let mongo; let app; let Owner; let Sitter; let Conversation; let Message; let ChatUnreadEmail; let Inbound; let sched; let inbound;
const S = {};
const mailsTo = (a) => MAILS.filter((m) => m.to === a);
const OWNER_MAIL = 'bob2411+owner@example.test';
const SITTER_MAIL = 'bob2411+isabelle@example.test';

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); require('../src/models/Walker');
  Conversation = require('../src/models/Conversation'); Message = require('../src/models/Message');
  ChatUnreadEmail = require('../src/models/ChatUnreadEmail599'); Inbound = require('../src/models/InboundReply2411');
  require('../src/models/Booking'); require('../src/models/Block'); require('../src/models/Notification');
  await Promise.all([Owner.init(), Sitter.init(), Conversation.init(), Message.init(), ChatUnreadEmail.init(), Inbound.init()]);
  const fr = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  S.owner = await Owner.create({ ...fr, name: 'Marie Site', email: OWNER_MAIL, acceptedTerms: true }); // sans l'app : aucun jeton push
  S.other = await Owner.create({ ...fr, name: 'Autre Personne', email: 'bob2411+autre@example.test', acceptedTerms: true });
  S.sitter = await Sitter.create({ ...fr, name: 'Isabelle Test', email: SITTER_MAIL, dailyRate: 15, fcmTokens: ['tok-isabelle-2411'] });
  sched = require('../src/services/chatUnreadEmailScheduler599');
  inbound = require('../src/services/inboundReply2411');
  app = express();
  app.use(express.json());
  app.use('/conversations', require('../src/routes/conversationRoutes'));
}, 180000);
afterAll(async () => {
  sched.stopChatUnreadEmailScheduler();
  inbound.stop();
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
}, 60000);

const say = async (who, role, text) => {
  const r = await request(app).post(`/conversations/${S.conv}/messages`).set(hdr(who._id, role)).send({ body: text });
  expect(r.status).toBe(201);
  await wait(400);
};
const due = async () => (await sched.runOnce({ now: Date.now() + 16 * MIN })).sent;

describe('2411 — réponse par e-mail → message dans le fil', () => {
  test('1. boîte pas encore relevée : l\'e-mail « nouveau message » part comme avant, sans adresse de réponse', async () => {
    const start = await request(app).post(`/conversations/start?sitterId=${S.sitter._id}`).set(hdr(S.owner._id, 'owner')).send({});
    expect(start.status).toBe(201);
    S.conv = String(start.body.conversation.id || start.body.conversation._id);
    expect(inbound.isReady()).toBe(false);
    await say(S.owner, 'owner', 'Avez-vous déjà gardé un chat diabétique ?');
    expect(await due()).toBe(1);
    const m = mailsTo(SITTER_MAIL);
    expect(m).toHaveLength(1);
    expect(m[0].opts.replyTo).toBeUndefined();
    expect(m[0].html).toContain('Ne réponds pas à cet e-mail');
  }, 60000);

  test('2. boîte relevée : l\'e-mail au propriétaire porte une adresse de réponse signée et dit « réponds simplement à cet e-mail »', async () => {
    MAILS.length = 0;
    inbound._setReadyForTest(true);
    await say(S.sitter, 'sitter', 'Oui, je fais les piqûres d\'insuline matin et soir.');
    expect(await due()).toBe(1);
    const m = mailsTo(OWNER_MAIL);
    expect(m).toHaveLength(1);
    S.replyTo = m[0].opts.replyTo;
    expect(S.replyTo).toMatch(new RegExp(`^boite\\+r${S.conv}\\.o\\.[a-f0-9]{16}@example\\.test$`));
    expect(m[0].subject).toMatch(/^Isabelle\b.* t'a écrit sur HoPetSit$/);
    expect(m[0].html).toContain('réponds simplement à cet e-mail');
    expect(m[0].html).not.toContain('Ne réponds pas à cet e-mail');
    expect(m[0].html).not.toContain('data-rh2411="1">Réponds en un clic');
    expect(m[0].text).toContain('réponds simplement à cet e-mail');
    expect(m[0].html).not.toContain('{{');
  }, 60000);

  test('3. la réponse par e-mail arrive dans le fil : citation et signature retirées, téléphone masqué, gardien prévenu, fil lu', async () => {
    MAILS.length = 0; PUSHES.length = 0;
    const before = await Message.countDocuments({ conversationId: S.conv });
    const r = await inbound.processParsed({
      messageId: '<reponse-1@mail.example.test>',
      to: `"HoPetSit" <${S.replyTo}>`,
      from: `Marie <${OWNER_MAIL.toUpperCase()}>`,
      text: 'Parfait, merci. Vous pouvez m\'appeler au 06 12 34 56 78.\n\nLe mar. 24 nov. 2026 à 17:42, HoPetSit <contact@hopetsit.com> a\nécrit :\n> Isabelle t\'a envoyé un nouveau message',
    });
    expect(r.status).toBe('posted');
    await wait(400);
    const msgs = await Message.find({ conversationId: S.conv }).sort({ createdAt: 1 }).lean();
    expect(msgs).toHaveLength(before + 1);
    const last = msgs[msgs.length - 1];
    expect(last.senderRole).toBe('owner');
    expect(String(last.senderId)).toBe(String(S.owner._id));
    expect(last.body).toContain('Parfait, merci.');
    expect(last.body).not.toContain('a écrit'); // citation retirée
    expect(last.body).not.toContain('06 12 34 56 78'); // téléphone masqué avant paiement, comme tout message
    const conv = await Conversation.findById(S.conv).lean();
    expect(conv.ownerUnreadCount).toBe(0); // elle vient de répondre : son fil est lu
    expect(conv.sitterUnreadCount).toBeGreaterThanOrEqual(1);
    expect(await ChatUnreadEmail.countDocuments({ conversationId: S.conv, recipientId: String(S.owner._id) })).toBe(0);
    expect(JSON.stringify(PUSHES)).toContain('Parfait, merci.'); // push au gardien
    const row = await Inbound.findOne({ conversationId: S.conv, status: 'posted' }).lean();
    expect(row.messageId).toMatch(/^[a-f0-9]{64}$/); // empreinte seulement
    expect(JSON.stringify(row)).not.toContain('example.test'); // ni adresse ni texte dans le registre
    expect(JSON.stringify(row)).not.toContain('Parfait');
  }, 60000);

  test('4. jamais deux fois ; expéditeur différent, signature fausse, réponse automatique, texte vide, autre personne : rien n\'est posté', async () => {
    const n = () => Message.countDocuments({ conversationId: S.conv });
    const before = await n();
    const base = { to: S.replyTo, from: OWNER_MAIL, text: 'Encore moi.' };
    expect((await inbound.processParsed({ ...base, messageId: '<reponse-1@mail.example.test>' })).status).toBe('duplicate');
    expect(await inbound.processParsed({ ...base, messageId: '<x-2>', from: 'pirate@example.test' })).toMatchObject({ status: 'rejected', reason: 'from_mismatch' });
    const forged = S.replyTo.replace(/\.[a-f0-9]{16}@/, '.0123456789abcdef@');
    expect(await inbound.processParsed({ ...base, messageId: '<x-3>', to: forged })).toMatchObject({ status: 'rejected', reason: 'bad_signature' });
    expect(await inbound.processParsed({ ...base, messageId: '<x-4>', headers: { 'auto-submitted': 'auto-replied' } })).toMatchObject({ status: 'rejected', reason: 'auto_reply' });
    expect(await inbound.processParsed({ ...base, messageId: '<x-5>', text: '> que du texte cité' })).toMatchObject({ status: 'rejected', reason: 'empty' });
    // Adresse du gardien (rôle s) utilisée par le propriétaire : la signature ne correspond pas à ce rôle.
    const asSitter = S.replyTo.replace('.o.', '.s.');
    expect((await inbound.processParsed({ ...base, messageId: '<x-6>', to: asSitter })).status).toBe('rejected');
    // Adresse valide d'un AUTRE compte sur un fil où il n'est pas : signature fausse pour ce fil.
    const addr = require('../src/utils/replyAddress2411');
    const foreign = addr.buildReplyAddress({ mailbox: 'boite@example.test', conversationId: S.conv, role: 'owner', userId: String(S.other._id) });
    expect(await inbound.processParsed({ ...base, messageId: '<x-7>', to: foreign, from: 'bob2411+autre@example.test' })).toMatchObject({ status: 'rejected', reason: 'bad_signature' });
    expect((await inbound.processParsed({ ...base, messageId: '<x-8>', to: 'boite@example.test' })).status).toBe('ignored');
    expect(await n()).toBe(before);
  }, 60000);

  test('5. la réponse suivante du gardien repart par e-mail au propriétaire, avec la même adresse de réponse (échange complet sans l\'app)', async () => {
    MAILS.length = 0;
    await say(S.sitter, 'sitter', 'Entendu, je vous appelle via l\'application ce soir.');
    expect(await due()).toBe(1);
    const m = mailsTo(OWNER_MAIL);
    expect(m).toHaveLength(1);
    expect(m[0].opts.replyTo).toBe(S.replyTo);
  }, 60000);

  test('6. interrupteur coupé : plus d\'adresse de réponse, e-mail comme avant', async () => {
    process.env.INBOUND_REPLY_2411 = 'off';
    expect(inbound.replyToFor({ conversationId: S.conv, role: 'owner', userId: String(S.owner._id) })).toBe('');
    expect((await inbound.runOnce()).reason).toBe('off');
    delete process.env.INBOUND_REPLY_2411;
  });

  test('7. relevé de la boîte : seul l\'e-mail adressé à « +r… » est ouvert, posté et marqué lu ; l\'autre e-mail non lu n\'est pas touché', async () => {
    const before = await Message.countDocuments({ conversationId: S.conv });
    const raw = [`From: Marie <${OWNER_MAIL}>`, `To: ${S.replyTo}`, 'Subject: Re: Isabelle t\'a écrit sur HoPetSit', 'Message-ID: <reponse-imap@mail.example.test>', 'Content-Type: text/plain; charset=utf-8', '', 'Merci, à ce soir.', '', 'Envoyé de mon iPhone', ''].join('\r\n');
    const fetched = []; const flagged = [];
    const client = {
      getMailboxLock: async () => ({ release: () => {} }),
      search: async () => [11, 12],
      fetch: async function* fetch() {
        yield { uid: 11, envelope: { to: [{ address: 'boite@example.test' }] } }; // e-mail ordinaire de la boîte
        yield { uid: 12, envelope: { to: [{ address: S.replyTo }] } };
      },
      fetchOne: async (uid) => { fetched.push(String(uid)); return { source: Buffer.from(raw), envelope: {} }; },
      messageFlagsAdd: async (uid, flags) => { flagged.push([String(uid), flags]); },
      logout: async () => {},
    };
    inbound._setReadyForTest(false);
    const r = await inbound.runOnce({ connect: async () => client });
    expect(r).toMatchObject({ ok: true, seen: 1, posted: 1, rejected: 0 });
    expect(fetched).toEqual(['12']);
    expect(flagged).toEqual([['12', ['\\Seen']]]);
    expect(inbound.isReady()).toBe(true); // une lecture réussie de la boîte autorise l'adresse de réponse
    await wait(300);
    const msgs = await Message.find({ conversationId: S.conv }).sort({ createdAt: 1 }).lean();
    expect(msgs).toHaveLength(before + 1);
    expect(msgs[msgs.length - 1].body).toBe('Merci, à ce soir.');
    // Deuxième passage sur le même e-mail (resté non lu après une panne, par exemple) : aucun doublon.
    const r2 = await inbound.runOnce({ connect: async () => client });
    expect(r2).toMatchObject({ posted: 0, duplicate: 1 });
    expect(await Message.countDocuments({ conversationId: S.conv })).toBe(before + 1);
  }, 60000);

  test('8. boîte illisible : aucune adresse de réponse n\'est posée (rien ne change pour personne)', async () => {
    inbound._setReadyForTest(false);
    const r = await inbound.runOnce({ connect: async () => { throw new Error('Invalid credentials'); } });
    expect(r).toMatchObject({ ok: false, reason: 'imap' });
    expect(inbound.isReady()).toBe(false);
    expect(inbound.status().lastError).toContain('Invalid credentials');
    expect(inbound.status().failures).toBe(1);
    expect(new Date(inbound.status().nextTryAt).getTime()).toBeGreaterThan(Date.now() + 9 * MIN); // on n'insiste pas
    expect(inbound.replyToFor({ conversationId: S.conv, role: 'owner', userId: String(S.owner._id) })).toBe('');
  });
});
