/**
 * 607 (PAM, 02/10/2026) — mini-peluches de la PawMap. Contrat JSON :
 * ~/hopetsit-social/CONTRAT_607_peluches.md (lu par LEO pour le site).
 *
 *   GET  /plush/active?lat=&lng=   peluches à 5 km (hors Balade : nearbyCount seul, jamais les positions)
 *   POST /plush/:id/catch {lat,lng} capture (< 30 m, Balade en cours…)
 *   GET  /plush/collection          mes captures (3 profils confondus)
 *   GET  /plush/rules               barème (public)
 *   GET  /plush/badges/:userId      badge « Collectionneur » d'un membre
 */
const express = require('express');
const { requireAuth } = require('../middleware/auth');
const plush = require('../services/plushService607');
const logger = require('../utils/logger');

const router = express.Router();

// Barème (public) : lu par le catalogue PawPoints de l'app et par le site.
router.get('/rules', (req, res) => res.json(plush.PLUSH_RULES));

// Badge « Collectionneur » d'un membre (fiche).
router.get('/badges/:userId', requireAuth, async (req, res) => {
  try {
    const id = String(req.params.userId || '');
    if (!/^[a-f0-9]{24}$/i.test(id)) return res.status(400).json({ error: 'userId required.' });
    return res.json({ collector: await plush.hasCollectorBadge(id) });
  } catch (e) {
    logger.error('[plush/badges]', e);
    return res.status(500).json({ error: 'Unable to read badges.' });
  }
});

router.get('/active', requireAuth, async (req, res) => {
  try {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res.status(400).json({ error: 'lat and lng are required.', code: 'POSITION_REQUIRED' });
    }
    return res.json(await plush.listActive({ userId: req.user.id, lat, lng }));
  } catch (e) {
    logger.error('[plush/active]', e);
    return res.status(500).json({ error: 'Unable to read plushies.' });
  }
});

router.get('/collection', requireAuth, async (req, res) => {
  try {
    return res.json(await plush.collection({ userId: req.user.id }));
  } catch (e) {
    logger.error('[plush/collection]', e);
    return res.status(500).json({ error: 'Unable to read collection.' });
  }
});

router.post('/:id/catch', requireAuth, async (req, res) => {
  try {
    const out = await plush.catchPlush({
      userId: req.user.id,
      role: String(req.user.role || 'owner').toLowerCase(),
      plushId: req.params.id,
      lat: Number(req.body && req.body.lat),
      lng: Number(req.body && req.body.lng),
    });
    return res.json(out);
  } catch (e) {
    if (e instanceof plush.PlushError) {
      return res.status(e.status).json({ error: e.code, code: e.code, ...e.extra });
    }
    logger.error('[plush/catch]', e);
    return res.status(500).json({ error: 'Unable to catch plush.' });
  }
});

module.exports = router;
