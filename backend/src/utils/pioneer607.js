'use strict';

/**
 * 607 (NEO, 02/10/2026) — BADGE « PIONNIER ».
 *
 * isPioneer = AUCUN autre prestataire actif (gardien ou promeneur) dans un
 * rayon de 25 km autour de la position de PROFIL de la personne (jamais son
 * direct), ou, sans position, dans sa ville déclarée.
 *
 * « Actif » = mêmes exclusions que le comptage public de l'offre
 * (supplyRoutes) : ni staff, ni masqué, ni banni, ni suspendu, ni compte de
 * test / interne. Les autres profils de la MÊME personne (son profil
 * promeneur quand elle est gardienne) ne comptent pas : elle reste seule.
 *
 * La personne elle-même doit être un vrai prestataire actif (sinon false).
 * Sortie : true / false, ou null quand on ne sait pas (aucune position ni
 * ville) — l'app n'affiche alors rien. Jamais une promesse : c'est un constat.
 */

const PIONEER_RADIUS_KM = 25;
const CACHE_TTL_MS = 10 * 60 * 1000;
const _cache = new Map();

function _resetPioneerCache() { _cache.clear(); }

async function computeIsPioneer(doc) {
  if (!doc || !doc._id) return null;
  const key = String(doc._id);
  const hit = _cache.get(key);
  if (hit && Date.now() - hit.at < CACHE_TTL_MS) return hit.v;

  const Sitter = require('../models/Sitter');
  const Walker = require('../models/Walker');
  const { homeOf, cityOf } = require('./personMapPosition');
  const { isRealSupply, cityRegex } = require('../routes/supplyRoutes');
  const { identityGroup } = require('./identityGroup');
  const { geocodeCity, baseCityName } = require('./geocodeCity');

  const plain = typeof doc.toObject === 'function' ? doc.toObject() : doc;
  // 02/10 (BOB) — un compte de test, staff, masqué, banni ou suspendu n'est
  // JAMAIS Pionnier : pas de badge, pas de +200 PawPoints (pawPointsActivity607).
  if (plain.isStaff === true || plain.hiddenFromPublic === true || plain.bannedAt
    || plain.status === 'banned' || plain.status === 'suspended'
    || require('./testAccountMap604').isTestAccountDoc(plain)) {
    _cache.set(key, { at: Date.now(), v: false });
    return false;
  }
  const city = baseCityName(cityOf(plain));
  let center = null;
  const home = homeOf(plain);
  if (home) center = home.coordinates;
  else if (city) {
    try {
      const g = await geocodeCity(city);
      if (g) center = [g.lng, g.lat];
    } catch (_) { center = null; }
  }
  const rx = city ? cityRegex(city) : null;
  if (!center && !rx) return null;

  const or = [];
  if (center) {
    const sphere = { $geoWithin: { $centerSphere: [center, PIONEER_RADIUS_KM / 6371] } };
    or.push({ location: sphere }, { 'homeLocation.coordinates': sphere });
  }
  if (rx) or.push({ city: rx }, { 'location.city': rx }, { coverageCity: rx });

  let mine = new Set([key]);
  try { mine = (await identityGroup(key)).set; } catch (_) { /* soi seul */ }

  const query = {
    isStaff: { $ne: true },
    hiddenFromPublic: { $ne: true },
    bannedAt: { $in: [null, undefined] },
    status: { $nin: ['banned', 'suspended'] },
    $or: or,
  };
  const sel = 'email _id';
  const [ss, ww] = await Promise.all([
    Sitter.find(query).select(sel).limit(500).lean(),
    Walker.find(query).select(sel).limit(500).lean(),
  ]);
  const others = [...ss, ...ww]
    .filter((d) => !mine.has(String(d._id)))
    .filter(isRealSupply);
  const v = others.length === 0;
  _cache.set(key, { at: Date.now(), v });
  if (_cache.size > 5000) _cache.delete(_cache.keys().next().value);
  return v;
}

module.exports = { computeIsPioneer, PIONEER_RADIUS_KM, _resetPioneerCache };
