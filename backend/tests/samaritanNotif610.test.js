/**
 * 610 (ZOE, 04/10/2026) — notification « geste du bon Samaritain » : in-app +
 * push, JAMAIS d'e-mail (règle de Daniel), 9 langues, jamais « récompense ».
 * Même banc d'essai que notificationSender.test.js (tout simulé, aucun envoi).
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
// v599 — la cloche regroupe par conversation : modèle Notification simulé (aucune entrée existante).
jest.mock('../src/models/Notification', () => ({ findOneAndUpdate: jest.fn(async () => null) }));
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

// v599 (29/09 08 h) — l'e-mail d'un message de chat est DIFFÉRÉ 15 min : le
// planificateur (attente en base) est simulé ; on capture ce qu'il reçoit.
const scheduled = [];
jest.mock('../src/services/chatUnreadEmailScheduler599', () => {
  const actual = jest.requireActual('../src/services/chatUnreadEmailScheduler599');
  return {
    ...actual,
    scheduleUnreadEmail: jest.fn(async (a) => { scheduled.push(a); return { created: true }; }),
  };
});

const { sendEmail } = require('../src/services/emailService');
const { createNotificationSafe } = require('../src/services/notificationService');
const { emitToUser } = require('../src/sockets/emitter');
const { sendNotification, sendDeferredChatEmail, categoryForType } = require('../src/services/notificationSender');


const fs = require('fs');
const path = require('path');
const { buildAppRoute } = require('../src/utils/emailLinkBuilder');
const RID = 'a'.repeat(24);

beforeEach(() => {
  jest.clearAllMocks();
  mockUser.notificationPrefs = null;
  mockUser.fcmTokens = ['tok-1'];
  mockUser.fcmDevices = [];
  mockUser.appLocale = 'fr';
  mockIsOnline.mockResolvedValue(false);
});

describe('good_samaritan_premium', () => {
  test('in-app + push, aucun e-mail, texte français de REGLES_610', async () => {
    await sendNotification({
      userId: mockUser._id, role: 'owner', type: 'good_samaritan_premium',
      data: { reportId: RID, reportType: 'poison' },
    });
    expect(createNotificationSafe).toHaveBeenCalledTimes(1);
    expect(mockSendMulticast).toHaveBeenCalled();
    expect(sendEmail).not.toHaveBeenCalled();
    const msg = mockSendMulticast.mock.calls[0][0];
    expect(`${msg.notification.title} : ${msg.notification.body}`).toBe(
      "Geste du bon Samaritain : Ton signalement a protégé d'autres animaux. Premium offert pendant 24 h.",
    );
  });

  test('catégorie PawMap, lien vers l’alerte', () => {
    expect(categoryForType('good_samaritan_premium')).toBe('pawmap');
    expect(buildAppRoute('good_samaritan_premium', { reportId: RID })).toBe(`/alert/${RID}`);
  });

  test('présente dans les 9 langues, jamais le mot « récompense »', () => {
    const words = /r[ée]compense|reward|recompensa|belohnung|ricompensa|nagroda|보상|報酬|ご褒美/i;
    for (const l of ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      const j = JSON.parse(fs.readFileSync(path.join(__dirname, `../src/locales/${l}/notifications.json`), 'utf8'));
      const t = j.good_samaritan_premium;
      expect(t && t.title && t.body).toBeTruthy();
      expect(`${t.title} ${t.body}`).not.toMatch(words);
      expect(t.body).toMatch(/24/);
    }
  });
});
