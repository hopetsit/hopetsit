// v569 — suppression d'une conversation + synchro multi-appareils.
// Sans base ni socket réels : Conversation / Message sont un magasin en
// mémoire, l'émetteur socket un espion.
//
// Ce qui est vérifié :
//   - l'événement `conversation:deleted` part vers MES rooms (et uniquement
//     les miennes), via le même helper que `message:read` ;
//   - seul un participant peut supprimer (403 sinon, 404 si inconnue) ;
//   - c'est un masquage PAR UTILISATEUR (clearedFor), pas une suppression
//     pour les deux : les messages restent tant que l'autre n'a pas masqué ;
//   - idempotent : rappeler la suppression ne duplique rien et ne casse rien.

process.env.NODE_ENV = 'test';

const mockStores = { Conversation: [], Message: [] };

const mockModel = (name) => ({
  findById: jest.fn(async (id) =>
    mockStores[name].find((d) => String(d._id) === String(id)) || null),
  updateOne: jest.fn(async (filter, update) => {
    const doc = mockStores[name].find((d) => String(d._id) === String(filter._id));
    if (!doc) return { modifiedCount: 0 };
    const add = (update.$addToSet || {});
    for (const [field, value] of Object.entries(add)) {
      doc[field] = Array.isArray(doc[field]) ? doc[field] : [];
      if (!doc[field].some((v) => String(v) === String(value))) doc[field].push(value);
    }
    Object.assign(doc, update.$set || {});
    return { modifiedCount: 1 };
  }),
  deleteOne: jest.fn(async (filter) => {
    const before = mockStores[name].length;
    mockStores[name] = mockStores[name].filter(
      (d) => String(d._id) !== String(filter._id));
    return { deletedCount: before - mockStores[name].length };
  }),
  deleteMany: jest.fn(async (filter) => {
    const before = mockStores[name].length;
    mockStores[name] = mockStores[name].filter(
      (d) => String(d.conversationId) !== String(filter.conversationId));
    return { deletedCount: before - mockStores[name].length };
  }),
});

jest.mock('../src/models/Conversation', () => mockModel('Conversation'));
jest.mock('../src/models/Message', () => mockModel('Message'));
jest.mock('../src/sockets/emitter', () => ({ emitToUsersAllRoles: jest.fn(() => 1) }));
jest.mock('../src/utils/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const { emitToUsersAllRoles } = require('../src/sockets/emitter');
const {
  deleteConversationForUser,
} = require('../src/services/conversationDeleteService');

const OWNER = 'owner_1';
const SITTER = 'sitter_1';
const FRIEND_A = 'owner_a';
const FRIEND_B = 'walker_b';
const STRANGER = 'owner_x';

const CONV = 'conv_1';
const FRIEND_CONV = 'conv_friend';

const seed = () => {
  mockStores.Conversation = [
    { _id: CONV, ownerId: OWNER, sitterId: SITTER, clearedFor: [] },
    {
      _id: FRIEND_CONV,
      friendChat: true,
      participants: [
        { userId: FRIEND_A, userModel: 'Owner' },
        { userId: FRIEND_B, userModel: 'Walker' },
      ],
      clearedFor: [],
    },
  ];
  mockStores.Message = [
    { _id: 'm1', conversationId: CONV, body: 'bonjour' },
    { _id: 'm2', conversationId: CONV, body: 'salut' },
    { _id: 'm3', conversationId: FRIEND_CONV, body: 'coucou' },
  ];
};

const convOf = (id) => mockStores.Conversation.find((c) => String(c._id) === id);

beforeEach(() => {
  jest.clearAllMocks();
  seed();
});

describe('DELETE conversation — masquage par utilisateur', () => {
  test('supprimer = me masquer la conversation, sans toucher aux messages', async () => {
    const out = await deleteConversationForUser({
      conversationId: CONV, userId: OWNER,
    });
    expect(out).toEqual({ deleted: true, conversationId: CONV });
    expect(out.hardDeleted).toBeUndefined();
    // la conversation existe toujours (l'autre garde sa copie)
    expect(convOf(CONV)).toBeTruthy();
    expect(convOf(CONV).clearedFor.map(String)).toEqual([OWNER]);
    // les messages ne sont PAS supprimés
    expect(mockStores.Message.filter((m) => m.conversationId === CONV)).toHaveLength(2);
  });

  test('quand les DEUX ont masqué → purge réelle (messages + conversation)', async () => {
    await deleteConversationForUser({ conversationId: CONV, userId: OWNER });
    const out = await deleteConversationForUser({ conversationId: CONV, userId: SITTER });
    expect(out).toEqual({ deleted: true, hardDeleted: true, conversationId: CONV });
    expect(convOf(CONV)).toBeUndefined();
    expect(mockStores.Message.filter((m) => m.conversationId === CONV)).toHaveLength(0);
    // la conversation amie n'a pas été touchée
    expect(convOf(FRIEND_CONV)).toBeTruthy();
    expect(mockStores.Message.filter((m) => m.conversationId === FRIEND_CONV)).toHaveLength(1);
  });

  test('chat ami (participants[]) : le participant peut supprimer', async () => {
    const out = await deleteConversationForUser({
      conversationId: FRIEND_CONV, userId: FRIEND_B,
    });
    expect(out.deleted).toBe(true);
    expect(convOf(FRIEND_CONV).clearedFor.map(String)).toEqual([FRIEND_B]);
  });
});

describe('DELETE conversation — autorisation', () => {
  test('non-participant → 403, rien de masqué, aucun événement', async () => {
    await expect(
      deleteConversationForUser({ conversationId: CONV, userId: STRANGER }),
    ).rejects.toMatchObject({ status: 403 });
    expect(convOf(CONV).clearedFor).toHaveLength(0);
    expect(emitToUsersAllRoles).not.toHaveBeenCalled();
  });

  test('non-participant sur un chat ami → 403', async () => {
    await expect(
      deleteConversationForUser({ conversationId: FRIEND_CONV, userId: STRANGER }),
    ).rejects.toMatchObject({ status: 403 });
    expect(emitToUsersAllRoles).not.toHaveBeenCalled();
  });

  test('conversation inconnue → 404, aucun événement', async () => {
    await expect(
      deleteConversationForUser({ conversationId: 'nope', userId: OWNER }),
    ).rejects.toMatchObject({ status: 404 });
    expect(emitToUsersAllRoles).not.toHaveBeenCalled();
  });

  test('identifiants manquants → 400', async () => {
    await expect(
      deleteConversationForUser({ conversationId: '', userId: OWNER }),
    ).rejects.toMatchObject({ status: 400 });
    await expect(
      deleteConversationForUser({ conversationId: CONV, userId: '' }),
    ).rejects.toMatchObject({ status: 400 });
    expect(emitToUsersAllRoles).not.toHaveBeenCalled();
  });
});

describe('DELETE conversation — synchro de MES appareils', () => {
  test('conversation:deleted { conversationId } émis à MOI seul', async () => {
    await deleteConversationForUser({ conversationId: CONV, userId: OWNER });
    expect(emitToUsersAllRoles).toHaveBeenCalledTimes(1);
    const [userIds, event, payload] = emitToUsersAllRoles.mock.calls[0];
    // mes rooms, pas celles de l'autre partie : elle garde sa conversation
    expect(userIds).toEqual([OWNER]);
    expect(userIds).not.toContain(SITTER);
    expect(event).toBe('conversation:deleted');
    expect(payload.conversationId).toBe(CONV);
    expect(typeof payload.at).toBe('string');
  });

  test('purge finale : l\'événement part vers celui qui supprime', async () => {
    await deleteConversationForUser({ conversationId: CONV, userId: OWNER });
    emitToUsersAllRoles.mockClear();
    await deleteConversationForUser({ conversationId: CONV, userId: SITTER });
    expect(emitToUsersAllRoles).toHaveBeenCalledTimes(1);
    expect(emitToUsersAllRoles.mock.calls[0][0]).toEqual([SITTER]);
  });

  test('un émetteur en panne ne fait pas échouer la suppression', async () => {
    emitToUsersAllRoles.mockImplementationOnce(() => { throw new Error('socket down'); });
    const out = await deleteConversationForUser({ conversationId: CONV, userId: OWNER });
    expect(out.deleted).toBe(true);
    expect(convOf(CONV).clearedFor.map(String)).toEqual([OWNER]);
  });
});

describe('DELETE conversation — idempotence', () => {
  test('deux fois le même utilisateur : pas de doublon, même réponse', async () => {
    const first = await deleteConversationForUser({ conversationId: CONV, userId: OWNER });
    const second = await deleteConversationForUser({ conversationId: CONV, userId: OWNER });
    expect(first).toEqual(second);
    expect(convOf(CONV).clearedFor.map(String)).toEqual([OWNER]);
    expect(mockStores.Message.filter((m) => m.conversationId === CONV)).toHaveLength(2);
    // chaque appel resynchronise mes appareils (un appareil hors ligne se recale)
    expect(emitToUsersAllRoles).toHaveBeenCalledTimes(2);
  });

  test('après la purge, un nouvel appel répond 404 (plus rien à supprimer)', async () => {
    await deleteConversationForUser({ conversationId: CONV, userId: OWNER });
    await deleteConversationForUser({ conversationId: CONV, userId: SITTER });
    await expect(
      deleteConversationForUser({ conversationId: CONV, userId: OWNER }),
    ).rejects.toMatchObject({ status: 404 });
  });
});
