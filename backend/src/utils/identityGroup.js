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

module.exports = { identityGroup };
