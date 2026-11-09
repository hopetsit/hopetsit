/**
 * 1011 (FLO) — message « un gardien est libre et vous attend » : SIMULATION depuis l'admin.
 *   GET /admin/sitter-free-1011?dryRun=1 → ce qui partirait maintenant (rien d'écrit ni d'envoyé) :
 *   questions « toujours libre ? », messages au propriétaire, et la raison de chaque exclusion,
 *   + état (allumé ou non) et registre des envois déjà faits.
 * Jamais d'adresse e-mail ni de téléphone dans la réponse : identifiants, prénoms, prix.
 * Cette route ne sait QUE simuler : l'envoi réel n'a lieu que par le balayage, si SITTER_FREE_1011=on.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

router.get('/', requireAdmin, async (req, res) => {
  try {
    const svc = require('../services/sitterFree1011');
    const Free = require('../models/SitterFree1011');
    const sim = await svc.runSitterFree({ dryRun: true });
    const rows = await Free.aggregate([{ $group: { _id: { kind: '$kind', status: '$status', answer: '$answer' }, n: { $sum: 1 } } }]);
    return res.json({
      ...sim,
      settings: {
        askAfterHours: svc.ASK_DELAY / 3600000, maxAskedPerRequest: svc.MAX_ASKED_PER_POST, maxPerPersonPerDay: svc.MAX_PER_PERSON_PER_DAY, maxRequestsPerRun: svc.MAX_POSTS_PER_RUN,
      },
      registry: rows.map((x) => ({ kind: x._id.kind, status: x._id.status, answer: x._id.answer || '', n: x.n })),
    });
  } catch (e) {
    logger.error('[adminSitterFree1011]', e);
    return res.status(500).json({ error: 'Unable to simulate.' });
  }
});

module.exports = router;
