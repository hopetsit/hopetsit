/**
 * Map Report Routes — Couche 2 of the PawMap.
 *
 * Ephemeral 48h signals (poop, pee, hazards, active water points, ...).
 * Premium-only feature:
 *   - Only active Premium users can create or view reports.
 *   - Free users get a 403 with an upsell hint.
 *
 * TTL is enforced by the MongoDB TTL index on `expiresAt` (48h) plus a
 * helper scheduler (services/mapReportTtlScheduler.js) that logs stats.
 */

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const MapReport = require('../models/MapReport');
const { REPORT_TYPES, REPORT_TTL_MS } = require('../models/MapReport');
const UserSubscription = require('../models/UserSubscription');
const logger = require('../utils/logger');

const router = express.Router();

const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };

function parseFloatOr(value, fallback) {
  const n = parseFloat(value);
  return Number.isFinite(n) ? n : fallback;
}

/** Middleware: require an active Premium subscription. */
async function requirePremium(req, res, next) {
  try {
    const userId = req.user.id;
    const userModel = ROLE_TO_MODEL_NAME[req.user.role] || 'Owner';
    const sub = await UserSubscription.findOne({ userId, userModel });

    const isPremium =
      sub && sub.status === 'active' && sub.currentPeriodEnd &&
      new Date(sub.currentPeriodEnd) > new Date();

    if (!isPremium) {
      return res.status(402).json({
        error: 'Premium subscription required.',
        code: 'PREMIUM_REQUIRED',
        upgradeUrl: '/subscriptions/plans',
      });
    }
    req.subscription = sub;
    return next();
  } catch (e) {
    logger.error('[mapReport/requirePremium]', e);
    return res.status(500).json({ error: e.message });
  }
}

// ── GET /types (public) ─────────────────────────────────────────────────────
router.get('/types', (req, res) => {
  res.json({ types: REPORT_TYPES, ttlHours: REPORT_TTL_MS / 3_600_000 });
});

// ── GET /nearby — Premium-only ─────────────────────────────────────────────
router.get('/nearby', requireAuth, requirePremium, async (req, res) => {
  try {
    const lat = parseFloatOr(req.query.lat, null);
    const lng = parseFloatOr(req.query.lng, null);
    if (lat === null || lng === null) {
      return res.status(400).json({ error: 'Missing lat/lng.' });
    }
    const maxDistance = Math.min(parseFloatOr(req.query.maxDistance, 3000), 30000);
    const type = req.query.type;

    const filter = {
      hidden: false,
      expiresAt: { $gt: new Date() },
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: [lng, lat] },
          $maxDistance: maxDistance,
        },
      },
    };
    if (type && REPORT_TYPES.includes(type)) filter.type = type;

    const reports = await MapReport.find(filter)
      .limit(200)
      .select('type note photoUrl location reporterId reporterModel expiresAt createdAt confirmations')
      .lean();

    // Enrich with a TTL countdown + confirmations count for the UI
    const enriched = reports.map((r) => ({
      ...r,
      hoursRemaining: Math.max(0, (new Date(r.expiresAt).getTime() - Date.now()) / 3_600_000),
      confirmationsCount: (r.confirmations || []).length,
      confirmations: undefined, // don't leak the user list
    }));

    res.json({ reports: enriched, count: enriched.length });
  } catch (e) {
    logger.error('[mapReport/nearby]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST / — create new report (Premium) ───────────────────────────────────
router.post('/', requireAuth, requirePremium, async (req, res) => {
  try {
    const { type, note, photoUrl, lat, lng, city } = req.body;

    if (!type || !REPORT_TYPES.includes(type)) {
      return res.status(400).json({
        error: `Invalid type. Allowed: ${REPORT_TYPES.join(', ')}`,
      });
    }
    const latNum = parseFloatOr(lat, null);
    const lngNum = parseFloatOr(lng, null);
    if (latNum === null || lngNum === null) {
      return res.status(400).json({ error: 'lat and lng are required.' });
    }

    const userModel = ROLE_TO_MODEL_NAME[req.user.role] || 'Owner';
    const report = new MapReport({
      type,
      note: note || '',
      photoUrl: photoUrl || '',
      location: {
        type: 'Point',
        coordinates: [lngNum, latNum],
        city: city || '',
      },
      reporterId: req.user.id,
      reporterModel: userModel,
      // expiresAt defaults to now + 48h via schema default
    });

    await report.save();
    logger.info(`[mapReport] ${req.user.role} ${req.user.id} created ${type} report`);
    res.status(201).json({ report });
  } catch (e) {
    logger.error('[mapReport/create]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /:id/confirm — extend life by 12h (Premium) ───────────────────────
router.post('/:id/confirm', requireAuth, requirePremium, async (req, res) => {
  try {
    const report = await MapReport.findById(req.params.id);
    if (!report || report.hidden) {
      return res.status(404).json({ error: 'Report not found.' });
    }

    const userModel = ROLE_TO_MODEL_NAME[req.user.role] || 'Owner';
    // prevent duplicate confirms
    const already = (report.confirmations || []).some(
      (c) => String(c.userId) === String(req.user.id) && c.userModel === userModel,
    );
    if (!already) {
      report.confirmations.push({ userId: req.user.id, userModel });
      // extend by 12h, cap at 96h from creation
      const MAX_TTL = 96 * 60 * 60 * 1000;
      const creationTime = new Date(report.createdAt).getTime();
      const cappedEnd = creationTime + MAX_TTL;
      const extended = new Date(Math.min(
        new Date(report.expiresAt).getTime() + 12 * 60 * 60 * 1000,
        cappedEnd,
      ));
      report.expiresAt = extended;
      await report.save();
    }

    res.json({
      confirmationsCount: report.confirmations.length,
      expiresAt: report.expiresAt,
    });
  } catch (e) {
    logger.error('[mapReport/confirm]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /:id/flag — moderation signal (any auth user) ─────────────────────
router.post('/:id/flag', requireAuth, async (req, res) => {
  try {
    const { reason } = req.body;
    const report = await MapReport.findById(req.params.id);
    if (!report) return res.status(404).json({ error: 'Report not found.' });

    const userModel = ROLE_TO_MODEL_NAME[req.user.role] || 'Owner';
    const already = (report.flags || []).some(
      (f) => String(f.userId) === String(req.user.id) && f.userModel === userModel,
    );
    if (!already) {
      report.flags.push({ userId: req.user.id, userModel, reason: reason || '' });
      if (report.flags.length >= 3) report.hidden = true;
      await report.save();
      logger.info(`[mapReport] ${req.params.id} flagged (${report.flags.length} total)`);
    }
    res.json({ flagsCount: report.flags.length, hidden: report.hidden });
  } catch (e) {
    logger.error('[mapReport/flag]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── DELETE /:id — remove your own report ───────────────────────────────────
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const report = await MapReport.findById(req.params.id);
    if (!report) return res.status(404).json({ error: 'Report not found.' });
    if (String(report.reporterId) !== String(req.user.id)) {
      return res.status(403).json({ error: 'Not your report.' });
    }
    await report.deleteOne();
    res.json({ message: 'Deleted.' });
  } catch (e) {
    logger.error('[mapReport/delete]', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
