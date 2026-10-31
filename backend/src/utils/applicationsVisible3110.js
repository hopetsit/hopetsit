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
  if (app.archivedAt) return false;
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

/**
 * 3110 (ordre de Daniel 31/10 : « enlève-les ») — ARCHIVE (archivedAt, jamais de suppression) les candidatures
 * dont la demande n'existe plus ou est masquée. `dryRun` = compte sans écrire. Retourne { examined, archived,
 * reasons: { postMissing, postHidden }, byStatus }.
 */
async function archiveOrphanApplications({ dryRun = true, ApplicationModel, PostModel } = {}) {
  const Application = ApplicationModel || require('../models/Application');
  const apps = await Application.find({ archivedAt: null, postId: { $ne: null } }).select('postId status').lean();
  const info = await postInfoByIds(apps.map((a) => a.postId), PostModel);
  const out = { dryRun, examined: apps.length, archived: 0, reasons: { postMissing: 0, postHidden: 0 }, byStatus: { pending: 0, accepted: 0, rejected: 0 } };
  const toArchive = [];
  for (const a of apps) {
    const i = info.get(idOf(a.postId));
    if (i && i.exists && i.hidden !== true) continue;
    const reason = !i || !i.exists ? 'post_missing' : 'post_hidden';
    out.reasons[reason === 'post_missing' ? 'postMissing' : 'postHidden'] += 1;
    out.byStatus[a.status || 'pending'] = (out.byStatus[a.status || 'pending'] || 0) + 1;
    toArchive.push({ id: a._id, reason });
  }
  if (!dryRun && toArchive.length) {
    const now = new Date();
    for (const reason of ['post_missing', 'post_hidden']) {
      const ids = toArchive.filter((t) => t.reason === reason).map((t) => t.id);
      if (!ids.length) continue;
      // eslint-disable-next-line no-await-in-loop
      const r = await Application.updateMany({ _id: { $in: ids }, archivedAt: null }, { $set: { archivedAt: now, archivedReason: reason } });
      out.archived += r.modifiedCount || 0;
    }
  } else {
    out.archived = dryRun ? 0 : 0;
  }
  out.toArchive = toArchive.length;
  return out;
}

/** 3110 — à l'effacement d'une demande : ses candidatures sont archivées (plus jamais de nouvelles orphelines). */
async function archiveApplicationsOfPost(postId, reason = 'post_deleted', ApplicationModel) {
  const Application = ApplicationModel || require('../models/Application');
  if (!idOf(postId)) return 0;
  const r = await Application.updateMany({ postId, archivedAt: null }, { $set: { archivedAt: new Date(), archivedReason: reason } });
  return r.modifiedCount || 0;
}

module.exports = { isApplicationVisible, postInfoByIds, filterVisibleApplications, idOf, archiveOrphanApplications, archiveApplicationsOfPost };
