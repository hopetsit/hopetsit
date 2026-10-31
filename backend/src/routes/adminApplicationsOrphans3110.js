'use strict';
/**
 * 3110 (ADA, bug vu par ZOE au contrôle du 631) — LECTURE SEULE.
 *
 *   GET /api/v1/admin/applications-3110/orphans
 *   → { total, byStatus, visible, hidden: { total, byStatus, reasons: { postMissing, postHidden, closedPending } },
 *       postIdNull, people: { test, real }, oldestHiddenDays, newestHiddenDays, examples: [...], generatedAt }
 *
 * Compte les candidatures que GET /applications(/my) ne renvoie plus (utils/applicationsVisible3110.js) :
 * demande supprimée, masquée par la modération, ou fermée avec candidature restée `pending`.
 * « test » = propriétaire OU prestataire interne (+test, hopetsit@, dadaciao84@ — utils/userCounts.isInternalEmail)
 * ou équipe (isStaff). Aucun e-mail, aucun nom dans la réponse : identifiants et âges seulement.
 * Ne supprime rien.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const logger = require('../utils/logger');
const { isInternalEmail } = require('../utils/userCounts');
const { isApplicationVisible, postInfoByIds, idOf } = require('../utils/applicationsVisible3110');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin')];
const DAY = 86400000;

const plainEmail = (stored) => {
  try { return require('../utils/encryption').decrypt(stored || '') || ''; } catch (_) { return String(stored || ''); }
};

async function internalIds(Model, ids) {
  const out = new Set();
  if (!ids.length) return out;
  const docs = await Model.find({ _id: { $in: ids } }).select('email isStaff').lean();
  for (const d of docs) if (d.isStaff === true || isInternalEmail(plainEmail(d.email))) out.add(String(d._id));
  return out;
}

router.get('/orphans', requireAdmin, async (req, res) => {
  try {
    const Application = require('../models/Application');
    const Owner = require('../models/Owner'); const Sitter = require('../models/Sitter'); const Walker = require('../models/Walker');
    const apps = await Application.find({}).select('postId ownerId sitterId walkerId status createdAt').lean();
    const info = await postInfoByIds(apps.map((a) => a.postId));

    const count = () => ({ pending: 0, accepted: 0, rejected: 0 });
    const bump = (c, st) => { c[st] = (c[st] || 0) + 1; };
    const byStatus = count(); const hiddenBy = count();
    const reasons = { postMissing: 0, postHidden: 0, closedPending: 0 };
    let postIdNull = 0; const hiddenApps = [];
    for (const a of apps) {
      bump(byStatus, a.status || 'pending');
      if (!idOf(a.postId)) { postIdNull += 1; continue; }
      const i = info.get(idOf(a.postId));
      if (isApplicationVisible(a, i)) continue;
      hiddenApps.push(a); bump(hiddenBy, a.status || 'pending');
      if (!i || !i.exists) reasons.postMissing += 1;
      else if (i.hidden) reasons.postHidden += 1;
      else reasons.closedPending += 1;
    }

    const uniq = (arr) => [...new Set(arr.filter(Boolean))];
    const [intOwners, intSitters, intWalkers] = await Promise.all([
      internalIds(Owner, uniq(hiddenApps.map((a) => idOf(a.ownerId)))),
      internalIds(Sitter, uniq(hiddenApps.map((a) => idOf(a.sitterId)))),
      internalIds(Walker, uniq(hiddenApps.map((a) => idOf(a.walkerId)))),
    ]);
    const isTest = (a) => intOwners.has(idOf(a.ownerId)) || intSitters.has(idOf(a.sitterId)) || intWalkers.has(idOf(a.walkerId));
    const people = { test: 0, real: 0, realPending: 0, realOwners: new Set() };
    const now = Date.now(); let oldest = null; let newest = null;
    for (const a of hiddenApps) {
      const t = a.createdAt ? new Date(a.createdAt).getTime() : NaN;
      if (!Number.isNaN(t)) { oldest = oldest === null ? t : Math.min(oldest, t); newest = newest === null ? t : Math.max(newest, t); }
      if (isTest(a)) people.test += 1;
      else { people.real += 1; if ((a.status || 'pending') === 'pending') people.realPending += 1; people.realOwners.add(idOf(a.ownerId)); }
    }
    const examples = hiddenApps
      .filter((a) => !isTest(a)).slice(0, 10)
      .map((a) => ({ id: String(a._id), postId: idOf(a.postId), status: a.status, ageDays: a.createdAt ? Math.round((now - new Date(a.createdAt).getTime()) / DAY) : null }));

    res.json({
      total: apps.length,
      byStatus,
      visible: apps.length - hiddenApps.length,
      hidden: { total: hiddenApps.length, byStatus: hiddenBy, reasons },
      postIdNull,
      people: { test: people.test, real: people.real, realPending: people.realPending, realOwners: people.realOwners.size },
      oldestHiddenDays: oldest === null ? null : Math.round((now - oldest) / DAY),
      newestHiddenDays: newest === null ? null : Math.round((now - newest) / DAY),
      examples,
      basis: 'hidden = candidatures que GET /applications(/my) ne renvoie plus : demande supprimée (postMissing), masquée (postHidden), fermée et restée pending (closedPending) ; test = propriétaire ou prestataire interne/équipe ; rien n\'est supprimé',
      generatedAt: new Date().toISOString(),
    });
  } catch (e) {
    logger.error('[admin/applications-3110] orphans', e);
    res.status(500).json({ error: 'Impossible de compter les candidatures orphelines.' });
  }
});

module.exports = router;
