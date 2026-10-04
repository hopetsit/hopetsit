/**
 * 611 (PAM, 04/10/2026) — REPRISE DU DIRECT SUR UN AUTRE TÉLÉPHONE.
 *
 * Cam (capture du 04/10, 17 h 30, app 610) : « En direct de mon autre iPhone
 * qui est resté à la maison. Du coup je ne peux pas être en direct avec ce
 * iPhone. » Le direct suit la personne (v589) : tant que l'iPhone de la
 * maison envoyait ses positions, l'iPhone en main n'avait que « Arrêter ».
 *
 * Règles :
 *   1. `POST /friends/live-takeover {deviceId}` (app ouverte) = UN geste :
 *      la Balade en cours passe sur le profil et l'appareil qui la reprend,
 *      avec la MÊME heure de départ, le même tracé, la même durée. Ce n'est
 *      pas un arrêt : ni `liveShareStoppedAt`, ni `map:friend-offline`, ni fin
 *      des demandes de suivi ; les suiveurs (followers589, rangés par
 *      personne) ne bougent pas.
 *   2. L'ancien appareil est prévenu par `map:self-live` :
 *        {active:false, reason:'device_takeover', keepDeviceId}
 *      — une app ≤ 610 s'arrête (comportement « arrêté ailleurs ») ; une app
 *      611 s'arrête si `keepDeviceId` n'est pas le sien et affiche « Direct
 *      repris sur ton autre téléphone » ; celle qui reprend l'ignore. Puis
 *        {active:true, reason:'device_takeover', deviceId}
 *      — l'ancien appareil affiche « direct sur ton autre téléphone ».
 *   3. Les positions TARDIVES de l'ancien appareil (socket, HTTP, battement,
 *      service de fond) sont ignorées tant que la Balade reprise dure. Une
 *      ancienne app n'envoie pas d'identifiant : « sans identifiant » est
 *      alors la valeur écartée — l'app 611 en envoie toujours un.
 *   4. Un arrêt voulu (stopEverywhere) ou la fin de la Balade lève tout :
 *      l'ancien téléphone peut relancer SA Balade plus tard.
 */
const logger = require('./logger');

/** id de profil (n'importe lequel de la personne) → { sessionKey, deviceId, displaced:Set } */
const _guards = new Map();

const _clean = (v) => String(v == null ? '' : v).trim().slice(0, 80);

/** Identifiant d'appareil d'une requête HTTP (corps ou en-tête). */
function deviceIdOfReq(req) {
  const b = (req && req.body) || {};
  const h = (req && req.headers) || {};
  return _clean(b.deviceId || h['x-live-device'] || '');
}

function _sessionAlive(sessionKey) {
  try {
    return !!require('../sockets/mapSocket').getLiveSession(sessionKey);
  } catch (_) {
    return false;
  }
}

/** Vrai si cet appareil a été remplacé par une reprise encore en cours. */
function isDisplaced(userId, deviceId) {
  const g = _guards.get(String(userId));
  if (!g) return false;
  if (!_sessionAlive(g.sessionKey)) {
    clearFor([...g.ids]);
    return false;
  }
  const id = _clean(deviceId);
  if (id && id === g.deviceId) return false;
  return g.displaced.has(id);
}

/** Première position d'une Balade : on retient l'appareil qui diffuse. */
function noteDevice(session, deviceId) {
  const id = _clean(deviceId);
  if (session && id && !session.deviceId) session.deviceId = id;
}

function clearFor(ids = []) {
  for (const id of ids) _guards.delete(String(id));
}

function _arm(ids, s) {
  const guard = {
    sessionKey: String(s.userId),
    deviceId: s.deviceId || '',
    displaced: new Set(Array.isArray(s.displaced) ? s.displaced.map(_clean) : []),
    ids: new Set(ids.map(String)),
  };
  for (const id of guard.ids) _guards.set(id, guard);
}

/** Au redémarrage du serveur : les reprises en cours sont réarmées. */
function rearmFromSession(s) {
  if (!s || !Array.isArray(s.displaced) || !s.displaced.length) return;
  const ids = Array.isArray(s.personIds) && s.personIds.length ? s.personIds : [s.userId];
  _arm(ids, s);
}

/**
 * Reprise atomique. `userId`/`role` = le profil de l'appareil qui reprend.
 * Renvoie { ok, takenOver, session }.
 */
async function takeOver({ userId, role, deviceId, now = Date.now() }) {
  const newId = _clean(deviceId);
  if (!newId) return { ok: false, error: 'DEVICE_ID_REQUIRED' };
  const { identityGroup } = require('./identityGroup');
  const g = await identityGroup(userId);
  const ids = (g.ids || [String(userId)]).map(String);
  const map = require('../sockets/mapSocket');
  const old = map.getLiveSessionForIds(ids);
  if (!old) return { ok: true, takenOver: false, session: null };

  const key = String(userId);
  const prevDevice = _clean(old.deviceId);
  const displaced = new Set(Array.isArray(old.displaced) ? old.displaced.map(_clean) : []);
  if (prevDevice !== newId) displaced.add(prevDevice); // '' = ancienne app sans identifiant
  displaced.delete(newId);

  let s = old;
  if (String(old.userId) !== key) {
    // La Balade change de profil (ex. lancée en propriétaire à la maison,
    // reprise en gardien) : même objet, nouvelle clé.
    s = { ...old, trail: Array.isArray(old.trail) ? old.trail.slice() : [] };
    map.clearLiveSession(old.userId);
    s.userId = key;
    if (role) s.role = String(role).toLowerCase();
  }
  s.deviceId = newId;
  s.displaced = [...displaced];
  s.personIds = ids;
  s.takenOverAt = now;
  s.lastSeenAt = now;
  map.adoptLiveSession(s);
  _arm(ids, s);

  // Base : le nouveau profil est « en direct », l'ancien profil éteint SANS
  // heure d'arrêt (ce n'est pas un arrêt voulu).
  try {
    const liveDevices = require('./liveDevices589');
    await liveDevices.markStartedByUser(key, { role });
    const docs = g.docs || [];
    for (const d of docs) {
      const M = d.model === 'Walker' ? require('../models/Walker')
        : d.model === 'Sitter' ? require('../models/Sitter') : require('../models/Owner');
      await M.updateOne(
        { _id: d.id },
        { $set: { 'location.liveShareActive': String(d.id) === key } },
      ).catch(() => {});
    }
  } catch (e) {
    logger.warn(`[liveTakeover] base : ${e.message}`);
  }

  // Les appareils de la personne : l'ancien s'arrête, puis voit « ailleurs ».
  try {
    const { emitToUser } = require('../sockets/emitter');
    const ROLE = { Owner: 'owner', Sitter: 'sitter', Walker: 'walker' };
    const at = new Date(now).toISOString();
    for (const d of g.docs || []) {
      emitToUser(ROLE[d.model] || 'owner', d.id, 'map:self-live', {
        active: false, reason: 'device_takeover', keepDeviceId: newId, at,
      });
    }
    for (const d of g.docs || []) {
      emitToUser(ROLE[d.model] || 'owner', d.id, 'map:self-live', {
        active: true, reason: 'device_takeover', deviceId: newId, role: s.role, fromId: key, at,
      });
    }
  } catch (e) {
    logger.warn(`[liveTakeover] annonce : ${e.message}`);
  }
  logger.info(`[liveTakeover] Balade reprise par ${role}:${key} (appareil remplacé : ${prevDevice || 'ancienne app'})`);
  return { ok: true, takenOver: true, session: map.describeLiveSession(s) };
}

function _resetForTests() {
  _guards.clear();
}

module.exports = {
  deviceIdOfReq,
  isDisplaced,
  noteDevice,
  clearFor,
  takeOver,
  rearmFromSession,
  _resetForTests,
};
