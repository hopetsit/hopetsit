'use strict';

/**
 * 616 (ZOE, 08/10/2026) — rattrapage des profils SANS position (accord écrit de
 * Daniel, 08/10). Détail de la règle : utils/cityPosition616.js.
 *
 *   POST /api/v1/admin/positions-from-city?dryRun=1   → simulation (rien n'est écrit)
 *   POST /api/v1/admin/positions-from-city             → écriture
 *        options : ?limit=300 (profils examinés au plus par appel)
 *                  corps { "cityQueries": { "Asnières": "Asnières-sur-Seine" } } : nom à
 *                  chercher pour une ville ambiguë, décidé par un humain après la simulation
 *
 * Réponse : compteurs + une ligne par profil examiné (id, rôle, ville, pays,
 * coordonnées du centre-ville trouvées ou raison du refus). JAMAIS d'e-mail,
 * de téléphone ni d'adresse. Le temps de réponse est borné (~75 s) : si
 * `remaining` > 0, rappeler la route (les villes déjà résolues sont en cache).
 * Aucun e-mail, aucune notification n'est envoyé.
 */

const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin')];

const truthy = (v) => ['1', 'true', 'yes', 'oui'].includes(String(v == null ? '' : v).trim().toLowerCase());

router.post('/', requireAdmin, async (req, res) => {
  try {
    const q = req.query || {};
    const b = req.body || {};
    const dryRun = truthy(q.dryRun != null ? q.dryRun : b.dryRun);
    const limit = Math.max(1, Math.min(1000, parseInt(q.limit || b.limit || '300', 10) || 300));
    const { backfillPositionsFromCity } = require('../utils/cityPosition616');
    // Corps facultatif : { "cityQueries": { "Asnières": "Asnières-sur-Seine" } }
    const cityQueries = b.cityQueries && typeof b.cityQueries === 'object' ? b.cityQueries : null;
    const out = await backfillPositionsFromCity({ dryRun, limit, cityQueries });
    logger.info(`[admin/positions-from-city] ${dryRun ? 'simulation' : 'écriture'} : examinés ${out.examined}, `
      + `posés ${out.set}, à poser ${out.wouldSet}, laissés ${out.skipped}, reste ${out.remaining}`);
    return res.json(out);
  } catch (e) {
    logger.error('[admin/positions-from-city]', e);
    return res.status(500).json({ error: 'positions_from_city_failed' });
  }
});

module.exports = router;
