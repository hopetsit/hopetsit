// 610 (ZOE, 04/10/2026) — bug de Daniel (iPhone 609) : « quand j'ai lu les
// notifications, elles restent dans la cloche, et sur l'icône de l'app il y a
// toujours le numéro de notifications ».
// VRAIE base Mongo en mémoire, vrais modèles, vrai contrôleur, vrai
// sendNotification ; seuls Firebase (push), le SMTP et les sockets sont simulés
// (on capture ce qui partirait : salles, compteurs, valeur `aps.badge`).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mockEmits = [];
const mockPushes = [];
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn((role, id, event, payload) => { mockEmits.push({ room: `${role}:${id}`, event, payload }); }),
  emitToUsersAllRoles: jest.fn(() => 0),
  isUserOnline: jest.fn(async () => false),
  isConversationOpenFor: jest.fn(async () => false),
}));
jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({
    sendEachForMulticast: jest.fn(async (m) => {
      mockPushes.push(m);
      return { successCount: m.tokens.length, failureCount: 0, responses: [] };
    }),
  }),
}));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async () => ({ messageId: 'mock' })) };
});
jest.mock('../src/services/chatUnreadEmailScheduler599', () => ({
  scheduleUnreadEmail: jest.fn(async () => ({ created: false })),
  cancelUnreadEmail: jest.fn(async () => ({ cancelled: 0 })),
  isTestEmail: () => true,
}));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let Walker; let Notification;
let ctrl; let sender; let chatRead;
let P; let X; // P = une personne aux 3 profils ; X = une autre personne

const mkRes = () => {
  const res = { code: 200, body: null };
  res.status = (c) => { res.code = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  return res;
};
const call = async (fn, user, { params = {}, query = {}, body = {} } = {}) => {
  const res = mkRes();
  await ctrl[fn]({ user, params, query, body, headers: {} }, res);
  return res;
};
const notif = (role, id, type = 'booking_new', extra = {}) => Notification.create({
  recipientRole: role, recipientId: id, type, title: type, body: 'b', data: extra,
});
const unread = (role, id) => Notification.countDocuments({ recipientRole: role, recipientId: id, readAt: null });

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Notification = require('../src/models/Notification');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Notification.init()]);
  ctrl = require('../src/controllers/notificationController');
  sender = require('../src/services/notificationSender');
  chatRead = require('../src/utils/chatReadSync599');
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

beforeEach(async () => {
  mockEmits.length = 0;
  mockPushes.length = 0;
  await Promise.all([Owner.deleteMany({}), Sitter.deleteMany({}), Walker.deleteMany({}), Notification.deleteMany({})]);
  require('../src/utils/identityGroup').invalidateIdentityGroup();
  const email = 'daniel610@example.test';
  const o = await Owner.create({ name: 'Daniel', email, password: 'MotDePasse610!' });
  const s = await Sitter.create({ name: 'Daniel', email, password: 'MotDePasse610!' });
  const w = await Walker.create({ name: 'Daniel', email, password: 'MotDePasse610!' });
  const x = await Owner.create({ name: 'Autre', email: 'autre610@example.test', password: 'MotDePasse610!' });
  P = {
    owner: { id: String(o._id), role: 'owner' },
    sitter: { id: String(s._id), role: 'sitter' },
    walker: { id: String(w._id), role: 'walker' },
  };
  X = { id: String(x._id), role: 'owner' };
});

describe('comptage des non-lues (profil actif ET personne)', () => {
  test('3 non lues propriétaire + 1 gardien : profil = 3, personne = 4, l\'autre compte ne compte pas', async () => {
    await notif('owner', P.owner.id); await notif('owner', P.owner.id); await notif('owner', P.owner.id);
    await notif('sitter', P.sitter.id);
    await notif('owner', X.id); await notif('owner', X.id);
    const old = await call('getMyUnreadCount', P.owner); // app ≤ 609
    expect(old.body).toEqual({ unreadCount: 3, roleUnreadCount: 3, totalUnreadCount: 4 });
    const now = await call('getMyUnreadCount', P.owner, { query: { scope: 'person' } }); // app ≥ 610
    expect(now.body.unreadCount).toBe(4);
    const fromWalker = await call('getMyUnreadCount', P.walker, { query: { scope: 'person' } });
    expect(fromWalker.body).toEqual({ unreadCount: 4, roleUnreadCount: 0, totalUnreadCount: 4 });
  });

  test('liste : ≤ 609 = profil actif seulement ; ≥ 610 = les 3 profils, jamais ceux d\'un autre', async () => {
    await notif('owner', P.owner.id); await notif('sitter', P.sitter.id); await notif('walker', P.walker.id);
    await notif('owner', X.id);
    const old = await call('getMyNotifications', P.owner, { query: { lang: 'fr' } });
    expect(old.body.notifications.map((n) => n.recipientRole)).toEqual(['owner']);
    const now = await call('getMyNotifications', P.owner, { query: { scope: 'person', lang: 'fr' } });
    expect(now.body.notifications.map((n) => n.recipientRole).sort()).toEqual(['owner', 'sitter', 'walker']);
    expect(now.body.notifications.some((n) => n.recipientId === X.id)).toBe(false);
  });
});

describe('marquer lu', () => {
  test('lire depuis le profil propriétaire une notification du profil gardien → lue, compteurs recalés dans chaque salle', async () => {
    await notif('owner', P.owner.id);
    const sit = await notif('sitter', P.sitter.id);
    const r = await call('markMyNotificationRead', P.owner, { params: { id: String(sit._id) } });
    expect(r.code).toBe(200);
    expect(await unread('sitter', P.sitter.id)).toBe(0);
    const reads = mockEmits.filter((e) => e.event === 'notification.read');
    const ownerRoom = reads.find((e) => e.room === `owner:${P.owner.id}`);
    const sitterRoom = reads.find((e) => e.room === `sitter:${P.sitter.id}`);
    expect(ownerRoom.payload).toMatchObject({ ids: [String(sit._id)], unreadCount: 1, totalUnreadCount: 1 });
    expect(sitterRoom.payload).toMatchObject({ unreadCount: 0, totalUnreadCount: 1 });
  });

  test('impossible de lire la notification d\'une autre personne (404, rien ne change)', async () => {
    const other = await notif('owner', X.id);
    const r = await call('markMyNotificationRead', P.owner, { params: { id: String(other._id) } });
    expect(r.code).toBe(404);
    expect(await unread('owner', X.id)).toBe(1);
  });

  test('lot choisi : ids de mes 3 profils lus, l\'id étranger ignoré', async () => {
    const a = await notif('owner', P.owner.id);
    const b = await notif('walker', P.walker.id);
    const c = await notif('owner', X.id);
    const r = await call('markMyNotificationsReadBatch', P.sitter, { body: { ids: [a._id, b._id, c._id].map(String) } });
    expect(r.body).toMatchObject({ ok: true, updated: 2, totalUnreadCount: 0 });
    expect(await unread('owner', X.id)).toBe(1);
  });

  test('« tout lire » app ≥ 610 (scope=person) → 0 partout pour la personne, badge envoyé = 0', async () => {
    await notif('owner', P.owner.id); await notif('sitter', P.sitter.id); await notif('walker', P.walker.id);
    await notif('owner', X.id);
    const spy = jest.spyOn(sender, 'sendBadgeSync');
    const r = await call('markMyNotificationsReadAll', P.owner, { query: { scope: 'person' } });
    expect(r.body).toMatchObject({ updatedCount: 3, unreadCount: 0, totalUnreadCount: 0 });
    const c = await call('getMyUnreadCount', P.walker, { query: { scope: 'person' } });
    expect(c.body.unreadCount).toBe(0);
    expect(await unread('owner', X.id)).toBe(1);
    expect(spy).toHaveBeenCalledWith(expect.objectContaining({ personUnreadCount: 0, unreadCount: 0 }));
    spy.mockRestore();
  });

  test('« tout lire » app ≤ 609 (sans scope) → seul le profil actif, comme avant', async () => {
    await notif('owner', P.owner.id); await notif('sitter', P.sitter.id);
    const r = await call('markMyNotificationsReadAll', P.sitter);
    expect(r.body.updatedCount).toBe(1);
    expect(await unread('owner', P.owner.id)).toBe(1);
    expect(await unread('sitter', P.sitter.id)).toBe(0);
    // l'appareil connecté au profil propriétaire n'a PAS reçu de « all »
    const ownerRoom = mockEmits.find((e) => e.room === `owner:${P.owner.id}`);
    expect(ownerRoom.payload.all).toBeUndefined();
    expect(ownerRoom.payload).toMatchObject({ ids: [], unreadCount: 1, totalUnreadCount: 1 });
  });
});

describe('notifications regroupées (« Nouveau message » par conversation)', () => {
  const CONV = '64b0000000000000000000c1';
  test('2 messages = 1 entrée de cloche ; lire la conversation (depuis un autre profil) la passe en lu', async () => {
    const data = { conversationId: CONV, senderName: 'Alex', preview: 'Salut' };
    await sender.sendNotification({ userId: P.owner.id, role: 'owner', type: 'NEW_MESSAGE', data });
    await sender.sendNotification({ userId: P.owner.id, role: 'owner', type: 'NEW_MESSAGE', data });
    const bell = await Notification.find({ recipientId: P.owner.id, type: 'NEW_MESSAGE' }).lean();
    expect(bell).toHaveLength(1);
    expect(await unread('owner', P.owner.id)).toBe(1);
    mockEmits.length = 0;
    const r = await chatRead.afterConversationRead({ conversationId: CONV, readerId: P.sitter.id });
    expect(r.bell).toBe(1);
    expect(await unread('owner', P.owner.id)).toBe(0);
    const ownerRoom = mockEmits.find((e) => e.event === 'notification.read' && e.room === `owner:${P.owner.id}`);
    expect(ownerRoom.payload).toMatchObject({ ids: [String(bell[0]._id)], unreadCount: 0, totalUnreadCount: 0 });
  });
});

describe('valeur `badge` envoyée dans le push APNs', () => {
  test('jeton iOS ≥ 610 → total des 3 profils ; iOS 566-609 → compteur du profil ; Android → aucun badge', async () => {
    await notif('owner', P.owner.id); await notif('owner', P.owner.id); // 2 non lues propriétaire
    await Owner.collection.updateOne({ _id: new mongoose.Types.ObjectId(P.owner.id) }, { $set: {
      fcmTokens: ['ios-610', 'ios-609', 'android-610'],
      fcmDevices: [
        { token: 'ios-610', platform: 'ios', appBuild: 610 },
        { token: 'ios-609', platform: 'ios', appBuild: 609 },
        { token: 'android-610', platform: 'android', appBuild: 610 },
      ],
    } });
    await sender.sendNotification({ userId: P.sitter.id, role: 'sitter', type: 'booking_new', data: { bookingId: 'b1' } });
    // gardien : 1 non lue (celle qu'on vient de créer) ; personne : 3
    const alerts = mockPushes.filter((m) => m.notification);
    const byToken = {};
    for (const m of alerts) for (const t of m.tokens) byToken[t] = m.apns.payload.aps.badge;
    expect(byToken['ios-610']).toBe(3);
    expect(byToken['ios-609']).toBe(1);
    expect(byToken['android-610']).toBeUndefined();
  });

  test('push « badge seul » après lecture : 610 reçoit le total, 609 le compteur du profil', async () => {
    await notif('sitter', P.sitter.id);
    const o = await notif('owner', P.owner.id);
    await Owner.collection.updateOne({ _id: new mongoose.Types.ObjectId(P.owner.id) }, { $set: {
      fcmTokens: ['ios-610', 'ios-609'],
      fcmDevices: [
        { token: 'ios-610', platform: 'ios', appBuild: 610 },
        { token: 'ios-609', platform: 'ios', appBuild: 609 },
      ],
    } });
    await call('markMyNotificationRead', P.owner, { params: { id: String(o._id) } });
    await new Promise((r) => setTimeout(r, 300)); // sendBadgeSync part sans attendre
    const syncs = mockPushes.filter((m) => m.data && m.data.type === 'badge_sync');
    const byToken = {};
    for (const m of syncs) for (const t of m.tokens) byToken[t] = m.apns.payload.aps.badge;
    expect(byToken['ios-610']).toBe(1); // reste la notification du profil gardien
    expect(byToken['ios-609']).toBe(0); // profil propriétaire : 0 (comportement 609)
  });
});
