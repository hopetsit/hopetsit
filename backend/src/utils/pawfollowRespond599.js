/**
 * v599 — QUI PEUT RÉPONDRE À UNE DEMANDE DE SUIVI EN DIRECT (Daniel, 29/09 :
 * son frère, propriétaire, lui a envoyé une demande depuis le chat ; Daniel
 * n'a rien pu accepter, nulle part).
 *
 * Cause prouvée dans le code : la demande (message `pawfollow_request`)
 * désignait le destinataire par son RÔLE (`metadata.responderRole`), et
 * l'app comme le serveur comparaient ce rôle au rôle du lecteur. Entre deux
 * PROPRIÉTAIRES amis (rôle identique des deux côtés), l'app croyait que le
 * destinataire était l'expéditeur (« Demande envoyée · En attente » chez les
 * deux, aucun bouton) et le serveur refusait la réponse dès que le lecteur
 * ouvrait le chat sous un autre de ses profils (403).
 *
 * Règle (pure, testée) : la PERSONNE compte, pas le rôle.
 *   · le demandeur ne répond jamais à sa propre demande (tous ses profils) ;
 *   · répond quiconque est l'AUTRE participant de la conversation, sous
 *     n'importe lequel de ses profils ;
 *   · une demande déjà traitée ne se retraite pas.
 */
const idStr = (v) => (v ? String(v._id || v.id || v) : '');

/** Ids de tous les participants d'une conversation (amis ou réservation). */
function participantIds(conversation) {
  if (!conversation) return [];
  const out = [];
  if (conversation.friendChat === true && Array.isArray(conversation.participants)) {
    for (const p of conversation.participants) {
      const id = idStr(p && p.userId);
      if (id) out.push(id);
    }
  } else {
    for (const k of ['ownerId', 'sitterId', 'walkerId']) {
      const id = idStr(conversation[k]);
      if (id) out.push(id);
    }
  }
  return out;
}

/**
 * @param {object} o
 * @param {object} o.message      message `pawfollow_request` (metadata.status, requesterId, senderId)
 * @param {object} o.conversation conversation du message
 * @param {string[]} o.myIds      tous les ids de profil du lecteur
 * @returns {{ok:boolean, code?:string, status?:number}}
 */
function respondDecision({ message, conversation, myIds }) {
  const mine = new Set((myIds || []).map(String).filter(Boolean));
  if (!message || message.type !== 'pawfollow_request') {
    return { ok: false, status: 400, code: 'NOT_PAWFOLLOW_REQUEST' };
  }
  const st = message.metadata && message.metadata.status;
  if (st !== 'pending') return { ok: false, status: 409, code: 'ALREADY_RESPONDED' };
  const requester = idStr((message.metadata && message.metadata.requesterId) || message.senderId);
  if (requester && mine.has(requester)) {
    return { ok: false, status: 403, code: 'OWN_REQUEST' };
  }
  const parts = participantIds(conversation);
  if (!parts.some((p) => mine.has(p))) {
    return { ok: false, status: 403, code: 'NOT_PARTICIPANT' };
  }
  return { ok: true };
}

module.exports = { respondDecision, participantIds };
