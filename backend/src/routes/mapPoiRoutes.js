/**
 * Map POI Routes — Couche 1 of the PawMap.
 *
 * Visibility: all POIs with status='active' are visible to every authenticated user
 *             (free tier). This is the hook that retains users and upsells Premium.
 *
 * Submission:
 *   POST /        → user submits a POI, starts in 'pending' status
 *   GET  /nearby  → returns active POIs near a [lng, lat] location (<= maxDistance m)
 *   GET  /:id     → single POI with reviews/photos counts
 *   GET  /mine    → POIs the current user submitted (any status)
 *
 * Moderation (admin-only — TODO wire up requireRole('admin')):
 *   GET  /admin/pending
 *   POST /admin/:id/validate
 *   POST /admin/:id/reject
 */

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const MapPOI = require('../models/MapPOI');
const { POI_CATEGORIES } = require('../models/MapPOI');
const logger = require('../utils/logger');

const router = express.Router();

// ── Helpers ──────────────────────────────────────────────────────────────────
const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };

function parseFloatOr(value, fallback) {
  const n = parseFloat(value);
  return Number.isFinite(n) ? n : fallback;
}

// ── GET /categories (public) ────────────────────────────────────────────────
router.get('/categories', (req, res) => {
  res.json({ categories: POI_CATEGORIES });
});

// ── GET /nearby (auth required — used by Map screen) ───────────────────────
router.get('/nearby', requireAuth, async (req, res) => {
  try {
    const lat = parseFloatOr(req.query.lat, null);
    const lng = parseFloatOr(req.query.lng, null);
    if (lat === null || lng === null) {
      return res.status(400).json({ error: 'Missing lat/lng query parameters.' });
    }

    const maxDistance = Math.min(parseFloatOr(req.query.maxDistance, 5000), 50000); // cap 50 km
    const category = req.query.category; // optional filter

    const filter = {
      status: 'active',
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: [lng, lat] },
          $maxDistance: maxDistance,
        },
      },
    };
    if (category && POI_CATEGORIES.includes(category)) {
      filter.category = category;
    }

    const pois = await MapPOI.find(filter)
      .limit(200)
      .select('title description category location address phone website rating reviewsCount photosCount source createdAt')
      .lean();

    res.json({ pois, count: pois.length });
  } catch (e) {
    logger.error('[mapPoi/nearby]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── GET /mine — user's own submissions ──────────────────────────────────────
router.get('/mine', requireAuth, async (req, res) => {
  try {
    const userModel = ROLE_TO_MODEL_NAME[req.user.role] || 'Owner';
    const pois = await MapPOI.find({
      submittedBy: req.user.id,
      submittedByModel: userModel,
    })
      .sort({ createdAt: -1 })
      .lean();
    res.json({ pois });
  } catch (e) {
    logger.error('[mapPoi/mine]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── GET /:id — single POI ───────────────────────────────────────────────────
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const poi = await MapPOI.findById(req.params.id).lean();
    if (!poi) return res.status(404).json({ error: 'POI not found.' });
    if (poi.status !== 'active' && String(poi.submittedBy) !== String(req.user.id)) {
      return res.status(404).json({ error: 'POI not found.' });
    }
    res.json({ poi });
  } catch (e) {
    logger.error('[mapPoi/get]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST / — submit a new POI (any auth user, starts pending) ──────────────
router.post('/', requireAuth, async (req, res) => {
  try {
    const {
      title, description, category, lat, lng, address, city,
      country, phone, website, openingHours,
    } = req.body;

    if (!title || !category) {
      return res.status(400).json({ error: 'title and category are required.' });
    }
    if (!POI_CATEGORIES.includes(category)) {
      return res.status(400).json({
        error: `Invalid category. Allowed: ${POI_CATEGORIES.join(', ')}`,
      });
    }
    const latNum = parseFloatOr(lat, null);
    const lngNum = parseFloatOr(lng, null);
    if (latNum === null || lngNum === null) {
      return res.status(400).json({ error: 'lat and lng are required numbers.' });
    }

    const userModel = ROLE_TO_MODEL_NAME[req.user.role] || 'Owner';

    const poi = new MapPOI({
      title,
      description: description || '',
      category,
      location: {
        type: 'Point',
        coordinates: [lngNum, latNum],
        city: city || '',
        country: country || '',
      },
      address: address || '',
      phone: phone || '',
      website: website || '',
      openingHours: openingHours || '',
      source: 'user',
      submittedBy: req.user.id,
      submittedByModel: userModel,
      status: 'pending',
    });

    await poi.save();
    logger.info(`[mapPoi] ${req.user.role} ${req.user.id} submitted POI "${title}" (${category})`);
    res.status(201).json({ poi, message: 'Submitted. Awaiting moderation.' });
  } catch (e) {
    logger.error('[mapPoi/create]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── PATCH /:id — edit own pending submission ───────────────────────────────
router.patch('/:id', requireAuth, async (req, res) => {
  try {
    const poi = await MapPOI.findById(req.params.id);
    if (!poi) return res.status(404).json({ error: 'POI not found.' });
    if (String(poi.submittedBy) !== String(req.user.id)) {
      return res.status(403).json({ error: 'Not your POI.' });
    }
    if (poi.status === 'active') {
      return res.status(400).json({ error: 'Approved POIs cannot be edited by users.' });
    }

    const fields = ['title', 'description', 'address', 'phone', 'website', 'openingHours'];
    fields.forEach((f) => {
      if (req.body[f] !== undefined) poi[f] = req.body[f];
    });
    if (req.body.category && POI_CATEGORIES.includes(req.body.category)) {
      poi.category = req.body.category;
    }
    const latNum = parseFloatOr(req.body.lat, null);
    const lngNum = parseFloatOr(req.body.lng, null);
    if (latNum !== null && lngNum !== null) {
      poi.location.coordinates = [lngNum, latNum];
    }
    poi.status = 'pending'; // back to review

    await poi.save();
    res.json({ poi });
  } catch (e) {
    logger.error('[mapPoi/patch]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── DELETE /:id — delete own submission ────────────────────────────────────
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const poi = await MapPOI.findById(req.params.id);
    if (!poi) return res.status(404).json({ error: 'POI not found.' });
    if (String(poi.submittedBy) !== String(req.user.id)) {
      return res.status(403).json({ error: 'Not your POI.' });
    }
    await poi.deleteOne();
    res.json({ message: 'Deleted.' });
  } catch (e) {
    logger.error('[mapPoi/delete]', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
