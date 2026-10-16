/**
 * 1610 (SAM, 16/10/2026) — admin « Partagez votre fiche » (ordre de Daniel du 16/10).
 *   GET  /admin/sitter-invite-1610            → registre (combien envoyés, par rôle,
 *                                               par ville, échecs) + candidats restants
 *                                               (dryRun, rien n'est envoyé). Aucun e-mail renvoyé.
 *   POST /admin/sitter-invite-1610/run        { testOnly = true, limit = 25, dryRun = false, ignoreNight = false }
 *        → un passage à la main. `testOnly` vaut TRUE par défaut : il faut écrire
 *          testOnly:false pour toucher de vrais comptes (le planificateur le fait
 *          déjà tout seul, étalé, de jour). Journalisé (auditAdmin).
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

router.get('/', requireAdmin, async (req, res) => {
  try {
    const Registry = require('../models/SitterInvite1610');
    const svc = require('../services/sitterInvite1610');
    const rows = await Registry.find({}).select('recipientRole city status testOnly createdAt').sort({ createdAt: -1 }).limit(2000).lean();
    const byRole = {}; const byCity = {};
    let failed = 0; let test = 0;
    for (const r of rows) {
      byRole[r.recipientRole] = (byRole[r.recipientRole] || 0) + 1;
      byCity[r.city || '?'] = (byCity[r.city || '?'] || 0) + 1;
      if (r.status === 'failed') failed += 1;
      if (r.testOnly) test += 1;
    }
    const remaining = await svc.runSitterInvites({ dryRun: true });
    res.json({
      total: rows.length, realSent: rows.length - failed - test, testSent: test, failed, byRole, byCity,
      last: rows.slice(0, 20).map((r) => ({ role: r.recipientRole, city: r.city, status: r.status, testOnly: r.testOnly, at: r.createdAt })),
      remaining: { eligible: remaining.eligible, waitingNight: remaining.waitingNight, byCity: remaining.byCity, excluded: remaining.skipped },
      schedulerOff: String(process.env.SITTER_INVITE_1610_OFF || '') === '1',
    });
  } catch (e) {
    logger.error('[admin/sitter-invite-1610]', e);
    res.status(500).json({ error: 'Lecture impossible.' });
  }
});

router.post('/run', requireAdmin, async (req, res) => {
  try {
    const b = req.body || {};
    const testOnly = b.testOnly !== false;
    const dryRun = b.dryRun === true;
    const limit = Math.min(200, Math.max(0, Number(b.limit) || 25));
    const svc = require('../services/sitterInvite1610');
    // ignoreNight : essai immédiat sur les comptes +test, ignoré dès que testOnly est faux.
    const r = await svc.runSitterInvites({ testOnly, dryRun, limit, ignoreNight: b.ignoreNight === true });
    res.json(r);
  } catch (e) {
    logger.error('[admin/sitter-invite-1610/run]', e);
    res.status(500).json({ error: 'Passage impossible.' });
  }
});

module.exports = router;
