const SUPPORTED_STRIPE_COUNTRIES = ['FR', 'ES', 'PT', 'IT', 'DE', 'BE', 'LU', 'CH', 'GB', 'US'];

const ibanToCountry = (iban) => {
  if (!iban || typeof iban !== 'string') return null;
  const prefix = iban.replace(/\s+/g, '').toUpperCase().slice(0, 2);
  return /^[A-Z]{2}$/.test(prefix) ? prefix : null;
};

const parseAcceptLanguage = (header) => {
  if (!header || typeof header !== 'string') return null;
  const firstTag = header.split(',')[0].trim();
  const parts = firstTag.split('-');
  if (parts.length >= 2) {
    const region = parts[1].toUpperCase().slice(0, 2);
    if (/^[A-Z]{2}$/.test(region)) return region;
  }
  // Map language-only tags to default country
  const langMap = { fr: 'FR', es: 'ES', pt: 'PT', it: 'IT', de: 'DE', en: 'GB' };
  const lang = parts[0].toLowerCase();
  return langMap[lang] || null;
};

const normalizeCountry = (value) => {
  if (!value) return null;
  const upper = String(value).toUpperCase().trim();
  return /^[A-Z]{2}$/.test(upper) ? upper : null;
};

/**
 * Resolve a Stripe-supported country code from multiple hints, in priority order:
 * 1. explicit (req.body.country)
 * 2. sitterCountry (Sitter.country)
 * 3. ibanCountry (IBAN prefix)
 * 4. acceptLanguage (Accept-Language header)
 * Returns the ISO-2 country code if supported, or null.
 */
const resolveCountry = ({ explicit, sitterCountry, ibanCountry, acceptLanguage } = {}) => {
  const candidates = [
    normalizeCountry(explicit),
    normalizeCountry(sitterCountry),
    normalizeCountry(ibanCountry),
    parseAcceptLanguage(acceptLanguage),
  ];
  for (const c of candidates) {
    if (c && SUPPORTED_STRIPE_COUNTRIES.includes(c)) return c;
  }
  return null;
};

module.exports = {
  SUPPORTED_STRIPE_COUNTRIES,
  ibanToCountry,
  resolveCountry,
};
