const express = require('express');

const { requireAuth } = require('../middleware/auth');
const {
  getMyNotifications,
  getMyUnreadCount,
  markMyNotificationRead,
  markMyNotificationsReadAll,
  deleteMyNotification,
  clearMyNotifications,
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
// v565 — Daniel : « toutes les notifications Apple ne marchent pas » → test type par
// type depuis l'app (Profil › Aide › Tester mes notifications). Le corps accepte
// `type` (n'importe quelle clé du catalogue locales/*/notifications.json) ; les
// variables de gabarit reçoivent des valeurs d'exemple. Limité à 20 tests / 10 min
// par utilisateur (chaque test envoie un push + un e-mail au compte lui-même).
const TEST_SAMPLE_DATA = {
  senderName: 'HoPetSit', ownerName: 'Camille', sitterName: 'Alex', walkerName: 'Sam',
  providerName: 'Alex', petName: 'Rex', name: 'Camille', preview: 'Ceci est un test.',
  serviceType: 'pet_sitting', city: 'Paris', amount: '24,00', currency: 'EUR', total: '24,00',
  price: '24,00', date: new Date().toISOString().slice(0, 10), time: '10:00', duration: '30',
  rating: '5', minutes: '30', hours: '4', reason: 'test', plan: 'PawPremium', tier: 'bronze',
  requesterName: 'Camille', friendName: 'Alex', inviterName: 'Camille', memberName: 'Alex',
  code: '1234', count: '1',
  // v566 — audit : variables de gabarit qui manquaient (textes troués pendant le test).
  comment: 'Super prestation, merci !', photoCount: '3', mood: '😊', avgRating: '4,9',
  autoConfirmHours: '2', bookingId: 'TEST',
};
const _testFireHits = new Map();
router.post('/test-fire', requireAuth, async (req, res) => {
  const userId = req.user?.id;
  const role = req.user?.role;
  if (!userId || !role) {
    return res.status(401).json({ error: 'Auth required.' });
  }
  const key = `${role}:${userId}`;
  const now = Date.now();
  const hits = (_testFireHits.get(key) || []).filter((t) => now - t < 10 * 60 * 1000);
  if (hits.length >= 20) {
    return res.status(429).json({ error: 'Trop de tests : réessaie dans 10 minutes.' });
  }
  hits.push(now);
  _testFireHits.set(key, hits);
  const requested = String(req.body?.type || 'NEW_MESSAGE').trim();
  logger.info(`[notif.test-fire] requested by ${key} type=${requested}`);
  try {
    await sendNotification({
      userId,
      role,
      type: requested,
      data: {
        ...TEST_SAMPLE_DATA,
        conversationId: 'debug',
        messageId: 'debug',
        isTest: '1',
      },
      actor: { role: 'system', id: null },
    });
    return res.json({ ok: true, type: requested, message: 'Notification fired. Check Render logs for [notif.*] lines and your device for the push/email.' });
  } catch (e) {
    logger.error(`[notif.test-fire] failed : ${e?.message || e}`);
    return res.status(500).json({ error: e?.message || String(e) });
  }
});

// v565 — GET /notifications/test-types : les clés du catalogue (langue fr = référence).
// v566 — ajoute `items: [{ type, title }]` : `title` = titre du gabarit rendu dans la langue
// du compte (?lang= prioritaire, sinon appLocale / language), variables = valeurs d'exemple.
// `types` RESTE une liste de chaînes : l'app 565 publiée fait `types.map(toString)`.
router.get('/test-types', requireAuth, async (req, res) => {
  try {
    const fs = require('fs');
    const path = require('path');
    const file = path.join(__dirname, '..', 'locales', 'fr', 'notifications.json');
    const keys = Object.keys(JSON.parse(fs.readFileSync(file, 'utf8') || '{}')).sort();
    const { renderNotificationContent, resolveAppLocaleAcrossRoles } = require('../services/notificationSender');
    let lang = String(req.query?.lang || '').toLowerCase().slice(0, 2) || null;
    if (!lang) {
      try {
        const role = req.user?.role;
        const Model = role === 'sitter' ? require('../models/Sitter')
          : role === 'walker' ? require('../models/Walker') : require('../models/Owner');
        const u = await Model.findById(req.user.id).select('appLocale language email oldId').lean();
        lang = (await resolveAppLocaleAcrossRoles(u, req.user.id)) || u?.language || null;
      } catch (_) { lang = null; }
    }
    const items = keys.map((type) => {
      const loc = renderNotificationContent(type, TEST_SAMPLE_DATA, lang);
      return { type, title: (loc && loc.title ? loc.title : type).trim() };
    });
    return res.json({ types: keys, items });
  } catch (e) {
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

// v409 — Daniel : "effacer notification". Suppression d'une notif ou de toutes
// (scoping strict au destinataire côté service).
router.delete('/my/clear', requireAuth, clearMyNotifications);
router.delete('/my/:id', requireAuth, deleteMyNotification);

module.exports = router;

