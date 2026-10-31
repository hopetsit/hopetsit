/**
 * 3110 (ADA) — relance « posez vos dates » : SIMULATION seulement depuis l'admin.
 *   GET /admin/dates-reminder-3110 → ce qui partirait maintenant (rien d'écrit ni d'envoyé), l'état
 *   (activée ou non), le registre COMMUN des relances (2810 + dates) et le nombre de relances déjà
 *   parties par demande (jamais plus de 3 au total).
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

router.get('/', requireAdmin, async (req, res) => {
  try {
    const svc = require('../services/datesReminder3110');
    const Reminder = require('../models/CandidatesReminder2810');
    const sim = await svc.runDatesReminders({ dryRun: true });
    const [bySlot, perPost] = await Promise.all([
      Reminder.aggregate([{ $group: { _id: { slot: '$slot', status: '$status' }, n: { $sum: 1 } } }]),
      Reminder.aggregate([{ $group: { _id: '$postId', n: { $sum: 1 } } }, { $group: { _id: '$n', posts: { $sum: 1 } } }]),
    ]);
    return res.json({
      ...sim,
      registry: bySlot.map((x) => ({ slot: x._id.slot, status: x._id.status, n: x.n })),
      postsByReminderCount: perPost.map((x) => ({ reminders: x._id, posts: x.posts })).sort((a, b) => a.reminders - b.reminders),
      maxPerPost: svc.MAX_TOTAL,
    });
  } catch (e) {
    logger.error('[adminDatesReminder3110]', e);
    return res.status(500).json({ error: 'Unable to simulate.' });
  }
});

module.exports = router;
