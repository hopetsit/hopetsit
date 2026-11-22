/**
 * 2211 — « Proposer mon prix » : LECTURE SEULE pour l'admin.
 *   GET /admin/price-offers-2211 → compteurs par statut (en attente, acceptées, refusées, expirées,
 *   annulées) + les 50 dernières propositions (montant, total d'origine, statut, dates).
 * Jamais d'adresse e-mail, de téléphone ni de nom : identifiants, rôles, montants.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

router.get('/', requireAdmin, async (req, res) => {
  try {
    return res.json(await require('../services/priceOffer2211').adminSummary());
  } catch (e) {
    logger.error('[adminPriceOffers2211]', e);
    return res.status(500).json({ error: 'Unable to list price offers.' });
  }
});

module.exports = router;
