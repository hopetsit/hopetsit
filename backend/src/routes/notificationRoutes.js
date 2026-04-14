const express = require('express');

const { requireAuth } = require('../middleware/auth');
const {
  getMyNotifications,
  getMyUnreadCount,
  markMyNotificationRead,
  markMyNotificationsReadAll,
} = require('../controllers/notificationController');

const router = express.Router();

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

