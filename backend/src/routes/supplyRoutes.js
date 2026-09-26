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

// 22/09/2026 — le géocodage vit dans utils/geocodeCity.js : les notifications
// « nouvelle demande près de chez toi » en ont besoin aussi, et les deux
// doivent répondre la même chose.
const { geocodeCity, baseCityName } = require('../utils/geocodeCity');

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
    // « Paris 11e » compte comme « Paris » : un gardien du 15e dessert le 11e.
    const city = baseCityName(String(req.query.city || '').trim().slice(0, 80));
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

/**
 * 26/09/2026 (SAM, carte blanche de Daniel) — DES VISAGES, PAS SEULEMENT UN NOMBRE.
 *
 * Mesure : /garde-animaux/paris, 224 visiteurs en 7 jours (pub Meta) → 3 clics
 * « Publier ma demande ». La phrase « 9 gardiens déjà inscrits » ne suffit pas :
 * on montre 3 vrais prestataires autour de la ville.
 *
 * Vie privée : on ne renvoie QUE ce que la fiche publique /p/<rôle>/<id>
 * (GET /sitters/:id, /walkers/:id) montre déjà à tout le monde : prénom,
 * photo, ville déclarée, note. Jamais le nom de famille, l'e-mail, la date de
 * naissance ni une position. Mêmes exclusions que le comptage, et seulement
 * les profils AVEC une photo (sans photo, une carte ne prouve rien).
 *
 * GET /api/v1/supply/city/faces?city=Paris[&limit=3]
 *   → { city, faces: [{ id, role, firstName, photo, city, rating, verified }] }
 */
router.get('/city/faces', async (req, res) => {
  try {
    const city = baseCityName(String(req.query.city || '').trim().slice(0, 80));
    if (!city) return res.status(400).json({ error: 'city required' });
    const limit = Math.min(6, Math.max(1, parseInt(req.query.limit, 10) || 3));
    const key = `faces|${city.toLowerCase()}|${limit}`;
    const cached = _cacheGet(key);
    if (cached) return res.json(cached);

    const Sitter = require('../models/Sitter');
    const Walker = require('../models/Walker');
    const rx = cityRegex(city);
    const or = [];
    if (rx) or.push({ 'location.city': rx }, { city: rx }, { coverageCity: rx });
    const g = await geocodeCity(city).catch(() => null);
    if (g && Number.isFinite(g.lat) && Number.isFinite(g.lng)) {
      or.push({ location: { $geoWithin: { $centerSphere: [[g.lng, g.lat], DEFAULT_RADIUS_KM / 6371] } } });
    }
    const filtre = { ...EXCLUS, 'avatar.url': { $regex: /^https:\/\// }, $or: or };
    const champs = 'firstName name avatar city location.city coverageCity averageRating rating kycStatus verified createdAt';

    const lire = async (Model, role) => {
      let docs;
      try {
        docs = await Model.find(filtre).select(champs).sort({ kycStatus: -1, averageRating: -1, createdAt: 1 }).limit(12).lean();
      } catch (e) {
        // Index géographique absent : on retombe sur le nom de ville seul.
        if (!rx) return [];
        docs = await Model.find({ ...EXCLUS, 'avatar.url': { $regex: /^https:\/\// }, $or: or.filter((o) => !o.location) })
          .select(champs).sort({ averageRating: -1, createdAt: 1 }).limit(12).lean();
      }
      return docs.map((d) => ({
        id: String(d._id),
        role,
        firstName: String(d.firstName || d.name || '').trim().split(/\s+/)[0].slice(0, 24),
        photo: d.avatar && d.avatar.url,
        city: String((d.location && d.location.city) || d.city || d.coverageCity || city).slice(0, 40),
        rating: Math.round((Number(d.averageRating || d.rating) || 0) * 10) / 10,
        verified: d.kycStatus === 'verified',
      })).filter((f) => f.firstName && f.photo);
    };

    const [s, w] = await Promise.all([lire(Sitter, 'sitter'), lire(Walker, 'walker')]);
    // Vérifiés d'abord, puis en alternant gardiens et promeneurs.
    const rang = (f) => (f.verified ? 0 : 1);
    s.sort((a, b) => rang(a) - rang(b)); w.sort((a, b) => rang(a) - rang(b));
    const faces = [];
    const vus = new Set();
    for (let i = 0; faces.length < limit && (i < s.length || i < w.length); i += 1) {
      for (const f of [s[i], w[i]]) {
        if (!f || faces.length >= limit) continue;
        const k = `${f.firstName.toLowerCase()}|${f.photo}`;
        if (vus.has(k)) continue; // la même personne peut avoir 2 rôles
        vus.add(k);
        faces.push(f);
      }
    }
    const out = { city, faces };
    _cacheSet(key, out);
    res.set('Cache-Control', 'public, max-age=600');
    return res.json(out);
  } catch (e) {
    logger.error('[supply/city/faces]', e);
    return res.status(500).json({ error: 'Unable to load providers.' });
  }
});

module.exports = router;
module.exports.cityRegex = cityRegex;
