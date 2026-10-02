'use strict';

/**
 * 607 (NEO, 02/10/2026) — FUITE relevée par LEO : deux gardiens avaient saisi
 * une adresse e-mail dans le champ « ville » ; elle sortait dans leur lien
 * public (/s/…-dadaniecka-gmail-com) et comme « ville » dans les routes
 * publiques. Règle commune : une « ville » qui contient un @, une adresse web,
 * un numéro (6 chiffres ou plus) ou plus de 60 caractères n'est JAMAIS publiée.
 * La donnée en base n'est pas touchée : on ne la montre simplement plus
 * (la personne elle-même la voit toujours dans son écran de modification).
 */
const MAX_CITY = 60;

function isUnsafeCity(v) {
  const s = String(v == null ? '' : v).trim();
  if (!s) return false;
  if (s.length > MAX_CITY) return true;
  if (s.includes('@')) return true;
  if (/(https?:\/\/|www\.|\.(com|fr|net|org|io|es|de|it|co|uk|us|pl|pt|be|ch)\b)/i.test(s)) return true;
  if ((s.match(/\d/g) || []).length >= 6) return true;
  return false;
}

/** La ville publiable, ou ''. */
const publicCity = (v) => (isUnsafeCity(v) ? '' : String(v == null ? '' : v).trim());

const CITY_KEYS = new Set(['city', 'coverageCity', 'label']);

/**
 * Nettoie EN PLACE toutes les villes non publiables d'une réponse publique
 * (à toutes les profondeurs : location.city, homeLocation.city, mapBoostLocation.label…).
 */
function scrubCities(obj, depth = 0) {
  if (!obj || typeof obj !== 'object' || depth > 6) return obj;
  if (Array.isArray(obj)) { obj.forEach((x) => scrubCities(x, depth + 1)); return obj; }
  for (const [k, v] of Object.entries(obj)) {
    if (CITY_KEYS.has(k) && typeof v === 'string') { if (isUnsafeCity(v)) obj[k] = ''; }
    else if (v && typeof v === 'object' && !(v instanceof Date) && !Buffer.isBuffer(v)) scrubCities(v, depth + 1);
  }
  return obj;
}

module.exports = { isUnsafeCity, publicCity, scrubCities, MAX_CITY };
