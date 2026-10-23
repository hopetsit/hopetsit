/**
 * 23/10/2026 (BOB, ordre de Daniel « vérifie les positions GPS, elles sortent toutes du même
 * endroit ») — OÙ EST CE CODE POSTAL ?
 *
 * Un compte inscrit avec sa ville seule, ou une demande publiée sur le site avec une ville,
 * était placé au CENTRE de la ville (geocodeCity) : 16 propriétaires et 13 prestataires au
 * même point à Paris / New York. Le site demande désormais le code postal (inscription et
 * « Publier ma demande ») ; ici on le transforme en position.
 *
 * Nominatim (OpenStreetMap, sans clé), `postalcode` + `country`, 1 requête à la fois,
 * mémorisé en RAM (un code postal ne bouge pas), échec mémorisé 1 h. En cas d'échec on
 * renvoie null et l'appelant garde le comportement d'avant : jamais d'erreur visible.
 */
const logger = require('./logger');
const UA = 'HoPetSit/23.1 (https://www.hopetsit.com; contact@hopetsit.com)';
const TIMEOUT_MS = 5000;
const MISS_TTL_MS = 60 * 60 * 1000;
const CACHE_MAX = 2000;
const _cache = new Map();
let _chain = Promise.resolve();

const cleanCode = (v) => String(v == null ? '' : v).toUpperCase().replace(/[^0-9A-Z]/g, '').slice(0, 10);
const cleanCountry = (v) => String(v == null ? '' : v).toLowerCase().replace(/[^a-z]/g, '').slice(0, 2);

/** Pays ISO-2 à partir du pays, sinon de la langue (fr → France, en → USA), sinon de la forme du code. */
function guessCountry(country, lang, code) {
  const c = cleanCountry(country);
  if (c.length === 2) return c;
  const l = String(lang || '').toLowerCase().slice(0, 2);
  if (l === 'fr' && /^\d{5}$/.test(code)) return 'fr';
  if (l === 'en' && /^\d{5}$/.test(code)) return 'us';
  if (l === 'es' && /^\d{5}$/.test(code)) return 'es';
  if (l === 'de' && /^\d{5}$/.test(code)) return 'de';
  if (l === 'it' && /^\d{5}$/.test(code)) return 'it';
  if (l === 'pt' && /^\d{4}(\d{3})?$/.test(code)) return 'pt';
  if (l === 'pl' && /^\d{5}$/.test(code)) return 'pl';
  return '';
}

async function fetchNominatim(code, country) {
  const q = new URLSearchParams({ postalcode: code, country, format: 'json', limit: '1', addressdetails: '1' });
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const r = await fetch(`https://nominatim.openstreetmap.org/search?${q}`, { headers: { 'User-Agent': UA, Accept: 'application/json' }, signal: ctrl.signal });
    if (!r.ok) return null;
    const d = await r.json();
    const a = Array.isArray(d) && d[0];
    if (!a || !a.lat || !a.lon) return null;
    const ad = a.address || {};
    const city = ad.city || ad.town || ad.village || ad.municipality || ad.suburb || ad.county || '';
    const lat = Number(a.lat); const lng = Number(a.lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || !city) return null;
    return { city, lat, lng, postalCode: code, country: country.toUpperCase() };
  } finally {
    clearTimeout(timer);
  }
}

/**
 * geocodePostal(code, { country, lang }) → { city, lat, lng, postalCode, country } | null
 */
async function geocodePostal(rawCode, { country, lang } = {}) {
  const code = cleanCode(rawCode);
  if (code.length < 3) return null;
  const cc = guessCountry(country, lang, code);
  if (!cc) return null;
  const key = `${cc}:${code}`;
  const hit = _cache.get(key);
  if (hit && (hit.v || Date.now() - hit.t < MISS_TTL_MS)) return hit.v;
  // une requête Nominatim à la fois (politesse) ; une seconde d'écart après un vrai appel
  const run = _chain.then(async () => {
    let v = null;
    try { v = await fetchNominatim(code, cc); } catch (e) { logger.warn(`[geocodePostal] ${key} : ${e?.message || e}`); }
    if (_cache.size >= CACHE_MAX) _cache.delete(_cache.keys().next().value);
    _cache.set(key, { t: Date.now(), v });
    await new Promise((r) => setTimeout(r, 1000));
    return v;
  });
  _chain = run.catch(() => null);
  return run;
}

/** Position d'un compte ou d'une demande : code postal d'abord, sinon null. */
async function locationFromPostal(postalCode, { country, lang, city } = {}) {
  const g = await geocodePostal(postalCode, { country, lang });
  if (!g) return null;
  const c = typeof city === 'string' && city.trim() ? city.trim() : g.city;
  return { city: c, lat: g.lat, lng: g.lng, postalCode: g.postalCode };
}

const _resetForTest = () => { _cache.clear(); _chain = Promise.resolve(); };
module.exports = { geocodePostal, locationFromPostal, guessCountry, cleanCode, _resetForTest };
