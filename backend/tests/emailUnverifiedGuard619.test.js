/**
 * 619 (BOB, 19/10/2026) — aucun e-mail de notification à un compte récent jamais
 * vérifié (retours « Address not found » vus par Daniel le 18/10) ; in-app et
 * push inchangés. Comptes d'avant la v565, frère vérifié ou coupe-circuit :
 * l'e-mail part comme avant.
 */
const mockUser = {
  _id: '64b000000000000000000001', email: 'anthony@example.com', appLocale: 'en', language: 'English',
  fcmTokens: ['tok-1'], fcmDevices: [], name: 'Neo', notificationPrefs: null,
  verified: false, createdAt: new Date('2026-10-12T10:00:00Z'),
};
const mockExists = jest.fn(async () => null);
const mkModel = () => {
  const chain = (value) => ({ select: () => ({ lean: async () => value }) });
  return {
    modelName: 'Mock',
    findById: jest.fn(() => chain(mockUser)),
    find: jest.fn(() => chain([mockUser])),
    findByIdAndUpdate: jest.fn(async () => null),
    exists: (...a) => mockExists(...a),
  };
};
jest.mock('../src/models/Owner', () => mkModel());
jest.mock('../src/models/Sitter', () => mkModel());
jest.mock('../src/models/Walker', () => mkModel());
jest.mock('../src/models/Notification', () => ({ findOneAndUpdate: jest.fn(async () => null) }));
const mockSendMulticast = jest.fn(async () => ({ successCount: 1, failureCount: 0, responses: [] }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ sendEachForMulticast: mockSendMulticast }) }));
jest.mock('../src/utils/encryption', () => ({ decrypt: (v) => v }));
jest.mock('../src/services/notificationService', () => ({
  createNotificationSafe: jest.fn(async () => ({ _id: '64b0000000000000000000aa', createdAt: new Date() })),
  getUnreadCount: jest.fn(async () => 1),
}));
jest.mock('../src/sockets/emitter', () => ({ emitToUser: jest.fn(), isUserOnline: jest.fn(async () => false) }));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async () => ({ messageId: 'mock' })) };
});
const { sendEmail } = require('../src/services/emailService');
const { createNotificationSafe } = require('../src/services/notificationService');
const { sendNotification, unverifiedEmailBlocked } = require('../src/services/notificationSender');

const fire = () => sendNotification({ userId: mockUser._id, role: 'owner', type: 'kyc_verified', data: { kycStatus: 'verified' } });

describe('619 — e-mails de notification et comptes jamais vérifiés', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    delete process.env.EMAIL_UNVERIFIED_GUARD;
    mockUser.verified = false;
    mockUser.createdAt = new Date('2026-10-12T10:00:00Z');
    mockExists.mockImplementation(async () => null);
  });

  // 27/10 (SAM, décision de Daniel) — propriétaire venu de la pub : NON vérifié jusqu'à son clic,
  // mais ses e-mails (candidatures…) partent : c'est par eux qu'il revient choisir et payer.
  test('propriétaire venu de la pub (adLeadAt), non vérifié : l\'e-mail PART quand même', async () => {
    mockUser.adLeadAt = new Date('2026-10-23T10:00:00Z');
    try {
      await fire();
      expect(sendEmail).toHaveBeenCalledTimes(1);
      expect(await unverifiedEmailBlocked({ ...mockUser }, 'owner')).toBe(false);
      // le marqueur ne vaut que pour le rôle propriétaire
      expect(await unverifiedEmailBlocked({ ...mockUser }, 'sitter')).toBe(true);
    } finally { delete mockUser.adLeadAt; }
  });

  test('compte récent, jamais vérifié, aucun frère vérifié : in-app + push oui, e-mail NON', async () => {
    await fire();
    expect(createNotificationSafe).toHaveBeenCalledTimes(1);
    expect(mockSendMulticast).toHaveBeenCalledTimes(1);
    expect(sendEmail).not.toHaveBeenCalled();
    expect(mockExists).toHaveBeenCalledTimes(2); // les 2 modèles frères interrogés
  });

  test('compte vérifié : e-mail envoyé', async () => {
    mockUser.verified = true;
    await fire();
    expect(sendEmail).toHaveBeenCalledTimes(1);
    expect(mockExists).not.toHaveBeenCalled();
  });

  test('profil frère vérifié (un compte, trois profils) : e-mail envoyé', async () => {
    mockExists.mockImplementation(async () => ({ _id: 'x' }));
    await fire();
    expect(sendEmail).toHaveBeenCalledTimes(1);
  });

  test('compte d\'avant la v565 (18/09) : jamais bloqué', async () => {
    mockUser.createdAt = new Date('2026-08-01T10:00:00Z');
    await fire();
    expect(sendEmail).toHaveBeenCalledTimes(1);
    expect(mockExists).not.toHaveBeenCalled();
  });

  test('coupe-circuit EMAIL_UNVERIFIED_GUARD=off : e-mail envoyé', async () => {
    process.env.EMAIL_UNVERIFIED_GUARD = 'off';
    await fire();
    expect(sendEmail).toHaveBeenCalledTimes(1);
  });

  test('erreur base pendant le contrôle : dans le doute, l\'e-mail part', async () => {
    mockExists.mockImplementation(async () => { throw new Error('mongo down'); });
    expect(await unverifiedEmailBlocked(mockUser, 'owner')).toBe(false);
  });

  test('25/10 — alerte « nouvelle demande près de chez vous » : e-mail envoyé même non vérifié', async () => {
    await sendNotification({ userId: mockUser._id, role: 'sitter', type: 'new_request_nearby', data: { postId: '64b0000000000000000000bb' } });
    expect(mockSendMulticast).toHaveBeenCalledTimes(1);
    expect(sendEmail).toHaveBeenCalledTimes(1);
  });

  test('25/10 — coupe-circuit REQUEST_ALERT_EMAIL_UNVERIFIED=off : alerte bloquée comme avant', async () => {
    process.env.REQUEST_ALERT_EMAIL_UNVERIFIED = 'off';
    try {
      await sendNotification({ userId: mockUser._id, role: 'sitter', type: 'new_request_nearby', data: { postId: '64b0000000000000000000bb' } });
      expect(sendEmail).not.toHaveBeenCalled();
    } finally { delete process.env.REQUEST_ALERT_EMAIL_UNVERIFIED; }
  });

  // 10/11/2026 (BOB, « Oui, autorise » de Daniel) — la question « Êtes-vous toujours libre ? »
  // part aussi vers un gardien / promeneur à l'e-mail jamais validé : il a lui-même candidaté.
  // Même appel que le service sitterFree1011 : e-mail seul, gabarit « candidats ».
  const askFree = (role) => require('../src/services/notificationSender').sendEmailOnly({
    userId: mockUser._id, role, type: 'still_free_1011', templateType: 'application_new_2610',
    data: { postId: '64b0000000000000000000bb', title: 'Toujours libre ?', body: 'Question', emailSubject: 'Toujours libre ?' },
  });
  test('10/11 — « toujours libre ? » : e-mail envoyé à un gardien et à un promeneur non vérifiés', async () => {
    expect(await askFree('sitter')).toMatchObject({ sent: true });
    expect(sendEmail).toHaveBeenCalledTimes(1);
    expect(await askFree('walker')).toMatchObject({ sent: true });
    expect(sendEmail).toHaveBeenCalledTimes(2);
  });

  test('10/11 — « toujours libre ? » : jamais côté propriétaire non vérifié', async () => {
    expect(await askFree('owner')).toMatchObject({ sent: false, reason: 'email_blocked:unverified' });
    expect(sendEmail).not.toHaveBeenCalled();
  });

  test('10/11 — coupe-circuit SITTER_FREE_EMAIL_UNVERIFIED=off : question bloquée comme avant', async () => {
    process.env.SITTER_FREE_EMAIL_UNVERIFIED = 'off';
    try {
      expect(await askFree('sitter')).toMatchObject({ sent: false, reason: 'email_blocked:unverified' });
      expect(sendEmail).not.toHaveBeenCalled();
    } finally { delete process.env.SITTER_FREE_EMAIL_UNVERIFIED; }
  });
});
