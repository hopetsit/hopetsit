const express = require('express');
const AppVersionConfig = require('../models/AppVersionConfig');
const logger = require('../utils/logger');

const router = express.Router();

// v561 — public : l'app compare son build (versionCode / CFBundleVersion)
// à `latest` / `minimum` pour proposer ou imposer la mise à jour.
// Cache court côté serveur (60 s) : appelé à chaque démarrage d'app.
let cache = { at: 0, body: null };

router.get('/', async (req, res) => {
  try {
    if (cache.body && Date.now() - cache.at < 60 * 1000) {
      return res.json(cache.body);
    }
    const doc = await AppVersionConfig.getSingleton();
    const body = {
      android: {
        latest: doc.android?.latest || 0,
        minimum: doc.android?.minimum || 0,
        url: doc.android?.url || '',
        message: doc.android?.message || '',
      },
      ios: {
        latest: doc.ios?.latest || 0,
        minimum: doc.ios?.minimum || 0,
        url: doc.ios?.url || '',
        message: doc.ios?.message || '',
      },
    };
    cache = { at: Date.now(), body };
    res.set('Cache-Control', 'public, max-age=60');
    res.json(body);
  } catch (e) {
    logger.error('[app-version:get]', e);
    res.status(500).json({ error: e.message });
  }
});

router.invalidateCache = () => {
  cache = { at: 0, body: null };
};

module.exports = router;
