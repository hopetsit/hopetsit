const express = require('express');
const PrivacyPolicyDocument = require('../models/PrivacyPolicyDocument');
const logger = require('../utils/logger');

const router = express.Router();

const SUPPORTED = ['en', 'fr', 'es', 'it', 'de', 'pt'];

const normalizeLang = (raw) => {
  const s = String(raw || '').toLowerCase().trim();
  if (!s) return '';
  const short = s.split(/[-_]/)[0];
  return SUPPORTED.includes(short) ? short : '';
};

/**
 * GET /privacy-policy/:lang
 * Public: returns the currently published Privacy Policy for the language.
 * The mobile app falls back to its bundled static text if nothing is
 * published for that locale yet, so 404 is a normal outcome at first.
 */
router.get('/:lang', async (req, res) => {
  try {
    const lang = normalizeLang(req.params.lang);
    if (!lang) {
      return res.status(400).json({ error: 'Unsupported language.' });
    }
    const doc = await PrivacyPolicyDocument.findOne({ language: lang }).lean();
    if (!doc) {
      return res
        .status(404)
        .json({ error: 'No privacy policy published for this language yet.' });
    }
    res.json({
      language: doc.language,
      content: doc.content,
      version: doc.version,
      updatedAt: doc.updatedAt,
    });
  } catch (e) {
    logger.error('[privacy-policy/:lang] failed', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
