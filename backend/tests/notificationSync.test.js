/**
 * v566 — synchronisation « lu / supprimé » entre appareils (Daniel, 18/09).
 * Sans base ni socket réels : le service et l'émetteur sont simulés.
 */
jest.mock('../src/services/notificationService', () => ({
  listNotifications: jest.fn(),
  getUnreadCount: jest.fn(),
  markNotificationRead: jest.fn(),
  markAllRead: jest.fn(),
  deleteNotification: jest.fn(),
  clearNotifications: jest.fn(),
}));
// 610 — la synchro passe par la personne (utils/notifPerson610, testé avec une
// vraie base en mémoire dans notifPerson610.test.js) : ici on vérifie que chaque
// action du contrôleur l'appelle avec les bons arguments.
const mockSync = jest.fn(async (event, a) => ({
  ...(a.all ? { all: true } : { ids: a.ids }), unreadCount: 3, totalUnreadCount: 4, at: 'x',
}));
jest.mock('../src/utils/notifPerson610', () => ({
  isPersonScope: (req) => String((req && req.query && req.query.scope) || '') === 'person',
  personProfiles: jest.fn(async (id, role) => [{ role, id }]),
  recipientFilter: (profiles) => ({ $or: profiles.map((p) => ({ recipientRole: p.role, recipientId: p.id })) }),
  personUnread: jest.fn(async () => ({ total: 4, byProfile: [] })),
  syncPerson: (...a) => mockSync(...a),
}));

const service = require('../src/services/notificationService');
const controller = require('../src/controllers/notificationController');

const mkRes = () => {
  const res = {};
  res.status = jest.fn(() => res);
  res.json = jest.fn(() => res);
  return res;
};
const USER = { id: '64b000000000000000000001', role: 'owner' };
const NOTIF_ID = '64b0000000000000000000aa';

beforeEach(() => jest.clearAllMocks());

describe('notification sync events', () => {
  test('mark one read → synchro « notification.read { ids } » de la personne', async () => {
    service.markNotificationRead.mockResolvedValue({
      _id: NOTIF_ID, recipientRole: 'owner', recipientId: USER.id, type: 'booking_new',
      title: 't', body: 'b', data: {}, readAt: new Date(), createdAt: new Date(),
    });
    const res = mkRes();
    await controller.markMyNotificationRead({ user: USER, params: { id: NOTIF_ID } }, res);
    expect(mockSync).toHaveBeenCalledTimes(1);
    const [event, args] = mockSync.mock.calls[0];
    expect(event).toBe('notification.read');
    expect(args).toMatchObject({ role: 'owner', userId: USER.id, ids: [NOTIF_ID], all: false });
    expect(res.json).toHaveBeenCalled();
  });

  test('mark all read (profil actif, app ≤ 609) → all sur CE profil seulement', async () => {
    service.markAllRead.mockResolvedValue(5);
    const res = mkRes();
    await controller.markMyNotificationsReadAll({ user: USER }, res);
    const [event, args] = mockSync.mock.calls[0];
    expect(event).toBe('notification.read');
    expect(args).toMatchObject({ all: true, allProfiles: false });
    expect(res.json).toHaveBeenCalledWith({ updatedCount: 5, unreadCount: 3, totalUnreadCount: 4 });
  });

  test('delete one → synchro « notification.removed { ids } »', async () => {
    service.deleteNotification.mockResolvedValue(1);
    const res = mkRes();
    await controller.deleteMyNotification({ user: { id: USER.id, role: 'walker' }, params: { id: NOTIF_ID } }, res);
    const [event, args] = mockSync.mock.calls[0];
    expect(event).toBe('notification.removed');
    expect(args).toMatchObject({ role: 'walker', ids: [NOTIF_ID] });
  });

  test('clear all (profil actif) → notification.removed { all }', async () => {
    service.clearNotifications.mockResolvedValue(7);
    const res = mkRes();
    await controller.clearMyNotifications({ user: USER }, res);
    const [event, args] = mockSync.mock.calls[0];
    expect(event).toBe('notification.removed');
    expect(args).toMatchObject({ all: true, allProfiles: false });
    expect(res.json).toHaveBeenCalledWith({ deletedCount: 7 });
  });

  test('a sync failure never breaks the HTTP answer', async () => {
    service.markAllRead.mockResolvedValue(1);
    mockSync.mockResolvedValueOnce(null);
    const res = mkRes();
    await controller.markMyNotificationsReadAll({ user: USER }, res);
    expect(res.json).toHaveBeenCalledWith({ updatedCount: 1 });
  });

  test('unauthenticated → 401, no event', async () => {
    const res = mkRes();
    await controller.markMyNotificationsReadAll({ user: null }, res);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(mockSync).not.toHaveBeenCalled();
  });
});

describe('notification e-mail layout', () => {
  const { buildNotificationEmailHtml } = require('../src/services/emailService');
  const link = 'https://www.hopetsit.com/bookings';
  const inner = `<p>Bonjour</p><p><a href="${link}" style="display:inline-block;padding:12px 24px;">Voir</a></p>`;

  test('adds viewport, centered button, fallback link and translated footer', () => {
    const html = buildNotificationEmailHtml(inner, { locale: 'de', link, preheader: 'Hallo <b>' });
    expect(html).toContain('name="viewport"');
    expect(html).toContain('<p style="text-align:center;margin:24px 0"><a href="' + link);
    expect(html.split(link).length - 1).toBeGreaterThanOrEqual(3); // bouton + lien de secours (href + texte)
    expect(html).toContain('Benachrichtigungen');
    expect(html).toContain('Hallo &lt;b&gt;');
  });

  test('does not duplicate an existing fallback link, unknown locale → English', () => {
    const withFallback = `${inner}<p>copie : ${link}</p>`;
    const html = buildNotificationEmailHtml(withFallback, { locale: 'xx', link });
    expect(html.split(link).length - 1).toBe(2);
    expect(html).toContain('You are receiving this email');
  });
});
