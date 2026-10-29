/**
 * 26/10/2026 (ADA, décision de Daniel — proposition C de SAM) — repère
 * « le propriétaire a OUVERT la page de ses candidats ».
 *
 *   POST /api/v1/owner-signals/candidates-view
 *     en-tête Authorization: Bearer <jeton du propriétaire> (comme tout appel connecté)
 *     corps { postId? , applicationId? , source? }   (l'un des deux identifiants suffit)
 *       source : 'email' | 'push' | 'notification' | 'direct' | 'link' | 'sms' (2910 : lien du SMS)
 *     → toujours 204 (ne dit jamais si la demande existe ni à qui elle est).
 *
 * Le canal (web / app) et l'origine (vraie session ou script) sont décidés par
 * le SERVEUR (utils/ownerReturn2610.classifyOrigin), pas par le client : un
 * script qui appelle cette route est noté « script » et n'est jamais compté.
 * Seul le propriétaire de la demande (ou un autre de ses profils, même e-mail)
 * crée un repère. Deux ouvertures à moins de 2 min = une seule.
 * Aucun cookie, aucune IP, aucun User-Agent stocké, aucun envoi.
 */
const express = require('express');
const { requireAuth } = require('../middleware/auth');
const logger = require('../utils/logger');
const { classifyOrigin, SOURCES } = require('../utils/ownerReturn2610');

const router = express.Router();
const isId = (s) => /^[a-f0-9]{24}$/i.test(String(s || ''));
const DEDUP_MS = 2 * 60 * 1000;

async function resolvePostId(body) {
  if (isId(body.postId)) return String(body.postId);
  if (isId(body.applicationId)) {
    const Application = require('../models/Application');
    const a = await Application.findById(String(body.applicationId)).select('postId').lean();
    if (a && a.postId) return String(a.postId);
  }
  return null;
}

async function isOwnerOf(user, post) {
  const ownerId = String(post.ownerId && (post.ownerId._id || post.ownerId));
  if (ownerId === String(user.id)) return true;
  try {
    const { identityGroup } = require('../utils/identityGroup');
    const g = await identityGroup(user.id);
    return !!(g && g.set && g.set.has(ownerId));
  } catch (_) {
    return false;
  }
}

router.post('/candidates-view', requireAuth, async (req, res) => {
  try {
    const body = req.body || {};
    const postId = await resolvePostId(body);
    if (!postId) return res.status(204).end();
    const Post = require('../models/Post');
    const post = await Post.findById(postId).select('ownerId postType').lean();
    if (!post || !(await isOwnerOf(req.user, post))) return res.status(204).end();
    const origin = classifyOrigin(req);
    const channel = origin === 'app' ? 'app' : origin === 'web' ? 'web' : '';
    const source = SOURCES.includes(String(body.source || '')) ? String(body.source) : '';
    const CandidatesView = require('../models/CandidatesView2610');
    const ownerId = String(post.ownerId && (post.ownerId._id || post.ownerId));
    const now = new Date();
    const recent = await CandidatesView.findOne({ ownerId, postId, origin, at: { $gte: new Date(now - DEDUP_MS) } })
      .select('_id source').lean();
    if (recent) {
      // Même ouverture (double rendu, rafraîchissement) : on garde la provenance la plus parlante.
      if (source && !recent.source) await CandidatesView.updateOne({ _id: recent._id }, { $set: { source } });
      return res.status(204).end();
    }
    await CandidatesView.create({
      postId, ownerId, at: now, channel, source, origin,
      appVersion: String(req.headers['x-app-version'] || '').slice(0, 40),
    });
    return res.status(204).end();
  } catch (e) {
    logger.warn(`[owner-signals/candidates-view] ${e?.message || e}`);
    return res.status(204).end();
  }
});

module.exports = router;
