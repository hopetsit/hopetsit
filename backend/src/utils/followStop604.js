/**
 * v604 (PAM, 30/09/2026) — « ARRÊTER DE SUIVRE » DEPUIS LA PAWMAP.
 *
 * Daniel : « Arrêter le suivre marche pas ». Sur la carte, « Arrêter de
 * suivre » ne faisait que décoller la caméra : la demande de suivi restait
 * acceptée et le chat affichait toujours « Suivi actif ».
 *
 * La carte connaît la PERSONNE suivie, pas la conversation : on retrouve les
 * conversations où une demande de suivi ACCEPTÉE nous relie tous les deux,
 * puis on délègue à la règle de ZOE (utils/pawfollowState604.js,
 * `endPawfollowInConversation`, scope 'following') qui ne termine QUE mon
 * sens de suiveur. Suivi mutuel : si la personne me suit aussi, son sens à
 * elle continue.
 */
const logger = require('./logger');

async function idsOf(userId) {
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

function involving(forms) {
  return {
    $or: [
      { 'metadata.requesterId': { $in: forms } },
      { 'metadata.respondedBy': { $in: forms } },
      { senderId: { $in: forms.filter((v) => typeof v !== 'string') } },
    ],
  };
}

/**
 * Conversations (ids, sans doublon) des demandes où [targetIds] PARTAGE et
 * où l'autre personne n'est pas lui (pure).
 */
function conversationsFollowing(messages, { targetIds, sharerIdOf }) {
  const target = new Set((targetIds || []).map(String));
  const out = [];
  for (const m of messages || []) {
    if (!m || !target.has(String(sharerIdOf(m) || ''))) continue;
    const cid = String(m.conversationId || '');
    if (cid && !out.includes(cid)) out.push(cid);
  }
  return out;
}

/**
 * Je (userId) ne suis plus [targetId] : termine mon sens de suiveur dans
 * chaque conversation qui nous relie. @returns nombre de demandes terminées.
 */
async function stopFollowing({ userId, targetId, now = new Date() }) {
  const pf = require('./pawfollowState604');
  const Message = require('../models/Message');
  const Conversation = require('../models/Conversation');
  const [myIds, targetIds] = await Promise.all([idsOf(userId), idsOf(targetId)]);
  if (!myIds.length || !targetIds.length) return 0;
  const accepted = await Message.find({
    type: pf.PF_TYPE,
    'metadata.status': 'accepted',
    deletedAt: null,
    $and: [involving(bothForms(myIds)), involving(bothForms(targetIds))],
  }).lean();
  const convIds = conversationsFollowing(accepted, { targetIds, sharerIdOf: pf.sharerIdOf });
  let n = 0;
  for (const cid of convIds) {
    try {
      // eslint-disable-next-line no-await-in-loop
      const conversation = await Conversation.findById(cid).lean();
      if (!conversation) continue;
      // eslint-disable-next-line no-await-in-loop
      n += await pf.endPawfollowInConversation({ conversation, userId, scope: 'following', now });
    } catch (e) {
      logger.warn(`[followStop604] ${cid} failed : ${e && e.message ? e.message : e}`);
    }
  }
  return n;
}

module.exports = { conversationsFollowing, stopFollowing };
