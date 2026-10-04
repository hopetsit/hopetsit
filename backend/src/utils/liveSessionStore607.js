// 607 (PAM, 02/10/2026) — persistance des sessions en direct (voir
// models/LiveSession607.js). Écriture « au fil de l'eau » regroupée par
// diffuseur (au plus une écriture toutes les 3 s), effacement immédiat à
// l'arrêt, rechargement au démarrage du serveur. Jamais bloquant : une base
// lente ne ralentit ni la socket ni la route HTTP.
const logger = require('./logger');

const FLUSH_MS = 3000;
const TTL_MS = 24 * 60 * 60 * 1000;
const _pending = new Map(); // userId → session (dernier état)
const _timers = new Map();
let _enabled = true;

function _model() {
  return require('../models/LiveSession607');
}
function _ready() {
  try {
    return require('mongoose').connection.readyState === 1;
  } catch (_) {
    return false;
  }
}

function toDoc(s) {
  return {
    userId: String(s.userId),
    role: s.role || '',
    lat: s.lat,
    lng: s.lng,
    city: s.city || '',
    at: s.at,
    lastSeenAt: s.lastSeenAt,
    startedAt: s.startedAt,
    duration: s.duration || 'until_stop',
    expiresAt: s.expiresAt || null,
    lastStillActiveNoticeAt: s.lastStillActiveNoticeAt,
    trail: Array.isArray(s.trail) ? s.trail.slice(-240) : [],
    // 611 (PAM) — reprise d'appareil : appareil qui diffuse, appareils écartés.
    deviceId: s.deviceId || '',
    displaced: Array.isArray(s.displaced) ? s.displaced.map(String) : [],
    personIds: Array.isArray(s.personIds) ? s.personIds.map(String) : [],
    purgeAt: new Date(Number(s.lastSeenAt || Date.now()) + TTL_MS),
  };
}

function fromDoc(d) {
  return {
    userId: String(d.userId),
    role: d.role || '',
    lat: d.lat,
    lng: d.lng,
    city: d.city || '',
    at: d.at,
    lastSeenAt: d.lastSeenAt,
    startedAt: d.startedAt,
    duration: d.duration || 'until_stop',
    expiresAt: d.expiresAt || null,
    lastStillActiveNoticeAt: d.lastStillActiveNoticeAt || d.lastSeenAt,
    trail: Array.isArray(d.trail) ? d.trail.map((p) => [Number(p[0]), Number(p[1]), Number(p[2])]) : [],
    deviceId: d.deviceId || '', // 611
    displaced: Array.isArray(d.displaced) ? d.displaced.map(String) : [],
    personIds: Array.isArray(d.personIds) ? d.personIds.map(String) : [],
  };
}

async function flush(userId) {
  _timers.delete(userId);
  const s = _pending.get(userId);
  _pending.delete(userId);
  if (!s || !_enabled || !_ready()) return;
  try {
    await _model().updateOne({ userId }, { $set: toDoc(s) }, { upsert: true });
  } catch (e) {
    logger.warn(`[liveStore] écriture ${userId} : ${e.message}`);
  }
}

/** Mémorise l'état d'une session (création : tout de suite ; sinon ≤ 3 s). */
function save(s, { now = false } = {}) {
  if (!s || !s.userId || !_enabled) return;
  const id = String(s.userId);
  _pending.set(id, s);
  if (now) {
    clearTimeout(_timers.get(id));
    return flush(id);
  }
  if (!_timers.has(id)) {
    const t = setTimeout(() => { flush(id).catch(() => {}); }, FLUSH_MS);
    if (t.unref) t.unref();
    _timers.set(id, t);
  }
  return undefined;
}

/** Session terminée : la ligne disparaît (et toute écriture en attente). */
function remove(userId) {
  const id = String(userId);
  clearTimeout(_timers.get(id));
  _timers.delete(id);
  _pending.delete(id);
  if (!_enabled || !_ready()) return Promise.resolve();
  return _model().deleteOne({ userId: id }).catch((e) => {
    logger.warn(`[liveStore] effacement ${id} : ${e.message}`);
  });
}

/** Démarrage du serveur : renvoie les sessions encore valables (< 24 h). */
async function loadAll({ now = Date.now() } = {}) {
  if (!_ready()) return [];
  try {
    const docs = await _model().find({ lastSeenAt: { $gte: now - TTL_MS } }).lean();
    return docs.map(fromDoc);
  } catch (e) {
    logger.warn(`[liveStore] rechargement : ${e.message}`);
    return [];
  }
}

/** Tests : vide les écritures en attente. */
async function flushAllForTests() {
  await Promise.all([..._timers.keys()].map((id) => {
    clearTimeout(_timers.get(id));
    return flush(id);
  }));
}

module.exports = { save, remove, loadAll, toDoc, fromDoc, flushAllForTests, _setEnabled: (v) => { _enabled = v; } };
