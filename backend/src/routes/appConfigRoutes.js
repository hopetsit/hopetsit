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
const { requireAuth, requireRole } = require('../middleware/auth');
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

module.exports = router;
