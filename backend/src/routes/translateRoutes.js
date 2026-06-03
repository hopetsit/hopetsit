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
        // v23.1.278 — timeout 6s : les instances LibreTranslate publiques sont
        // souvent mortes/payantes ; sans timeout le bouton "Traduire" pendait.
        signal: AbortSignal.timeout(6000),
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

// v23.1 part 122 — Daniel : "'AUTO' IS AN INVALID SOURCE LANGUAGE".
// MyMemory n'accepte PAS 'auto' comme source — il faut un code ISO-2.
// Quand source='auto', on essaie plusieurs candidats courants jusqu'à ce
// qu'on en trouve un qui marche (avec un score > 0.5). On commence par
// les langues les plus probables : EN puis la langue du target (souvent
// le user parle la même que target), puis les autres principales.
async function _tryMyMemory(text, source, target) {
  // Si source connue et différente de 'auto', essai unique.
  if (source && source !== 'auto') {
    return _myMemoryTrySingle(text, source, target);
  }
  // Auto-detect : on essaie EN, FR, ES, DE, IT, PT en cascade et on garde la
  // MEILLEURE correspondance (match score le plus élevé), pas juste la 1ère —
  // sinon on choisissait une mauvaise source.
  const candidates = ['en', 'fr', 'es', 'de', 'it', 'pt'].filter(
    (l) => l !== target,
  );
  let best = null;
  for (const src of candidates) {
    const r = await _myMemoryTrySingle(text, src, target);
    if (r && (!best || (r.matchScore || 0) > (best.matchScore || 0))) {
      best = r;
      // Confiance haute → on arrête tôt (évite d'épuiser le quota MyMemory).
      if ((r.matchScore || 0) >= 0.85) break;
    }
  }
  return best;
}

async function _myMemoryTrySingle(text, src, target) {
  try {
    const email = (process.env.MYMEMORY_EMAIL || '').trim();
    const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=${src}|${target}${email ? `&de=${encodeURIComponent(email)}` : ''}`;
    const r = await fetch(url, { signal: AbortSignal.timeout(6000) });
    if (!r.ok) return null;
    const data = await r.json();
    const tr = data?.responseData?.translatedText;
    const match = Number(data?.responseData?.match || 0);
    // Si MyMemory renvoie une erreur (genre "INVALID SOURCE LANGUAGE")
    // dans le translatedText, on ignore.
    if (!tr || typeof tr !== 'string') return null;
    const trU = tr.toUpperCase();
    if (trU.includes('INVALID') ||
        trU.includes('NO CONTENT') ||
        trU.includes('MUST BE A VALID') ||
        trU.includes('QUERY LENGTH LIMIT') ||
        trU.includes('MYMEMORY WARNING')) {
      return null;
    }
    // v23.1.278 — Daniel : "le bouton traduire ne marche pas". L'ancien filtre
    // match < 0.5 rejetait des traductions VALIDES (le score MyMemory est un
    // score de mémoire de traduction, souvent bas pour une trad machine
    // correcte). On accepte donc toute trad non-erreur et DIFFÉRENTE du texte
    // source ; le score sert juste au ranking de la source auto-détectée.
    if (tr.trim().toLowerCase() === String(text).trim().toLowerCase()) {
      return null; // identique → pas une vraie traduction (mauvaise source)
    }
    return {
      translation: tr,
      detectedSourceLang: src,
      provider: 'mymemory',
      matchScore: match,
    };
  } catch (e) {
    logger.warn(`[translate] MyMemory ${src}->${target} failed : ${e.message}`);
    return null;
  }
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
