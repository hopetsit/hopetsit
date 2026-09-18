// v566 — accusés de réception et de lecture façon WhatsApp.
//
//   ✓   envoyé   : le message existe côté serveur (deliveredAt = readAt = null)
//   ✓✓  remis    : `deliveredAt` posé (l'appareil du destinataire l'a reçu)
//   ✓✓  lu (bleu): `readAt` posé (le destinataire a ouvert la conversation)
//
// Règles :
//   - jamais de mise à jour message par message : un `find` borné pour connaître
//     les ids concernés + un `updateMany` groupé ;
//   - idempotent : le filtre porte toujours `readAt: null` / `deliveredAt: null`,
//     un second appel ne trouve rien, n'écrit rien et n'émet rien (pas de boucle) ;
//   - l'événement part UNIQUEMENT vers l'expéditeur (ses 3 rooms de rôle, comme
//     `message:new`), jamais vers celui qui vient de lire ;
//   - conversations de réservation (ownerId / sitterId / walkerId) ET
//     conversations amies (friendChat + participants[]) couvertes.
const Conversation = require('../models/Conversation');
const Message = require('../models/Message');
const { emitToUsersAllRoles } = require('../sockets/emitter');
const logger = require('../utils/logger');

// Nombre maximal d'ids renvoyés dans un événement (les plus récents). Le client
// applique de toute façon « tous mes messages ≤ readAt sont lus ».
const MAX_EVENT_IDS = 200;

const idOf = (v) => (v ? String(v._id || v.id || v) : '');

/** Ids (String) des participants humains d'une conversation. */
const participantIdsOf = (conversation) => {
  if (!conversation) return [];
  const out = [];
  if (conversation.friendChat === true && Array.isArray(conversation.participants)) {
    for (const p of conversation.participants) {
      const id = idOf(p && p.userId);
      if (id) out.push(id);
    }
  } else {
    for (const v of [conversation.ownerId, conversation.sitterId, conversation.walkerId]) {
      const id = idOf(v);
      if (id) out.push(id);
    }
  }
  return [...new Set(out)];
};

/** 'read' | 'delivered' | 'sent' pour un message (doc ou objet nettoyé). */
const receiptStatusOf = (message) => {
  if (!message) return null;
  if (message.readAt) return 'read';
  if (message.deliveredAt) return 'delivered';
  return 'sent';
};

const loadConversationLite = (conversationId) =>
  Conversation.findById(conversationId)
    .select('friendChat participants ownerId sitterId walkerId')
    .lean();

const groupBySender = (docs) => {
  const map = new Map();
  for (const d of docs) {
    const sid = idOf(d.senderId);
    if (!sid) continue;
    if (!map.has(sid)) map.set(sid, []);
    map.get(sid).push(idOf(d._id));
  }
  return map;
};

/**
 * Le lecteur a ouvert la conversation : tous les messages de l'AUTRE partie
 * encore non lus passent à `readAt = now` (et `deliveredAt` s'il manquait).
 * Émet `message:read { conversationId, readerId, readAt, messageIds }` à
 * chaque expéditeur concerné. Renvoie `{ count, readAt, messageIds }`.
 */
const markMessagesRead = async ({ conversationId, readerId, conversation = null }) => {
  const empty = { count: 0, readAt: null, messageIds: [] };
  const reader = idOf(readerId);
  if (!conversationId || !reader) return empty;

  const conv = conversation || (await loadConversationLite(conversationId));
  if (!conv) return empty;
  if (!participantIdsOf(conv).includes(reader)) return empty;

  const convId = conv._id || conversationId;
  const base = {
    conversationId: convId,
    senderId: { $ne: reader },
    senderRole: { $ne: 'system' },
  };

  const pending = await Message.find({ ...base, readAt: null })
    .select('_id senderId')
    .sort({ createdAt: -1 })
    .limit(MAX_EVENT_IDS)
    .lean();
  if (!pending || !pending.length) return empty;

  const now = new Date();
  // Lu implique remis : on complète `deliveredAt` d'abord, puis `readAt`.
  await Message.updateMany(
    { ...base, readAt: null, deliveredAt: null, createdAt: { $lte: now } },
    { $set: { deliveredAt: now } },
  );
  const res = await Message.updateMany(
    { ...base, readAt: null, createdAt: { $lte: now } },
    { $set: { readAt: now } },
  );

  const readAt = now.toISOString();
  const allIds = [];
  for (const [senderId, ids] of groupBySender(pending)) {
    ids.reverse(); // ordre chronologique
    allIds.push(...ids);
    emitToUsersAllRoles([senderId], 'message:read', {
      conversationId: String(convId),
      readerId: reader,
      readAt,
      messageIds: ids,
    });
  }
  return { count: (res && res.modifiedCount) || pending.length, readAt, messageIds: allIds };
};

/**
 * Le destinataire accuse réception d'un ou plusieurs messages (socket
 * `message:delivered`). Un accusé redondant coûte UNE requête indexée par _id.
 * Émet `message:delivered { conversationId, messageId, messageIds, deliveredAt }`
 * à l'expéditeur.
 */
const markMessagesDelivered = async ({ conversationId, messageIds, recipientId }) => {
  const empty = { count: 0, deliveredAt: null, messageIds: [] };
  const recipient = idOf(recipientId);
  const ids = [...new Set((Array.isArray(messageIds) ? messageIds : [messageIds]).map(idOf).filter(Boolean))]
    .slice(0, MAX_EVENT_IDS);
  if (!conversationId || !recipient || !ids.length) return empty;

  const pending = await Message.find({
    _id: { $in: ids },
    conversationId,
    senderId: { $ne: recipient },
    senderRole: { $ne: 'system' },
    deliveredAt: null,
  })
    .select('_id senderId')
    .lean();
  if (!pending || !pending.length) return empty;

  // Seul un participant peut accuser réception.
  const conv = await loadConversationLite(conversationId);
  if (!conv || !participantIdsOf(conv).includes(recipient)) return empty;

  const now = new Date();
  const pendingIds = pending.map((d) => d._id);
  await Message.updateMany(
    { _id: { $in: pendingIds }, deliveredAt: null },
    { $set: { deliveredAt: now } },
  );

  const deliveredAt = now.toISOString();
  const out = [];
  for (const [senderId, mids] of groupBySender(pending)) {
    out.push(...mids);
    emitToUsersAllRoles([senderId], 'message:delivered', {
      conversationId: String(conversationId),
      messageId: mids[mids.length - 1],
      messageIds: mids,
      deliveredAt,
    });
  }
  return { count: out.length, deliveredAt, messageIds: out };
};

/**
 * Rattrapage : l'utilisateur vient de charger sa liste de conversations →
 * tout ce qui l'attendait dans les conversations NON LUES est « remis ».
 * (Couvre l'app fermée au moment de l'envoi et les anciennes versions de
 * l'app qui n'émettent pas `message:delivered`.) Un find + un updateMany
 * pour TOUTES les conversations, jamais un par message.
 */
const markDeliveredForConversations = async ({ conversationIds, recipientId }) => {
  const recipient = idOf(recipientId);
  const convIds = (conversationIds || []).filter(Boolean);
  if (!recipient || !convIds.length) return { count: 0 };

  const pending = await Message.find({
    conversationId: { $in: convIds },
    senderId: { $ne: recipient },
    senderRole: { $ne: 'system' },
    deliveredAt: null,
    readAt: null,
  })
    .select('_id senderId conversationId')
    .sort({ createdAt: -1 })
    .limit(MAX_EVENT_IDS * 2)
    .lean();
  if (!pending || !pending.length) return { count: 0 };

  const now = new Date();
  await Message.updateMany(
    { _id: { $in: pending.map((d) => d._id) }, deliveredAt: null },
    { $set: { deliveredAt: now } },
  );

  const deliveredAt = now.toISOString();
  const byConv = new Map();
  for (const d of pending) {
    const cid = idOf(d.conversationId);
    if (!byConv.has(cid)) byConv.set(cid, []);
    byConv.get(cid).push(d);
  }
  for (const [cid, docs] of byConv) {
    for (const [senderId, mids] of groupBySender(docs)) {
      mids.reverse();
      emitToUsersAllRoles([senderId], 'message:delivered', {
        conversationId: cid,
        messageId: mids[mids.length - 1],
        messageIds: mids,
        deliveredAt,
      });
    }
  }
  return { count: pending.length };
};

/**
 * Pour la liste des conversations : dernier message de chaque conversation
 * (UNE requête, bornée par `lastMessageAt` pour rester sur l'index
 * { conversationId, createdAt }). Renvoie Map<conversationId, infos>.
 */
const lastMessageReceipts = async ({ conversations, userId }) => {
  const out = new Map();
  const me = idOf(userId);
  const or = [];
  for (const c of conversations || []) {
    if (!c || !c._id || !c.lastMessageAt) continue;
    const from = new Date(new Date(c.lastMessageAt).getTime() - 15000);
    or.push({ conversationId: c._id, createdAt: { $gte: from } });
  }
  if (!or.length) return out;
  const docs = await Message.find({ $or: or })
    .select('conversationId senderId senderRole deliveredAt readAt createdAt deletedAt')
    .sort({ createdAt: 1 })
    .lean();
  for (const d of docs || []) {
    // tri croissant → le dernier écrit gagne
    out.set(idOf(d.conversationId), {
      lastMessageId: idOf(d._id),
      lastMessageSenderId: idOf(d.senderId),
      lastMessageSenderRole: d.senderRole || null,
      lastMessageMine: d.senderRole !== 'system' && idOf(d.senderId) === me,
      lastMessageStatus: receiptStatusOf(d),
      lastMessageDeliveredAt: d.deliveredAt ? new Date(d.deliveredAt).toISOString() : null,
      lastMessageReadAt: d.readAt ? new Date(d.readAt).toISOString() : null,
    });
  }
  return out;
};

/** Enveloppe « ne casse jamais la requête principale ». */
const safely = (label, promise) =>
  Promise.resolve(promise).catch((e) => {
    logger.warn(`[receipts] ${label} failed : ${e?.message || e}`);
    return null;
  });

module.exports = {
  MAX_EVENT_IDS,
  participantIdsOf,
  receiptStatusOf,
  markMessagesRead,
  markMessagesDelivered,
  markDeliveredForConversations,
  lastMessageReceipts,
  safely,
};
