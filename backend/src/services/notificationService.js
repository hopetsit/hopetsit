const Notification = require('../models/Notification');
const logger = require('../utils/logger');

const safeString = (value) => (typeof value === 'string' ? value : value == null ? '' : String(value));

const createNotification = async ({
  recipientRole,
  recipientId,
  actorRole = null,
  actorId = null,
  type,
  title = '',
  body = '',
  data = {},
}) => {
  if (!recipientRole || !recipientId || !type) {
    throw new Error('recipientRole, recipientId, and type are required to create notification.');
  }

  return Notification.create({
    recipientRole,
    recipientId,
    actorRole,
    actorId,
    type,
    title: safeString(title),
    body: safeString(body),
    data: data && typeof data === 'object' ? data : {},
  });
};

const createNotificationSafe = async (payload) => {
  try {
    return await createNotification(payload);
  } catch (error) {
    // v23.1 part 50 — pino's API is logger.warn(msg, ...args). The
    // previous call passed a context object as the 2nd arg which pino
    // ignored, so the Render logs only ever showed "⚠️ Unable to
    // create notification" without ever telling us WHY. Now we
    // serialise the cause + offending payload into the message itself.
    logger.warn(
      `⚠️ Unable to create notification : ${error?.message || String(error)} | ` +
      `type=${payload?.type} role=${payload?.recipientRole} ` +
      `recipientId=${payload?.recipientId} ` +
      `titleLen=${(payload?.title || '').length} bodyLen=${(payload?.body || '').length}`,
    );
    return null;
  }
};

const listNotifications = async ({ recipientRole, recipientId, limit = 50, cursor = null }) => {
  const query = {
    recipientRole,
    recipientId,
  };
  if (cursor) {
    query._id = { $lt: cursor };
  }

  const safeLimit = Math.max(1, Math.min(Number(limit) || 50, 100));
  const items = await Notification.find(query).sort({ _id: -1 }).limit(safeLimit);
  return items;
};

const getUnreadCount = async ({ recipientRole, recipientId }) => {
  return Notification.countDocuments({
    recipientRole,
    recipientId,
    readAt: null,
  });
};

const markNotificationRead = async ({ recipientRole, recipientId, notificationId }) => {
  const updated = await Notification.findOneAndUpdate(
    { _id: notificationId, recipientRole, recipientId, readAt: null },
    { $set: { readAt: new Date() } },
    { new: true }
  );
  return updated;
};

const markAllRead = async ({ recipientRole, recipientId }) => {
  const result = await Notification.updateMany(
    { recipientRole, recipientId, readAt: null },
    { $set: { readAt: new Date() } }
  );
  return result.modifiedCount || 0;
};

module.exports = {
  createNotification,
  createNotificationSafe,
  listNotifications,
  getUnreadCount,
  markNotificationRead,
  markAllRead,
};

