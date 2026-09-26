/**
 * v590 — onglet « Dernière connexion » de l'admin. Enregistre un début de
 * session par personne connectée : la première requête authentifiée après
 * SESSION_GAP_MS d'inactivité. Appelé sans attendre depuis requireAuth :
 * une erreur ici ne bloque jamais une requête.
 */
const logger = require('./logger');

const SESSION_GAP_MS = 30 * 60 * 1000;
const _seen = new Map(); // userId → dernier passage (ms)
// v594 — Daniel (26/09) : son frère, actif le jour même, restait « Vu il y a
// 5 j » sur la PawMap. `lastSeenAt` n'était écrit qu'à la déconnexion du
// socket de chat — jamais quand le serveur redémarre (chaque mise en ligne)
// ni quand le téléphone coupe l'app. On le pose aussi sur l'activité réelle,
// sur les 3 profils de la personne, au plus toutes les 5 minutes.
const TOUCH_GAP_MS = 5 * 60 * 1000;
const _touched = new Map(); // userId → dernière écriture de lastSeenAt (ms)

async function touchLastSeen(id, now) {
  const last = _touched.get(id);
  if (last && now - last < TOUCH_GAP_MS) return;
  _touched.set(id, now);
  if (_touched.size > 50000) _touched.clear();
  try {
    const { identityGroup } = require('./identityGroup');
    const g = await identityGroup(id);
    const ids = g && Array.isArray(g.ids) && g.ids.length ? g.ids : [id];
    const at = new Date(now);
    await Promise.all(Object.values(MODEL_PATH).map((mp) =>
      require(mp).updateMany({ _id: { $in: ids } }, { $set: { lastSeenAt: at } })));
  } catch (e) {
    logger.warn(`[activity] lastSeenAt ${e?.message || e}`);
  }
}

const MODEL_PATH = { owner: '../models/Owner', sitter: '../models/Sitter', walker: '../models/Walker' };

function _header(req, name) {
  const v = req && req.headers ? req.headers[name] : '';
  return String(v || '').slice(0, 40);
}

/** Vrai si ce passage ouvre une nouvelle session (pur, testable). */
function isNewSession(last, now, gap = SESSION_GAP_MS) {
  return !last || now - last >= gap;
}

async function recordActivity(req, userId, role, now = Date.now()) {
  const id = String(userId || '');
  if (!id || !MODEL_PATH[role]) return null;
  touchLastSeen(id, now).catch(() => {});
  const last = _seen.get(id);
  _seen.set(id, now);
  if (!isNewSession(last, now)) return null;
  if (_seen.size > 50000) _seen.clear();
  try {
    const ActivityEvent = require('../models/ActivityEvent');
    // Après un redémarrage du serveur la mémoire est vide : on relit la base.
    if (!last) {
      const prev = await ActivityEvent.findOne({ userId: id }).sort({ at: -1 }).select('at').lean();
      if (prev && !isNewSession(new Date(prev.at).getTime(), now)) return null;
    }
    const doc = await require(MODEL_PATH[role]).findById(id).select('city country location.city').lean();
    const platform = _header(req, 'x-app-platform').toLowerCase()
      || (/android/i.test(_header(req, 'user-agent')) ? 'android'
        : /iphone|ipad|darwin|cfnetwork/i.test(_header(req, 'user-agent')) ? 'ios' : '');
    return await ActivityEvent.create({
      userId: id,
      role,
      at: new Date(now),
      platform,
      appVersion: _header(req, 'x-app-version'),
      city: (doc && ((doc.location && doc.location.city) || doc.city)) || '',
      country: (doc && doc.country) || '',
    });
  } catch (e) {
    logger.warn(`[activity] ${e?.message || e}`);
    return null;
  }
}

/** Personnes actives sur `days` jours : dernière session + nombre de sessions. */
async function activitySummary({ days = 30, limit = 500 } = {}) {
  const ActivityEvent = require('../models/ActivityEvent');
  const since = new Date(Date.now() - Math.max(1, Math.min(90, days)) * 86400000);
  const rows = await ActivityEvent.aggregate([
    { $match: { at: { $gte: since } } },
    { $sort: { at: -1 } },
    { $group: {
      _id: '$userId',
      role: { $first: '$role' },
      lastAt: { $first: '$at' },
      platform: { $first: '$platform' },
      appVersion: { $first: '$appVersion' },
      city: { $first: '$city' },
      country: { $first: '$country' },
      sessions: { $sum: 1 },
    } },
    { $sort: { lastAt: -1 } },
    { $limit: limit },
  ]);
  const byRole = { owner: [], sitter: [], walker: [] };
  for (const r of rows) if (byRole[r.role]) byRole[r.role].push(r._id);
  const names = {};
  for (const role of Object.keys(byRole)) {
    if (!byRole[role].length) continue;
    // eslint-disable-next-line no-await-in-loop
    const docs = await require(MODEL_PATH[role]).find({ _id: { $in: byRole[role] } })
      .select('name email status').lean();
    for (const d of docs) names[String(d._id)] = d;
  }
  return rows.map((r) => ({
    userId: r._id, role: r.role, lastAt: r.lastAt, sessions: r.sessions,
    platform: r.platform, appVersion: r.appVersion, city: r.city, country: r.country,
    name: (names[r._id] && names[r._id].name) || '', email: (names[r._id] && names[r._id].email) || '',
    status: (names[r._id] && names[r._id].status) || 'deleted',
  }));
}

async function userSessions(userId, limit = 30) {
  const ActivityEvent = require('../models/ActivityEvent');
  return ActivityEvent.find({ userId: String(userId) }).sort({ at: -1 }).limit(limit).lean();
}

module.exports = { recordActivity, touchLastSeen, activitySummary, userSessions, isNewSession, SESSION_GAP_MS, _seen };
