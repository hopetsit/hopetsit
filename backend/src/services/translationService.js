const SUPPORTED = ['fr', 'en', 'es', 'de', 'it', 'pt'];
const PROVIDER = (process.env.TRANSLATION_API_PROVIDER || 'none').toLowerCase();

const passthrough = async (text /*, _from, _to */) => `[auto] ${text}`;

// Stubs for real providers — flip TRANSLATION_API_PROVIDER to enable.
const deepl = async (text, from, to) => {
  // TODO: call https://api.deepl.com/v2/translate with process.env.DEEPL_API_KEY
  return passthrough(text, from, to);
};
const googleTranslate = async (text, from, to) => {
  // TODO: call Google Cloud Translation v3 with process.env.GOOGLE_TRANSLATE_API_KEY
  return passthrough(text, from, to);
};

const translate = async (text, from, to) => {
  if (!text || !to || from === to) return text;
  switch (PROVIDER) {
    case 'deepl':
      return deepl(text, from, to);
    case 'google':
      return googleTranslate(text, from, to);
    case 'none':
    default:
      return passthrough(text, from, to);
  }
};

/**
 * Translate a single body into all supported locales.
 * Returns { fr, en, es, de, it, pt } with the source locale keeping the original text.
 */
const translateToAll = async (text, sourceLang) => {
  const source = SUPPORTED.includes(String(sourceLang || '').toLowerCase())
    ? sourceLang.toLowerCase()
    : 'en';
  const targets = SUPPORTED.filter((l) => l !== source);
  const entries = await Promise.allSettled(
    targets.map(async (to) => [to, await translate(text, source, to)])
  );
  const out = { [source]: text };
  for (const r of entries) {
    if (r.status === 'fulfilled') {
      const [lang, value] = r.value;
      out[lang] = value;
    }
  }
  // Ensure all keys exist (empty fallback) so the Mongoose sub-document is clean.
  for (const l of SUPPORTED) if (out[l] == null) out[l] = '';
  return { translations: out, sourceLanguage: source };
};

module.exports = { translate, translateToAll, SUPPORTED };
