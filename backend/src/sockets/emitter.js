let ioInstance = null;

const setSocketServer = (io) => {
  ioInstance = io;
};

const getSocketServer = () => ioInstance;

const shouldExcludeSocket = (socket, conversationId, exclude) => {
  if (!exclude?.length) {
    return false;
  }

  const socketId = socket.id;
  const conversationMetadata = socket.data?.conversationMetadata || {};
  const metadata = conversationMetadata[conversationId] || {};
  const { role: socketRole, userId: socketUserId } = metadata;

  return exclude.some((item) => {
    if (item.socketId && item.socketId === socketId) {
      return true;
    }
    if (item.userId && item.userId !== socketUserId) {
      return false;
    }
    if (item.role && item.role !== socketRole) {
      return false;
    }
    if (!item.userId && !item.role && !item.socketId) {
      return false;
    }
    if (item.userId && item.userId === socketUserId && !item.role) {
      return true;
    }
    if (item.role && item.role === socketRole && !item.userId) {
      return true;
    }
    return item.userId === socketUserId && item.role === socketRole;
  });
};

const emitToConversation = (conversationId, event, payload, options = {}) => {
  if (!ioInstance) return;
  const { exclude = [] } = options;

  if (!exclude.length) {
    ioInstance.to(conversationId).emit(event, payload);
    return;
  }

  const room = ioInstance.sockets.adapter.rooms.get(conversationId);
  if (!room) return;

  room.forEach((socketId) => {
    const socket = ioInstance.sockets.sockets.get(socketId);
    if (!socket) return;

    if (shouldExcludeSocket(socket, conversationId, exclude)) {
      return;
    }

    socket.emit(event, payload);
  });
};

// v23.1 part 229 — Daniel : badge unread invisible. Audit room format
// match : on force lowercase role + String userId pour garantir que
// socket.join(userRoom('owner', '...')) et emit ioInstance.to(userRoom('Owner', '...'))
// touchent le MEME room. Avant : si JWT stockait 'Owner' (capital) mais
// emit utilisait 'owner', les 2 rooms etaient differents → badge muet.
const userRoom = (role, userId) =>
  `user:${String(role || '').toLowerCase()}:${String(userId || '')}`;

const emitToUser = (role, userId, event, payload) => {
  if (!ioInstance || !role || !userId) return;
  ioInstance.to(userRoom(role, userId)).emit(event, payload);
};

const walkRoom = (walkId) => `walk:${walkId}`;

const emitToWalk = (walkId, event, payload) => {
  if (!ioInstance || !walkId) return;
  ioInstance.to(walkRoom(walkId)).emit(event, payload);
};

// v23.1 part 227 — Daniel : "lorsque un message chat est recu tjt
// afficher badge 1 dans le menu a coter de l'icone". Root cause :
// emitToConversation cible UNIQUEMENT le room `conversation_<id>`. Or
// les users qui ne sont PAS actuellement dans l'ecran chat (ex : Daniel
// sur Home) ne sont PAS membres de ce room → le message:new ne leur
// arrive jamais → NotificationsController ne bumpe jamais unreadChat
// → badge invisible.
//
// Fix : helper `emitChatMessage(conversation, event, payload)` qui emit
// (a) au conversation-room pour les users actifs dans le chat
// (b) AUSSI a chaque user-room des participants (independamment du tab
//     ouvert dans l'app cote frontend). La dedup cote frontend est
//     basee sur message.id donc pas de risque de double ajout en UI.
//
// Conversation participants resolves :
//   - friendChat=true → conversation.participants[].userModel/userId
//   - sinon (booking conv classique) → ownerId / sitterId / walkerId
const emitChatMessage = (conversation, event, payload) => {
  if (!ioInstance || !conversation) return;
  const convIdRaw = conversation._id || conversation.id;
  if (!convIdRaw) return;
  const convId = String(convIdRaw);
  // 1) Conversation room (active chat users).
  ioInstance.to(convId).emit(event, payload);
  // 2) Per-participant user rooms (so badge bumps even when on Home).
  const participants = [];
  if (conversation.friendChat === true && Array.isArray(conversation.participants)) {
    for (const p of conversation.participants) {
      if (p?.userId && p?.userModel) {
        participants.push({
          role: String(p.userModel).toLowerCase(),
          userId: String(p.userId._id || p.userId),
        });
      }
    }
  } else {
    // v441 — Daniel : "message reçu en sitter/walker → pas de badge 1". ROOT
    // CAUSE : le chemin socket `message:send` (chatSocket.js) passe ici une
    // conversation SANITISÉE (assertAccessAndFetch → sanitizeConversation).
    // sanitizeConversation SUPPRIME ownerId/sitterId/walkerId quand ils sont
    // peuplés et les remplace par owner/sitter/walker (objets { id, ... }).
    // Du coup ownerId/sitterId/walkerId étaient tous undefined → participants
    // vide → AUCUN emit user-room → badge chat muet quand l'envoi passait par
    // le socket. On résout désormais l'id depuis (a) le champ *Id brut/peuplé
    // OU (b) le champ sanitisé owner/sitter/walker (.id). emitChatMessage
    // devient ainsi tolérant aux 3 formes (raw / populated / sanitized),
    // quel que soit l'appelant.
    const resolveId = (raw, sanitized) => {
      if (raw) return String(raw._id || raw);
      if (sanitized) return String(sanitized.id || sanitized._id || sanitized);
      return null;
    };
    const ownerUid = resolveId(conversation.ownerId, conversation.owner);
    const sitterUid = resolveId(conversation.sitterId, conversation.sitter);
    const walkerUid = resolveId(conversation.walkerId, conversation.walker);
    if (ownerUid) participants.push({ role: 'owner', userId: ownerUid });
    if (sitterUid) participants.push({ role: 'sitter', userId: sitterUid });
    if (walkerUid) participants.push({ role: 'walker', userId: walkerUid });
  }
  // v401 — Daniel : "qd je recoi des messages le badge 1 ds menu ne vient
  // pas". ROOT CAUSE pour les comptes STAFF multi-profils (1 compte = owner +
  // sitter + walker) : l'amitié/conversation stocke le `userModel` figé au
  // moment de sa création (ex. 'Owner'), donc on emit vers user:owner:<id>.
  // Mais le destinataire rejoint sa room avec le rôle de SA SESSION COURANTE
  // (JWT) — s'il est connecté en walker, il est dans user:walker:<id> et ne
  // reçoit JAMAIS le message:new → badge chat muet, alors que le message
  // existe bien (et le resync serveur ne tourne qu'au resume de l'app).
  //
  // FIX (deploy-only, pas de rebuild app) : on emit vers les 3 rooms de rôle
  // (owner/sitter/walker) de chaque userId destinataire. Un socket n'est
  // membre QUE d'une seule de ces rooms (son rôle JWT courant) → exactement
  // UNE livraison, aucune double-incrémentation du badge. On dédup les userId
  // pour ne pas re-emit plusieurs fois au même utilisateur.
  const seenUserIds = new Set();
  for (const p of participants) {
    if (!p.userId || seenUserIds.has(p.userId)) continue;
    seenUserIds.add(p.userId);
    for (const r of ['owner', 'sitter', 'walker']) {
      ioInstance.to(userRoom(r, p.userId)).emit(event, payload);
    }
  }
};

// v566 — accusés de réception/lecture : UNE seule diffusion vers les 3 rooms
// de rôle de chaque destinataire (socket.io dédoublonne les sockets quand
// plusieurs rooms sont passées au même `to([...])`) → une livraison par socket.
const emitToUsersAllRoles = (userIds, event, payload) => {
  if (!ioInstance) return 0;
  const ids = [...new Set((userIds || []).map((v) => (v ? String(v._id || v) : '')).filter(Boolean))];
  if (!ids.length) return 0;
  const rooms = [];
  for (const id of ids) for (const r of ['owner', 'sitter', 'walker']) rooms.push(userRoom(r, id));
  ioInstance.to(rooms).emit(event, payload);
  return ids.length;
};

// v448 — AUDIT MESSAGERIE : présence en ligne pour le gating des emails.
// Un utilisateur est « en ligne » (= app ouverte/connectée) s'il a au moins un
// socket dans l'une de ses 3 rooms de rôle. On teste les 3 rôles car le même
// userId peut être connecté sous owner/sitter/walker. Sert à n'envoyer l'email
// QUE si le destinataire est HORS LIGNE (règle produit : push + in-app en
// direct, email seulement en secours). Best-effort : en cas d'erreur ou d'io
// absent → false (hors ligne) → l'email part (on ne rate jamais un email par
// excès de prudence).
const isUserOnline = async (userId) => {
  if (!ioInstance || !userId) return false;
  const uid = String(userId);
  try {
    for (const r of ['owner', 'sitter', 'walker']) {
      const sockets = await ioInstance.in(userRoom(r, uid)).fetchSockets();
      if (sockets && sockets.length > 0) return true;
    }
  } catch (_) {
    return false;
  }
  return false;
};

// ─── v565 §6 — présence « en ligne » ────────────────────────────────────────
// Un humain = jusqu'à 3 docs (owner/sitter/walker) ; le socket porte l'id du
// rôle de SA session. Pour répondre « cette personne est-elle en ligne ? »
// on construit UN index (ids des sockets connectés + e-mails/oldId de ces
// docs), mis en cache 10 s, puis chaque doc lu (liste de conversations, amis,
// membres proches) est testé en O(1) — au lieu de 3 fetchSockets par ligne.
const ROLE_KEYS = ['owner', 'sitter', 'walker'];
const socketUserId = (s) => {
  const d = s && s.data;
  if (d?.user?.id) return String(d.user.id);
  if (d?.userRoom?.userId) return String(d.userRoom.userId);
  if (d?.mapIdentity?.userId) return String(d.mapIdentity.userId);
  return null;
};

/** Ids (String) de tous les utilisateurs ayant au moins un socket connecté. */
const getOnlineUserIds = async () => {
  const set = new Set();
  if (!ioInstance) return set;
  try {
    const sockets = await ioInstance.fetchSockets();
    for (const s of sockets) {
      const id = socketUserId(s);
      if (id) set.add(id);
    }
  } catch (_) { /* best-effort */ }
  return set;
};

/** Nombre de sockets des ids donnés (3 rooms de rôle chacun), hors `excludeSocketId`. */
const countSocketsForIds = async (ids, excludeSocketId = null) => {
  if (!ioInstance || !ids || !ids.length) return 0;
  try {
    const rooms = [];
    for (const id of ids) for (const r of ROLE_KEYS) rooms.push(userRoom(r, id));
    const sockets = await ioInstance.in(rooms).fetchSockets();
    const idSet = new Set(ids.map(String));
    let n = 0;
    for (const s of sockets) {
      if (excludeSocketId && s.id === excludeSocketId) continue;
      n += 1;
    }
    // Sockets connectés mais pas encore dans une room (juste après le handshake).
    const all = await ioInstance.fetchSockets();
    for (const s of all) {
      if (excludeSocketId && s.id === excludeSocketId) continue;
      const uid = socketUserId(s);
      if (uid && idSet.has(uid)) {
        const inRoom = ROLE_KEYS.some((r) => s.rooms && s.rooms.has && s.rooms.has(userRoom(r, uid)));
        if (!inRoom) n += 1;
      }
    }
    return n;
  } catch (_) {
    return 0;
  }
};

/** Étend une liste d'ids de rôle à TOUS les ids de rôle des mêmes personnes. */
const expandIdentityIds = async (ids) => {
  const out = new Set((ids || []).map(String).filter(Boolean));
  if (!out.size) return out;
  try {
    const Owner = require('../models/Owner');
    const Sitter = require('../models/Sitter');
    const Walker = require('../models/Walker');
    const arr = [...out];
    const docs = (await Promise.all([Owner, Sitter, Walker].map((M) =>
      M.find({ _id: { $in: arr } }).select('email oldId').lean(),
    ))).flat();
    const emails = [...new Set(docs.map((d) => d.email).filter(Boolean))];
    const oldIds = [...new Set(docs.map((d) => d.oldId).filter((v) => v != null).map(String))];
    const or = [];
    if (emails.length) or.push({ email: { $in: emails } });
    if (oldIds.length) or.push({ oldId: { $in: oldIds } });
    if (or.length) {
      const sib = (await Promise.all([Owner, Sitter, Walker].map((M) =>
        M.find({ $or: or }).select('_id').lean(),
      ))).flat();
      for (const d of sib) out.add(String(d._id));
    }
  } catch (_) { /* best-effort */ }
  return out;
};

let _presenceCache = { at: 0, index: null };
const PRESENCE_CACHE_MS = 10 * 1000;
/** Index { ids, emails, oldIds } des personnes en ligne (cache 10 s). */
const buildPresenceIndex = async ({ fresh = false } = {}) => {
  const now = Date.now();
  if (!fresh && _presenceCache.index && now - _presenceCache.at < PRESENCE_CACHE_MS) {
    return _presenceCache.index;
  }
  const ids = await getOnlineUserIds();
  const index = { ids, emails: new Set(), oldIds: new Set() };
  if (ids.size) {
    try {
      const Owner = require('../models/Owner');
      const Sitter = require('../models/Sitter');
      const Walker = require('../models/Walker');
      const arr = [...ids];
      const docs = (await Promise.all([Owner, Sitter, Walker].map((M) =>
        M.find({ _id: { $in: arr } }).select('email oldId').lean(),
      ))).flat();
      for (const d of docs) {
        if (d.email) index.emails.add(String(d.email).toLowerCase());
        if (d.oldId != null) index.oldIds.add(String(d.oldId));
      }
    } catch (_) { /* best-effort */ }
  }
  _presenceCache = { at: now, index };
  return index;
};
const invalidatePresenceIndex = () => { _presenceCache = { at: 0, index: null }; };

/** Vrai si la PERSONNE derrière ce doc ({ _id|id, email, oldId }) est en ligne. */
const isIdentityOnline = (doc, index) => {
  if (!doc || !index) return false;
  const id = doc._id ? String(doc._id) : (doc.id ? String(doc.id) : null);
  if (id && index.ids.has(id)) return true;
  if (doc.email && index.emails.has(String(doc.email).toLowerCase())) return true;
  if (doc.oldId != null && index.oldIds.has(String(doc.oldId))) return true;
  return false;
};

/**
 * Émet `presence:update { userId, userIds, online, at }` aux destinataires
 * (ids de rôle → 3 rooms chacun). `userId` = id du socket, `userIds` = tous
 * les ids de rôle de la personne (pour que le client matche l'id qu'il connaît).
 */
const emitPresenceUpdate = ({ userId, userIds, online, at, recipients }) => {
  if (!ioInstance) return 0;
  const payload = {
    userId: String(userId),
    userIds: [...new Set((userIds || [userId]).map(String))],
    online: !!online,
    at: at || new Date().toISOString(),
  };
  const seen = new Set();
  let n = 0;
  for (const rid of recipients || []) {
    const id = String(rid);
    if (!id || seen.has(id) || payload.userIds.includes(id)) continue;
    seen.add(id);
    for (const r of ROLE_KEYS) ioInstance.to(userRoom(r, id)).emit('presence:update', payload);
    n += 1;
  }
  return n;
};

module.exports = {
  setSocketServer,
  getSocketServer,
  emitToConversation,
  emitToUser,
  emitToWalk,
  emitChatMessage,
  emitToUsersAllRoles,
  isUserOnline,
  userRoom,
  walkRoom,
  // v565 §6
  getOnlineUserIds,
  countSocketsForIds,
  expandIdentityIds,
  buildPresenceIndex,
  invalidatePresenceIndex,
  isIdentityOnline,
  emitPresenceUpdate,
};

