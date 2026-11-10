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

// Motif d'échec affichable : seulement un code du serveur (« email_blocked:unverified », « no_email »…).
// Tout autre texte (message d'erreur d'un prestataire d'e-mail, qui peut citer une adresse) devient « error ».
const failureCode = (raw) => {
  const v = String(raw || '').trim();
  return /^[a-z_]{2,40}(:[a-z0-9_]{1,40})?$/.test(v) ? v : (v ? 'error' : 'unknown');
};
const foldFailures = (rows) => {
  const m = new Map();
  (rows || []).forEach((x) => {
    const k = `${(x && x._id && x._id.kind) || ''}|${failureCode(x && x._id && x._id.error)}`;
    m.set(k, (m.get(k) || 0) + ((x && x.n) || 0));
  });
  return [...m.entries()].map(([k, n]) => ({ kind: k.split('|')[0], reason: k.split('|')[1], n })).sort((a, b) => b.n - a.n);
};
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

router.get('/', requireAdmin, async (req, res) => {
  try {
    const svc = require('../services/sitterFree1011');
    const Free = require('../models/SitterFree1011');
    const sim = await svc.runSitterFree({ dryRun: true });
    const rows = await Free.aggregate([{ $group: { _id: { kind: '$kind', status: '$status', answer: '$answer' }, n: { $sum: 1 } } }]);
    // 10/11 (BOB) — pourquoi un envoi n'est pas parti : le motif est rangé dans le registre, on le rend lisible ici.
    const failedRows = await Free.aggregate([{ $match: { status: 'failed' } }, { $group: { _id: { kind: '$kind', error: '$error' }, n: { $sum: 1 } } }]);
    return res.json({
      ...sim,
      settings: {
        askAfterHours: svc.ASK_DELAY / 3600000, maxAskedPerRequest: svc.MAX_ASKED_PER_POST, maxPerPersonPerDay: svc.MAX_PER_PERSON_PER_DAY, maxRequestsPerRun: svc.MAX_POSTS_PER_RUN,
      },
      registry: rows.map((x) => ({ kind: x._id.kind, status: x._id.status, answer: x._id.answer || '', n: x.n })),
      failures: foldFailures(failedRows),
    });
  } catch (e) {
    logger.error('[adminSitterFree1011]', e);
    return res.status(500).json({ error: 'Unable to simulate.' });
  }
});

module.exports = router;
module.exports.failureCode = failureCode;
module.exports.foldFailures = foldFailures;
