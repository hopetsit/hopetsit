/**
 * Translate Routes — v23.1 part 72.
 *
 * Daniel : "Chat traduire selon langue prifil". Owners / sitters /
 * walkers can chat in their own language and have the other party's
 * messages translated to their profile language on demand.
 *
 * Backend strategy : proxy to a free translation provider.
 *   1. Try LibreTranslate (community public instance — free, no key)
 *   2. Try MyMemory (free public API, 1000 words/day per IP)
 *   3. Fall back to identity (return source unchanged + warn)
 *
 * Endpoints :
 *   POST /translate { text, targetLang, sourceLang? }
 *     → { translation, detectedSourceLang, provider }
 */
const express = require('express');
const { requireAuth } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();

// Public LibreTranslate endpoints (community instances). We try them in
// order — if one is down or rate-limited we fall through to the next.
const LT_INSTANCES = [
  'https://libretranslate.de/translate',
  'https://translate.argosopentech.com/translate',
];

async function _tryLibreTranslate(text, source, target) {
  for (const url of LT_INSTANCES) {
    try {
      const r = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          q: text,
          source: source || 'auto',
          target,
          format: 'text',
        }),
      });
      if (!r.ok) continue;
      const data = await r.json();
      if (data && data.translatedText) {
        return {
          translation: data.translatedText,
          detectedSourceLang: data.detectedLanguage?.language || source || 'auto',
          provider: `libretranslate (${new URL(url).hostname})`,
        };
      }
    } catch (e) {
      logger.warn(`[translate] LT ${url} failed : ${e.message}`);
    }
  }
  return null;
}

// MyMemory free fallback : GET https://api.mymemory.translated.net/get?q=...&langpair=fr|en
async function _tryMyMemory(text, source, target) {
  try {
    const src = source && source !== 'auto' ? source : 'auto';
    const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=${src}|${target}`;
    const r = await fetch(url);
    if (!r.ok) return null;
    const data = await r.json();
    const tr = data?.responseData?.translatedText;
    if (tr && typeof tr === 'string') {
      return {
        translation: tr,
        detectedSourceLang: src,
        provider: 'mymemory',
      };
    }
  } catch (e) {
    logger.warn(`[translate] MyMemory failed : ${e.message}`);
  }
  return null;
}

router.post('/', requireAuth, async (req, res) => {
  try {
    const text = (req.body?.text || '').toString();
    const targetLang = (req.body?.targetLang || '').toString().slice(0, 5).toLowerCase();
    const sourceLang = (req.body?.sourceLang || 'auto').toString().slice(0, 5).toLowerCase();

    if (!text || !targetLang) {
      return res.status(400).json({ error: 'text + targetLang required.' });
    }
    if (text.length > 2000) {
      return res.status(413).json({ error: 'Text too long (max 2000 chars).' });
    }

    // Skip translation if source already matches target.
    if (sourceLang !== 'auto' && sourceLang === targetLang) {
      return res.json({
        translation: text,
        detectedSourceLang: sourceLang,
        provider: 'identity',
      });
    }

    let result = await _tryLibreTranslate(text, sourceLang, targetLang);
    if (!result) result = await _tryMyMemory(text, sourceLang, targetLang);
    if (!result) {
      // No provider succeeded — return identity with a flag so the UI
      // can show "translation unavailable" instead of the raw error.
      return res.json({
        translation: text,
        detectedSourceLang: sourceLang,
        provider: 'identity',
        warning: 'translation_unavailable',
      });
    }
    res.json(result);
  } catch (e) {
    logger.error(`[translate] ${e.message}`);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
