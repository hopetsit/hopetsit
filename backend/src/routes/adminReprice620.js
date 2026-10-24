/**
 * 620b (ZOE, 24/10/2026 — ordre de Daniel « mets à jour les annonces déjà publiées ») —
 * REJOUER le recalcul « changement de service » sur une demande déjà requalifiée.
 *
 * BOB a requalifié 4 demandes (garde → visites à domicile) AVANT que le serveur ne sache
 * recalculer les candidatures : leurs candidatures gardaient des totaux à la journée.
 * POST /admin/reprice-620/posts/:id            → recalcule / marque les candidatures en
 *   attente pour le service ACTUEL de la demande (services/applicationRepricing620
 *   .repriceAfterServiceChange), prévient prestataires + propriétaire. Idempotent : une
 *   candidature déjà alignée n'est ni réécrite ni re-notifiée (aucun double envoi).
 *   ?dryRun=1 → simulation, rien d'écrit, rien d'envoyé.
 * Admin seulement (requireAdmin), journalisé par auditAdmin.
 */
const express = require('express');
const mongoose = require('mongoose');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

router.post('/posts/:id', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.isValidObjectId(String(id))) return res.status(400).json({ error: 'Invalid post id.' });
    const Post = require('../models/Post');
    const post = await Post.findById(id);
    if (!post) return res.status(404).json({ error: 'Post not found.' });
    const dryRun = String(req.query.dryRun || (req.body && req.body.dryRun) || '') === '1';
    const svc = require('../services/applicationRepricing620');
    const out = await svc.repriceAfterServiceChange(post, { dryRun });
    const engine = require('../utils/pricingEngine620');
    return res.json({
      postId: String(post._id),
      service: engine.mainService(post),
      dateMode: engine.effectiveDateMode(post),
      visitsPerDay: engine.visitsPerDayOf(post),
      dryRun,
      ...out,
    });
  } catch (e) {
    logger.error('[adminReprice620]', e);
    return res.status(500).json({ error: 'Unable to reprice.' });
  }
});

module.exports = router;
