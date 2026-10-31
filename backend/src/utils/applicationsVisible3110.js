'use strict';
/**
 * 3110 (ADA — bug vu par ZOE au contrôle du build 631) — candidatures « fantômes ».
 *
 * Une demande (Post) est SUPPRIMÉE physiquement quand le propriétaire l'efface
 * (postController.deletePost → Post.findByIdAndDelete) ; ses candidatures restent en base.
 * GET /applications(/my) les renvoyait → bandeau « Nouvelle candidature » fantôme et
 * compteur faux dans l'app (compte test : 65 candidatures sur 63 demandes effacées, 27 pending).
 *
 * Règle de lecture (aucune donnée supprimée, filtre à la lecture seulement) :
 *   - postId absent (candidatures d'avant v17.1)      → on garde (on ne peut pas trancher) ;
 *   - demande introuvable (supprimée)                  → on retire ;
 *   - demande masquée par la modération (hidden)       → on retire ;
 *   - demande fermée (status 'closed', service terminé) → on retire seulement les `pending`
 *     (celles qui n'ont pas été choisies) ; acceptées / refusées = historique (réservation, avis).
 */

const idOf = (v) => (v && typeof v === 'object' && v._id ? String(v._id) : (v ? String(v) : ''));

/** Pur. `info` = { exists, hidden, status } de la demande (undefined = introuvable). */
function isApplicationVisible(app, info) {
  if (!app) return false;
  if (!idOf(app.postId)) return true;
  if (!info || !info.exists) return false;
  if (info.hidden === true) return false;
  if (info.status === 'closed' && app.status === 'pending') return false;
  return true;
}

/** Lit l'état des demandes citées (une requête, champs minimaux). */
async function postInfoByIds(postIds, PostModel) {
  const Post = PostModel || require('../models/Post');
  const ids = [...new Set(postIds.map(idOf).filter(Boolean))];
  const out = new Map();
  if (!ids.length) return out;
  const docs = await Post.find({ _id: { $in: ids } }).select('_id hidden status').lean();
  for (const d of docs) out.set(String(d._id), { exists: true, hidden: d.hidden === true, status: d.status || 'open' });
  return out;
}

/** Garde seulement les candidatures dont la demande existe encore (règle ci-dessus). */
async function filterVisibleApplications(apps, PostModel) {
  const list = Array.isArray(apps) ? apps : [];
  const info = await postInfoByIds(list.map((a) => a.postId), PostModel);
  return list.filter((a) => isApplicationVisible(a, info.get(idOf(a.postId))));
}

module.exports = { isApplicationVisible, postInfoByIds, filterVisibleApplications, idOf };
