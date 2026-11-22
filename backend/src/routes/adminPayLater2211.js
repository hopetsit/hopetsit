/**
 * 2211 — « Réserver, payer plus tard » : LECTURE SEULE pour l'admin.
 *   GET /admin/pay-later-2211 → compteurs (en attente, échéance passée non encore balayée, payées, libérées,
 *   annulées autrement) + les 50 dernières lignes (identifiants, rôle, montant, dates, état, relances).
 * Jamais d'adresse e-mail, de téléphone ni de nom. Rien n'est écrit, rien n'est envoyé.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

router.get('/', requireAdmin, async (req, res) => {
  try {
    return res.json(await require('../services/payLater2211').adminSummary());
  } catch (e) {
    logger.error('[adminPayLater2211]', e);
    return res.status(500).json({ error: 'Unable to list pay-later bookings.' });
  }
});

module.exports = router;
