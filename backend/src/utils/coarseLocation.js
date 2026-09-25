/**
 * 22/09/2026 — FLOUTAGE DES POSITIONS, une seule implémentation.
 *
 * La couche monde de la PawMap arrondit volontairement la position des membres
 * à ~1 km avant de la servir (v550) : c'est la règle du produit. Mais les
 * fiches publiques `GET /sitters/:id` et `GET /walkers/:id` la contournaient et
 * renvoyaient les coordonnées EXACTES — donc, en pratique, le domicile du
 * prestataire — à quiconque possède l'identifiant. Découvert le 22/09 en
 * préparant le lien de profil partageable.
 *
 * Ce module porte désormais la fonction unique. Le code vient de
 * friendRoutes.js (v550), inchangé, pour que les deux usages ne divergent pas.
 *
 * Erreur maximale : 0,5 km (grille) + 0,2 km (décalage) ≈ 0,7 km.
 */

const WORLD_APPROX_KM = 1; // rayon d'imprécision annoncé aux clients
const KM_PER_DEG_LAT = 111.32;

/**
 * Hash stable → décalage déterministe borné à ±0,2 km sur chaque axe. Il ne
 * sert qu'à ne pas empiler deux membres sur le même nœud de grille : la
 * confidentialité vient de l'arrondi (irréversible), pas du décalage.
 */
function jitterKm(idStr) {
  let h = 0;
  for (let i = 0; i < idStr.length; i += 1) h = (h * 31 + idStr.charCodeAt(i)) | 0;
  const a = ((h & 0xffff) / 0xffff - 0.5) * 0.4;
  const b = (((h >> 16) & 0xffff) / 0xffff - 0.5) * 0.4;
  return [a, b];
}

/** Renvoie [lng, lat] flouté. */
function blurLngLat(lat, lng, idStr) {
  const cosLat = Math.max(0.05, Math.cos((lat * Math.PI) / 180));
  const stepLat = WORLD_APPROX_KM / KM_PER_DEG_LAT;
  const stepLng = WORLD_APPROX_KM / (KM_PER_DEG_LAT * cosLat);
  const [kLng, kLat] = jitterKm(String(idStr || ''));
  const outLat = Math.round(lat / stepLat) * stepLat + kLat / KM_PER_DEG_LAT;
  const outLng = Math.round(lng / stepLng) * stepLng
    + kLng / (KM_PER_DEG_LAT * cosLat);
  return [Math.round(outLng * 1e5) / 1e5, Math.round(outLat * 1e5) / 1e5];
}

/**
 * Floute le bloc `location` d'une fiche publique. Ne touche à rien quand le
 * lecteur est la personne elle-même, ni quand il n'y a pas de coordonnées.
 *
 * @param {object|null} location bloc { coordinates:[lng,lat], city, ... }
 * @param {string} idStr identifiant de la fiche (décalage déterministe)
 * @param {boolean} isSelf le lecteur est-il cette personne ?
 */
function coarsenLocation(location, idStr, isSelf) {
  if (isSelf || !location) return location;
  const c = location.coordinates;
  if (!Array.isArray(c) || c.length < 2) return location;
  const lng = Number(c[0]);
  const lat = Number(c[1]);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || (lat === 0 && lng === 0)) {
    return location;
  }
  return { ...location, coordinates: blurLngLat(lat, lng, idStr), approxKm: WORLD_APPROX_KM };
}


/**
 * v585 (25/09) — Daniel : « regarde, il est dans l'eau ». Un point flouté
 * pouvait tomber en mer (membre sur la côte : l'arrondi à 1 km + le décalage
 * partaient au large). Quand on connaît le centre de la ville du membre
 * (`anchor`), on part du nœud de grille (irréversible, donc toujours privé) et
 * on le rapproche du centre-ville d'au plus 0,8 km : le point glisse vers
 * l'intérieur des terres au lieu de s'en éloigner. Plus près du centre que
 * 1 km → le centre-ville lui-même (+ petit décalage stable).
 * Sans `anchor`, comportement inchangé (`blurLngLat`).
 */
function blurTowardAnchor(lat, lng, idStr, anchor) {
  if (!anchor || !Number.isFinite(anchor.lat) || !Number.isFinite(anchor.lng)) {
    return blurLngLat(lat, lng, idStr);
  }
  const cosLat = Math.max(0.05, Math.cos((lat * Math.PI) / 180));
  const toKm = (dLat, dLng) => [dLat * KM_PER_DEG_LAT, dLng * KM_PER_DEG_LAT * cosLat];
  const [kx, ky] = jitterKm(String(idStr || ''));
  const small = (v) => v * 0.25; // ±0,05 km : ne sert qu'à ne pas empiler
  const [dyC, dxC] = toKm(anchor.lat - lat, anchor.lng - lng);
  const distCenter = Math.hypot(dyC, dxC);
  // Loin de toute ville connue (> 30 km) : l'ancre ne veut rien dire ici.
  if (distCenter > 30) return blurLngLat(lat, lng, idStr);
  let outLat;
  let outLng;
  if (distCenter <= 1) {
    outLat = anchor.lat + small(ky) / KM_PER_DEG_LAT;
    outLng = anchor.lng + small(kx) / (KM_PER_DEG_LAT * cosLat);
  } else {
    const stepLat = WORLD_APPROX_KM / KM_PER_DEG_LAT;
    const stepLng = WORLD_APPROX_KM / (KM_PER_DEG_LAT * cosLat);
    const gLat = Math.round(lat / stepLat) * stepLat;
    const gLng = Math.round(lng / stepLng) * stepLng;
    const [dy, dx] = toKm(anchor.lat - gLat, anchor.lng - gLng);
    const d = Math.hypot(dy, dx);
    const move = Math.min(0.8, d);
    const f = d > 0 ? move / d : 0;
    outLat = gLat + (dy * f + small(ky)) / KM_PER_DEG_LAT;
    outLng = gLng + (dx * f + small(kx)) / (KM_PER_DEG_LAT * cosLat);
  }
  return [Math.round(outLng * 1e5) / 1e5, Math.round(outLat * 1e5) / 1e5];
}

module.exports = { WORLD_APPROX_KM, KM_PER_DEG_LAT, jitterKm, blurLngLat, blurTowardAnchor, coarsenLocation };
