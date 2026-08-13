const logger = require('../utils/logger');
const {
  listNotifications,
  getUnreadCount,
  markNotificationRead,
  markAllRead,
  deleteNotification,
  clearNotifications,
} = require('../services/notificationService');

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
    const items = await listNotifications({
      recipientRole: role,
      recipientId: userId,
      limit,
      cursor,
    });

    // v497 — Daniel : « je suis en espagnol mais les notifs du site sont en FR ».
    // On RE-REND titre/corps dans la langue COURANTE du lecteur au lieu de la
    // langue figée à l'envoi → app + web suivent la langue choisie. Fallback :
    // texte stocké si pas de template.
    // v530 — cascade fiabilisée : 1) ?lang= envoyé par le client (la langue UI
    // RÉELLE au moment de la lecture, insensible aux docs pas synchronisés),
    // 2) appLocale cherchée sur les 3 docs de rôle de la personne (l'app ne la
    // synchronisait que sur le rôle courant), 3) champ libre `language`.
    const VALID_LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja'];
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

    const unreadCount = await getUnreadCount({ recipientRole: role, recipientId: userId });
    res.json({ unreadCount });
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

    const updated = await markNotificationRead({
      recipientRole: role,
      recipientId: userId,
      notificationId: id,
    });

    if (!updated) {
      return res.status(404).json({ error: 'Notification not found (or already read).' });
    }

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

    const updatedCount = await markAllRead({ recipientRole: role, recipientId: userId });
    res.json({ updatedCount });
  } catch (error) {
    logger.error('Mark all notifications read error', error);
    res.status(500).json({ error: 'Unable to mark notifications as read. Please try again later.' });
  }
};

// v409 — Daniel : "effacer notification" (web + app).
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
    const deleted = await deleteNotification({
      recipientRole: role,
      recipientId: userId,
      notificationId: id,
    });
    if (!deleted) {
      return res.status(404).json({ error: 'Notification not found.' });
    }
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
    const deletedCount = await clearNotifications({ recipientRole: role, recipientId: userId });
    res.json({ deletedCount });
  } catch (error) {
    logger.error('Clear notifications error', error);
    res.status(500).json({ error: 'Unable to clear notifications. Please try again later.' });
  }
};

module.exports = {
  getMyNotifications,
  getMyUnreadCount,
  markMyNotificationRead,
  markMyNotificationsReadAll,
  deleteMyNotification,
  clearMyNotifications,
};

