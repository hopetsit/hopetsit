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

/**
 * Freemium hook (session avril 2026) — these 3 report types are usable by
 * FREE users so community-oriented signals (lost pet, found pet, active water
 * point) get a broad base of reporters. The other 6 types (poop, pee, hazards,
 * aggressive dog, water broken, other) remain Premium-only to keep the
 * subscription attractive. See also the frontend gating in
 * `CreateReportSheet` and the upsell banner on PawMap.
 */
const FREE_REPORT_TYPES = ['lost_pet', 'found_pet', 'water_active'];

function parseFloatOr(value, fallback) {
  const n = parseFloat(value);
  return Number.isFinite(n) ? n : fallback;
}

/** Helper: read the user's Premium status (does not block). */
async function resolvePremium(req) {
  const userId = req.user.id;
  const userModel = ROLE_TO_MODEL_NAME[req.user.role] || 'Owner';
  const sub = await UserSubscription.findOne({ userId, userModel });
  const isPremium =
    sub && sub.status === 'active' && sub.currentPeriodEnd &&
    new Date(sub.currentPeriodEnd) > new Date();
  return { isPremium, sub };
}

/** Middleware: require an active Premium subscription. Kept for endpoints
 *  that should stay strictly Premium (e.g. confirm an extension). */
async function requirePremium(req, res, next) {
  try {
    const { isPremium, sub } = await resolvePremium(req);
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

/** Middleware: attach `req.isPremium` without blocking free users. */
async function attachPremium(req, res, next) {
  try {
    const { isPremium, sub } = await resolvePremium(req);
    req.isPremium = isPremium;
    req.subscription = sub;
    next();
  } catch (e) {
    logger.error('[mapReport/attachPremium]', e);
    req.isPremium = false;
    next();
  }
}

// ── GET /types (public) ─────────────────────────────────────────────────────
router.get('/types', (req, res) => {
  res.json({
    types: REPORT_TYPES,
    freeTypes: FREE_REPORT_TYPES,
    ttlHours: REPORT_TTL_MS / 3_600_000,
  });
});

// ── GET /nearby ────────────────────────────────────────────────────────────
// Premium users see all report types. Free users only see reports of the
// freemium-whitelisted types (lost_pet, found_pet, water_active). The payload
// includes `isPremium` so the client can show an upsell banner for the rest.
router.get('/nearby', requireAuth, attachPremium, async (req, res) => {
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

    if (type && REPORT_TYPES.includes(type)) {
      // Explicit type filter — free users may only request free types.
      if (!req.isPremium && !FREE_REPORT_TYPES.includes(type)) {
        return res.status(402).json({
          error: 'This report category is Premium-only.',
          code: 'PREMIUM_REQUIRED',
          upgradeUrl: '/subscriptions/plans',
        });
      }
      filter.type = type;
    } else if (!req.isPremium) {
      // No type filter + free user → restrict to free types.
      filter.type = { $in: FREE_REPORT_TYPES };
    }

    const reports = await MapReport.find(filter)
      .limit(200)
      .select('type note photoUrl location reporterId reporterModel expiresAt createdAt confirmations')
      .lean();

    const enriched = reports.map((r) => ({
      ...r,
      hoursRemaining: Math.max(0, (new Date(r.expiresAt).getTime() - Date.now()) / 3_600_000),
      confirmationsCount: (r.confirmations || []).length,
      confirmations: undefined,
    }));

    res.json({
      reports: enriched,
      count: enriched.length,
      isPremium: Boolean(req.isPremium),
      freeTypes: FREE_REPORT_TYPES,
    });
  } catch (e) {
    logger.error('[mapReport/nearby]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST / — create new report ─────────────────────────────────────────────
// Free users may create any of the FREE_REPORT_TYPES; Premium is required for
// the 6 remaining categories (poop, pee, water_broken, hazard, aggressive_dog,
// other).
router.post('/', requireAuth, attachPremium, async (req, res) => {
  try {
    const { type, note, photoUrl, lat, lng, city } = req.body;

    if (!type || !REPORT_TYPES.includes(type)) {
      return res.status(400).json({
        error: `Invalid type. Allowed: ${REPORT_TYPES.join(', ')}`,
      });
    }

    // Freemium gate.
    if (!req.isPremium && !FREE_REPORT_TYPES.includes(type)) {
      return res.status(402).json({
        error: 'This report type is Premium-only.',
        code: 'PREMIUM_REQUIRED',
        freeTypes: FREE_REPORT_TYPES,
        upgradeUrl: '/subscriptions/plans',
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
// Attach the freemium whitelist so other modules (e.g. adminRoutes admin stats)
// can import it without re-declaring the list.
module.exports.FREE_REPORT_TYPES = FREE_REPORT_TYPES;
