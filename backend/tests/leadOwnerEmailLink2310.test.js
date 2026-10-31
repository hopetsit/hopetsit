/**
 * 23/10/2026 (BOB, accord de Daniel) — propriétaire créé par la pub à formulaire (AdLead
 * confirmé, mot de passe aléatoire) : le bouton de ses e-mails passe par
 * /posts/confirmer?l=<jeton>&next=<cible>, qui ouvre la session sans mot de passe.
 * Un propriétaire ordinaire garde le lien direct.
 */
const mockUser = {
  _id: '64b000000000000000000001', email: 'karine@example.com', appLocale: 'fr', language: 'French',
  fcmTokens: [], fcmDevices: [], name: 'Karine', notificationPrefs: null, verified: true,
};
const mkModel = () => {
  const chain = (value) => ({ select: () => ({ lean: async () => value }) });
  return { modelName: 'Mock', findById: jest.fn(() => chain(mockUser)), find: jest.fn(() => chain([mockUser])), findByIdAndUpdate: jest.fn(async () => null) };
};
jest.mock('../src/models/Owner', () => mkModel());
jest.mock('../src/models/Sitter', () => mkModel());
jest.mock('../src/models/Walker', () => mkModel());
jest.mock('../src/models/Notification', () => ({ findOneAndUpdate: jest.fn(async () => null) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }) }));
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
let leadFound = { _id: 'fdf72ce42f0a0580e128388e13149050' };
const mockFindOne = jest.fn(() => ({ select: () => ({ lean: async () => leadFound }) }));
jest.mock('../src/models/AdLead2210', () => ({ findOne: mockFindOne }));

const { sendEmail } = require('../src/services/emailService');
const { sendNotification } = require('../src/services/notificationSender');
const { BASE_URL, buildEmailRoute } = require('../src/utils/emailLinkBuilder');

const lastLink = () => {
  // sendEmail(email, subject, text, html) : le texte brut porte le lien en clair.
  const call = sendEmail.mock.calls[sendEmail.mock.calls.length - 1];
  const m = String(call[2] || call[3] || '').match(/https?:\/\/[^\s"<)]+/);
  return m ? m[0] : '';
};

describe('e-mail de candidature pour un propriétaire issu de la pub', () => {
  beforeEach(() => { sendEmail.mockClear(); mockFindOne.mockClear(); });

  test('le bouton passe par /posts/confirmer?l=<jeton>&next=/application/<id>', async () => {
    leadFound = { _id: 'fdf72ce42f0a0580e128388e13149050' };
    await sendNotification({ userId: mockUser._id, role: 'owner', type: 'application_new',
      data: { applicationId: '6a0000000000000000000002', providerRole: 'sitter', providerId: '6a0000000000000000000004', postId: '6a0000000000000000000001' } });
    expect(sendEmail).toHaveBeenCalledTimes(1);
    expect(mockFindOne).toHaveBeenCalledWith({ ownerId: mockUser._id, confirmedAt: { $ne: null } });
    const link = lastLink();
    expect(link.startsWith(`${BASE_URL}/posts/confirmer?l=fdf72ce42f0a0580e128388e13149050&next=`)).toBe(true);
    // la cible = exactement celle que le bouton aurait eue sans réécriture (même routeur que la cloche)
    const attendu = buildEmailRoute('application_new', { applicationId: '6a0000000000000000000002', providerRole: 'sitter', providerId: '6a0000000000000000000004', postId: '6a0000000000000000000001' }, { role: 'owner', devices: null });
    // 31/10 (LEO) — la cible porte en plus le jeton signé `&k=` (utils/applicationLink3110) :
    // même route, suivie du jeton qui ouvre la session sans mot de passe.
    const next = decodeURIComponent(link.split('next=')[1]);
    expect(next.startsWith(`${attendu}&k=`)).toBe(true);
    expect(require('../src/utils/applicationLink3110').verifyApplicationLink(next.split('&k=')[1])).toMatchObject({ ok: true, applicationId: '6a0000000000000000000002' });
    expect(attendu.startsWith('/')).toBe(true);
  });

  test('un propriétaire ordinaire garde le lien direct', async () => {
    leadFound = null;
    await sendNotification({ userId: mockUser._id, role: 'owner', type: 'application_new',
      data: { applicationId: '6a0000000000000000000002', providerRole: 'sitter', providerId: '6a0000000000000000000004' } });
    const attendu = buildEmailRoute('application_new', { applicationId: '6a0000000000000000000002', providerRole: 'sitter', providerId: '6a0000000000000000000004' }, { role: 'owner', devices: null });
    // 31/10 (LEO) — lien direct + jeton signé `&k=` (sans mot de passe pour tous, feu vert BOB).
    expect(lastLink().startsWith(`${BASE_URL}${attendu}&k=`)).toBe(true);
    expect(require('../src/utils/applicationLink3110').verifyApplicationLink(lastLink().split('&k=')[1])).toMatchObject({ ok: true, ownerId: String(mockUser._id), applicationId: '6a0000000000000000000002' });
    expect(lastLink().indexOf('/posts/confirmer')).toBe(-1);
  });

  test('un gardien n\'est jamais réécrit (pas de recherche de contact)', async () => {
    leadFound = { _id: 'fdf72ce42f0a0580e128388e13149050' };
    await sendNotification({ userId: mockUser._id, role: 'sitter', type: 'application_accepted', data: { bookingId: '6a5007807b1c2d3e4f5a6b7c' } });
    expect(mockFindOne).not.toHaveBeenCalled();
    expect(lastLink().indexOf('/posts/confirmer')).toBe(-1);
  });
});
