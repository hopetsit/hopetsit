/**
 * v589 — LE DIRECT SUIT LA PERSONNE, PAS LE TÉLÉPHONE.
 *
 * Constat (Daniel, 26/09 : « si je me connecte sur un Android puis sur un
 * Apple, la géolocalisation est synchronisée ? ») :
 *   · l'état « En direct » vivait dans chaque téléphone : un direct lancé sur
 *     Android restait affiché éteint sur l'iPhone ;
 *   · « Arrêter » sur l'iPhone coupait la session, mais le service de fond
 *     Android la relançait au POST suivant (~15 s) ;
 *   · l'arrêt ne visait que le PROFIL actif : direct lancé en propriétaire sur
 *     Android, arrêté en gardien sur l'iPhone = rien d'arrêté.
 *
 * Règles posées ici (serveur seul, valables pour les apps déjà installées) :
 *   1. un arrêt VOULU coupe le direct sur les 3 profils de la personne et note
 *      `location.liveShareStoppedAt` ;
 *   2. tant que cette note existe, les envois du SERVICE DE FOND (requêtes sans
 *      en-tête `X-App-Version`, que l'app ouverte envoie toujours) sont
 *      ignorés : un autre téléphone ne peut plus rallumer le direct tout seul ;
 *   3. un démarrage depuis l'app OUVERTE (en-tête présent, ou socket) efface
 *      la note sur les 3 profils ;
 *   4. chaque changement est annoncé aux AUTRES appareils de la personne
 *      (`map:self-live`) et lisible à l'ouverture (`GET /friends/live-state`).
 */
const logger = require('./logger');
const { LIVE_STOP_SET } = require('./liveShareStart');

const STOPPED_FIELD = 'location.liveShareStoppedAt';

function modelOf(name) {
  if (name === 'Walker') return require('../models/Walker');
  if (name === 'Sitter') return require('../models/Sitter');
  return require('../models/Owner');
}

const ROLE_OF_MODEL = { Owner: 'owner', Sitter: 'sitter', Walker: 'walker' };

async function groupOf(userId) {
  const { identityGroup } = require('./identityGroup');
  const g = await identityGroup(userId);
  // identityGroup renvoie toujours l'id d'entrée ; s'il n'a trouvé aucun doc,
  // on ne sait pas quelle collection viser : on n'écrit rien.
  return g;
}

/** Requête envoyée par l'app ouverte (et non par le service de fond Android). */
function isForegroundRequest(req) {
  const v = String((req && req.headers && req.headers['x-app-version']) || '').trim();
  return v.length > 0;
}

function emitSelfLive(docs, payload) {
  try {
    const { emitToUser } = require('../sockets/emitter');
    for (const d of docs) {
      emitToUser(ROLE_OF_MODEL[d.model] || 'owner', d.id, 'map:self-live', payload);
    }
  } catch (e) {
    logger.warn(`[liveDevices] emit self-live failed: ${e.message}`);
  }
}

/**
 * Arrêt VOULU : coupe le direct sur les 3 profils, note l'heure d'arrêt,
 * prévient les amis (depuis chaque profil) et les autres appareils.
 * Renvoie la liste des ids coupés.
 */
async function stopEverywhere(userId, { now = new Date(), notifyFriends = true } = {}) {
  const g = await groupOf(userId);
  const map = require('../sockets/mapSocket');
  for (const d of g.docs) {
    try {
      await modelOf(d.model).updateOne(
        { _id: d.id },
        { $set: { ...LIVE_STOP_SET, [STOPPED_FIELD]: now } },
      );
    } catch (e) {
      logger.warn(`[liveDevices] stop ${d.model}:${d.id} failed: ${e.message}`);
    }
    try { map.clearLiveSession(d.id); } catch (_) { /* ignore */ }
  }
  if (notifyFriends && typeof map.listPositionListeners === 'function') {
    const { emitToUser } = require('../sockets/emitter');
    for (const d of g.docs) {
      const role = ROLE_OF_MODEL[d.model] || 'owner';
      try {
        const listeners = await map.listPositionListeners(d.id, role);
        for (const l of listeners) {
          emitToUser(l.role, l.userId, 'map:friend-offline', {
            userId: l.viewAsId || d.id,
            role,
            at: now.toISOString(),
            reason: 'user_stopped',
            personIds: g.ids.map(String),
          });
        }
      } catch (e) {
        logger.warn(`[liveDevices] friend-offline ${d.id} failed: ${e.message}`);
      }
    }
  }
  emitSelfLive(g.docs, { active: false, at: now.toISOString(), reason: 'user_stopped' });
  return g.docs.map((d) => d.id);
}

/** Vrai si la personne a arrêté son direct et ne l'a pas relancé depuis l'app ouverte. */
async function isStoppedByUser(userId) {
  const g = await groupOf(userId);
  for (const d of g.docs) {
    try {
      const doc = await modelOf(d.model).findById(d.id).select(STOPPED_FIELD).lean();
      if (doc && doc.location && doc.location.liveShareStoppedAt) return true;
    } catch (_) { /* ignore */ }
  }
  return false;
}

/**
 * Démarrage depuis l'app ouverte : efface la note d'arrêt sur les 3 profils.
 * Annonce `map:self-live {active:true}` seulement quand le direct repart
 * (pas à chaque position).
 */
async function markStartedByUser(userId, { role, now = new Date() } = {}) {
  const g = await groupOf(userId);
  let restarted = false;
  for (const d of g.docs) {
    try {
      const r = await modelOf(d.model).updateOne(
        { _id: d.id, [STOPPED_FIELD]: { $ne: null } },
        { $set: { [STOPPED_FIELD]: null } },
      );
      if (r && r.modifiedCount > 0) restarted = true;
    } catch (_) { /* ignore */ }
  }
  return { restarted, docs: g.docs, role, at: now };
}

/** Annonce aux autres appareils qu'un direct vient de démarrer. */
function announceStarted(docs, { role, userId, at = new Date() } = {}) {
  emitSelfLive(docs, { active: true, at: at.toISOString(), role: role || null, fromId: userId ? String(userId) : null });
}

/**
 * État du direct de la personne, tous profils confondus — lu par l'app à
 * l'ouverture et au retour au premier plan.
 */
async function getMyLiveState(userId) {
  const g = await groupOf(userId);
  const map = require('../sockets/mapSocket');
  const session = map.getLiveSessionForIds(g.ids);
  let startedAt = null;
  let stoppedAt = null;
  let dbActive = false;
  for (const d of g.docs) {
    try {
      const doc = await modelOf(d.model).findById(d.id)
        .select('location.liveShareActive location.liveShareStartedAt location.liveShareStoppedAt location.updatedAt')
        .lean();
      const loc = (doc && doc.location) || {};
      if (loc.liveShareActive === true) dbActive = true;
      if (loc.liveShareStartedAt && (!startedAt || loc.liveShareStartedAt > startedAt)) startedAt = loc.liveShareStartedAt;
      if (loc.liveShareStoppedAt && (!stoppedAt || loc.liveShareStoppedAt > stoppedAt)) stoppedAt = loc.liveShareStoppedAt;
    } catch (_) { /* ignore */ }
  }
  const described = session ? map.describeLiveSession(session) : null;
  const active = !!session && !stoppedAt;
  return {
    active,
    stopped: !!stoppedAt,
    stoppedAt: stoppedAt ? new Date(stoppedAt).toISOString() : null,
    startedAt: startedAt ? new Date(startedAt).toISOString() : (session ? new Date(session.startedAt).toISOString() : null),
    role: session ? session.role : null,
    fromId: session ? String(session.userId) : null,
    dbActive,
    session: described,
  };
}

module.exports = {
  STOPPED_FIELD,
  isForegroundRequest,
  stopEverywhere,
  isStoppedByUser,
  markStartedByUser,
  announceStarted,
  getMyLiveState,
};
