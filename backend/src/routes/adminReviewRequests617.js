/**
 * 617 (ADA, 16/10/2026) — LECTURE du registre des demandes d'avis (ReviewRequest617 :
 * « Comment s'est passée la garde avec <Prénom> ? », envoyée au propriétaire quand une
 * réservation passe en `completed`). Preuve en production que le mécanisme tourne.
 * LECTURE SEULE, aucune adresse e-mail renvoyée.
 *   GET /admin/review-requests-617?limit=50
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

router.get('/', requireAdmin, async (req, res) => {
  try {
    const Registry = require('../models/ReviewRequest617');
    const limit = Math.min(200, Math.max(1, parseInt(req.query.limit, 10) || 50));
    const [total, failed, last] = await Promise.all([
      Registry.countDocuments({}),
      Registry.countDocuments({ status: 'failed' }),
      Registry.find({}).select('bookingId ownerId revieweeRole revieweeId status createdAt')
        .sort({ createdAt: -1 }).limit(limit).lean(),
    ]);
    res.json({ total, failed, requests: last });
  } catch (e) {
    logger.error('[admin/review-requests-617]', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
