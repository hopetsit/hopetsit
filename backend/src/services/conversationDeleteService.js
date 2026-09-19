// v569 — suppression d'une conversation, extraite de la route pour être
// testable et pour porter la synchronisation multi-appareils.
//
// CE QUE FAIT VRAIMENT LA SUPPRESSION (inchangé depuis v23.1.255) :
//   - ce n'est PAS une suppression pour les deux : on ajoute l'utilisateur à
//     `conversation.clearedFor`, ce qui masque la conversation pour LUI seul
//     (`GET /conversations/list` exclut `clearedFor: userId`) ;
//   - l'autre partie garde sa copie et peut continuer à écrire ;
//   - un nouveau message remet `clearedFor: []` (cf. conversationController) :
//     la conversation REVIENT chez moi, avec son historique (aucun message
//     n'est supprimé tant que les deux parties ne l'ont pas masquée) ;
//   - quand TOUS les participants l'ont masquée, on purge vraiment (messages +
//     document) — c'est le seul cas de suppression définitive.
//
// v569 — nouveauté : après la suppression on prévient EN DIRECT les AUTRES
// appareils du même utilisateur (iPhone, Android, site) avec
//   conversation:deleted { conversationId, at }
// émis vers SES trois rooms de rôle — exactement le mécanisme de
// `message:read` / `message:delivered` (`emitToUsersAllRoles`), qui garantit
// une seule livraison par socket quel que soit le profil (owner/sitter/walker)
// sous lequel l'appareil est connecté. L'autre partie n'est JAMAIS notifiée :
// chez elle, rien ne change.
const Conversation = require('../models/Conversation');
const Message = require('../models/Message');
const { emitToUsersAllRoles } = require('../sockets/emitter');
const logger = require('../utils/logger');

const idOf = (v) => (v ? String(v._id || v.id || v) : '');

/** Participants « métier » : ceux qui doivent tous avoir masqué pour purger. */
const participantIdsOf = (conversation) => {
  if (!conversation) return [];
  if (conversation.friendChat === true && Array.isArray(conversation.participants)) {
    return conversation.participants.map((p) => idOf(p && p.userId)).filter(Boolean);
  }
  return [conversation.ownerId, conversation.sitterId, conversation.walkerId]
    .map(idOf)
    .filter(Boolean);
};

/**
 * Qui a le DROIT de supprimer : l'union des deux formes, car une conversation
 * friendChat mal formée peut porter les deux (cf. le fix v23.1 part 240 :
 * 403 sur les chats amis dont les participants vivent dans `participants[]`).
 */
const memberIdsOf = (conversation) => {
  const set = new Set(participantIdsOf(conversation));
  for (const v of [conversation.ownerId, conversation.sitterId, conversation.walkerId]) {
    const id = idOf(v);
    if (id) set.add(id);
  }
  if (Array.isArray(conversation.participants)) {
    for (const p of conversation.participants) {
      const id = idOf(p && p.userId);
      if (id) set.add(id);
    }
  }
  return set;
};

class ConversationDeleteError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'ConversationDeleteError';
    this.status = status;
  }
}

/**
 * Masque une conversation pour UN utilisateur (purge si tout le monde l'a
 * masquée) puis synchronise ses autres appareils.
 *
 * Idempotent : rappelée avec le même utilisateur, elle ne duplique rien,
 * répond de nouveau `{ deleted: true }` et ré-émet l'événement (un appareil
 * qui l'avait manqué se recale).
 *
 * @throws {ConversationDeleteError} 400 / 403 / 404
 */
const deleteConversationForUser = async ({ conversationId, userId }) => {
  const uid = String(userId || '');
  const cid = String(conversationId || '');
  if (!cid || !uid) {
    throw new ConversationDeleteError(400, 'Invalid request.');
  }
  const conversation = await Conversation.findById(cid);
  if (!conversation) {
    throw new ConversationDeleteError(404, 'Conversation not found.');
  }
  if (!memberIdsOf(conversation).has(uid)) {
    throw new ConversationDeleteError(403, 'Not a conversation participant.');
  }

  const cleared = new Set((conversation.clearedFor || []).map(String));
  const alreadyCleared = cleared.has(uid);
  cleared.add(uid);

  const participantIds = participantIdsOf(conversation);
  const allCleared =
    participantIds.length > 0 && participantIds.every((pid) => cleared.has(pid));

  let hardDeleted = false;
  if (allCleared) {
    await Message.deleteMany({ conversationId: conversation._id });
    await Conversation.deleteOne({ _id: conversation._id });
    hardDeleted = true;
  } else if (!alreadyCleared) {
    await Conversation.updateOne(
      { _id: conversation._id },
      { $addToSet: { clearedFor: userId } },
    );
  }

  try {
    emitToUsersAllRoles([uid], 'conversation:deleted', {
      conversationId: cid,
      at: new Date().toISOString(),
    });
  } catch (e) {
    // La synchro est un confort : jamais bloquante pour la suppression.
    logger.warn(`[conversation.delete] emit failed : ${e && e.message ? e.message : e}`);
  }

  return {
    deleted: true,
    ...(hardDeleted ? { hardDeleted: true } : {}),
    conversationId: cid,
  };
};

module.exports = {
  deleteConversationForUser,
  ConversationDeleteError,
  participantIdsOf,
};
