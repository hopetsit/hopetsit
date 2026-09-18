// v566 — accusés de réception / lecture du chat (✓ ✓✓ ✓✓ bleu), SANS base
// réelle : Conversation et Message remplacés par un magasin en mémoire,
// l'émetteur socket par un espion.

process.env.NODE_ENV = 'test';

const mockStores = { Conversation: [], Message: [] };

const mockEq = (a, b) => {
  if (a == null && b == null) return true; // { field: null } matche aussi « absent »
  if (a == null || b == null) return false;
  if (a instanceof Date || b instanceof Date) return new Date(a).getTime() === new Date(b).getTime();
  return String(a) === String(b);
};

const mockMatches = (doc, filter) =>
  Object.entries(filter || {}).every(([k, v]) => {
    if (k === '$or') return v.some((f) => mockMatches(doc, f));
    const val = doc[k];
    if (v && typeof v === 'object' && !(v instanceof Date) && !Array.isArray(v)) {
      return Object.entries(v).every(([op, arg]) => {
        if (op === '$ne') return !mockEq(val, arg);
        if (op === '$in') return arg.some((x) => mockEq(val, x));
        if (op === '$lte') return new Date(val).getTime() <= new Date(arg).getTime();
        if (op === '$gte') return new Date(val).getTime() >= new Date(arg).getTime();
        throw new Error(`opérateur non simulé : ${op}`);
      });
    }
    return mockEq(val, v);
  });

const mockChain = (rows) => {
  let out = Array.isArray(rows) ? [...rows] : rows;
  const api = {
    select: () => api,
    sort: (spec) => {
      const [[key, dir]] = Object.entries(spec);
      out.sort((a, b) => (new Date(a[key]) - new Date(b[key])) * dir);
      return api;
    },
    limit: (n) => { out = out.slice(0, n); return api; },
    lean: async () => (Array.isArray(out) ? out.map((d) => ({ ...d })) : out ? { ...out } : out),
  };
  return api;
};

const mockModel = (name) => ({
  find: jest.fn((filter) => mockChain(mockStores[name].filter((d) => mockMatches(d, filter)))),
  findById: jest.fn((id) => mockChain(mockStores[name].find((d) => String(d._id) === String(id)) || null)),
  updateMany: jest.fn(async (filter, update) => {
    const docs = mockStores[name].filter((d) => mockMatches(d, filter));
    docs.forEach((d) => Object.assign(d, update.$set || {}));
    return { modifiedCount: docs.length };
  }),
});

jest.mock('../src/models/Conversation', () => mockModel('Conversation'));
jest.mock('../src/models/Message', () => mockModel('Message'));
jest.mock('../src/sockets/emitter', () => ({ emitToUsersAllRoles: jest.fn(() => 1) }));
jest.mock('../src/utils/logger', () => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() }));

const Message = require('../src/models/Message');
const { emitToUsersAllRoles } = require('../src/sockets/emitter');
const receipts = require('../src/services/messageReceiptService');

const OWNER = 'owner_1';
const SITTER = 'sitter_1';
const FRIEND_A = 'owner_a';
const FRIEND_B = 'walker_b';
const STRANGER = 'owner_x';
const BOOKING_CONV = 'conv_booking';
const FRIEND_CONV = 'conv_friend';

let mockT = 0;
const msg = (id, conversationId, senderId, extra = {}) => ({
  _id: id,
  conversationId,
  senderId,
  senderRole: 'owner',
  body: id,
  deliveredAt: null,
  readAt: null,
  createdAt: new Date(Date.now() - 60000 + (mockT += 1000)),
  ...extra,
});

beforeEach(() => {
  mockT = 0;
  jest.clearAllMocks();
  mockStores.Conversation.length = 0;
  mockStores.Message.length = 0;
  mockStores.Conversation.push(
    { _id: BOOKING_CONV, friendChat: false, ownerId: OWNER, sitterId: SITTER, walkerId: null, lastMessageAt: new Date() },
    {
      _id: FRIEND_CONV,
      friendChat: true,
      participants: [
        { userId: FRIEND_A, userModel: 'Owner', unreadCount: 0 },
        { userId: FRIEND_B, userModel: 'Walker', unreadCount: 2 },
      ],
      lastMessageAt: new Date(),
    },
  );
  mockStores.Message.push(
    msg('m1', BOOKING_CONV, OWNER),
    msg('m2', BOOKING_CONV, OWNER),
    msg('m3', BOOKING_CONV, SITTER, { senderRole: 'sitter' }),
    msg('sys', BOOKING_CONV, OWNER, { senderRole: 'system' }),
    msg('f1', FRIEND_CONV, FRIEND_A),
    msg('f2', FRIEND_CONV, FRIEND_A),
  );
});

const byId = (id) => mockStores.Message.find((m) => m._id === id);

describe('markMessagesRead', () => {
  test('conversation de réservation : marque les messages de l’AUTRE partie et prévient l’expéditeur', async () => {
    const r = await receipts.markMessagesRead({ conversationId: BOOKING_CONV, readerId: SITTER });

    expect(r.count).toBe(2);
    expect(r.messageIds).toEqual(['m1', 'm2']);
    expect(byId('m1').readAt).toBeInstanceOf(Date);
    expect(byId('m2').readAt).toBeInstanceOf(Date);
    expect(byId('m1').deliveredAt).toBeInstanceOf(Date); // lu implique remis
    expect(byId('m3').readAt).toBeNull(); // mon propre message : intact
    expect(byId('sys').readAt).toBeNull(); // message système : intact

    expect(emitToUsersAllRoles).toHaveBeenCalledTimes(1);
    const [targets, event, payload] = emitToUsersAllRoles.mock.calls[0];
    expect(targets).toEqual([OWNER]);
    expect(event).toBe('message:read');
    expect(payload).toEqual({
      conversationId: BOOKING_CONV,
      readerId: SITTER,
      readAt: r.readAt,
      messageIds: ['m1', 'm2'],
    });
    // Groupé : deux updateMany (deliveredAt puis readAt), jamais un par message.
    expect(Message.updateMany).toHaveBeenCalledTimes(2);
  });

  test('idempotent : un second appel n’écrit rien et n’émet rien', async () => {
    await receipts.markMessagesRead({ conversationId: BOOKING_CONV, readerId: SITTER });
    const firstReadAt = byId('m1').readAt;
    jest.clearAllMocks();

    const r = await receipts.markMessagesRead({ conversationId: BOOKING_CONV, readerId: SITTER });
    expect(r.count).toBe(0);
    expect(Message.updateMany).not.toHaveBeenCalled();
    expect(emitToUsersAllRoles).not.toHaveBeenCalled();
    expect(byId('m1').readAt).toBe(firstReadAt);
  });

  test('conversation amie (participants[]) couverte', async () => {
    const r = await receipts.markMessagesRead({ conversationId: FRIEND_CONV, readerId: FRIEND_B });
    expect(r.messageIds).toEqual(['f1', 'f2']);
    expect(emitToUsersAllRoles.mock.calls[0][0]).toEqual([FRIEND_A]);
    expect(emitToUsersAllRoles.mock.calls[0][1]).toBe('message:read');
    expect(byId('f2').readAt).toBeInstanceOf(Date);
  });

  test('un non-participant ne marque rien', async () => {
    const r = await receipts.markMessagesRead({ conversationId: BOOKING_CONV, readerId: STRANGER });
    expect(r.count).toBe(0);
    expect(byId('m1').readAt).toBeNull();
    expect(emitToUsersAllRoles).not.toHaveBeenCalled();
  });

  test('l’expéditeur qui ouvre sa propre conversation ne marque pas ses messages', async () => {
    mockStores.Message.splice(0, mockStores.Message.length, msg('m1', BOOKING_CONV, OWNER));
    const r = await receipts.markMessagesRead({ conversationId: BOOKING_CONV, readerId: OWNER });
    expect(r.count).toBe(0);
    expect(byId('m1').readAt).toBeNull();
  });
});

describe('markMessagesDelivered', () => {
  test('pose deliveredAt et émet message:delivered à l’expéditeur', async () => {
    const r = await receipts.markMessagesDelivered({
      conversationId: BOOKING_CONV,
      messageIds: ['m2'],
      recipientId: SITTER,
    });
    expect(r.count).toBe(1);
    expect(byId('m2').deliveredAt).toBeInstanceOf(Date);
    expect(byId('m1').deliveredAt).toBeNull();
    const [targets, event, payload] = emitToUsersAllRoles.mock.calls[0];
    expect(targets).toEqual([OWNER]);
    expect(event).toBe('message:delivered');
    expect(payload).toEqual({
      conversationId: BOOKING_CONV,
      messageId: 'm2',
      messageIds: ['m2'],
      deliveredAt: r.deliveredAt,
    });
  });

  test('accusé redondant : une lecture, aucune écriture, aucune émission', async () => {
    await receipts.markMessagesDelivered({ conversationId: BOOKING_CONV, messageIds: ['m2'], recipientId: SITTER });
    jest.clearAllMocks();
    const r = await receipts.markMessagesDelivered({ conversationId: BOOKING_CONV, messageIds: ['m2'], recipientId: SITTER });
    expect(r.count).toBe(0);
    expect(Message.find).toHaveBeenCalledTimes(1);
    expect(Message.updateMany).not.toHaveBeenCalled();
    expect(emitToUsersAllRoles).not.toHaveBeenCalled();
  });

  test('on n’accuse pas réception de son propre message, ni sans être participant', async () => {
    const own = await receipts.markMessagesDelivered({ conversationId: BOOKING_CONV, messageIds: ['m1'], recipientId: OWNER });
    expect(own.count).toBe(0);
    const stranger = await receipts.markMessagesDelivered({ conversationId: BOOKING_CONV, messageIds: ['m1'], recipientId: STRANGER });
    expect(stranger.count).toBe(0);
    expect(byId('m1').deliveredAt).toBeNull();
    expect(emitToUsersAllRoles).not.toHaveBeenCalled();
  });

  test('conversation amie + plusieurs ids en un seul updateMany', async () => {
    const r = await receipts.markMessagesDelivered({
      conversationId: FRIEND_CONV,
      messageIds: ['f1', 'f2'],
      recipientId: FRIEND_B,
    });
    expect(r.count).toBe(2);
    expect(Message.updateMany).toHaveBeenCalledTimes(1);
    expect(emitToUsersAllRoles).toHaveBeenCalledTimes(1);
    expect(emitToUsersAllRoles.mock.calls[0][2].messageIds.sort()).toEqual(['f1', 'f2']);
  });
});

describe('markDeliveredForConversations (rattrapage à la lecture de la liste)', () => {
  test('un find + un updateMany pour toutes les conversations, un événement par expéditeur', async () => {
    const r = await receipts.markDeliveredForConversations({
      conversationIds: [BOOKING_CONV, FRIEND_CONV],
      recipientId: SITTER,
    });
    // m1, m2 (réservation) ; f1, f2 ne sont PAS de SITTER donc comptent aussi
    // comme « autre partie » — c'est la liste de l'appelant qui borne les ids.
    expect(r.count).toBe(4);
    expect(Message.find).toHaveBeenCalledTimes(1);
    expect(Message.updateMany).toHaveBeenCalledTimes(1);
    expect(emitToUsersAllRoles).toHaveBeenCalledTimes(2);
    expect(byId('m3').deliveredAt).toBeNull();
    expect(byId('sys').deliveredAt).toBeNull();
  });

  test('rien à faire → rien écrit', async () => {
    const r = await receipts.markDeliveredForConversations({ conversationIds: [], recipientId: SITTER });
    expect(r.count).toBe(0);
    expect(Message.find).not.toHaveBeenCalled();
  });
});

describe('lastMessageReceipts + receiptStatusOf', () => {
  test('statut du dernier message et « le mien ? »', async () => {
    byId('m2').deliveredAt = new Date();
    mockStores.Message.splice(mockStores.Message.findIndex((m) => m._id === 'm3'), 1);
    mockStores.Message.splice(mockStores.Message.findIndex((m) => m._id === 'sys'), 1);
    // En production `lastMessageAt` est posé au moment de l'envoi du dernier message.
    mockStores.Conversation.find((c) => c._id === BOOKING_CONV).lastMessageAt = byId('m2').createdAt;
    mockStores.Conversation.find((c) => c._id === FRIEND_CONV).lastMessageAt = byId('f2').createdAt;
    const map = await receipts.lastMessageReceipts({
      conversations: mockStores.Conversation,
      userId: OWNER,
    });
    expect(Message.find).toHaveBeenCalledTimes(1);
    expect(map.get(BOOKING_CONV)).toMatchObject({
      lastMessageId: 'm2',
      lastMessageMine: true,
      lastMessageStatus: 'delivered',
    });
    expect(map.get(FRIEND_CONV)).toMatchObject({ lastMessageId: 'f2', lastMessageMine: false, lastMessageStatus: 'sent' });
  });

  test('receiptStatusOf', () => {
    expect(receipts.receiptStatusOf({})).toBe('sent');
    expect(receipts.receiptStatusOf({ deliveredAt: new Date() })).toBe('delivered');
    expect(receipts.receiptStatusOf({ deliveredAt: new Date(), readAt: new Date() })).toBe('read');
    expect(receipts.receiptStatusOf(null)).toBeNull();
  });
});
