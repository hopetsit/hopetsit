const logger = require('../utils/logger');
const {
  listNotifications,
  getUnreadCount,
  markNotificationRead,
  markAllRead,
  deleteNotification,
  clearNotifications,
} = require('../services/notificationService');
const {
  isPersonScope, personProfiles, recipientFilter, personUnread, syncPerson,
} = require('../utils/notifPerson610');

// v566 — Daniel (18/09) : « quand je mets une notification en lu sur un appareil, les
// autres doivent se synchroniser ». L'état lu / supprimé vit en base (source de vérité
// unique, par compte + rôle) ; après chaque changement on prévient EN DIRECT tous les
// appareils connectés du même compte (iPhone, Android, site) :
//   notification.read    { ids: [...] | all: true, unreadCount, at }
//   notification.removed { ids: [...] | all: true, unreadCount, at }
// Un appareil hors ligne se resynchronise à son retour (GET /my + /my/unread-count).
// 610 (ZOE) — la synchro passe par la PERSONNE (3 profils) : chaque appareil
// reçoit dans la salle de SON profil `unreadCount` (son profil, comme avant) et
// `totalUnreadCount` (les 3 profils, lu par l'app ≥ 610). Voir utils/notifPerson610.
const emitNotificationSync = async (event, { role, userId, ids = null, all = false, allProfiles = false }) =>
  syncPerson(event, { role, userId, ids, all, allProfiles });

const mapNotification = (n) => ({
  id: n._id.toString(),
  recipientRole: n.recipientRole,
  recipientId: n.recipientId?.toString?.() || String(n.recipientId),
  actorRole: n.actorRole || null,
  actorId: n.actorId ? (n.actorId.toString?.() || String(n.actorId)) : null,
  type: n.type,
  title: n.title || '',
  body: n.body || '',
  data: n.data || {},
  readAt: n.readAt ? n.readAt.toISOString() : null,
  createdAt: n.createdAt ? n.createdAt.toISOString() : null,
});

const getMyNotifications = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;
    const { limit, cursor } = req.query || {};

    if (!userId || !role) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }
    if (!['owner', 'sitter', 'walker'].includes(role)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner", "sitter" or "walker".' });
    }

    // Session v16.2 - walker notifications are now first-class (Notification
    // recipientRole enum includes 'walker'). The previous empty-list short
    // circuit was hiding booking events from walker accounts.
    // 610 — `?scope=person` (app ≥ 610) : la cloche liste les notifications des
    // 3 profils de la personne. Sans le paramètre : profil actif seul (≤ 609).
    let items;
    if (isPersonScope(req)) {
      const Notification = require('../models/Notification');
      const profiles = await personProfiles(userId, role);
      const query = { ...recipientFilter(profiles) };
      if (cursor) query._id = { $lt: cursor };
      const safeLimit = Math.max(1, Math.min(Number(limit) || 50, 100));
      items = await Notification.find(query).sort({ _id: -1 }).limit(safeLimit);
    } else {
      items = await listNotifications({
        recipientRole: role,
        recipientId: userId,
        limit,
        cursor,
      });
    }

    // v497 — Daniel : « je suis en espagnol mais les notifs du site sont en FR ».
    // On RE-REND titre/corps dans la langue COURANTE du lecteur au lieu de la
    // langue figée à l'envoi → app + web suivent la langue choisie. Fallback :
    // texte stocké si pas de template.
    // v530 — cascade fiabilisée : 1) ?lang= envoyé par le client (la langue UI
    // RÉELLE au moment de la lecture, insensible aux docs pas synchronisés),
    // 2) appLocale cherchée sur les 3 docs de rôle de la personne (l'app ne la
    // synchronisait que sur le rôle courant), 3) champ libre `language`.
    // v566 — audit : 'pl' manquait (polonais ajouté en v546) → ?lang=pl était ignoré.
    const VALID_LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
    const reqLang = String(req.query?.lang || '').toLowerCase().slice(0, 2);
    let userLang = VALID_LANGS.includes(reqLang) ? reqLang : null;
    if (!userLang) {
      try {
        const Model =
          role === 'sitter'
            ? require('../models/Sitter')
            : role === 'walker'
              ? require('../models/Walker')
              : require('../models/Owner');
        const u = await Model.findById(userId)
          .select('appLocale language email oldId')
          .lean();
        const { resolveAppLocaleAcrossRoles } = require('../services/notificationSender');
        const appLocale = await resolveAppLocaleAcrossRoles(u, userId);
        userLang = appLocale || u?.language || null;
      } catch (_) {/* locale inconnue → garde le texte stocké */}
    }
    const { renderNotificationContent } = require('../services/notificationSender');

    res.json({
      notifications: items.map((n) => {
        const base = mapNotification(n);
        const loc = renderNotificationContent(n.type, n.data, userLang);
        if (loc && loc.title) {
          base.title = loc.title;
          base.body = loc.body;
        }
        return base;
      }),
      nextCursor: items.length ? items[items.length - 1]._id.toString() : null,
      count: items.length,
    });
  } catch (error) {
    logger.error('Get notifications error', error);
    res.status(500).json({ error: 'Unable to fetch notifications. Please try again later.' });
  }
};

const getMyUnreadCount = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;

    if (!userId || !role) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }
    if (!['owner', 'sitter', 'walker'].includes(role)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner", "sitter" or "walker".' });
    }

    // 610 — `totalUnreadCount` = non lues des 3 profils (cloche + icône de l'app
    // ≥ 610). `unreadCount` reste le profil actif, sauf avec `?scope=person`.
    const roleUnread = await getUnreadCount({ recipientRole: role, recipientId: userId });
    let totalUnreadCount = roleUnread;
    try {
      totalUnreadCount = (await personUnread(await personProfiles(userId, role))).total;
    } catch (_) { /* repli : profil actif */ }
    res.json({
      unreadCount: isPersonScope(req) ? totalUnreadCount : roleUnread,
      roleUnreadCount: roleUnread,
      totalUnreadCount,
    });
  } catch (error) {
    logger.error('Get unread count error', error);
    res.status(500).json({ error: 'Unable to fetch unread count. Please try again later.' });
  }
};

const markMyNotificationRead = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;
    const { id } = req.params;

    if (!userId || !role) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }
    if (!['owner', 'sitter', 'walker'].includes(role)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner", "sitter" or "walker".' });
    }

    // 610 — lisible depuis n'importe lequel des 3 profils de la personne.
    let updated = await markNotificationRead({
      recipientRole: role,
      recipientId: userId,
      notificationId: id,
    });
    if (!updated && /^[a-f0-9]{24}$/i.test(String(id || ''))) {
      const Notification = require('../models/Notification');
      const profiles = await personProfiles(userId, role);
      updated = await Notification.findOneAndUpdate(
        { _id: id, readAt: null, ...recipientFilter(profiles) },
        { $set: { readAt: new Date() } },
        { new: true },
      );
    }

    if (!updated) {
      return res.status(404).json({ error: 'Notification not found (or already read).' });
    }

    await emitNotificationSync('notification.read', { role, userId, ids: [id] });
    res.json({ notification: mapNotification(updated) });
  } catch (error) {
    logger.error('Mark notification read error', error);
    res.status(500).json({ error: 'Unable to mark notification as read. Please try again later.' });
  }
};

const markMyNotificationsReadAll = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;

    if (!userId || !role) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }
    if (!['owner', 'sitter', 'walker'].includes(role)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner", "sitter" or "walker".' });
    }

    // 610 — `?scope=person` : tout lu sur les 3 profils (ce que montre la cloche ≥ 610).
    let updatedCount;
    const person = isPersonScope(req);
    if (person) {
      const Notification = require('../models/Notification');
      const profiles = await personProfiles(userId, role);
      const r = await Notification.updateMany(
        { readAt: null, ...recipientFilter(profiles) },
        { $set: { readAt: new Date() } },
      );
      updatedCount = (r && (r.modifiedCount ?? r.nModified)) || 0;
    } else {
      updatedCount = await markAllRead({ recipientRole: role, recipientId: userId });
    }
    const sync = await emitNotificationSync('notification.read', { role, userId, all: true, allProfiles: person });
    res.json({ updatedCount, ...(sync ? { unreadCount: sync.unreadCount, totalUnreadCount: sync.totalUnreadCount } : {}) });
  } catch (error) {
    logger.error('Mark all notifications read error', error);
    res.status(500).json({ error: 'Unable to mark notifications as read. Please try again later.' });
  }
};

// v409 — Daniel : "effacer notification" (web + app).
// v599 (ZOE) — Daniel : « pouvoir CHOISIR » dans la cloche. Lecture et
// suppression PAR LOT (ids choisis), mêmes garanties que l'unitaire :
// portée au destinataire, synchro `notification.read` / `notification.removed`
// vers ses autres appareils + badge iOS. Compatible 598 (routes ajoutées).
const _batchIds = (req) => {
  const raw = (req.body && req.body.ids) || (req.query && req.query.ids) || [];
  const arr = Array.isArray(raw) ? raw : String(raw).split(',');
  return [...new Set(arr.map((v) => String(v || '').trim()).filter((v) => /^[a-f0-9]{24}$/i.test(v)))].slice(0, 200);
};

const markMyNotificationsReadBatch = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;
    if (!userId || !role) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }
    if (!['owner', 'sitter', 'walker'].includes(role)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner", "sitter" or "walker".' });
    }
    const ids = _batchIds(req);
    if (!ids.length) return res.status(400).json({ error: 'ids is required.' });
    const Notification = require('../models/Notification');
    // 610 — borné aux 3 profils de la personne (la cloche ≥ 610 les mélange).
    const profiles = await personProfiles(userId, role);
    const r = await Notification.updateMany(
      { _id: { $in: ids }, readAt: null, ...recipientFilter(profiles) },
      { $set: { readAt: new Date() } },
    );
    const sync = await emitNotificationSync('notification.read', { role, userId, ids });
    res.json({
      ok: true,
      updated: (r && (r.modifiedCount ?? r.nModified)) || 0,
      unreadCount: sync ? sync.unreadCount : undefined,
      totalUnreadCount: sync ? sync.totalUnreadCount : undefined,
    });
  } catch (error) {
    logger.error('Mark notifications read (batch) error', error);
    res.status(500).json({ error: 'Unable to mark notifications as read. Please try again later.' });
  }
};

const deleteMyNotificationsBatch = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;
    if (!userId || !role) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }
    if (!['owner', 'sitter', 'walker'].includes(role)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner", "sitter" or "walker".' });
    }
    const ids = _batchIds(req);
    if (!ids.length) return res.status(400).json({ error: 'ids is required.' });
    const Notification = require('../models/Notification');
    const profiles = await personProfiles(userId, role);
    const r = await Notification.deleteMany({ _id: { $in: ids }, ...recipientFilter(profiles) });
    const sync = await emitNotificationSync('notification.removed', { role, userId, ids });
    res.json({
      ok: true,
      deleted: (r && r.deletedCount) || 0,
      unreadCount: sync ? sync.unreadCount : undefined,
      totalUnreadCount: sync ? sync.totalUnreadCount : undefined,
    });
  } catch (error) {
    logger.error('Delete notifications (batch) error', error);
    res.status(500).json({ error: 'Unable to delete notifications. Please try again later.' });
  }
};

const deleteMyNotification = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;
    const { id } = req.params;
    if (!userId || !role) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }
    if (!['owner', 'sitter', 'walker'].includes(role)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner", "sitter" or "walker".' });
    }
    let deleted = await deleteNotification({
      recipientRole: role,
      recipientId: userId,
      notificationId: id,
    });
    if (!deleted && /^[a-f0-9]{24}$/i.test(String(id || ''))) {
      // 610 — notification d'un autre profil de la personne (cloche ≥ 610).
      const Notification = require('../models/Notification');
      const profiles = await personProfiles(userId, role);
      const r = await Notification.deleteOne({ _id: id, ...recipientFilter(profiles) });
      deleted = (r && r.deletedCount) || 0;
    }
    if (!deleted) {
      return res.status(404).json({ error: 'Notification not found.' });
    }
    await emitNotificationSync('notification.removed', { role, userId, ids: [id] });
    res.json({ ok: true });
  } catch (error) {
    logger.error('Delete notification error', error);
    res.status(500).json({ error: 'Unable to delete notification. Please try again later.' });
  }
};

const clearMyNotifications = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;
    if (!userId || !role) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }
    if (!['owner', 'sitter', 'walker'].includes(role)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner", "sitter" or "walker".' });
    }
    let deletedCount;
    const person = isPersonScope(req);
    if (person) {
      const Notification = require('../models/Notification');
      const profiles = await personProfiles(userId, role);
      const r = await Notification.deleteMany(recipientFilter(profiles));
      deletedCount = (r && r.deletedCount) || 0;
    } else {
      deletedCount = await clearNotifications({ recipientRole: role, recipientId: userId });
    }
    await emitNotificationSync('notification.removed', { role, userId, all: true, allProfiles: person });
    res.json({ deletedCount });
  } catch (error) {
    logger.error('Clear notifications error', error);
    res.status(500).json({ error: 'Unable to clear notifications. Please try again later.' });
  }
};

module.exports = {
  markMyNotificationsReadBatch, // v599
  deleteMyNotificationsBatch, // v599
  getMyNotifications,
  getMyUnreadCount,
  markMyNotificationRead,
  markMyNotificationsReadAll,
  deleteMyNotification,
  clearMyNotifications,
  emitNotificationSync, // v566 (tests)
};

