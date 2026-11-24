/**
 * 2411 (BOB) — réponses par e-mail postées dans les fils : LECTURE SEULE pour l'admin.
 *   GET /admin/inbound-replies-2411 → état du relevé de la boîte (actif, dernière lecture réussie, dernière erreur),
 *   compteurs par résultat et par raison de refus, et les 50 dernières lignes (fil, rôle, résultat, longueur, date).
 * Jamais d'adresse e-mail, de nom ni de texte de message. Rien n'est écrit, rien n'est envoyé.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

router.get('/', requireAdmin, async (req, res) => {
  try {
    const Inbound = require('../models/InboundReply2411');
    const [byStatus, byReason, rows] = await Promise.all([
      Inbound.aggregate([{ $group: { _id: '$status', n: { $sum: 1 } } }]),
      Inbound.aggregate([{ $match: { status: 'rejected' } }, { $group: { _id: '$reason', n: { $sum: 1 } } }]),
      Inbound.find({}).sort({ createdAt: -1 }).limit(50).select('conversationId role status reason chars receivedAt createdAt').lean(),
    ]);
    const counts = { posted: 0, rejected: 0, claimed: 0 };
    byStatus.forEach((x) => { counts[x._id] = x.n; });
    return res.json({
      mailbox: require('../services/inboundReply2411').status(),
      counts,
      rejectedBy: Object.fromEntries(byReason.map((x) => [x._id || 'unknown', x.n])),
      rows: rows.map((r) => ({ conversationId: r.conversationId, role: r.role, status: r.status, reason: r.reason, chars: r.chars, receivedAt: r.receivedAt, at: r.createdAt })),
    });
  } catch (e) {
    logger.error('[adminInboundReplies2411]', e);
    return res.status(500).json({ error: 'Unable to list inbound replies.' });
  }
});

// 2411 (BOB) — « le propriétaire a regardé ta proposition » : SIMULATION (rien n'est envoyé) + compteurs du registre.
router.get('/owner-viewed', requireAdmin, async (req, res) => {
  try {
    const Nudge = require('../models/OwnerViewedNudge2411');
    const svc = require('../services/ownerViewedNudge2411');
    const [sim, byStatus] = await Promise.all([
      svc.runOnce({ dryRun: true }),
      Nudge.aggregate([{ $group: { _id: '$status', n: { $sum: 1 } } }]),
    ]);
    return res.json({ enabled: svc.enabled(), simulation: sim, counts: Object.fromEntries(byStatus.map((x) => [x._id, x.n])) });
  } catch (e) {
    logger.error('[adminOwnerViewed2411]', e);
    return res.status(500).json({ error: 'Unable to simulate.' });
  }
});

module.exports = router;
