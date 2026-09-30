/**
 * v604 (ZOE, 30/09/2026) — ÉTAT RÉEL DU SUIVI EN DIRECT D'UNE CONVERSATION,
 * PAR SENS.
 *
 * Daniel (captures du 30/09) : dans une conversation, l'en-tête montrait
 * encore « En direct · voir la carte », « Suivi actif · Ouvrir la carte » et
 * « Ta position part en direct » ALORS QUE le direct avait été arrêté. Puis :
 * « que les boutons de Messages et de la PawMap soient coordonnés, que l'un
 * suive l'autre ou que les deux se suivent en même temps ».
 *
 * Causes :
 *   · la demande de suivi (message `pawfollow_request`) restait « accepted »
 *     pour toujours (ou 12 h sans date de fin) ; chaque téléphone devinait
 *     ensuite, avec ses caches, si le partage tournait encore ;
 *   · l'en-tête ne regardait que la DERNIÈRE demande acceptée, tous sens
 *     confondus : avec un suivi mutuel (A suit B ET B suit A), l'un des deux
 *     sens écrasait l'autre ;
 *   · l'anti-doublon de création renvoyait la demande EN ATTENTE de l'autre
 *     personne (« duplicate ») : B ne pouvait pas demander tant que la
 *     demande de A attendait — son sens à lui n'était jamais créé.
 *
 * Règles posées ici — le SERVEUR est la seule source de vérité :
 *   1. chaque demande a UN sens : un partageur (sa position part) et un
 *      suiveur. Deux sens = deux demandes indépendantes, deux directs
 *      indépendants ;
 *   2. quand la personne qui PARTAGE arrête son direct (bouton d'arrêt, fin
 *      de la durée choisie, fin de prestation, déconnexion), seules les
 *      demandes acceptées dont elle est le PARTAGEUR passent à `ended` ; son
 *      suivi de l'autre (sens inverse) n'est pas touché ;
 *   3. « Arrêter de suivre » (POST /conversations/:id/pawfollow/stop) ne
 *      termine que MON sens de suiveur ; `scope: 'sharing'` termine mon sens
 *      de partageur, `scope: 'all'` les deux ;
 *   4. chaque changement est poussé aux DEUX personnes (tous leurs appareils,
 *      tous leurs profils) : `message:updated` (la carte du chat) et
 *      `pawfollow:state` (état par sens, calculé POUR CHAQUE destinataire) ;
 *   5. à l'ouverture d'une conversation l'app relit
 *      GET /conversations/:id/pawfollow-state, jamais un cache seul.
 *
 * Qui partage ? Même règle que l'app (live_share_starter.dart) : une demande
 * envoyée par un PROPRIÉTAIRE (« je veux suivre ») est partagée par celui qui
 * a répondu ; une demande envoyée par un gardien / promeneur (« je partage ma
 * position ») est partagée par le demandeur.
 *
 * Forme de l'état (pour UN lecteur) :
 *   { outgoing: Dir, incoming: Dir }
 *   outgoing = MA position part vers l'autre (il me suit) ;
 *   incoming = SA position vient vers moi (je le suis).
 *   Dir = { status: none|pending|accepted|refused|expired|ended,
 *           following: bool   (demande acceptée et en cours),
 *           live: bool        (following ET le partageur diffuse),
 *           messageId, sharerId, followerId, since, endedAt, endReason }
 */
const logger = require('./logger');

const PF_TYPE = 'pawfollow_request';
const idStr = (v) => (v ? String(v._id || v.id || v) : '');

function requesterRoleOf(message) {
  const md = (message && message.metadata) || {};
  return String(md.requesterRole || (message && message.senderRole) || '').toLowerCase();
}

/** Id de profil de la personne qui a envoyé la demande. */
function requesterIdOf(message) {
  if (!message) return '';
  const md = message.metadata || {};
  return idStr(md.requesterId || message.senderId);
}

/** Id de profil de la personne qui PARTAGE sa position ('' si inconnu). */
function sharerIdOf(message) {
  if (!message) return '';
  const md = message.metadata || {};
  if (requesterRoleOf(message) === 'owner') return idStr(md.respondedBy);
  return requesterIdOf(message);
}

/** Id de profil de la personne qui SUIT ('' si inconnu). */
function followerIdOf(message) {
  if (!message) return '';
  const md = message.metadata || {};
  if (requesterRoleOf(message) === 'owner') return requesterIdOf(message);
  return idStr(md.respondedBy);
}

/**
 * Sens d'une demande pour un lecteur (pure) : 'outgoing' (ma position part),
 * 'incoming' (je suis l'autre) ou null (je n'y suis pas).
 */
function directionFor(message, viewerIds) {
  const mine = new Set((viewerIds || []).map(String));
  const sharer = sharerIdOf(message);
  if (sharer) return mine.has(sharer) ? 'outgoing' : 'incoming';
  // Demande de propriétaire encore sans réponse : le demandeur est le suiveur.
  const follower = followerIdOf(message);
  if (follower) return mine.has(follower) ? 'incoming' : 'outgoing';
  return null;
}

/**
 * Statut effectif d'une demande (pure) : pending | accepted | refused |
 * expired | ended.
 */
function effectiveStatus(message, now = Date.now()) {
  if (!message) return 'none';
  const md = message.metadata || {};
  const st = String(md.status || 'pending');
  if (st === 'pending') {
    const exp = md.expiresAt ? new Date(md.expiresAt).getTime() : NaN;
    if (Number.isFinite(exp) && exp < now) return 'expired';
    return 'pending';
  }
  if (st === 'accepted') {
    const end = md.endAt ? new Date(md.endAt).getTime() : NaN;
    if (Number.isFinite(end) && end < now) return 'ended';
    return 'accepted';
  }
  return st;
}

const EMPTY_DIR = Object.freeze({
  status: 'none', following: false, live: false, messageId: null,
  sharerId: null, followerId: null, since: null, endedAt: null, endReason: null,
});

const iso = (v) => {
  if (!v) return null;
  const d = new Date(v);
  return Number.isFinite(d.getTime()) ? d.toISOString() : null;
};

/** Demande qui pilote UN sens : la plus récente encore acceptée, sinon la plus récente. */
function pickDriving(list, now) {
  if (!list.length) return null;
  const t = (m) => new Date(m.createdAt || 0).getTime() || 0;
  const sorted = [...list].sort((a, b) => t(b) - t(a));
  return sorted.find((m) => effectiveStatus(m, now) === 'accepted') || sorted[0];
}

function dirState(message, liveOf, now) {
  if (!message) return { ...EMPTY_DIR };
  const md = message.metadata || {};
  const status = effectiveStatus(message, now);
  const following = status === 'accepted';
  const sharer = sharerIdOf(message);
  return {
    status,
    following,
    live: following && !!sharer && liveOf(sharer) === true,
    messageId: idStr(message._id || message.id) || null,
    sharerId: sharer || null,
    followerId: followerIdOf(message) || null,
    since: following ? iso(md.respondedAt) : null,
    endedAt: iso(md.endedAt),
    endReason: md.endReason || null,
  };
}

/**
 * État par sens pour UN lecteur (pure).
 * @param {object} o
 * @param {object[]} o.messages   demandes de la conversation (tout ordre)
 * @param {string[]} o.viewerIds  tous les ids de profil du lecteur
 * @param {(sharerId:string)=>boolean} [o.liveOf] le partageur diffuse-t-il ?
 */
function directionalState({ messages, viewerIds, liveOf = () => false, now = Date.now() } = {}) {
  const buckets = { outgoing: [], incoming: [] };
  for (const m of messages || []) {
    if (!m || m.type !== PF_TYPE || m.deletedAt) continue;
    const d = directionFor(m, viewerIds);
    if (d) buckets[d].push(m);
  }
  return {
    outgoing: dirState(pickDriving(buckets.outgoing, now), liveOf, now),
    incoming: dirState(pickDriving(buckets.incoming, now), liveOf, now),
  };
}

/** Le partageur (toute sa personne, 3 profils) diffuse-t-il en ce moment ? */
async function isSharerLive(sharerId) {
  if (!sharerId) return false;
  try {
    const st = await require('./liveDevices589').getMyLiveState(sharerId);
    if (!st || st.active !== true) return false;
    const { liveState } = require('./liveState');
    const seen = st.session && st.session.lastSeenAt;
    return liveState({ sharing: true, lastSeenAt: seen }) !== 'seen';
  } catch (e) {
    logger.warn(`[pawfollowState] live lookup failed : ${e && e.message ? e.message : e}`);
    return false;
  }
}

/** Base joignable ? (sans connexion, mongoose met la requête en attente 10 s.) */
function dbReady() {
  try { return require('mongoose').connection.readyState === 1; } catch (_) { return false; }
}

async function idsOfPerson(userId) {
  try {
    const { identityGroup } = require('./identityGroup');
    const g = await identityGroup(userId);
    if (g && Array.isArray(g.ids) && g.ids.length) return g.ids.map(String);
  } catch (_) { /* repli : l'id seul */ }
  return userId ? [String(userId)] : [];
}

/** Valeurs à chercher en base : chaîne ET ObjectId (les deux formes existent). */
function bothForms(ids) {
  const out = [];
  let ObjectId = null;
  try { ({ ObjectId } = require('mongoose').Types); } catch (_) { /* tests */ }
  for (const id of ids) {
    out.push(String(id));
    if (ObjectId && /^[a-f0-9]{24}$/i.test(String(id))) {
      try { out.push(new ObjectId(String(id))); } catch (_) { /* ignore */ }
    }
  }
  return out;
}

async function requestsOf(conversationId) {
  const Message = require('../models/Message');
  return Message.find({ conversationId, type: PF_TYPE, deletedAt: null })
    .sort({ createdAt: -1 })
    .limit(30)
    .lean();
}

/**
 * Fonction « le partageur diffuse ? » avec mémo, et des personnes forcées
 * (un direct qui vient de démarrer n'a pas encore sa session en mémoire).
 */
function liveResolver({ forceLiveIds = [], forceOffIds = [] } = {}) {
  const on = new Set(forceLiveIds.map(String));
  const off = new Set(forceOffIds.map(String));
  const memo = new Map();
  const resolve = async (sharerIds) => {
    for (const id of sharerIds) {
      if (!id || memo.has(id)) continue;
      if (on.has(id)) memo.set(id, true);
      else if (off.has(id)) memo.set(id, false);
      // eslint-disable-next-line no-await-in-loop
      else memo.set(id, await isSharerLive(id));
    }
  };
  return { resolve, liveOf: (id) => memo.get(String(id)) === true };
}

/** État par sens de la conversation pour le lecteur [viewerId]. */
async function readConversationState(conversationId, viewerId, opts = {}) {
  const [msgs, viewerIds] = await Promise.all([requestsOf(conversationId), idsOfPerson(viewerId)]);
  const r = liveResolver(opts);
  const sharers = [...new Set(msgs
    .filter((m) => effectiveStatus(m) === 'accepted')
    .map(sharerIdOf)
    .filter(Boolean))];
  await r.resolve(sharers);
  return directionalState({ messages: msgs, viewerIds, liveOf: r.liveOf });
}

/**
 * Pousse `pawfollow:state` à CHAQUE personne de la conversation, avec SON
 * état par sens (tous ses appareils, tous ses profils). Best-effort.
 */
async function emitStateToParticipants(conv, opts = {}) {
  try {
    const { participantIds } = require('./pawfollowRespond599');
    const { emitToUsersAllRoles } = require('../sockets/emitter');
    const cid = idStr(conv._id || conv.id);
    const msgs = await requestsOf(conv._id || conv.id);
    const r = liveResolver(opts);
    await r.resolve([...new Set(msgs
      .filter((m) => effectiveStatus(m) === 'accepted')
      .map(sharerIdOf)
      .filter(Boolean))]);
    const at = new Date().toISOString();
    const seen = new Set();
    for (const p of participantIds(conv)) {
      // eslint-disable-next-line no-await-in-loop
      const ids = await idsOfPerson(p);
      const key = [...ids].sort().join(',');
      if (seen.has(key)) continue;
      seen.add(key);
      const state = directionalState({ messages: msgs, viewerIds: ids, liveOf: r.liveOf });
      emitToUsersAllRoles(ids, 'pawfollow:state', { conversationId: cid, ...state, at });
    }
  } catch (e) {
    logger.warn(`[pawfollowState] emit state failed : ${e && e.message ? e.message : e}`);
  }
}

function emitMessageUpdated(conv, message) {
  try {
    const { emitChatMessage } = require('../sockets/emitter');
    emitChatMessage(conv, 'message:updated', {
      conversationId: idStr(conv._id || conv.id),
      message: typeof message.toObject === 'function' ? message.toObject() : message,
    });
  } catch (e) {
    logger.warn(`[pawfollowState] emit message:updated failed : ${e && e.message ? e.message : e}`);
  }
}

/** Passe une demande acceptée à « terminée » et la sauve (sans prévenir). */
async function _markEnded(message, { by, reason, now }) {
  message.metadata = {
    ...(message.metadata || {}),
    status: 'ended',
    endedAt: now,
    endedBy: by ? String(by) : null,
    endReason: reason || 'stopped',
  };
  if (typeof message.markModified === 'function') message.markModified('metadata');
  await message.save();
}

/** Prévient les deux côtés des conversations touchées. */
async function _notifyConversations(messagesByConv, opts) {
  const Conversation = require('../models/Conversation');
  for (const [cid, msgs] of messagesByConv) {
    // eslint-disable-next-line no-await-in-loop
    const conv = await Conversation.findById(cid).lean();
    if (!conv) continue;
    for (const m of msgs) emitMessageUpdated(conv, m);
    // eslint-disable-next-line no-await-in-loop
    await emitStateToParticipants(conv, opts);
  }
}

async function _acceptedWhereSharer(ids) {
  const Message = require('../models/Message');
  const forms = bothForms(ids);
  const candidates = await Message.find({
    type: PF_TYPE,
    'metadata.status': 'accepted',
    deletedAt: null,
    $or: [
      { 'metadata.requesterId': { $in: forms } },
      { 'metadata.respondedBy': { $in: forms } },
      { senderId: { $in: forms.filter((v) => typeof v !== 'string') } },
    ],
  });
  const mine = new Set(ids);
  return candidates.filter((m) => mine.has(sharerIdOf(m)));
}

/**
 * La personne [userId] a arrêté son direct : chaque demande ACCEPTÉE dont
 * elle est le PARTAGEUR passe à « terminée » (son suivi de l'autre, sens
 * inverse, reste intact). Best-effort, ne lève jamais.
 * @returns {Promise<number>} nombre de demandes terminées
 */
async function endPawfollowForSharer(userId, { reason = 'live_stopped', now = new Date() } = {}) {
  try {
    if (!dbReady()) return 0;
    const ids = await idsOfPerson(userId);
    if (!ids.length) return 0;
    const list = await _acceptedWhereSharer(ids);
    const byConv = new Map();
    for (const m of list) {
      try {
        // eslint-disable-next-line no-await-in-loop
        await _markEnded(m, { by: userId, reason, now });
        const k = String(m.conversationId);
        byConv.set(k, [...(byConv.get(k) || []), m]);
      } catch (e) {
        logger.warn(`[pawfollowState] end ${m._id} failed : ${e && e.message ? e.message : e}`);
      }
    }
    await _notifyConversations(byConv, { forceOffIds: ids });
    return list.length;
  } catch (e) {
    logger.warn(`[pawfollowState] endPawfollowForSharer failed : ${e && e.message ? e.message : e}`);
    return 0;
  }
}

/**
 * Le direct de [userId] vient de (re)partir : chaque conversation où une
 * demande acceptée le désigne comme partageur reçoit son nouvel état.
 */
async function announceSharerLive(userId) {
  try {
    if (!dbReady()) return 0;
    const ids = await idsOfPerson(userId);
    if (!ids.length) return 0;
    const list = await _acceptedWhereSharer(ids);
    const convs = new Map();
    for (const m of list) {
      if (effectiveStatus(m) !== 'accepted') continue;
      convs.set(String(m.conversationId), []);
    }
    await _notifyConversations(convs, { forceLiveIds: ids });
    return convs.size;
  } catch (e) {
    logger.warn(`[pawfollowState] announceSharerLive failed : ${e && e.message ? e.message : e}`);
    return 0;
  }
}

/**
 * Quelles demandes « arrêter » termine (pure) :
 *   scope 'following' (défaut) → celles où JE SUIS (sens entrant) ;
 *   scope 'sharing'            → celles où JE PARTAGE (sens sortant) ;
 *   scope 'all'                → les deux ;
 * `messageId` restreint à cette demande (toujours dans le sens demandé).
 */
function selectToStop(messages, viewerIds, { scope = 'following', messageId = null, now = Date.now() } = {}) {
  const want = scope === 'all' ? ['incoming', 'outgoing']
    : scope === 'sharing' ? ['outgoing'] : ['incoming'];
  return (messages || []).filter((m) => m && m.type === PF_TYPE && !m.deletedAt
    && effectiveStatus(m, now) === 'accepted'
    && (!messageId || idStr(m._id || m.id) === String(messageId))
    && want.includes(directionFor(m, viewerIds)));
}

/** « Arrêter de suivre » / « arrêter le partage » depuis la conversation. */
async function endPawfollowInConversation({ conversation, userId, scope = 'following', messageId = null, now = new Date() }) {
  const Message = require('../models/Message');
  const ids = await idsOfPerson(userId);
  const msgs = await Message.find({
    conversationId: conversation._id,
    type: PF_TYPE,
    'metadata.status': 'accepted',
    deletedAt: null,
  });
  const targets = selectToStop(msgs, ids, { scope, messageId, now: now.getTime() });
  for (const m of targets) {
    // eslint-disable-next-line no-await-in-loop
    await _markEnded(m, { by: userId, reason: scope === 'sharing' ? 'share_stopped' : 'follow_stopped', now });
  }
  if (targets.length) {
    await _notifyConversations(new Map([[String(conversation._id), targets]]), {});
  }
  return targets.length;
}

module.exports = {
  PF_TYPE,
  sharerIdOf,
  followerIdOf,
  requesterIdOf,
  directionFor,
  effectiveStatus,
  directionalState,
  selectToStop,
  isSharerLive,
  readConversationState,
  emitStateToParticipants,
  endPawfollowForSharer,
  announceSharerLive,
  endPawfollowInConversation,
};
