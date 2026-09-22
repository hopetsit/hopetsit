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
  return Model.countDocuments({ ...EXCLUS, $or: or });
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

    const [sitters, walkers] = await Promise.all([
      countRole(Sitter, rx, lat, lng, radiusKm),
      countRole(Walker, rx, lat, lng, radiusKm),
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
