const logger = require('../utils/logger');
const {
  listNotifications,
  getUnreadCount,
  markNotificationRead,
  markAllRead,
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
    if (!['owner', 'sitter'].includes(role)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner" or "sitter".' });
    }

    const items = await listNotifications({
      recipientRole: role,
      recipientId: userId,
      limit,
      cursor,
    });

    res.json({
      notifications: items.map(mapNotification),
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
    if (!['owner', 'sitter'].includes(role)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner" or "sitter".' });
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
    if (!['owner', 'sitter'].includes(role)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner" or "sitter".' });
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
    if (!['owner', 'sitter'].includes(role)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner" or "sitter".' });
    }

    const updatedCount = await markAllRead({ recipientRole: role, recipientId: userId });
    res.json({ updatedCount });
  } catch (error) {
    logger.error('Mark all notifications read error', error);
    res.status(500).json({ error: 'Unable to mark notifications as read. Please try again later.' });
  }
};

module.exports = {
  getMyNotifications,
  getMyUnreadCount,
  markMyNotificationRead,
  markMyNotificationsReadAll,
};

