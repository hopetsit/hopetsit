'use strict';
/**
 * 2910 (BOB) — simulation de la relance de paiement : GET /admin/payment-reminder-2910
 * = ce qui partirait maintenant (dryRun), sans rien envoyer. L'envoi réel n'a lieu que par le balayage.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin')];

router.get('/', requireAdmin, async (req, res) => {
  try {
    const { runPaymentReminders } = require('../services/paymentReminder2910');
    const Booking = require('../models/Booking');
    const sim = await runPaymentReminders({ dryRun: true });
    const registry = await Booking.aggregate([
      { $match: { 'paymentReminder2910.sent.0': { $exists: true } } },
      { $unwind: '$paymentReminder2910.sent' },
      { $group: { _id: { slot: '$paymentReminder2910.sent.slot', paid: { $eq: ['$paymentStatus', 'paid'] } }, n: { $sum: 1 } } },
    ]);
    return res.json({ ...sim, registry: registry.map((x) => ({ slot: x._id.slot, paidAfter: x._id.paid, n: x.n })) });
  } catch (e) {
    logger.error('[adminPaymentReminder2910]', e);
    return res.status(500).json({ error: 'Unable to simulate.' });
  }
});

module.exports = router;
