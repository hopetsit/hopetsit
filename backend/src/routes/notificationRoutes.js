const express = require('express');

const { requireAuth } = require('../middleware/auth');
const {
  getMyNotifications,
  getMyUnreadCount,
  markMyNotificationRead,
  markMyNotificationsReadAll,
} = require('../controllers/notificationController');
const { sendNotification } = require('../services/notificationSender');
const logger = require('../utils/logger');

const router = express.Router();

/**
 * v23.1 part 49 — debug endpoint : force a test notification to flow
 * through sendNotification end-to-end. Useful when the production logs
 * don't show whether notifs are being attempted at all (e.g. when the
 * webhook fires but [notif.entry] never appears). Hit this from the
 * authenticated user's device — they should immediately get an in-app
 * bell notification, push (if FCM token registered), and email (if
 * SMTP configured). Whatever fails, the [notif.*] log lines surface
 * the cause.
 *
 * Auth-protected so only logged-in users can trigger it on their own
 * account ; no admin role needed.
 */
router.post('/test-fire', requireAuth, async (req, res) => {
  const userId = req.user?.id;
  const role = req.user?.role;
  if (!userId || !role) {
    return res.status(401).json({ error: 'Auth required.' });
  }
  logger.info(`[notif.test-fire] requested by ${role}:${userId}`);
  try {
    // We use NEW_MESSAGE template because it exists for all 3 roles
    // and all 6 locales — guaranteed renderable.
    await sendNotification({
      userId,
      role,
      type: 'NEW_MESSAGE',
      data: {
        senderName: 'HoPetSit Test',
        preview: 'Test notification from /notifications/test-fire',
        conversationId: 'debug',
        messageId: 'debug',
      },
      actor: { role: 'system', id: null },
    });
    return res.json({ ok: true, message: 'Notification fired. Check Render logs for [notif.*] lines and your device for the push/email.' });
  } catch (e) {
    logger.error(`[notif.test-fire] failed : ${e?.message || e}`);
    return res.status(500).json({ error: e?.message || String(e) });
  }
});

/**
 * @swagger
 * /notifications/my:
 *   get:
 *     summary: Get my notifications (Owner or Sitter)
 *     tags: [Notifications]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *           maximum: 100
 *         description: Page size
 *       - in: query
 *         name: cursor
 *         schema:
 *           type: string
 *         description: Pagination cursor (last notification id from previous page)
 *     responses:
 *       200:
 *         description: Notifications retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 notifications:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Notification'
 *                 nextCursor:
 *                   type: string
 *                   nullable: true
 *                 count:
 *                   type: integer
 *       401:
 *         description: Unauthorized
 */
router.get('/my', requireAuth, getMyNotifications);

/**
 * @swagger
 * /notifications/my/unread-count:
 *   get:
 *     summary: Get my unread notifications count (Owner or Sitter)
 *     tags: [Notifications]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Unread count retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 unreadCount:
 *                   type: integer
 *       401:
 *         description: Unauthorized
 */
router.get('/my/unread-count', requireAuth, getMyUnreadCount);

/**
 * @swagger
 * /notifications/my/{id}/read:
 *   patch:
 *     summary: Mark a notification as read (Owner or Sitter)
 *     tags: [Notifications]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Notification ID
 *     responses:
 *       200:
 *         description: Notification marked as read
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 notification:
 *                   $ref: '#/components/schemas/Notification'
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Notification not found (or already read)
 */
router.patch('/my/:id/read', requireAuth, markMyNotificationRead);

/**
 * @swagger
 * /notifications/my/read-all:
 *   patch:
 *     summary: Mark all my notifications as read (Owner or Sitter)
 *     tags: [Notifications]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Notifications updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 updatedCount:
 *                   type: integer
 *       401:
 *         description: Unauthorized
 */
router.patch('/my/read-all', requireAuth, markMyNotificationsReadAll);

module.exports = router;

