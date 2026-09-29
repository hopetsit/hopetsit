// v599 (ZOE, 29/09/2026) — point vert « En ligne » et notifications.
//  1. Présence : un socket en ARRIÈRE-PLAN (presence:state foreground=false) ou
//     muet depuis > 2 min n'est plus « en ligne » ; la conversation « ouverte »
//     se voit dans la salle du fil.
//  2. Notifications : un message de chat pousse UNE notification par
//     conversation (Android tag/collapseKey, iOS apns-collapse-id/thread-id)
//     et RIEN si le destinataire a la conversation ouverte à l'écran.
// Sans base, sans Firebase, sans réseau.

process.env.NODE_ENV = 'test';

describe('emitter — présence réelle (v599)', () => {
  const emitter = require('../src/sockets/emitter');
  const now = Date.now();

  test('socket tout neuf (pas encore de signe) = présent', () => {
    expect(emitter.isSocketPresent({ data: {} }, now)).toBe(true);
  });
  test('socket actif il y a 30 s = présent ; muet depuis 3 min = absent', () => {
    expect(emitter.isSocketPresent({ data: { lastActiveAt: now - 30 * 1000 } }, now)).toBe(true);
    expect(emitter.isSocketPresent({ data: { lastActiveAt: now - 3 * 60 * 1000 } }, now)).toBe(false);
  });
  test('app en arrière-plan = absent même si le socket vient de parler', () => {
    expect(emitter.isSocketPresent({ data: { foreground: false, lastActiveAt: now } }, now)).toBe(false);
    expect(emitter.isSocketPresent({ data: { foreground: true, lastActiveAt: now } }, now)).toBe(true);
  });
  test('markSocketActivity pose lastActiveAt', () => {
    const s = { data: { lastActiveAt: 1 } };
    emitter.markSocketActivity(s);
    expect(s.data.lastActiveAt).toBeGreaterThan(now - 1000);
  });

  describe('getOnlineUserIds / isConversationOpenFor avec un faux io', () => {
    const sockets = [
      { id: 'a', data: { user: { id: 'D1', role: 'owner' }, foreground: false, lastActiveAt: now } }, // Daniel en arrière-plan
      { id: 'b', data: { user: { id: 'J1', role: 'owner' }, foreground: true, lastActiveAt: now, openConversationId: 'F' } }, // John dans le fil F
      { id: 'c', data: { user: { id: 'L1', role: 'sitter' }, lastActiveAt: now - 10 * 60 * 1000 } }, // Léa muette depuis 10 min
    ];
    const fakeIo = {
      fetchSockets: async () => sockets,
      in: (room) => ({ fetchSockets: async () => (room === 'F' ? [sockets[1]] : []) }),
    };
    beforeAll(() => emitter.setSocketServer(fakeIo));
    afterAll(() => emitter.setSocketServer(null));

    test('seul John est en ligne', async () => {
      const ids = await emitter.getOnlineUserIds();
      expect([...ids]).toEqual(['J1']);
      expect(await emitter.isUserOnline('D1')).toBe(false);
    });
    test('la conversation F est ouverte chez John, pas chez Daniel ni pour un autre fil', async () => {
      expect(await emitter.isConversationOpenFor('F', ['J1', 'J2'])).toBe(true);
      expect(await emitter.isConversationOpenFor('F', ['D1', 'D2', 'D3'])).toBe(false);
      expect(await emitter.isConversationOpenFor('A', ['J1'])).toBe(false);
    });
  });
});

describe('notificationSender — une notification par conversation (v599)', () => {
  const mockUser = {
    _id: '64b000000000000000000001', email: 'camille@example.com', appLocale: 'fr', language: 'French',
    fcmTokens: ['tok-1'], name: 'Camille', notificationPrefs: null,
  };
  const mkModel = () => {
    const chain = (value) => ({ select: () => ({ lean: async () => value }) });
    return { modelName: 'Mock', findById: jest.fn(() => chain(mockUser)), find: jest.fn(() => chain([mockUser])), findByIdAndUpdate: jest.fn(async () => null) };
  };
  const mockSendMulticast = jest.fn(async () => ({ successCount: 1, failureCount: 0, responses: [] }));
  let openFor = false;
  beforeAll(() => {
    jest.resetModules();
    jest.doMock('../src/models/Owner', () => mkModel());
    jest.doMock('../src/models/Sitter', () => mkModel());
    jest.doMock('../src/models/Walker', () => mkModel());
    jest.doMock('../src/models/Message', () => ({
      findById: jest.fn(() => ({ select: () => ({ lean: async () => ({ senderId: 'x', senderRole: 'owner' }) }) })),
    }));
    jest.doMock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ sendEachForMulticast: mockSendMulticast }) }));
    jest.doMock('../src/utils/encryption', () => ({ decrypt: (v) => v }));
    jest.doMock('../src/services/notificationService', () => ({
      createNotificationSafe: jest.fn(async () => ({ _id: '64b0000000000000000000aa', createdAt: new Date() })),
      getUnreadCount: jest.fn(async () => 1),
    }));
    jest.doMock('../src/sockets/emitter', () => ({
      emitToUser: jest.fn(),
      isUserOnline: async () => false,
      isConversationOpenFor: async () => openFor,
    }));
    jest.doMock('../src/services/emailService', () => {
      const actual = jest.requireActual('../src/services/emailService');
      return { ...actual, sendEmail: jest.fn(async () => ({ messageId: 'mock' })) };
    });
  });

  test('NEW_MESSAGE : Android tag + collapseKey, iOS apns-collapse-id + thread-id = conv:<id>', async () => {
    openFor = false;
    const { sendNotification } = require('../src/services/notificationSender');
    await sendNotification({
      userId: mockUser._id, role: 'owner', type: 'NEW_MESSAGE',
      data: { conversationId: 'F', messageId: 'm1', senderName: 'John', preview: 'Coucou' },
    });
    expect(mockSendMulticast).toHaveBeenCalled();
    const payload = mockSendMulticast.mock.calls[0][0];
    expect(payload.android.collapseKey).toBe('conv:F');
    expect(payload.android.notification.tag).toBe('conv:F');
    expect(payload.apns.headers['apns-collapse-id']).toBe('conv:F');
    expect(payload.apns.payload.aps['thread-id']).toBe('conv:F');
  });

  test('NEW_MESSAGE avec la conversation OUVERTE chez le destinataire : aucun push, aucun e-mail', async () => {
    mockSendMulticast.mockClear();
    openFor = true;
    const { sendNotification } = require('../src/services/notificationSender');
    const { sendEmail } = require('../src/services/emailService');
    sendEmail.mockClear();
    await sendNotification({
      userId: mockUser._id, role: 'owner', type: 'NEW_MESSAGE',
      data: { conversationId: 'F', messageId: 'm2', senderName: 'John', preview: 'Encore' },
    });
    expect(mockSendMulticast).not.toHaveBeenCalled();
    expect(sendEmail).not.toHaveBeenCalled();
  });

  test('un autre type (réservation) ne porte pas de collapse par conversation', async () => {
    mockSendMulticast.mockClear();
    openFor = true;
    const { sendNotification } = require('../src/services/notificationSender');
    await sendNotification({
      userId: mockUser._id, role: 'owner', type: 'BOOKING_ACCEPTED',
      data: { bookingId: 'b1', conversationId: 'F' },
    });
    if (mockSendMulticast.mock.calls.length) {
      const payload = mockSendMulticast.mock.calls[0][0];
      expect(payload.android.collapseKey).toBeUndefined();
    }
  });
});
