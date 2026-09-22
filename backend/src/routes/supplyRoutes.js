/**
 * 22/09/2026 — COMBIEN DE GARDIENS ET DE PROMENEURS DANS CETTE VILLE ?
 *
 * Pourquoi : les pages villes propriétaires (cibles de la publicité Meta Paris
 * et Dallas) ne montraient AUCUNE preuve qu'il y a des prestataires. Un
 * visiteur lisait une promesse commerciale et repartait : mesuré le 22/09,
 * 52 visiteurs sur /garde-animaux/paris, zéro clic sur quoi que ce soit.
 * Un nombre vrai et vérifiable vaut mieux qu'un argumentaire.
 *
 * Vie privée : cette route est PUBLIQUE, donc elle ne renvoie QUE des
 * NOMBRES — aucun nom, aucune photo, aucune position, aucun identifiant.
 * (La liste nominative des membres, /friends/members/world, reste réservée
 * aux personnes connectées : c'est volontaire, on ne l'ouvre pas.)
 * Sont exclus : comptes de test, staff, bannis et profils masqués.
 *
 * GET /api/v1/supply/city?city=Paris[&lat=48.85&lng=2.35&radiusKm=25]
 *   → { city, sitters, walkers, total, radiusKm }
 */

const express = require('express');
const logger = require('../utils/logger');

const router = express.Router();

const CACHE_TTL_MS = 10 * 60 * 1000; // 10 min : ça ne bouge pas vite.
const CACHE_MAX = 300;
const DEFAULT_RADIUS_KM = 25;
const GEOCODE_TTL_MS = 24 * 60 * 60 * 1000; // une ville ne bouge pas.
const PHOTON = 'https://photon.komoot.io/api/';
const UA = 'HoPetSit/23.1 (https://www.hopetsit.com; contact@hopetsit.com)';
const GEO_TIMEOUT_MS = 4000;
const MAX_RADIUS_KM = 100;

const _cache = new Map();

function _cacheGet(key) {
  const hit = _cache.get(key);
  if (!hit) return null;
  if (Date.now() - hit.t > CACHE_TTL_MS) {
    _cache.delete(key);
    return null;
  }
  return hit.v;
}

function _cacheSet(key, v) {
  if (_cache.size >= CACHE_MAX) _cache.delete(_cache.keys().next().value);
  _cache.set(key, { t: Date.now(), v });
}

/**
 * Où est cette ville ? — 22/09/2026.
 *
 * Sans coordonnées, on ne comptait que les prestataires dont la ville
 * s'ÉCRIT exactement comme la page : « Paris » ratait Boulogne, Courbevoie,
 * Asnières et Bois-d'Arcy, qui desservent pourtant Paris ; et « Dallas »
 * renvoyait 0 alors qu'il y a des prestataires à Arlington, Euless et Haslet.
 * On géocode donc la ville (Photon, même fournisseur que l'autocomplétion de
 * la PawMap, sans clé ni coût) et on compte aussi dans un rayon. Mémorisé
 * 24 h ; si Photon ne répond pas, on retombe sur le nom seul — jamais d'échec.
 */
const _geoCache = new Map();

async function geocodeCity(city) {
  const key = city.toLowerCase();
  const hit = _geoCache.get(key);
  if (hit && Date.now() - hit.t < GEOCODE_TTL_MS) return hit.v;
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), GEO_TIMEOUT_MS);
  try {
    const url = `${PHOTON}?limit=1&osm_tag=place:city&osm_tag=place:town`
      + `&q=${encodeURIComponent(city)}`;
    const r = await fetch(url, {
      headers: { 'User-Agent': UA, Accept: 'application/json' },
      signal: ctl.signal,
    });
    if (!r.ok) throw new Error(`http ${r.status}`);
    const j = await r.json();
    const c = (((j.features || [])[0] || {}).geometry || {}).coordinates || [];
    const v = Number.isFinite(Number(c[0])) && Number.isFinite(Number(c[1]))
      ? { lat: Number(c[1]), lng: Number(c[0]) }
      : null;
    _geoCache.set(key, { t: Date.now(), v });
    return v;
  } catch (e) {
    logger.warn(`[supply/city] géocodage indisponible pour « ${city} » : ${e && e.message ? e.message : e}`);
    _geoCache.set(key, { t: Date.now(), v: null });
    return null;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Regex de ville insensible à la casse ET aux accents — même règle que la
 * notification « nouvelle demande près de chez toi » (postController), pour
 * que le nombre affiché corresponde bien aux prestataires qui seront prévenus.
 * « Malaga » ↔ « Málaga », « Paris (Île-de-France) » ↔ « paris ».
 */
const ACCENTS = {
  a: 'aàáâãäåą', c: 'cçćč', e: 'eèéêëęě', i: 'iìíîïı', l: 'lł',
  n: 'nñńň', o: 'oòóôõöøő', s: 'sśšş', u: 'uùúûüůű', y: 'yýÿ', z: 'zźżž',
};

function cityRegex(city) {
  const core = String(city || '').split(/[(,/]/)[0].trim();
  if (!core) return null;
  const base = core.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  const pattern = base
    .split('')
    .map((ch) => {
      if (ACCENTS[ch]) return `[${ACCENTS[ch]}${ACCENTS[ch].toUpperCase()}]`;
      if (/\s/.test(ch)) return '\\s*';
      return ch.replace(/[.*+?^${}()|[\]\\-]/g, '\\$&');
    })
    .join('');
  return new RegExp(`^${pattern}`, 'i');
}

/** Comptes qui ne doivent jamais être comptés comme de la vraie offre. */
const EXCLUS = {
  isStaff: { $ne: true },
  hiddenFromPublic: { $ne: true },
  bannedAt: { $in: [null, undefined] },
  email: { $not: /(\+test|^hopetsit@|^dadaciao84@|@invalid\.example)/i },
};

async function countRole(Model, rx, lat, lng, radiusKm) {
  const or = [];
  if (rx) or.push({ 'location.city': rx }, { city: rx }, { coverageCity: rx });
  if (Number.isFinite(lat) && Number.isFinite(lng) && !(lat === 0 && lng === 0)) {
    or.push({
      location: {
        $geoWithin: { $centerSphere: [[lng, lat], radiusKm / 6371] },
      },
    });
  }
  if (!or.length) return 0;
  try {
    return await Model.countDocuments({ ...EXCLUS, $or: or });
  } catch (e) {
    // Un index géographique manquant ferait échouer $geoWithin : on ne perd
    // pas la page pour autant, on recompte sur le nom de ville seul.
    logger.warn(`[supply/city] comptage géographique impossible : ${e && e.message ? e.message : e}`);
    if (!rx) return 0;
    return Model.countDocuments({
      ...EXCLUS,
      $or: [{ 'location.city': rx }, { city: rx }, { coverageCity: rx }],
    });
  }
}

router.get('/city', async (req, res) => {
  try {
    const city = String(req.query.city || '').trim().slice(0, 80);
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    const radiusKm = Math.min(
      MAX_RADIUS_KM,
      Math.max(1, Number(req.query.radiusKm) || DEFAULT_RADIUS_KM),
    );
    if (!city && !(Number.isFinite(lat) && Number.isFinite(lng))) {
      return res.status(400).json({ error: 'city or lat/lng required' });
    }

    const key = `${city.toLowerCase()}|${lat}|${lng}|${radiusKm}`;
    const cached = _cacheGet(key);
    if (cached) return res.json(cached);

    const Sitter = require('../models/Sitter');
    const Walker = require('../models/Walker');
    const rx = cityRegex(city);

    // Coordonnées fournies par l'appelant, sinon géocodées depuis le nom.
    let useLat = lat;
    let useLng = lng;
    if (!(Number.isFinite(useLat) && Number.isFinite(useLng)) && city) {
      const g = await geocodeCity(city);
      if (g) {
        useLat = g.lat;
        useLng = g.lng;
      }
    }

    const [sitters, walkers] = await Promise.all([
      countRole(Sitter, rx, useLat, useLng, radiusKm),
      countRole(Walker, rx, useLat, useLng, radiusKm),
    ]);

    const out = { city, sitters, walkers, total: sitters + walkers, radiusKm };
    _cacheSet(key, out);
    res.set('Cache-Control', 'public, max-age=600');
    return res.json(out);
  } catch (e) {
    logger.error('[supply/city]', e);
    return res.status(500).json({ error: 'Unable to count providers.' });
  }
});

module.exports = router;
module.exports.cityRegex = cityRegex;
