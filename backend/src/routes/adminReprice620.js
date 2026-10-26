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
 *   ?silent=1 → écrit les prix corrigés SANS rien envoyer à personne (2610, Daniel).
 *   Une candidature est « alignée » seulement si son prix stocké = celui du moteur unique.
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
    // 2610 (ZOE, ordre de Daniel du 26/10 « corrige les prix SANS envoyer de message aux
    // clients ») — ?silent=1 : recalcul sans AUCUN envoi (ni push, ni e-mail, ni cloche,
    // ni propriétaire ni prestataire).
    const silent = String(req.query.silent || (req.body && req.body.silent) || '') === '1';
    const svc = require('../services/applicationRepricing620');
    const out = await svc.repriceAfterServiceChange(post, { dryRun, notify: silent ? false : undefined });
    const engine = require('../utils/pricingEngine620');
    return res.json({
      postId: String(post._id),
      service: engine.mainService(post),
      dateMode: engine.effectiveDateMode(post),
      visitsPerDay: engine.visitsPerDayOf(post),
      dryRun,
      silent,
      ...out,
    });
  } catch (e) {
    logger.error('[adminReprice620]', e);
    return res.status(500).json({ error: 'Unable to reprice.' });
  }
});

module.exports = router;
