/**
 * v585 (lot D, 25/09/2026) — RAYON DE RECHERCHE : une seule règle pour
 * `/sitters/nearby`, `/walkers/nearby` et `/posts/requests/nearby`.
 *
 * Demande de Daniel : « le curseur de distance marche bien et les gens
 * apparaissent au bon km ». Avant :
 *   · les curseurs de l'app montent à 500 km, mais /sitters/nearby plafonnait
 *     à 200 km et /walkers/nearby à 200 000 m → à 250 ou 500 km l'app affichait
 *     une valeur que le serveur n'appliquait pas ;
 *   · trois haversines recopiées, trois lectures du rayon différentes
 *     (`radius` en km, `radiusInMeters`, `maxDistance` en km).
 * Ici : une lecture, un plafond (500 km, comme les curseurs), une borne
 * INCLUSIVE (« à 4 km » apparaît à 4 km), un seul haversine. Fonctions pures,
 * testées par jest (tests/radius585.test.js).
 */

const MAX_RADIUS_KM = 500;
const MIN_RADIUS_KM = 0.1;
const EARTH_RADIUS_KM = 6371;

const toRad = (x) => (x * Math.PI) / 180;

/** Distance orthodromique en km (haversine). */
function haversineKm(lat1, lng1, lat2, lng2) {
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Lit le rayon demandé (km) depuis la requête, quel que soit le nom du
 * paramètre : `radiusInMeters` (m), `radius` (km) ou `maxDistance` (km).
 * Valeur absente / invalide → `defaultKm`. Toujours borné à
 * [MIN_RADIUS_KM, maxKm] (plafond 500 km = le maximum des curseurs de l'app).
 */
function parseRadiusKm(query, { defaultKm = 50, maxKm = MAX_RADIUS_KM } = {}) {
  const q = query || {};
  let km;
  if (q.radiusInMeters !== undefined) {
    const m = parseFloat(q.radiusInMeters);
    km = Number.isFinite(m) && m > 0 ? m / 1000 : defaultKm;
  } else if (q.radius !== undefined) {
    const r = parseFloat(q.radius);
    km = Number.isFinite(r) && r > 0 ? r : defaultKm;
  } else if (q.maxDistance !== undefined) {
    const r = parseFloat(q.maxDistance);
    km = Number.isFinite(r) && r > 0 ? r : defaultKm;
  } else {
    km = defaultKm;
  }
  return Math.min(maxKm, Math.max(MIN_RADIUS_KM, km));
}

/** Borne INCLUSIVE, tolérante aux arrondis flottants (1 m). */
function withinRadiusKm(distanceKm, radiusKm) {
  if (!Number.isFinite(distanceKm) || !Number.isFinite(radiusKm)) return false;
  return distanceKm <= radiusKm + 0.001;
}

/**
 * Filtre pur : garde les éléments dont `getLatLng(item)` est à ≤ radiusKm du
 * centre (ou sans coordonnées si `keepWithoutCoords`), triés du plus proche
 * au plus loin, avec `distanceKm` calculé.
 */
function filterByRadius(items, center, radiusKm, getLatLng, { keepWithoutCoords = false } = {}) {
  const out = [];
  for (const item of items) {
    const ll = getLatLng(item);
    if (!ll || !Number.isFinite(ll.lat) || !Number.isFinite(ll.lng)) {
      if (keepWithoutCoords) out.push({ item, distanceKm: null });
      continue;
    }
    const d = haversineKm(center.lat, center.lng, ll.lat, ll.lng);
    if (withinRadiusKm(d, radiusKm)) out.push({ item, distanceKm: d });
  }
  return out.sort((a, b) => (a.distanceKm ?? Infinity) - (b.distanceKm ?? Infinity));
}

module.exports = {
  MAX_RADIUS_KM,
  MIN_RADIUS_KM,
  haversineKm,
  parseRadiusKm,
  withinRadiusKm,
  filterByRadius,
};
