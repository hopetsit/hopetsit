'use strict';
/**
 * 3010 (ADA, demande de Daniel 30/10 11 h : « un cadre "nombre de personnes dans l'app" ») — LECTURE SEULE.
 *
 *   GET /api/v1/admin/app-presence
 *   → { online, active24h, active7d, installed, previous: { active24h, active7d }, basis: {…}, generatedAt }
 *
 * Une PERSONNE = un e-mail (jusqu'à 3 profils owner/sitter/walker). Exclus : comptes de test et internes
 * (+test, hopetsit@, dadaciao84@, sonde — utils/userCounts.isInternalEmail), équipe (isStaff) et comptes
 * bloqués/suspendus (status ≠ active) : une personne est exclue dès qu'un de ses profils l'est.
 *  - online     : sockets PRÉSENTS maintenant (sockets/emitter.getOnlineUserIds : au premier plan, signe de vie < 2 min).
 *  - active24h / active7d : personnes ayant au moins un DÉBUT DE SESSION RÉELLE (ActivityEvent, origine app ou web,
 *                 jamais nos scripts ni l'admin — utils/ownerReturn2610.REAL_SESSION_FILTER) dans la fenêtre ;
 *                 previous = même mesure sur la fenêtre d'avant (24-48 h, 7-14 j) pour la variation.
 *  - installed  : personnes ayant au moins un jeton push (fcmDevices non vide). Pas de variation : aucun historique.
 * Aucun e-mail dans la réponse.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const logger = require('../utils/logger');
const { isInternalEmail } = require('../utils/userCounts');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin')];
const DAY = 86400000;

const plainEmail = (stored) => {
  try { return require('../utils/encryption').decrypt(stored || '') || ''; } catch (_) { return String(stored || ''); }
};
const norm = (e) => String(e || '').trim().toLowerCase();

/** Lit les 3 collections : id → { key (e-mail), excluded, hasPush }. Pur après lecture (testé). */
function indexPeople(docs) {
  const byId = new Map();
  const excludedKeys = new Set();
  for (const d of docs) {
    const key = norm(plainEmail(d.email)) || `id:${d._id}`;
    const excluded = isInternalEmail(key) || d.isStaff === true || (d.status && d.status !== 'active');
    if (excluded) excludedKeys.add(key);
    const hasPush = Array.isArray(d.fcmDevices) && d.fcmDevices.some((t) => t && String(t.token || '').trim());
    byId.set(String(d._id), { key, hasPush });
  }
  return { byId, excludedKeys };
}

/** Compte les personnes (clés distinctes, exclues retirées) parmi des ids de profils. */
function countPeople(ids, idx) {
  const keys = new Set();
  for (const id of ids) {
    const p = idx.byId.get(String(id));
    if (!p || idx.excludedKeys.has(p.key)) continue;
    keys.add(p.key);
  }
  return keys.size;
}

async function computePresence({ Owner, Sitter, Walker, ActivityEvent, onlineIds, now = Date.now() }) {
  const sel = 'email isStaff status fcmDevices';
  const [o, s, w] = await Promise.all([Owner.find({}).select(sel).lean(), Sitter.find({}).select(sel).lean(), Walker.find({}).select(sel).lean()]);
  const idx = indexPeople([...o, ...s, ...w]);
  const { REAL_SESSION_FILTER } = require('../utils/ownerReturn2610');
  const distinct = async (from, to) => ActivityEvent.distinct('userId', { ...REAL_SESSION_FILTER, at: { $gte: new Date(from), $lt: new Date(to) } });
  const [a24, a24prev, a7, a7prev] = await Promise.all([
    distinct(now - DAY, now + 60000), distinct(now - 2 * DAY, now - DAY),
    distinct(now - 7 * DAY, now + 60000), distinct(now - 14 * DAY, now - 7 * DAY),
  ]);
  const installedIds = [...idx.byId.entries()].filter(([, p]) => p.hasPush).map(([id]) => id);
  return {
    online: countPeople([...(onlineIds || [])], idx),
    active24h: countPeople(a24, idx),
    active7d: countPeople(a7, idx),
    installed: countPeople(installedIds, idx),
    previous: { active24h: countPeople(a24prev, idx), active7d: countPeople(a7prev, idx) },
    excludedPeople: idx.excludedKeys.size,
    basis: {
      person: 'un e-mail = une personne (3 profils max) ; exclus : comptes de test/internes, équipe (isStaff), bloqués (status ≠ active)',
      online: 'sockets présents maintenant (premier plan, signe de vie < 2 min) — sockets/emitter.getOnlineUserIds',
      active: 'débuts de session RÉELLE (ActivityEvent, origine app ou web, scripts et admin exclus) dans la fenêtre ; previous = fenêtre précédente (24-48 h, 7-14 j)',
      installed: 'au moins un jeton push (fcmDevices) sur un des profils ; pas de variation (aucun historique)',
    },
    generatedAt: new Date(now).toISOString(),
  };
}

router.get('/', requireAdmin, async (req, res) => {
  try {
    const { getOnlineUserIds } = require('../sockets/emitter');
    const onlineIds = await getOnlineUserIds().catch(() => new Set());
    const out = await computePresence({
      Owner: require('../models/Owner'), Sitter: require('../models/Sitter'), Walker: require('../models/Walker'),
      ActivityEvent: require('../models/ActivityEvent'), onlineIds,
    });
    return res.json(out);
  } catch (e) {
    logger.error('[adminAppPresence3010]', e);
    return res.status(500).json({ error: 'Unable to compute presence.' });
  }
});

module.exports = router;
module.exports.computePresence = computePresence;
module.exports.indexPeople = indexPeople;
module.exports.countPeople = countPeople;
