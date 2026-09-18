/**
 * v566 — audit des notifications : sendNotification de bout en bout, SANS base,
 * SANS Firebase, SANS SMTP (tout est simulé ; aucun envoi réel).
 */
const mockUser = {
  _id: '64b000000000000000000001',
  email: 'camille@example.com',
  appLocale: 'de',
  language: 'French',
  fcmTokens: ['tok-1'],
  name: 'Camille',
  notificationPrefs: null,
};
const mkModel = () => {
  const chain = (value) => ({ select: () => ({ lean: async () => value }) });
  return {
    modelName: 'Mock',
    findById: jest.fn(() => chain(mockUser)),
    find: jest.fn(() => chain([mockUser])),
    findByIdAndUpdate: jest.fn(async () => null),
  };
};
jest.mock('../src/models/Owner', () => mkModel());
jest.mock('../src/models/Sitter', () => mkModel());
jest.mock('../src/models/Walker', () => mkModel());
jest.mock('../src/models/Message', () => ({
  findById: jest.fn(() => ({ select: () => ({ lean: async () => ({ senderId: 'x', senderRole: 'owner' }) }) })),
}), { virtual: false });
const mockSendMulticast = jest.fn(async () => ({ successCount: 1, failureCount: 0, responses: [] }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ sendEachForMulticast: mockSendMulticast }) }));
jest.mock('../src/utils/encryption', () => ({ decrypt: (v) => v }));
jest.mock('../src/services/notificationService', () => ({
  createNotificationSafe: jest.fn(async () => ({ _id: '64b0000000000000000000aa', createdAt: new Date() })),
  getUnreadCount: jest.fn(async () => 4),
}));
const mockIsOnline = jest.fn(async () => false);
jest.mock('../src/sockets/emitter', () => ({ emitToUser: jest.fn(), isUserOnline: (...a) => mockIsOnline(...a) }));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async () => ({ messageId: 'mock' })) };
});

const { sendEmail } = require('../src/services/emailService');
const { createNotificationSafe } = require('../src/services/notificationService');
const { emitToUser } = require('../src/sockets/emitter');
const { sendNotification, categoryForType } = require('../src/services/notificationSender');

const CONV = 'c'.repeat(24);
beforeEach(() => {
  jest.clearAllMocks();
  mockUser.notificationPrefs = null;
  mockUser.fcmTokens = ['tok-1'];
  mockUser.fcmDevices = [];
  mockIsOnline.mockResolvedValue(false);
});

describe('sendNotification', () => {
  test('3 canaux, langue du compte (appLocale), lien www, son grenouille par défaut', async () => {
    await sendNotification({
      userId: mockUser._id, role: 'owner', type: 'NEW_MESSAGE',
      data: { conversationId: CONV, senderName: 'Alex', preview: 'Hallo' },
    });
    expect(createNotificationSafe).toHaveBeenCalledTimes(1);
    expect(emitToUser).toHaveBeenCalledWith('owner', mockUser._id, 'notification.new', expect.any(Object));
    const msg = mockSendMulticast.mock.calls[0][0];
    expect(msg.notification.title).toContain('Alex');
    expect(msg.notification.title).not.toMatch(/Nouveau message/); // allemand, pas le repli fr
    expect(msg.data.route).toBe(`/chat/${CONV}`);
    expect(msg.data.notificationId).toBe('64b0000000000000000000aa');
    expect(msg.data.sound).toBe('frog');
    expect(msg.android.priority).toBe('high');
    expect(msg.android.notification.channelId).toBe('hopetsit_frog_v2');
    expect(msg.apns.payload.aps.sound).toBe('frog.caf');
    expect(msg.apns.headers['apns-priority']).toBe('10');
    const [to, subject, text, html] = sendEmail.mock.calls[0];
    expect(to).toBe('camille@example.com');
    expect(subject).toBeTruthy();
    expect(text).toContain(`https://www.hopetsit.com/chat/${CONV}`);
    expect(html).toContain(`href="https://www.hopetsit.com/chat/${CONV}"`);
    expect(html).toContain('name="viewport"');
    expect(html).toContain('Benachrichtigungen'); // pied de page traduit
  });

  test('variables utilisateur échappées dans le HTML de l\'e-mail', async () => {
    await sendNotification({
      userId: mockUser._id, role: 'owner', type: 'NEW_MESSAGE',
      data: { conversationId: CONV, senderName: 'Alex', preview: '<a href="https://evil.example">payer</a>' },
    });
    const html = sendEmail.mock.calls[0][3];
    expect(html).not.toContain('<a href="https://evil.example">');
    expect(html).toContain('&lt;a href=');
    // le push, lui, garde le texte brut
    expect(mockSendMulticast.mock.calls[0][0].notification.body).toContain('<a href=');
  });

  test('NEW_MESSAGE sans senderName → jamais de titre troué', async () => {
    await sendNotification({
      userId: mockUser._id, role: 'owner', type: 'NEW_MESSAGE',
      data: { conversationId: CONV, messageId: 'm'.repeat(24).replace(/m/g, 'a'), preview: 'Hi' },
    });
    const title = mockSendMulticast.mock.calls[0][0].notification.title;
    expect(title.trim().endsWith('Camille') || title.includes('HoPetSit')).toBe(true);
  });

  test('catégorie coupée → ni push ni e-mail, in-app conservée', async () => {
    mockUser.notificationPrefs = { sound: 'bark', categories: { messages: false } };
    await sendNotification({
      userId: mockUser._id, role: 'owner', type: 'NEW_MESSAGE',
      data: { conversationId: CONV, senderName: 'Alex', preview: 'x' },
    });
    expect(createNotificationSafe).toHaveBeenCalledTimes(1);
    expect(mockSendMulticast).not.toHaveBeenCalled();
    expect(sendEmail).not.toHaveBeenCalled();
  });

  test('message : e-mail seulement si le destinataire est HORS LIGNE ; paiement : toujours', async () => {
    mockIsOnline.mockResolvedValue(true);
    await sendNotification({
      userId: mockUser._id, role: 'owner', type: 'NEW_MESSAGE',
      data: { conversationId: CONV, senderName: 'Alex', preview: 'x' },
    });
    expect(mockSendMulticast).toHaveBeenCalledTimes(1);
    expect(sendEmail).not.toHaveBeenCalled();
    await sendNotification({
      userId: mockUser._id, role: 'owner', type: 'wallet_credited', data: { amount: '24,00', currency: 'EUR' },
    });
    expect(sendEmail).toHaveBeenCalledTimes(1);
  });

  test('son silencieux / vibreur → pas de champ sound APNs, canal dédié', async () => {
    mockUser.notificationPrefs = { sound: 'silent', categories: {} };
    await sendNotification({ userId: mockUser._id, role: 'owner', type: 'booking_new', data: {} });
    const msg = mockSendMulticast.mock.calls[0][0];
    expect(msg.apns.payload.aps.sound).toBeUndefined();
    expect(msg.android.notification.channelId).toBe('hopetsit_silent_v2');
  });

  test('type sans gabarit → rien n\'est envoyé', async () => {
    await sendNotification({ userId: mockUser._id, role: 'owner', type: 'does_not_exist', data: {} });
    expect(createNotificationSafe).not.toHaveBeenCalled();
    expect(mockSendMulticast).not.toHaveBeenCalled();
  });

  test('catégories du contrat §2', () => {
    expect(categoryForType('handover_picked_up')).toBe('bookings');
    expect(categoryForType('live_session_ended')).toBe('live');
    expect(categoryForType('kyc_payment_succeeded')).toBe('payments');
    expect(categoryForType('sos_pet_nearby')).toBe('pawmap');
    expect(categoryForType('unknown_type')).toBe('bookings');
  });
});

describe('badge chiffré iOS (build ≥ 566 seulement)', () => {
  const { sendBadgeSync } = require('../src/services/notificationSender');
  const setDevices = () => {
    mockUser.fcmTokens = ['ios-566', 'ios-565', 'android-566', 'legacy'];
    mockUser.fcmDevices = [
      { token: 'ios-566', platform: 'ios', appBuild: 566 },
      { token: 'ios-565', platform: 'ios', appBuild: 565 },
      { token: 'android-566', platform: 'android', appBuild: 566 },
      // 'legacy' : jeton sans fiche d'appareil (enregistré avant la v565)
    ];
  };

  test('jeton iOS 566 → aps.badge = non lues ; iOS 565, Android et anciens jetons → pas de badge', async () => {
    setDevices();
    await sendNotification({ userId: mockUser._id, role: 'owner', type: 'booking_new', data: {} });
    expect(mockSendMulticast).toHaveBeenCalledTimes(2);
    const calls = mockSendMulticast.mock.calls.map((c) => c[0]);
    const withBadge = calls.find((m) => m.apns.payload.aps.badge !== undefined);
    const without = calls.find((m) => m.apns.payload.aps.badge === undefined);
    expect(withBadge.tokens).toEqual(['ios-566']);
    expect(withBadge.apns.payload.aps.badge).toBe(4);
    expect(withBadge.apns.payload.aps.sound).toBe('frog.caf');
    expect(without.tokens.sort()).toEqual(['android-566', 'ios-565', 'legacy']);
  });

  test('aucun jeton iOS 566 → un seul lot, sans badge, sans compter les non lues', async () => {
    const { getUnreadCount } = require('../src/services/notificationService');
    mockUser.fcmTokens = ['ios-565'];
    mockUser.fcmDevices = [{ token: 'ios-565', platform: 'ios', appBuild: 565 }];
    await sendNotification({ userId: mockUser._id, role: 'owner', type: 'booking_new', data: {} });
    expect(mockSendMulticast).toHaveBeenCalledTimes(1);
    expect(mockSendMulticast.mock.calls[0][0].apns.payload.aps.badge).toBeUndefined();
    expect(getUnreadCount).not.toHaveBeenCalled();
  });

  test('un appareil désinscrit (fiche sans jeton actif) ne reçoit rien', async () => {
    mockUser.fcmTokens = ['tok-1'];
    mockUser.fcmDevices = [{ token: 'gone', platform: 'ios', appBuild: 566 }];
    await sendNotification({ userId: mockUser._id, role: 'owner', type: 'booking_new', data: {} });
    expect(mockSendMulticast).toHaveBeenCalledTimes(1);
    expect(mockSendMulticast.mock.calls[0][0].tokens).toEqual(['tok-1']);
  });

  test('sendBadgeSync : push « badge seul » aux seuls jetons iOS 566, sans bannière', async () => {
    setDevices();
    await sendBadgeSync({ role: 'owner', userId: mockUser._id, unreadCount: 0 });
    expect(mockSendMulticast).toHaveBeenCalledTimes(1);
    const msg = mockSendMulticast.mock.calls[0][0];
    expect(msg.tokens).toEqual(['ios-566']);
    expect(msg.notification).toBeUndefined();
    expect(msg.apns.payload.aps).toEqual({ badge: 0 });
    expect(msg.data.type).toBe('badge_sync');
  });

  test('sendBadgeSync : rien à envoyer sans jeton iOS 566', async () => {
    mockUser.fcmTokens = ['android-566'];
    mockUser.fcmDevices = [{ token: 'android-566', platform: 'android', appBuild: 566 }];
    const r = await sendBadgeSync({ role: 'owner', userId: mockUser._id, unreadCount: 2 });
    expect(r.skipped).toBe(true);
    expect(mockSendMulticast).not.toHaveBeenCalled();
  });
});

describe('buildAppRoute', () => {
  const { buildAppRoute, BASE_URL } = require('../src/utils/emailLinkBuilder');
  test('liens sur www + partage en direct routé', () => {
    expect(BASE_URL).toBe('https://www.hopetsit.com');
    expect(buildAppRoute('live_still_active', {})).toBe('/friends/live');
    expect(buildAppRoute('live_session_ended', {})).toBe('/friends/live');
    expect(buildAppRoute('handover_returned', { bookingId: 'b'.repeat(24).replace(/b/g, 'b') })).toMatch(/^\/bookings\//);
  });
});
