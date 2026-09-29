/**
 * v603 (ZOE, 29/09/2026) — le bouton des e-mails de notification vise la MÊME
 * cible précise que la cloche et le push du 602 (DeepLinkService.routeForNotification).
 *  1. Parité : la table du test Dart du 602 (frontend/test/zoe602_notification_routing_test.dart)
 *     est relue ici et chaque ligne doit donner la même route côté serveur.
 *  2. Compatibilité 598-602 : les 5 cibles propres au 602 ne partent que si tous les
 *     appareils savent les ouvrir (iOS ≥ 602, Android ≥ 603), sinon repli précis connu.
 *  3. De bout en bout : l'e-mail porte le lien précis, le push garde sa route historique.
 */
const fs = require('fs');
const path = require('path');

const mockUser = {
  _id: '64b000000000000000000001',
  email: 'camille@example.com',
  appLocale: 'fr',
  language: 'French',
  fcmTokens: ['tok-1'],
  fcmDevices: [],
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

const {
  buildEmailRoute, buildPreciseRoute, buildAppRoute, legacyFallbackFor, deviceOpensPreciseLinks,
} = require('../src/utils/emailLinkBuilder');
const { sendEmail } = require('../src/services/emailService');
const { sendNotification } = require('../src/services/notificationSender');

const V = {
  b: '6a5007807b1c2d3e4f5a6b7c', c: '6a976145aa1c2d3e4f5a6b7c', p: '6a0000000000000000000001',
  a: '6a0000000000000000000002', r: '6a0000000000000000000003', s: '6a0000000000000000000004',
  u: '6a0000000000000000000005',
};
const { b, c, p, a, r, s, u } = V;
const IOS602 = [{ token: 't1', platform: 'ios', appBuild: 602 }];

describe('parité avec le routeur de l\'app 602', () => {
  const dartFile = path.join(__dirname, '../../frontend/test/zoe602_notification_routing_test.dart');
  const rows = [];
  if (fs.existsSync(dartFile)) {
    const src = fs.readFileSync(dartFile, 'utf8');
    const re = /\['([A-Za-z_]+)', '(owner|sitter|walker)', \{(.*?)\}, '([^']+)'\],/g;
    let m;
    while ((m = re.exec(src))) {
      // eslint-disable-next-line no-new-func
      const data = new Function(...Object.keys(V), `return {${m[3]}};`)(...Object.values(V));
      const expected = m[4].replace(/\$([a-z])/g, (_, k) => V[k]);
      rows.push([m[1], m[2], data, expected]);
    }
  }

  test('la table Dart est lue (≥ 70 lignes)', () => {
    if (!fs.existsSync(dartFile)) return; // dépôt sans l'app : rien à comparer
    expect(rows.length).toBeGreaterThanOrEqual(70);
  });

  test('chaque type → même route que l\'app 602 (appareils récents)', () => {
    const diffs = rows
      .map(([t, role, data, want]) => [t, role, buildEmailRoute(t, data, { role, devices: IOS602 }), want])
      .filter(([, , got, want]) => got !== want);
    expect(diffs).toEqual([]);
  });

  test('anciennes notifications sans id : même repli que l\'app', () => {
    expect(buildPreciseRoute('booking_new', {}, 'sitter')).toBe('/bookings');
    expect(buildPreciseRoute('application_rejected', { applicationId: a }, 'sitter')).toBe('/bookings');
    expect(buildPreciseRoute('NEW_MESSAGE', {}, 'owner')).toBe('/chat');
    expect(buildPreciseRoute('sos_pet_nearby', {}, 'owner')).toBe('/map');
    expect(buildPreciseRoute('pawspot_validated', {}, 'owner')).toBe('/shop/2');
  });

  test('suivi en direct (PAM) : route serveur 602 inchangée', () => {
    for (const t of ['live_tracking_request_received', 'live_tracking_accepted', 'live_tracking_refused',
      'live_still_active', 'live_session_ended']) {
      expect(buildEmailRoute(t, { conversationId: c }, { role: 'owner' })).toBe(buildAppRoute(t, { conversationId: c }));
    }
  });
});

describe('compatibilité apps 598-602', () => {
  test('appareils capables : iOS ≥ 602, Android ≥ 603 seulement', () => {
    expect(deviceOpensPreciseLinks({ token: 'x', platform: 'ios', appBuild: 602 })).toBe(true);
    expect(deviceOpensPreciseLinks({ token: 'x', platform: 'ios', appBuild: 601 })).toBe(false);
    expect(deviceOpensPreciseLinks({ token: 'x', platform: 'android', appBuild: 602 })).toBe(false);
    expect(deviceOpensPreciseLinks({ token: 'x', platform: 'android', appBuild: 603 })).toBe(true);
    expect(deviceOpensPreciseLinks({ token: 'x', platform: '', appBuild: 0 })).toBe(false);
  });

  const cases = [
    ['booking_new', 'sitter', { bookingId: b }, `/request/${b}`, `/bookings/${b}`],
    ['application_new', 'owner', { applicationId: a, postId: p }, `/application/${a}`, `/post/${p}`],
    ['kyc_verified', 'sitter', {}, '/identity', '/profile'],
    ['NEW_REVIEW', 'walker', { reviewId: u }, '/reviews', '/profile'],
    ['friend_request_accepted', 'owner', { byUserId: u, byUserRole: 'walker' }, `/member/walker/${u}`, '/friends'],
  ];
  test.each(cases)('%s (%s) : précis si tous les appareils suivent, sinon repli', (t, role, data, precise, fallback) => {
    expect(buildEmailRoute(t, data, { role, devices: IOS602 })).toBe(precise);
    expect(buildEmailRoute(t, data, { role, devices: [...IOS602, { token: 't2', platform: 'android', appBuild: 602 }] })).toBe(fallback);
    expect(buildEmailRoute(t, data, { role, devices: [{ token: 't3', platform: 'ios', appBuild: 599 }] })).toBe(fallback);
    expect(buildEmailRoute(t, data, { role, devices: [] })).toBe(fallback); // pas d'app : le site
    expect(buildEmailRoute(t, data, { role })).toBe(fallback);
    expect(legacyFallbackFor(precise, data)).toBe(fallback);
  });

  test('les autres cibles précises partent pour tout le monde (chemins déjà connus des apps 598-601)', () => {
    const none = { devices: [] };
    expect(buildEmailRoute('booking_mutually_accepted', { bookingId: b }, { role: 'owner', ...none })).toBe(`/pay?bookingId=${b}`);
    expect(buildEmailRoute('application_rejected', { postId: p }, { role: 'sitter', ...none })).toBe(`/post/${p}`);
    expect(buildEmailRoute('pawspot_validated', { spotId: s }, { role: 'owner', ...none })).toBe(`/spot/${s}`);
    expect(buildEmailRoute('family_member_added', {}, { role: 'owner', ...none })).toBe('/friends/family');
    expect(buildEmailRoute('subscription_activated', { plan: 'premium_yearly' }, { role: 'owner', ...none })).toBe('/shop/3');
    expect(buildEmailRoute('sos_pet_nearby', { reportId: r }, { role: 'sitter', ...none })).toBe(`/alert/${r}`);
  });
});

describe('de bout en bout (sendNotification)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockUser.fcmTokens = ['tok-1'];
    mockUser.fcmDevices = [];
  });
  const lastEmail = () => sendEmail.mock.calls[sendEmail.mock.calls.length - 1];
  const pushRoute = () => mockSendMulticast.mock.calls[0][0].data.route;

  test('iOS 602 : e-mail « identité vérifiée » → /identity ; push garde /profile (apps 598-601)', async () => {
    mockUser.fcmDevices = [{ token: 'tok-1', platform: 'ios', appBuild: 602 }];
    await sendNotification({ userId: mockUser._id, role: 'sitter', type: 'kyc_verified', data: { kycStatus: 'verified' } });
    const [, , text, html] = lastEmail();
    expect(text).toContain('https://www.hopetsit.com/identity');
    expect(html).toContain('https://www.hopetsit.com/identity');
    expect(pushRoute()).toBe('/profile');
  });

  test('Android 602 : repli /profile dans l\'e-mail (lien non déclaré dans son APK)', async () => {
    mockUser.fcmDevices = [{ token: 'tok-1', platform: 'android', appBuild: 602 }];
    await sendNotification({ userId: mockUser._id, role: 'sitter', type: 'kyc_verified', data: {} });
    expect(lastEmail()[2]).toContain('https://www.hopetsit.com/profile');
  });

  test('jeton sans fiche d\'appareil (app ancienne) = repli', async () => {
    mockUser.fcmDevices = [];
    await sendNotification({ userId: mockUser._id, role: 'sitter', type: 'booking_new', data: { bookingId: b } });
    expect(lastEmail()[2]).toContain(`https://www.hopetsit.com/bookings/${b}`);
  });

  test('candidature refusée : l\'e-mail ouvre la demande (avant : la liste)', async () => {
    await sendNotification({ userId: mockUser._id, role: 'sitter', type: 'application_rejected', data: { applicationId: a, postId: p } });
    expect(lastEmail()[2]).toContain(`https://www.hopetsit.com/post/${p}`);
  });
});
