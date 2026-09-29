// v599 (ZOE, 29/09/2026 08 h — décision Daniel) — E-MAIL DIFFÉRÉ « message non lu ».
// L'e-mail lié aux messages ne part que si le premier message non lu d'une
// conversation est TOUJOURS non lu après 15 minutes, une seule fois par
// conversation tant qu'elle n'est pas lue ; la lecture annule ; le compteur
// repart après une lecture ; robuste au redémarrage (attente en base).
// VRAIE base Mongo en mémoire (modèles Conversation, ChatUnreadEmail, Owner,
// Sitter, Notification), vrai sendNotification, vrai planificateur.
// Sans SMTP, sans Firebase, sans socket réel.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const sentEmails = [];
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return {
    ...actual,
    sendEmail: jest.fn(async (to, subject, text, html) => { sentEmails.push({ to, subject, text, html }); return { messageId: 'mock' }; }),
  };
});
jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({ sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }),
}));
const mockState = { conversationOpen: false };
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn(),
  emitToUsersAllRoles: jest.fn(() => 0),
  isUserOnline: jest.fn(async () => false),
  isConversationOpenFor: jest.fn(async () => mockState.conversationOpen),
}));
jest.mock('../src/services/notificationService', () => ({
  createNotificationSafe: jest.fn(async () => ({ _id: 'bell-1', createdAt: new Date() })),
  getUnreadCount: jest.fn(async () => 0),
}));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const MIN = 60 * 1000;
let mongo;
let Conversation;
let ChatUnreadEmail;
let sched;
let sendNotification;
let afterConversationRead;
let ownerId;
let sitterId;
let convId;
let t0;
let msgCount = 0;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  const Owner = require('../src/models/Owner');
  const Sitter = require('../src/models/Sitter');
  Conversation = require('../src/models/Conversation');
  ChatUnreadEmail = require('../src/models/ChatUnreadEmail599');
  await Promise.all([Owner.init(), Sitter.init(), Conversation.init(), ChatUnreadEmail.init()]);
  const o = await Owner.collection.insertOne({ name: 'Camille', email: 'camille599@example.test', appLocale: 'fr', language: 'fr' });
  ownerId = o.insertedId.toString();
  const s = await Sitter.collection.insertOne({ name: 'Léa', email: 'lea599@example.test', appLocale: 'fr', language: 'fr' });
  sitterId = s.insertedId.toString();
  sched = require('../src/services/chatUnreadEmailScheduler599');
  ({ sendNotification } = require('../src/services/notificationSender'));
  ({ afterConversationRead } = require('../src/utils/chatReadSync599'));
}, 60000);

afterAll(async () => {
  sched.stopChatUnreadEmailScheduler();
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

beforeEach(async () => {
  sentEmails.length = 0;
  mockState.conversationOpen = false;
  await ChatUnreadEmail.deleteMany({});
  await Conversation.deleteMany({});
  const c = await Conversation.create({ ownerId, sitterId, ownerUnreadCount: 0, sitterUnreadCount: 0 });
  convId = String(c._id);
  t0 = Date.now();
});

/** Camille écrit à Léa : compteur non-lu de Léa +1, puis la notification (comme conversationService). */
const messageFromOwner = async () => {
  msgCount += 1;
  const after = await Conversation.findByIdAndUpdate(convId, { $inc: { sitterUnreadCount: 1 } }, { new: true }).lean();
  await sendNotification({
    userId: sitterId,
    role: 'sitter',
    type: 'NEW_MESSAGE',
    data: {
      conversationId: convId,
      messageId: new mongoose.Types.ObjectId().toString(),
      senderName: 'Camille',
      preview: `Coucou ${msgCount}`,
      unreadForRecipient: after.sitterUnreadCount,
    },
    actor: { role: 'owner', id: ownerId },
  });
};

/** Léa lit la conversation (n'importe quel appareil) : compteur à 0 + synchro « lu ». */
const sitterReads = async () => {
  await Conversation.updateOne({ _id: convId }, { $set: { sitterUnreadCount: 0, sitterLastReadAt: new Date() } });
  return afterConversationRead({ conversationId: convId, readerId: sitterId, readerIds: [sitterId] });
};

const pendingDocs = () => ChatUnreadEmail.find({ conversationId: convId }).lean();

test('1. message non lu : aucun e-mail immédiat, e-mail UNE fois après 15 min', async () => {
  await messageFromOwner();
  expect(sentEmails).toHaveLength(0);
  const docs = await pendingDocs();
  expect(docs).toHaveLength(1);
  expect(docs[0].recipientId).toBe(sitterId);
  expect(docs[0].recipientRole).toBe('sitter');
  expect(docs[0].sentAt).toBeNull();
  const due = new Date(docs[0].unreadEmailDueAt).getTime();
  expect(due - t0).toBeGreaterThanOrEqual(15 * MIN - 2000);
  expect(due - t0).toBeLessThanOrEqual(15 * MIN + 2000);
  // 5 min : rien. 14 min : rien. 15 min + 1 s : envoyé.
  expect((await sched.runOnce({ now: t0 + 5 * MIN })).sent).toBe(0);
  expect((await sched.runOnce({ now: t0 + 14 * MIN })).sent).toBe(0);
  expect(sentEmails).toHaveLength(0);
  const r = await sched.runOnce({ now: t0 + 15 * MIN + 1000 });
  expect(r.sent).toBe(1);
  expect(sentEmails).toHaveLength(1);
  expect(sentEmails[0].to).toBe('lea599@example.test');
  expect(sentEmails[0].subject).toBeTruthy();
  expect(sentEmails[0].text).toContain(`https://www.hopetsit.com/chat/${convId}`);
  expect(sentEmails[0].html).toContain('Camille');
  // Idempotent : un 2e balayage n'envoie rien de plus.
  expect((await sched.runOnce({ now: t0 + 16 * MIN })).sent).toBe(0);
  expect(sentEmails).toHaveLength(1);
  const after = await pendingDocs();
  expect(after).toHaveLength(1);
  expect(after[0].sentAt).toBeTruthy();
});

test('2. lu à 5 min (sur n\'importe quel appareil) : attente annulée, aucun e-mail', async () => {
  await messageFromOwner();
  expect(await pendingDocs()).toHaveLength(1);
  const r = await sitterReads();
  expect(r.emailCancelled).toBe(1);
  expect(await pendingDocs()).toHaveLength(0);
  expect((await sched.runOnce({ now: t0 + 16 * MIN })).sent).toBe(0);
  expect(sentEmails).toHaveLength(0);
});

test('2b. filet de sécurité : compteur remis à 0 sans passer par la synchro → aucun e-mail non plus', async () => {
  await messageFromOwner();
  await Conversation.updateOne({ _id: convId }, { $set: { sitterUnreadCount: 0 } });
  const r = await sched.runOnce({ now: t0 + 16 * MIN });
  expect(r.sent).toBe(0);
  expect(r.cancelled).toBe(1);
  expect(sentEmails).toHaveLength(0);
  expect(await pendingDocs()).toHaveLength(0);
});

test('3. trois messages non lus : une seule attente, un seul e-mail ; un 4e après l\'envoi n\'en refait pas', async () => {
  await messageFromOwner();
  await messageFromOwner();
  await messageFromOwner();
  const docs = await pendingDocs();
  expect(docs).toHaveLength(1);
  expect(docs[0].payload.data.preview).toBe(`Coucou ${msgCount - 2}`); // le PREMIER message non lu
  expect((await sched.runOnce({ now: t0 + 16 * MIN })).sent).toBe(1);
  expect(sentEmails).toHaveLength(1);
  await messageFromOwner(); // toujours non lu
  expect(await pendingDocs()).toHaveLength(1);
  expect((await sched.runOnce({ now: t0 + 40 * MIN })).sent).toBe(0);
  expect(sentEmails).toHaveLength(1);
});

test('4. nouveau cycle après lecture : lu, puis nouveau message → nouvelle attente → nouvel e-mail', async () => {
  await messageFromOwner();
  expect((await sched.runOnce({ now: t0 + 16 * MIN })).sent).toBe(1);
  await sitterReads();
  expect(await pendingDocs()).toHaveLength(0);
  const t1 = t0 + 30 * MIN;
  const now = jest.spyOn(Date, 'now').mockReturnValue(t1);
  try {
    await messageFromOwner();
  } finally {
    now.mockRestore();
  }
  const docs = await pendingDocs();
  expect(docs).toHaveLength(1);
  expect(docs[0].sentAt).toBeNull();
  expect(new Date(docs[0].unreadEmailDueAt).getTime()).toBe(t1 + 15 * MIN);
  expect((await sched.runOnce({ now: t1 + 10 * MIN })).sent).toBe(0);
  expect((await sched.runOnce({ now: t1 + 16 * MIN })).sent).toBe(1);
  expect(sentEmails).toHaveLength(2);
});

test('5. redémarrage du serveur : l\'attente est en base, le balayage relancé envoie une fois, jamais deux', async () => {
  await messageFromOwner();
  // « Arrêt » du serveur : plus de balayage. L'attente survit en base.
  sched.stopChatUnreadEmailScheduler();
  expect(await pendingDocs()).toHaveLength(1);
  // « Redémarrage » 16 min plus tard : le balayage périodique reprend seul.
  const now = jest.spyOn(Date, 'now').mockReturnValue(t0 + 16 * MIN);
  try {
    sched.startChatUnreadEmailScheduler({ intervalMs: 25 });
    await new Promise((r) => setTimeout(r, 400));
    sched.stopChatUnreadEmailScheduler();
    await new Promise((r) => setTimeout(r, 100));
  } finally {
    now.mockRestore();
  }
  expect(sentEmails).toHaveLength(1);
  // Deux instances : une attente déjà réclamée par l'autre n'est pas renvoyée.
  await Conversation.deleteMany({});
  await ChatUnreadEmail.deleteMany({});
  const c = await Conversation.create({ ownerId, sitterId, ownerUnreadCount: 0, sitterUnreadCount: 0 });
  convId = String(c._id);
  await messageFromOwner();
  await ChatUnreadEmail.updateOne({ conversationId: convId }, { $set: { claimedAt: new Date() } });
  const r = await sched.runOnce({ now: t0 + 20 * MIN });
  expect(r.sent).toBe(0);
  expect(sentEmails).toHaveLength(1);
});

test('6. conversation ouverte à l\'écran à l\'échéance, ou supprimée : aucun e-mail', async () => {
  await messageFromOwner();
  mockState.conversationOpen = true;
  expect((await sched.runOnce({ now: t0 + 16 * MIN })).cancelled).toBe(1);
  expect(sentEmails).toHaveLength(0);
  mockState.conversationOpen = false;
  await sitterReads(); // lu → compteur à 0
  await messageFromOwner(); // nouvelle attente (l'ancienne a été effacée)
  expect(await pendingDocs()).toHaveLength(1);
  await Conversation.deleteOne({ _id: convId });
  expect((await sched.runOnce({ now: t0 + 40 * MIN })).cancelled).toBe(1);
  expect(sentEmails).toHaveLength(0);
});

test('7. panne d\'envoi : réclamation rendue, nouvel essai au balayage suivant, un seul e-mail au final', async () => {
  const { sendEmail } = require('../src/services/emailService');
  await messageFromOwner();
  sendEmail.mockImplementationOnce(async () => { throw new Error('SMTP down'); });
  const r1 = await sched.runOnce({ now: t0 + 16 * MIN });
  expect(r1.failed).toBe(1);
  expect(sentEmails).toHaveLength(0);
  const d = (await pendingDocs())[0];
  expect(d.claimedAt).toBeNull();
  expect(d.attempts).toBe(1);
  expect(d.lastError).toContain('SMTP down');
  const r2 = await sched.runOnce({ now: t0 + 17 * MIN });
  expect(r2.sent).toBe(1);
  expect(sentEmails).toHaveLength(1);
});

describe('isStillUnread (règle pure)', () => {
  const { isStillUnread } = require('../src/services/chatUnreadEmailScheduler599');
  test('réservation : côté propriétaire / prestataire ; amis : participants[]', () => {
    const p = { recipientId: 'S1', recipientIds: ['S1', 'O9'] };
    expect(isStillUnread({ ownerId: 'O1', sitterId: 'S1', sitterUnreadCount: 2 }, p)).toBe(true);
    expect(isStillUnread({ ownerId: 'O1', sitterId: 'S1', sitterUnreadCount: 0 }, p)).toBe(false);
    expect(isStillUnread({ ownerId: 'O9', walkerId: 'W1', ownerUnreadCount: 1 }, p)).toBe(true);
    expect(isStillUnread({ ownerId: 'O1', sitterId: 'S2', sitterUnreadCount: 5 }, p)).toBe(false); // plus membre
    expect(isStillUnread({ friendChat: true, participants: [{ userId: 'S1', unreadCount: 1 }, { userId: 'X', unreadCount: 0 }] }, p)).toBe(true);
    expect(isStillUnread({ friendChat: true, participants: [{ userId: 'S1', unreadCount: 0 }, { userId: 'X', unreadCount: 3 }] }, p)).toBe(false);
    expect(isStillUnread(null, p)).toBe(false);
  });
});
