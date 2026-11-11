/**
 * 11/11/2026 (BOB, ordre de Daniel : « les annonces finies s'effacent sous 48 h mais avec une liste
 * d'historique ») — LECTURE SEULE.
 *
 *   GET /admin/posts-history-1111/list?page=1&limit=50&tests=0|1
 *
 * Une ligne par demande effacée automatiquement (services/postCleanupScheduler écrit la ligne juste avant
 * d'effacer). JAMAIS d'e-mail ni de téléphone : prénom, ville, services, dates, candidatures reçues, et si
 * elle avait été réservée. `pending` = demandes finies qui attendent encore leurs 48 h (seront effacées).
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];
const H48 = 48 * 3600000;

router.get('/list', requireAdmin, async (req, res) => {
  try {
    const PostArchive = require('../models/PostArchive1111');
    const Post = require('../models/Post');
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(200, Math.max(1, parseInt(req.query.limit, 10) || 50));
    const withTests = String(req.query.tests || '') === '1';
    const filter = withTests ? {} : { isTest: { $ne: true } };
    const now = new Date();
    const cutoff = new Date(now.getTime() - H48);
    const [total, rows, testsCount, pending] = await Promise.all([
      PostArchive.countDocuments(filter),
      PostArchive.find(filter).sort({ archivedAt: -1 }).skip((page - 1) * limit).limit(limit).lean(),
      PostArchive.countDocuments({ isTest: true }),
      // finies (ou service terminé) depuis moins de 48 h : encore en base, effacées bientôt
      Post.countDocuments({
        postType: 'request',
        $or: [
          { closedAt: { $ne: null, $gte: cutoff } },
          { closedAt: { $in: [null] }, endDate: { $ne: null, $lt: now, $gte: cutoff } },
          { closedAt: { $in: [null] }, endDate: { $in: [null] }, startDate: { $ne: null, $lt: now, $gte: cutoff } },
        ],
      }),
    ]);
    res.json({
      generatedAt: now.toISOString(),
      archiveEnabled: String(process.env.POST_ARCHIVE_1111 || '').trim().toLowerCase() !== 'off',
      total,
      testsCount,
      pending,
      page,
      limit,
      pages: Math.max(1, Math.ceil(total / limit)),
      items: rows.map((r) => ({
        id: String(r._id),
        postId: String(r.postId),
        ownerId: r.ownerId ? String(r.ownerId) : null,
        firstName: r.ownerFirstName || '',
        city: r.city || '',
        serviceTypes: r.serviceTypes || [],
        dateMode: r.dateMode || null,
        startDate: r.startDate || null,
        endDate: r.endDate || null,
        body: r.body || '',
        applications: r.applicationsCount || 0,
        booked: !!r.bookingId,
        bookingId: r.bookingId ? String(r.bookingId) : null,
        reason: r.reason || 'date_passee',
        createdAt: r.postCreatedAt || null,
        archivedAt: r.archivedAt || null,
        isTest: !!r.isTest,
      })),
    });
  } catch (error) {
    logger.error('[posts-history-1111] list failed', error);
    res.status(500).json({ error: 'Unable to load the history.' });
  }
});

module.exports = router;
