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
    if (conversation.ownerId) {
      participants.push({ role: 'owner', userId: String(conversation.ownerId._id || conversation.ownerId) });
    }
    if (conversation.sitterId) {
      participants.push({ role: 'sitter', userId: String(conversation.sitterId._id || conversation.sitterId) });
    }
    if (conversation.walkerId) {
      participants.push({ role: 'walker', userId: String(conversation.walkerId._id || conversation.walkerId) });
    }
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

module.exports = {
  setSocketServer,
  getSocketServer,
  emitToConversation,
  emitToUser,
  emitToWalk,
  emitChatMessage,
  userRoom,
  walkRoom,
};

