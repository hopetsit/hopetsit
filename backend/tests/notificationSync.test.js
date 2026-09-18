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
jest.mock('../src/sockets/emitter', () => ({ emitToUser: jest.fn() }));
const mockBadgeSync = jest.fn(async () => ({}));
jest.mock('../src/services/notificationSender', () => ({ sendBadgeSync: (...a) => mockBadgeSync(...a) }));

const service = require('../src/services/notificationService');
const { emitToUser } = require('../src/sockets/emitter');
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
  test('mark one read → notification.read { ids, unreadCount } to the user room', async () => {
    service.markNotificationRead.mockResolvedValue({
      _id: NOTIF_ID, recipientRole: 'owner', recipientId: USER.id, type: 'booking_new',
      title: 't', body: 'b', data: {}, readAt: new Date(), createdAt: new Date(),
    });
    service.getUnreadCount.mockResolvedValue(3);
    const res = mkRes();
    await controller.markMyNotificationRead({ user: USER, params: { id: NOTIF_ID } }, res);
    expect(emitToUser).toHaveBeenCalledTimes(1);
    const [role, userId, event, payload] = emitToUser.mock.calls[0];
    expect([role, userId, event]).toEqual(['owner', USER.id, 'notification.read']);
    expect(payload.ids).toEqual([NOTIF_ID]);
    expect(payload.all).toBeUndefined();
    expect(payload.unreadCount).toBe(3);
    expect(typeof payload.at).toBe('string');
    expect(res.json).toHaveBeenCalled();
  });

  test('already read / unknown → 404 and NO event', async () => {
    service.markNotificationRead.mockResolvedValue(null);
    const res = mkRes();
    await controller.markMyNotificationRead({ user: USER, params: { id: NOTIF_ID } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(emitToUser).not.toHaveBeenCalled();
  });

  test('mark all read → notification.read { all: true, unreadCount: 0 }', async () => {
    service.markAllRead.mockResolvedValue(5);
    service.getUnreadCount.mockResolvedValue(0);
    const res = mkRes();
    await controller.markMyNotificationsReadAll({ user: USER }, res);
    const [, , event, payload] = emitToUser.mock.calls[0];
    expect(event).toBe('notification.read');
    expect(payload.all).toBe(true);
    expect(payload.ids).toBeUndefined();
    expect(payload.unreadCount).toBe(0);
    expect(res.json).toHaveBeenCalledWith({ updatedCount: 5 });
    // badge iOS des autres appareils remis à 0
    expect(mockBadgeSync).toHaveBeenCalledWith({ role: 'owner', userId: USER.id, unreadCount: 0 });
  });

  test('delete one → notification.removed { ids }', async () => {
    service.deleteNotification.mockResolvedValue(1);
    service.getUnreadCount.mockResolvedValue(2);
    const res = mkRes();
    await controller.deleteMyNotification({ user: { id: USER.id, role: 'walker' }, params: { id: NOTIF_ID } }, res);
    const [role, , event, payload] = emitToUser.mock.calls[0];
    expect(role).toBe('walker');
    expect(event).toBe('notification.removed');
    expect(payload.ids).toEqual([NOTIF_ID]);
    expect(payload.unreadCount).toBe(2);
  });

  test('delete unknown → 404 and NO event', async () => {
    service.deleteNotification.mockResolvedValue(0);
    const res = mkRes();
    await controller.deleteMyNotification({ user: USER, params: { id: NOTIF_ID } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(emitToUser).not.toHaveBeenCalled();
  });

  test('clear all → notification.removed { all: true }', async () => {
    service.clearNotifications.mockResolvedValue(7);
    service.getUnreadCount.mockResolvedValue(0);
    const res = mkRes();
    await controller.clearMyNotifications({ user: USER }, res);
    const [, , event, payload] = emitToUser.mock.calls[0];
    expect(event).toBe('notification.removed');
    expect(payload.all).toBe(true);
    expect(res.json).toHaveBeenCalledWith({ deletedCount: 7 });
  });

  test('a socket failure never breaks the HTTP answer', async () => {
    service.markAllRead.mockResolvedValue(1);
    service.getUnreadCount.mockRejectedValue(new Error('db down'));
    const res = mkRes();
    await controller.markMyNotificationsReadAll({ user: USER }, res);
    expect(emitToUser).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith({ updatedCount: 1 });
  });

  test('unauthenticated → 401, no event', async () => {
    const res = mkRes();
    await controller.markMyNotificationsReadAll({ user: null }, res);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(emitToUser).not.toHaveBeenCalled();
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
