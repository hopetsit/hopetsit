// v599 (ZOE, 29/09/2026) — « Lu » synchronisé partout : lire une conversation
// sur un appareil prévient mes autres appareils (3 rôles), passe en lu les
// entrées « Nouveau message » de la cloche pour ce fil, et remet le badge iOS.
// Sans base, sans socket réel, sans push.

process.env.NODE_ENV = 'test';

const mockNotifs = [];
const emitted = [];
const badgeSyncs = [];

jest.mock('../src/utils/identityGroup', () => ({
  identityGroup: async (id) => ({
    ids: id === 'D1' ? ['D1', 'D2', 'D3'] : [String(id)],
    set: new Set(id === 'D1' ? ['D1', 'D2', 'D3'] : [String(id)]),
    // 610 — profils de la personne (owner D1, sitter D2, walker D3).
    docs: id === 'D1'
      ? [{ id: 'D1', model: 'Owner' }, { id: 'D2', model: 'Sitter' }, { id: 'D3', model: 'Walker' }]
      : [],
  }),
}));
jest.mock('../src/models/Notification', () => ({
  find: jest.fn((q) => ({
    select: () => ({
      lean: async () => mockNotifs.filter((n) =>
        q.recipientId.$in.includes(n.recipientId)
        && q.type.$in.includes(n.type)
        && n.data && n.data.conversationId === q['data.conversationId']
        && n.readAt == null),
    }),
  })),
  // 610 — compteur par profil (syncPerson).
  countDocuments: jest.fn(async (q) => mockNotifs.filter((n) =>
    n.recipientId === q.recipientId && n.recipientRole === q.recipientRole && n.readAt == null).length),
  updateMany: jest.fn(async (q, u) => {
    let n = 0;
    for (const d of mockNotifs) {
      if (q._id.$in.map(String).includes(String(d._id))) { d.readAt = u.$set.readAt; n += 1; }
    }
    return { modifiedCount: n };
  }),
}));
jest.mock('../src/sockets/emitter', () => ({
  emitToUsersAllRoles: jest.fn((ids, event, payload) => { emitted.push({ ids, event, payload }); return ids.length; }),
  emitToUser: jest.fn((role, userId, event, payload) => { emitted.push({ role, userId, event, payload }); }),
}));
jest.mock('../src/services/notificationService', () => ({
  getUnreadCount: jest.fn(async () => 2),
}));
jest.mock('../src/services/notificationSender', () => ({
  sendBadgeSync: jest.fn(async (a) => { badgeSyncs.push(a); return { ok: true }; }),
}));
jest.mock('../src/utils/logger', () => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() }));
// v599 (29/09 08 h) — lire le fil annule l'e-mail différé « message non lu ».
const cancelled = [];
jest.mock('../src/services/chatUnreadEmailScheduler599', () => ({
  cancelUnreadEmail: jest.fn(async (a) => { cancelled.push(a); return { cancelled: 1 }; }),
}));

const { afterConversationRead } = require('../src/utils/chatReadSync599');

beforeEach(() => {
  mockNotifs.length = 0;
  emitted.length = 0;
  badgeSyncs.length = 0;
  mockNotifs.push(
    { _id: 'n1', recipientId: 'D2', recipientRole: 'sitter', type: 'NEW_MESSAGE', data: { conversationId: 'F' }, readAt: null },
    { _id: 'n2', recipientId: 'D1', recipientRole: 'owner', type: 'NEW_MESSAGE', data: { conversationId: 'F' }, readAt: null },
    { _id: 'n3', recipientId: 'D1', recipientRole: 'owner', type: 'NEW_MESSAGE', data: { conversationId: 'L' }, readAt: null }, // autre fil
    { _id: 'n4', recipientId: 'J1', recipientRole: 'owner', type: 'NEW_MESSAGE', data: { conversationId: 'F' }, readAt: null }, // autre personne
    { _id: 'n5', recipientId: 'D1', recipientRole: 'owner', type: 'BOOKING_ACCEPTED', data: { conversationId: 'F' }, readAt: null },
  );
});

test('lire F en tant que D1 prévient D1/D2/D3 et passe en lu les 2 entrées de cloche de F (pas L, pas J1, pas la réservation)', async () => {
  const r = await afterConversationRead({ conversationId: 'F', readerId: 'D1' });
  expect(r.bell).toBe(2);
  expect(r.emailCancelled).toBe(1);
  expect(cancelled).toEqual([{ conversationId: 'F', readerIds: ['D1', 'D2', 'D3'] }]);
  const self = emitted.find((e) => e.event === 'conversation:read:self');
  expect(self).toBeTruthy();
  expect(self.ids).toEqual(['D1', 'D2', 'D3']);
  expect(self.payload.conversationId).toBe('F');
  const byId = Object.fromEntries(mockNotifs.map((n) => [n._id, n]));
  expect(byId.n1.readAt).toBeTruthy();
  expect(byId.n2.readAt).toBeTruthy();
  expect(byId.n3.readAt).toBeNull();
  expect(byId.n4.readAt).toBeNull();
  expect(byId.n5.readAt).toBeNull();
  // 610 — notification.read émis UNE fois par profil de la personne, dans la
  // salle de CE profil, avec SON compteur et le total des 3 profils.
  const reads = emitted.filter((e) => e.event === 'notification.read');
  expect(reads.map((e) => `${e.role}:${e.userId}`).sort()).toEqual(['owner:D1', 'sitter:D2', 'walker:D3']);
  const owner = reads.find((e) => e.userId === 'D1');
  expect(owner.payload.ids.sort()).toEqual(['n1', 'n2']);
  expect(owner.payload.unreadCount).toBe(2); // n3 + n5 restent non lues côté propriétaire
  expect(reads.find((e) => e.userId === 'D2').payload.unreadCount).toBe(0);
  expect(owner.payload.totalUnreadCount).toBe(2);
  // badge iOS : une synchro pour la personne (total 2)
  expect(badgeSyncs).toHaveLength(1);
  expect(badgeSyncs[0].personUnreadCount).toBe(2);
});

test('sans entrée de cloche : seule l\'annonce « lu » part, rien ne casse', async () => {
  mockNotifs.length = 0;
  const r = await afterConversationRead({ conversationId: 'X', readerId: 'J1' });
  expect(r.bell).toBe(0);
  expect(emitted.filter((e) => e.event === 'conversation:read:self')).toHaveLength(1);
  expect(emitted.filter((e) => e.event === 'notification.read')).toHaveLength(0);
});

test('paramètres vides → rien', async () => {
  const r = await afterConversationRead({ conversationId: '', readerId: 'D1' });
  expect(r).toEqual({ notified: 0, bell: 0 });
  expect(emitted).toHaveLength(0);
});
