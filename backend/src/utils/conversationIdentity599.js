/**
 * v599 (ZOE, 29/09/2026) — UNE conversation par paire de PERSONNES.
 *
 * Constat sur la prod (captures du frère de Daniel, 28/09) : « Daniel C »
 * apparaissait DEUX fois dans la liste de John. Un humain = jusqu'à 3
 * documents (Owner / Sitter / Walker) reliés par l'e-mail ; chaque parcours
 * (réservation, candidature, bouton 💬 ami, suivi en direct) ouvrait SA
 * conversation sur SA paire d'ids de rôle. Résultat : 3 fils John ↔ Daniel
 * (ami owner↔owner avec les vocaux, réservation John-owner ↔ Daniel-sitter
 * avec « Demande de suivi en direct », réservation Daniel-owner ↔ John-walker),
 * et des messages que Daniel ne voyait pas depuis son profil propriétaire.
 *
 * Ce module donne au serveur une vue « par personne » :
 *   - sideOf(conv, mesIds)            : de quel côté de la conversation je suis ;
 *   - isMemberByIdentity(conv, mesIds): accès à la conversation (tous rôles) ;
 *   - resolveConversation(id)         : suit `mergedInto` (fil fusionné → fil
 *                                       canonique), pour que l'app 598 qui
 *                                       garde un ancien id continue de marcher ;
 *   - findConversationBetweenPersons  : réutilise un fil existant avant d'en
 *                                       créer un nouveau ;
 *   - mergeDuplicatesFor(mesIds)      : fusion paresseuse et idempotente des
 *                                       doublons d'une personne (déclenchée à
 *                                       la lecture de sa liste) : les messages
 *                                       sont DÉPLACÉS, jamais supprimés ;
 *   - personalizeMessage              : `mine` + `senderId` vu par le lecteur
 *                                       (l'app 598 décide « à moi » par
 *                                       senderId == mon id de rôle courant).
 *
 * Compatibilité app 598 : aucun contrat changé, champs ajoutés seulement.
 */
const Conversation = require('../models/Conversation');
const Message = require('../models/Message');
const { identityGroup } = require('./identityGroup');
const logger = require('./logger');

const idOf = (v) => (v ? String(v._id || v.id || v) : '');

/** Tous les ids (String) présents dans une conversation, quel que soit le type. */
const memberIdsOf = (conversation) => {
  const out = new Set();
  if (!conversation) return out;
  for (const v of [conversation.ownerId, conversation.sitterId, conversation.walkerId]) {
    const id = idOf(v);
    if (id) out.add(id);
  }
  if (Array.isArray(conversation.participants)) {
    for (const p of conversation.participants) {
      const id = idOf(p && p.userId);
      if (id) out.add(id);
    }
  }
  return out;
};

const toSet = (ids) => {
  if (ids instanceof Set) return ids;
  if (Array.isArray(ids)) return new Set(ids.map(String));
  if (ids && typeof ids.has === 'function') return ids;
  return new Set(ids ? [String(ids)] : []);
};

/** Vrai si l'un de mes ids (tous rôles) est membre de la conversation. */
const isMemberByIdentity = (conversation, myIds) => {
  const mine = toSet(myIds);
  for (const id of memberIdsOf(conversation)) if (mine.has(id)) return true;
  return false;
};

/**
 * De quel côté suis-je ?
 *   { side: 'owner' | 'provider' | 'participant' | null,
 *     myIds: [ids de MOI dans ce fil], otherIds: [ids de l'AUTRE dans ce fil],
 *     otherRole: 'owner' | 'sitter' | 'walker' | null,
 *     participantIndexes: [index de mes entrées participants[]] }
 * Une conversation avec moi-même (les deux côtés sont à moi) renvoie
 * side = 'owner'/'participant' avec otherIds vide : l'appelant décide.
 */
const sideOf = (conversation, myIds) => {
  const mine = toSet(myIds);
  const res = { side: null, myIds: [], otherIds: [], otherRole: null, participantIndexes: [] };
  if (!conversation) return res;
  if (conversation.friendChat === true && Array.isArray(conversation.participants)) {
    conversation.participants.forEach((p, i) => {
      const id = idOf(p && p.userId);
      if (!id) return;
      if (mine.has(id)) {
        res.myIds.push(id);
        res.participantIndexes.push(i);
      } else {
        res.otherIds.push(id);
        if (!res.otherRole) res.otherRole = String(p.userModel || 'Owner').toLowerCase();
      }
    });
    res.side = res.myIds.length ? 'participant' : null;
    return res;
  }
  const ownerId = idOf(conversation.ownerId);
  const providerId = idOf(conversation.sitterId) || idOf(conversation.walkerId);
  const providerRole = idOf(conversation.sitterId) ? 'sitter' : (idOf(conversation.walkerId) ? 'walker' : null);
  const iAmOwner = ownerId && mine.has(ownerId);
  const iAmProvider = providerId && mine.has(providerId);
  if (iAmOwner) {
    res.side = 'owner';
    res.myIds.push(ownerId);
    if (providerId && !mine.has(providerId)) { res.otherIds.push(providerId); res.otherRole = providerRole; }
  } else if (iAmProvider) {
    res.side = 'provider';
    res.myIds.push(providerId);
    if (ownerId && !mine.has(ownerId)) { res.otherIds.push(ownerId); res.otherRole = 'owner'; }
  }
  return res;
};

/**
 * Suit `mergedInto` jusqu'au fil canonique (3 sauts max). Renvoie le document
 * Mongoose (ou null). `select` / `populate` optionnels s'appliquent au fil final.
 */
const resolveConversation = async (conversationId, { select = null, populate = null, lean = false } = {}) => {
  let id = idOf(conversationId);
  if (!id) return null;
  let conv = null;
  for (let hop = 0; hop < 4; hop += 1) {
    let q = Conversation.findById(id);
    if (select) q = q.select(select);
    if (populate) for (const p of [].concat(populate)) q = q.populate(p);
    if (lean) q = q.lean();
    // eslint-disable-next-line no-await-in-loop
    conv = await q;
    if (!conv) return null;
    const next = idOf(conv.mergedInto);
    if (!next || next === id) return conv;
    id = next;
  }
  return conv;
};

/** Ids canonique d'un id de conversation (suit mergedInto, sans populate). */
const canonicalIdOf = async (conversationId) => {
  const c = await resolveConversation(conversationId, { select: '_id mergedInto', lean: true });
  return c ? String(c._id) : idOf(conversationId);
};

/**
 * Fil existant entre deux PERSONNES (deux groupes d'ids), non fusionné.
 * Préfère un fil « réservation » (ownerId + prestataire) au fil « ami »,
 * puis le plus récent.
 */
const findConversationBetweenPersons = async (idsA, idsB, { populate = null } = {}) => {
  const a = [...toSet(idsA)];
  const b = [...toSet(idsB)];
  if (!a.length || !b.length) return null;
  const inA = { $in: a };
  const inB = { $in: b };
  const pairs = [
    { ownerId: inA, sitterId: inB }, { ownerId: inA, walkerId: inB },
    { ownerId: inB, sitterId: inA }, { ownerId: inB, walkerId: inA },
    { friendChat: true, $and: [{ 'participants.userId': inA }, { 'participants.userId': inB }] },
  ];
  let q = Conversation.find({ $or: pairs, mergedInto: null }).sort({ lastMessageAt: -1, updatedAt: -1 });
  if (populate) for (const p of [].concat(populate)) q = q.populate(p);
  const rows = await q;
  if (!rows || !rows.length) return null;
  const booking = rows.find((c) => c.friendChat !== true);
  return booking || rows[0];
};

/**
 * Clé « personne » d'un document utilisateur : e-mail (en minuscules) sinon
 * oldId sinon id. Sert à regrouper les fils par correspondant.
 */
const personKeyOf = (doc) => {
  if (!doc) return '';
  if (doc.email) return `e:${String(doc.email).toLowerCase()}`;
  if (doc.oldId != null) return `o:${String(doc.oldId)}`;
  return `i:${idOf(doc)}`;
};

/** Canonique parmi des doublons : le plus récent ; à égalité, la réservation. */
const pickCanonical = (convs) => {
  const sorted = [...convs].sort((x, y) => {
    const tx = new Date(x.lastMessageAt || x.updatedAt || 0).getTime();
    const ty = new Date(y.lastMessageAt || y.updatedAt || 0).getTime();
    if (ty !== tx) return ty - tx;
    const bx = x.friendChat === true ? 1 : 0;
    const by = y.friendChat === true ? 1 : 0;
    return bx - by;
  });
  return sorted[0];
};

/**
 * Fusionne `dups` dans `canonical` : messages déplacés, compteurs non lus
 * additionnés côté par côté, `mergedInto` posé sur chaque doublon. Idempotent.
 * Ne supprime RIEN.
 */
const mergeInto = async (canonical, dups, personIdsA, personIdsB) => {
  const canonId = idOf(canonical);
  let moved = 0;
  for (const dup of dups) {
    const dupId = idOf(dup);
    if (!dupId || dupId === canonId) continue;
    // eslint-disable-next-line no-await-in-loop
    const r = await Message.updateMany({ conversationId: dup._id }, { $set: { conversationId: canonical._id } });
    moved += (r && (r.modifiedCount || r.nModified)) || 0;
    // Compteurs non lus : on reporte ceux du doublon sur le côté correspondant
    // du canonique (par personne, pas par rôle).
    const inc = {};
    const sideA = sideOf(dup, personIdsA);
    const sideB = sideOf(dup, personIdsB);
    const unreadOf = (s, conv) => {
      if (!s.side) return 0;
      if (s.side === 'participant') {
        return s.participantIndexes.reduce((n, i) => n + ((conv.participants[i] && conv.participants[i].unreadCount) || 0), 0);
      }
      return s.side === 'owner' ? (conv.ownerUnreadCount || 0) : (conv.sitterUnreadCount || 0);
    };
    const addTo = (s, n) => {
      if (!n || !s.side) return;
      if (s.side === 'participant') {
        const i = s.participantIndexes[0];
        if (i != null) inc[`participants.${i}.unreadCount`] = (inc[`participants.${i}.unreadCount`] || 0) + n;
      } else if (s.side === 'owner') inc.ownerUnreadCount = (inc.ownerUnreadCount || 0) + n;
      else inc.sitterUnreadCount = (inc.sitterUnreadCount || 0) + n;
    };
    addTo(sideOf(canonical, personIdsA), unreadOf(sideA, dup));
    addTo(sideOf(canonical, personIdsB), unreadOf(sideB, dup));
    const set = { mergedInto: canonical._id };
    const dupAt = new Date(dup.lastMessageAt || 0).getTime();
    const canAt = new Date(canonical.lastMessageAt || 0).getTime();
    const setCanon = {};
    if (dupAt > canAt) {
      setCanon.lastMessage = dup.lastMessage || '';
      setCanon.lastMessageKind = dup.lastMessageKind || '';
      setCanon.lastMessageAt = dup.lastMessageAt;
    }
    // eslint-disable-next-line no-await-in-loop
    await Conversation.updateOne({ _id: dup._id }, { $set: set });
    const update = {};
    if (Object.keys(inc).length) update.$inc = inc;
    if (Object.keys(setCanon).length) update.$set = setCanon;
    // eslint-disable-next-line no-await-in-loop
    if (Object.keys(update).length) await Conversation.updateOne({ _id: canonical._id }, update);
    logger.info(`[chat.merge] ${dupId} → ${canonId} (${moved} message(s) déplacé(s))`);
  }
  return moved;
};

/**
 * Fusion paresseuse pour une personne (ses ids de rôle) : regroupe ses fils
 * par correspondant et fusionne les doublons. Ramène aussi dans le fil
 * canonique les messages qu'un ancien chemin (webhook, app 598) aurait posés
 * dans un fil déjà fusionné. Ne lève jamais.
 */
const mergeDuplicatesFor = async (myIds) => {
  const mine = [...toSet(myIds)];
  if (!mine.length) return { merged: 0, moved: 0 };
  try {
    const inMine = { $in: mine };
    const all = await Conversation.find({
      $or: [{ ownerId: inMine }, { sitterId: inMine }, { walkerId: inMine }, { 'participants.userId': inMine }],
    });
    if (!all || !all.length) return { merged: 0, moved: 0 };
    // 1) Balayage : messages restés dans un fil fusionné → canonique.
    let moved = 0;
    for (const c of all) {
      const target = idOf(c.mergedInto);
      if (!target) continue;
      // eslint-disable-next-line no-await-in-loop
      const canonId = await canonicalIdOf(target);
      // eslint-disable-next-line no-await-in-loop
      const r = await Message.updateMany({ conversationId: c._id }, { $set: { conversationId: canonId } });
      moved += (r && (r.modifiedCount || r.nModified)) || 0;
    }
    // 2) Regroupement par correspondant.
    const live = all.filter((c) => !idOf(c.mergedInto));
    if (live.length < 2) return { merged: 0, moved };
    const Owner = require('../models/Owner');
    const Sitter = require('../models/Sitter');
    const Walker = require('../models/Walker');
    const otherIds = new Set();
    const mineSet = new Set(mine);
    for (const c of live) for (const id of memberIdsOf(c)) if (!mineSet.has(id)) otherIds.add(id);
    if (!otherIds.size) return { merged: 0, moved };
    const arr = [...otherIds];
    const docs = (await Promise.all([Owner, Sitter, Walker].map((M) =>
      M.find({ _id: { $in: arr } }).select('email oldId').lean(),
    ))).flat();
    const keyById = new Map(docs.map((d) => [String(d._id), personKeyOf(d)]));
    const groups = new Map(); // personKey → { convs, ids }
    for (const c of live) {
      const others = [...memberIdsOf(c)].filter((id) => !mineSet.has(id));
      if (!others.length) continue; // fil avec moi-même : laissé tel quel (masqué par la liste)
      const key = keyById.get(others[0]) || `i:${others[0]}`;
      const g = groups.get(key) || { convs: [], ids: new Set() };
      g.convs.push(c);
      for (const id of others) g.ids.add(id);
      groups.set(key, g);
    }
    let merged = 0;
    for (const [, g] of groups) {
      if (g.convs.length < 2) continue;
      // Tous les ids de rôle de l'autre personne (pour les côtés du canonique).
      const otherKey = keyById.get([...g.ids][0]);
      const otherAll = new Set(g.ids);
      if (otherKey) for (const [id, k] of keyById) if (k === otherKey) otherAll.add(id);
      const canonical = pickCanonical(g.convs);
      const dups = g.convs.filter((c) => idOf(c) !== idOf(canonical));
      // eslint-disable-next-line no-await-in-loop
      moved += await mergeInto(canonical, dups, mineSet, otherAll);
      merged += dups.length;
    }
    return { merged, moved };
  } catch (e) {
    logger.warn(`[chat.merge] fusion impossible : ${e && e.message ? e.message : e}`);
    return { merged: 0, moved: 0, error: true };
  }
};

/**
 * Message vu par un lecteur : `mine` (envoyé par l'un de MES profils) et, pour
 * l'app 598 qui compare senderId à son id de rôle courant, `senderId` réécrit
 * sur mon id courant quand le message est à moi.
 */
const personalizeMessage = (message, myIds, myCurrentId) => {
  if (!message) return message;
  const mine = toSet(myIds);
  const sid = idOf(message.senderId);
  const isMine = !!sid && mine.has(sid) && String(message.senderRole || '') !== 'system';
  const out = { ...message, mine: isMine };
  if (isMine && myCurrentId) out.senderId = String(myCurrentId);
  if (out.replyTo && typeof out.replyTo === 'object') {
    const rid = idOf(out.replyTo.senderId);
    if (rid && mine.has(rid) && myCurrentId) out.replyTo = { ...out.replyTo, senderId: String(myCurrentId) };
  }
  return out;
};

/** Groupe d'identité (Set d'ids) d'un utilisateur ; contient toujours l'id passé. */
const identityIds = async (userId) => {
  try {
    const g = await identityGroup(userId);
    return g.set;
  } catch (_) {
    return new Set(userId ? [String(userId)] : []);
  }
};

module.exports = {
  idOf,
  memberIdsOf,
  isMemberByIdentity,
  sideOf,
  resolveConversation,
  canonicalIdOf,
  findConversationBetweenPersons,
  personKeyOf,
  pickCanonical,
  mergeInto,
  mergeDuplicatesFor,
  personalizeMessage,
  identityIds,
};
