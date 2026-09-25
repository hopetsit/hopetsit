// v565 — configuration applicative pilotée depuis l'admin (ex. fonctions du
// chat : médias, vocal, réponses). Monté sur /api/v1/app-config.
//
//   GET   /app-config/chat-features         (auth)  → { media, voice, reply }
//   GET   /app-config/admin/chat-features   (admin) → { media, voice, reply }
//   PATCH /app-config/admin/chat-features   (admin, corps partiel) → objet complet
//
// Côté serveur, un drapeau à false fait répondre la route correspondante
// 403 { code: 'FEATURE_DISABLED', feature } (voir conversationController).
const express = require('express');
const { requireAuth, requireRole, optionalAuth } = require('../middleware/auth');
const AppConfig = require('../models/AppConfig');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin')];

router.get('/chat-features', requireAuth, async (req, res) => {
  try {
    res.json(await AppConfig.getChatFeatures());
  } catch (e) {
    logger.error('[app-config/chat-features]', e);
    res.status(500).json({ error: 'Unable to load chat features.' });
  }
});

router.get('/admin/chat-features', requireAdmin, async (req, res) => {
  try {
    res.json(await AppConfig.getChatFeatures());
  } catch (e) {
    logger.error('[app-config/admin/chat-features]', e);
    res.status(500).json({ error: 'Unable to load chat features.' });
  }
});

router.patch('/admin/chat-features', requireAdmin, async (req, res) => {
  try {
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    const known = AppConfig.CHAT_FEATURE_KEYS.filter((k) =>
      Object.prototype.hasOwnProperty.call(body, k));
    if (!known.length) {
      return res.status(400).json({
        error: `Provide at least one of: ${AppConfig.CHAT_FEATURE_KEYS.join(', ')}.`,
      });
    }
    const value = await AppConfig.setChatFeatures(body);
    logger.info(`[app-config] chat-features updated by admin ${req.user?.id}: ${JSON.stringify(value)}`);
    res.json(value);
  } catch (e) {
    if (e && e.status === 400) return res.status(400).json({ error: e.message });
    logger.error('[app-config/admin/chat-features PATCH]', e);
    res.status(500).json({ error: 'Unable to update chat features.' });
  }
});

// v565 — « code du moment » pré-rempli dans le pop-up promo de l'app.
//   GET   /app-config/public-promo        (auth)  → { code, enabled, message }
//   GET   /app-config/admin/public-promo  (admin) → idem
//   PATCH /app-config/admin/public-promo  (admin, corps partiel { code, enabled, message })
router.get('/public-promo', requireAuth, async (req, res) => {
  try {
    return res.json(await AppConfig.getPublicPromo());
  } catch (e) {
    logger.warn(`[app-config] public-promo read failed : ${e?.message || e}`);
    return res.json({ code: 'HOPDALIOS', enabled: true, message: '' });
  }
});
router.get('/admin/public-promo', requireAdmin, async (req, res) => {
  try {
    return res.json(await AppConfig.getPublicPromo());
  } catch (e) {
    return res.status(500).json({ error: e?.message || 'Erreur.' });
  }
});
router.patch('/admin/public-promo', requireAdmin, async (req, res) => {
  try {
    return res.json(await AppConfig.setPublicPromo(req.body || {}));
  } catch (e) {
    return res.status(e?.status || 500).json({ error: e?.message || 'Erreur.' });
  }
});

// v589 — FENÊTRES D'ANNONCE de la PawMap (une fois par appareil, côté app).
//   GET    /app-config/announcements                 (compte facultatif)
//          → { announcements: [{ id, title, body, kind, url, updatedAt }] }
//          filtre : actives, dans leur fenêtre, rôle, plateforme
//          (X-App-Platform), build (X-App-Version, « maxBuild »), langue ?lang=
//   GET    /app-config/admin/announcements           (admin) → liste complète
//   POST   /app-config/admin/announcements           (admin) → créée
//   PATCH  /app-config/admin/announcements/:id       (admin, partiel)
//   DELETE /app-config/admin/announcements/:id       (admin)
const MapAnnouncement = require('../models/MapAnnouncement');
const announce = require('../utils/mapAnnouncements589');

router.get('/announcements', optionalAuth, async (req, res) => {
  try {
    const list = await MapAnnouncement.find({ active: true })
      .sort({ createdAt: -1 }).limit(20).lean();
    const ctx = {
      role: (req.user && req.user.role) || req.query.role || '',
      platform: String(req.headers['x-app-platform'] || req.query.platform || '').toLowerCase(),
      build: announce.buildFromHeader(req.headers['x-app-version']),
      email: '',
    };
    if (req.user && req.user.id && list.some((a) => (a.onlyEmails || []).length)) {
      try {
        const Model = require(`../models/${({ sitter: 'Sitter', walker: 'Walker' })[req.user.role] || 'Owner'}`);
        const doc = await Model.findById(req.user.id).select('email').lean();
        ctx.email = (doc && doc.email) || '';
      } catch (_) {/* e-mail inconnu : les annonces réservées restent cachées */}
    }
    const lang = req.query.lang || (req.headers['accept-language'] || '').slice(0, 2);
    const out = list.filter((a) => announce.isVisibleTo(a, ctx))
      .map((a) => announce.toPublic(a, lang))
      .filter((a) => a.title || a.body);
    res.json({ announcements: out });
  } catch (e) {
    logger.warn(`[app-config] announcements read failed : ${e?.message || e}`);
    res.json({ announcements: [] });
  }
});

router.get('/admin/announcements', requireAdmin, async (req, res) => {
  try {
    const list = await MapAnnouncement.find({}).sort({ createdAt: -1 }).limit(100).lean();
    res.json({ announcements: list });
  } catch (e) {
    res.status(500).json({ error: e?.message || 'Erreur.' });
  }
});

router.post('/admin/announcements', requireAdmin, async (req, res) => {
  try {
    const { value, error } = announce.validate(req.body || {});
    if (error) return res.status(400).json({ error });
    const doc = await MapAnnouncement.create({ ...value, createdBy: String(req.user?.id || '') });
    logger.info(`[app-config] announcement ${doc._id} created by admin ${req.user?.id}`);
    res.status(201).json(doc);
  } catch (e) {
    res.status(500).json({ error: e?.message || 'Erreur.' });
  }
});

router.patch('/admin/announcements/:id', requireAdmin, async (req, res) => {
  try {
    const { value, error } = announce.validate(req.body || {}, { partial: true });
    if (error) return res.status(400).json({ error });
    const doc = await MapAnnouncement.findByIdAndUpdate(req.params.id, { $set: value }, { new: true });
    if (!doc) return res.status(404).json({ error: 'Annonce introuvable.' });
    res.json(doc);
  } catch (e) {
    res.status(500).json({ error: e?.message || 'Erreur.' });
  }
});

router.delete('/admin/announcements/:id', requireAdmin, async (req, res) => {
  try {
    const r = await MapAnnouncement.deleteOne({ _id: req.params.id });
    if (!r.deletedCount) return res.status(404).json({ error: 'Annonce introuvable.' });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e?.message || 'Erreur.' });
  }
});

module.exports = router;
