const express = require('express');
const mongoose = require('mongoose');
const Report = require('../models/Report');
const { requireAuth } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();

const TARGET_TYPES = ['profile', 'comment', 'message', 'review', 'post', 'photo'];
const REASONS = ['spam', 'harassment', 'inappropriate', 'fraud', 'safety', 'other'];

/**
 * POST /reports
 * Body:
 *   { targetType, targetId, reason, details?, snapshot?,
 *     conversationId?, postId?, photoUrl? }
 *
 * Any authenticated user (owner or sitter) can file a report. We enforce
 * a soft rate-limit of 1 duplicate report per hour (same reporter + same
 * target) so the admin queue stays signal-heavy.
 */
router.post('/', requireAuth, async (req, res) => {
  try {
    const {
      targetType,
      targetId,
      reason = 'other',
      details = '',
      snapshot = '',
      conversationId = null,
      postId = null,
      photoUrl = '',
    } = req.body || {};

    if (!TARGET_TYPES.includes(targetType)) {
      return res.status(400).json({ error: 'Invalid targetType.' });
    }
    if (!REASONS.includes(reason)) {
      return res.status(400).json({ error: 'Invalid reason.' });
    }
    if (!targetId || !mongoose.Types.ObjectId.isValid(targetId)) {
      // Photos may not have an ObjectId target — fall back to a synthetic
      // id derived from the photo URL so we can still store the report.
      if (targetType !== 'photo') {
        return res.status(400).json({ error: 'Invalid targetId.' });
      }
    }

    const reporterRole = req.user.role === 'sitter' ? 'sitter' : 'owner';
    const reporterId = req.user.id;

    // Soft-dedupe: don't accept the same (reporter, target) in under an hour.
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const recent = await Report.findOne({
      reporterId,
      targetType,
      targetId: targetId || undefined,
      createdAt: { $gte: oneHourAgo },
    }).lean();
    if (recent) {
      return res.status(200).json({ ok: true, deduped: true, report: recent });
    }

    const doc = await Report.create({
      reporterRole,
      reporterId,
      targetType,
      targetId: targetId && mongoose.Types.ObjectId.isValid(targetId)
        ? targetId
        : new mongoose.Types.ObjectId(),
      reason,
      details: String(details || '').slice(0, 2000),
      snapshot: String(snapshot || '').slice(0, 4000),
      contextIds: {
        conversationId:
          conversationId && mongoose.Types.ObjectId.isValid(conversationId)
            ? conversationId
            : null,
        postId:
          postId && mongoose.Types.ObjectId.isValid(postId) ? postId : null,
        photoUrl: String(photoUrl || ''),
      },
    });

    logger.info(
      `[report] ${reporterRole} ${reporterId} reported ${targetType} ${targetId} for ${reason}`
    );
    res.status(201).json({ ok: true, report: doc });
  } catch (e) {
    logger.error('[reports] POST failed', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
