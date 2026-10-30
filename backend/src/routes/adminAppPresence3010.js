'use strict';
/**
 * 3010 (ADA, demande de Daniel 30/10 11 h : « un cadre "nombre de personnes dans l'app" ») — LECTURE SEULE.
 *
 *   GET /api/v1/admin/app-presence
 *   → { total, online, active24h, active7d, installed, previous: { active24h, active7d }, basis: {…}, generatedAt }
 *  - total      : toutes les personnes inscrites (connectées ou pas), mêmes exclusions.
 *
 * Une PERSONNE = un e-mail (jusqu'à 3 profils owner/sitter/walker). Exclus : comptes de test et internes
 * (+test, hopetsit@, dadaciao84@, sonde — utils/userCounts.isInternalEmail), équipe (isStaff) et comptes
 * bloqués/suspendus (status ≠ active) : une personne est exclue dès qu'un de ses profils l'est.
 *  - online     : sockets PRÉSENTS maintenant (sockets/emitter.getOnlineUserIds : au premier plan, signe de vie < 2 min).
 *  - active24h / active7d : personnes ayant au moins un DÉBUT DE SESSION RÉELLE (ActivityEvent, origine app ou web,
 *                 jamais nos scripts ni l'admin — utils/ownerReturn2610.REAL_SESSION_FILTER) dans la fenêtre ;
 *                 previous = même mesure sur la fenêtre d'avant (24-48 h, 7-14 j) pour la variation.
 *  - installed  : personnes ayant au moins un jeton push (fcmDevices non vide). Pas de variation : aucun historique.
 *  - today / week : { joined, left } — 30/10 15 h 30 (Daniel : « le total ne bouge pas ») : joined = personnes dont le
 *                 PREMIER profil a été créé depuis minuit (heure de Paris) / depuis 7 jours, mêmes exclusions ;
 *                 left = personnes (emailHash distinct) ayant supprimé leur compte (AccountDeletion) sur la même fenêtre.
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

/** Minuit (début du jour) dans un fuseau, en ms UTC. */
function startOfDayTz(nowMs, tz) {
  const fmt = new Intl.DateTimeFormat('en-US', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
  const p = {}; fmt.formatToParts(new Date(nowMs)).forEach((x) => { p[x.type] = x.value; });
  const wall = Date.UTC(+p.year, +p.month - 1, +p.day, (+p.hour) % 24, +p.minute, +p.second);
  const offset = wall - Math.floor(nowMs / 1000) * 1000;
  return Date.UTC(+p.year, +p.month - 1, +p.day) - offset;
}

/** Lit les 3 collections : id → { key (e-mail), excluded, hasPush, createdAt }. Pur après lecture (testé). */
function indexPeople(docs) {
  const byId = new Map();
  const excludedKeys = new Set();
  const firstCreated = new Map(); // key → ms de création du PREMIER profil
  for (const d of docs) {
    const key = norm(plainEmail(d.email)) || `id:${d._id}`;
    const excluded = isInternalEmail(key) || d.isStaff === true || (d.status && d.status !== 'active');
    if (excluded) excludedKeys.add(key);
    const hasPush = Array.isArray(d.fcmDevices) && d.fcmDevices.some((t) => t && String(t.token || '').trim());
    byId.set(String(d._id), { key, hasPush });
    const c = d.createdAt ? new Date(d.createdAt).getTime() : NaN;
    if (!Number.isNaN(c) && (!firstCreated.has(key) || c < firstCreated.get(key))) firstCreated.set(key, c);
  }
  return { byId, excludedKeys, firstCreated };
}

/** Personnes (non exclues) dont le premier profil a été créé à partir de `from` (ms). */
function countJoined(idx, from) {
  let n = 0;
  for (const [key, c] of idx.firstCreated) if (c >= from && !idx.excludedKeys.has(key)) n += 1;
  return n;
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

async function computePresence({ Owner, Sitter, Walker, ActivityEvent, AccountDeletion, onlineIds, now = Date.now(), tz = 'Europe/Paris' }) {
  const sel = 'email isStaff status fcmDevices createdAt';
  const [o, s, w] = await Promise.all([Owner.find({}).select(sel).lean(), Sitter.find({}).select(sel).lean(), Walker.find({}).select(sel).lean()]);
  const idx = indexPeople([...o, ...s, ...w]);
  const { REAL_SESSION_FILTER } = require('../utils/ownerReturn2610');
  const distinct = async (from, to) => ActivityEvent.distinct('userId', { ...REAL_SESSION_FILTER, at: { $gte: new Date(from), $lt: new Date(to) } });
  const [a24, a24prev, a7, a7prev] = await Promise.all([
    distinct(now - DAY, now + 60000), distinct(now - 2 * DAY, now - DAY),
    distinct(now - 7 * DAY, now + 60000), distinct(now - 14 * DAY, now - 7 * DAY),
  ]);
  const installedIds = [...idx.byId.entries()].filter(([, p]) => p.hasPush).map(([id]) => id);
  // 30/10 15 h 30 — mouvements : arrivées (premier profil créé) et départs (suppressions de compte, une par personne).
  const dayStart = startOfDayTz(now, tz); const weekStart = now - 7 * DAY;
  const leftSince = async (from) => (AccountDeletion ? (await AccountDeletion.distinct('emailHash', { deletedAt: { $gte: new Date(from) } })).length : 0);
  const [leftToday, leftWeek] = await Promise.all([leftSince(dayStart), leftSince(weekStart)]);
  const today = { joined: countJoined(idx, dayStart), left: leftToday };
  const week = { joined: countJoined(idx, weekStart), left: leftWeek };
  // 30/10 11 h 20 (Daniel) — EN PREMIER : toutes les personnes inscrites, connectées ou pas (mêmes exclusions).
  const total = countPeople([...idx.byId.keys()], idx);
  return {
    total,
    online: countPeople([...(onlineIds || [])], idx),
    active24h: countPeople(a24, idx),
    active7d: countPeople(a7, idx),
    installed: countPeople(installedIds, idx),
    today,
    week,
    previous: { active24h: countPeople(a24prev, idx), active7d: countPeople(a7prev, idx) },
    excludedPeople: idx.excludedKeys.size,
    basis: {
      person: 'un e-mail = une personne (3 profils max) ; exclus : comptes de test/internes, équipe (isStaff), bloqués (status ≠ active)',
      total: 'toutes les personnes inscrites, connectées ou pas (mêmes exclusions)',
      online: 'sockets présents maintenant (premier plan, signe de vie < 2 min) — sockets/emitter.getOnlineUserIds',
      active: 'débuts de session RÉELLE (ActivityEvent, origine app ou web, scripts et admin exclus) dans la fenêtre ; previous = fenêtre précédente (24-48 h, 7-14 j)',
      installed: 'au moins un jeton push (fcmDevices) sur un des profils ; pas de variation (aucun historique)',
      moves: 'today/week : joined = personnes dont le premier profil est créé depuis minuit (' + tz + ') / 7 jours, mêmes exclusions ; left = suppressions de compte (AccountDeletion, une par personne)',
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
      ActivityEvent: require('../models/ActivityEvent'), AccountDeletion: require('../models/AccountDeletion').AccountDeletion, onlineIds,
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
module.exports.startOfDayTz = startOfDayTz;
