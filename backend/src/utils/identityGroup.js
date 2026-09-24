/**
 * v526 — Groupe d'identité multi-rôles.
 *
 * Un même humain = jusqu'à 3 documents Mongo distincts (Owner / Sitter /
 * Walker) reliés uniquement par l'email (et l'oldId legacy). Les amitiés et
 * positions live étant stockées PAR document de rôle, toute lecture qui
 * raisonne « par personne » doit matcher l'ENSEMBLE du groupe — sinon un ami
 * inscrit en sitter « disparaît » dès qu'il bascule sur son profil owner ou
 * walker (bug Daniel du 15/07/2026). Même famille de correctifs que la
 * couronne premium cross-rôle (fetchUserMini / members/nearby / premiumIds).
 *
 * identityGroup(userId) → {
 *   ids:  [String],           // tous les _id de rôle de la personne
 *   docs: [{ id, model }],    // avec leur collection ('Owner'|'Sitter'|'Walker')
 *   set:  Set<String>,        // les mêmes ids, en Set pour les checks O(1)
 * }
 * Contient TOUJOURS au moins l'id passé en entrée (fallback sûr si le doc
 * est introuvable ou si le lookup échoue).
 */
const logger = require('./logger');

async function identityGroup(userId) {
  const Owner = require('../models/Owner');
  const Sitter = require('../models/Sitter');
  const Walker = require('../models/Walker');

  const id = String(userId);
  const ids = [id];
  const set = new Set(ids);
  const docs = [];

  try {
    const sel = 'email oldId';
    const [o, s, w] = await Promise.all([
      Owner.findById(id).select(sel).lean().catch(() => null),
      Sitter.findById(id).select(sel).lean().catch(() => null),
      Walker.findById(id).select(sel).lean().catch(() => null),
    ]);
    if (o) docs.push({ id, model: 'Owner' });
    if (s) docs.push({ id, model: 'Sitter' });
    if (w) docs.push({ id, model: 'Walker' });

    const meDoc = o || s || w;
    const or = [];
    if (meDoc && meDoc.email) or.push({ email: meDoc.email });
    if (meDoc && meDoc.oldId != null) or.push({ oldId: meDoc.oldId });
    if (or.length) {
      const [oo, ss, ww] = await Promise.all([
        Owner.find({ $or: or }).select('_id').lean(),
        Sitter.find({ $or: or }).select('_id').lean(),
        Walker.find({ $or: or }).select('_id').lean(),
      ]);
      const push = (arr, model) => {
        for (const d of arr) {
          const did = String(d._id);
          if (!set.has(did)) {
            set.add(did);
            ids.push(did);
            docs.push({ id: did, model });
          }
        }
      };
      push(oo, 'Owner');
      push(ss, 'Sitter');
      push(ww, 'Walker');
    }
  } catch (e) {
    logger.warn(`[identityGroup] lookup failed for ${id}: ${e.message}`);
  }

  return { ids, docs, set };
}

/**
 * v573 — Set des ids (3 rôles) de la personne connectée, ou Set vide si
 * anonyme. Ne lève jamais.
 */
async function selfIdSet(req) {
  try {
    const id = req && req.user && req.user.id;
    if (!id) return new Set();
    const g = await identityGroup(id);
    return g.set;
  } catch (_) {
    return new Set();
  }
}

/**
 * v583 (lot A du 24/09, validé par Daniel le 23/09) — une conversation dont
 * l'AUTRE participant appartient à mon groupe d'identité (mes propres profils
 * propriétaire / gardien / promeneur) est une conversation avec MOI-MÊME :
 * elle ne doit pas s'afficher dans la liste. Rien n'est supprimé en base ;
 * elle est seulement retirée de la réponse.
 *
 * @param {string|null|undefined} otherPartyId  id du correspondant
 * @param {Set<string>} selfSet  ids de mes 3 rôles (selfIdSet)
 */
function isSelfConversation(otherPartyId, selfSet) {
  if (!otherPartyId || !selfSet || typeof selfSet.has !== 'function') return false;
  return selfSet.has(String(otherPartyId));
}

/**
 * Filtre une liste de conversations enrichies ({ otherParty: { id } }) :
 * retire celles avec moi-même, garde toutes les autres dans le même ordre.
 * Une entrée sans otherParty est laissée telle quelle (c'est le filtre
 * « compte supprimé » du contrôleur qui s'en charge).
 */
function excludeSelfConversations(conversations, selfSet) {
  if (!Array.isArray(conversations)) return [];
  return conversations.filter((c) => {
    const otherId = c && c.otherParty && c.otherParty.id;
    return !isSelfConversation(otherId, selfSet);
  });
}

module.exports = { identityGroup, selfIdSet, isSelfConversation, excludeSelfConversations };
