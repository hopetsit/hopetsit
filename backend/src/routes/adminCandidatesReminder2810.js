/**
 * 2810 (BOB) — relance « candidats non consultés » : simulation seulement depuis l'admin.
 *   GET /admin/candidates-reminder-2810  → ce qui partirait maintenant (rien d'écrit ni d'envoyé),
 *   + état (activé ou non) et registre des envois déjà faits.
 * L'envoi réel n'a lieu que par le balayage, sauf si CANDIDATES_REMINDER_2810=off.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

router.get('/', requireAdmin, async (req, res) => {
  try {
    const svc = require('../services/candidatesReminder2810');
    const Reminder = require('../models/CandidatesReminder2810');
    const sim = await svc.runCandidatesReminders({ dryRun: true });
    const bySlot = await Reminder.aggregate([{ $group: { _id: { slot: '$slot', status: '$status' }, n: { $sum: 1 } } }]);
    return res.json({ ...sim, registry: bySlot.map((x) => ({ slot: x._id.slot, status: x._id.status, n: x.n })) });
  } catch (e) {
    logger.error('[adminCandidatesReminder2810]', e);
    return res.status(500).json({ error: 'Unable to simulate.' });
  }
});

module.exports = router;
