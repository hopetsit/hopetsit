const express = require('express');
const TermsDocument = require('../models/TermsDocument');
const logger = require('../utils/logger');

const router = express.Router();

const SUPPORTED = ['en', 'fr', 'es', 'it', 'de', 'pt'];

const normalizeLang = (raw) => {
  const s = String(raw || '').toLowerCase().trim();
  if (!s) return '';
  // Accept things like 'fr-FR', 'pt_BR', etc.
  const short = s.split(/[-_]/)[0];
  return SUPPORTED.includes(short) ? short : '';
};

/**
 * GET /terms/:lang
 * Public: returns the currently published Terms of Service for the language.
 * The mobile app falls back to its bundled static text if the document does
 * not exist yet (e.g. admin hasn't published a version), so 404 is normal.
 */
router.get('/:lang', async (req, res) => {
  try {
    const lang = normalizeLang(req.params.lang);
    if (!lang) {
      return res.status(400).json({ error: 'Unsupported language.' });
    }
    const doc = await TermsDocument.findOne({ language: lang }).lean();
    if (!doc) {
      return res.status(404).json({ error: 'No terms document published for this language yet.' });
    }
    res.json({
      language: doc.language,
      content: doc.content,
      version: doc.version,
      updatedAt: doc.updatedAt,
    });
  } catch (e) {
    logger.error('[terms/:lang] failed', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
