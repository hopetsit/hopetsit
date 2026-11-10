'use strict';

// 640 (BOB, 10/11/2026) — retour de Daniel : « il m'apparaît une annonce du
// Brésil […] le mec est au Brésil, moi en Espagne ».
//
// Cause mesurée sur le vrai serveur : la demande n'avait AUCUNE position
// enregistrée (ville + code postal seulement ; le code postal brésilien n'est
// pas reconnu par le géocodeur). Or le fil des demandes (GET /posts/requests)
// gardait PARTOUT DANS LE MONDE une annonce sans coordonnées (« fail-open » de
// la v530). Le compte de test en zone fictive la recevait aussi.
//
// Règle 640, pour une annonce SANS coordonnées vue par un prestataire qui a
// une position :
//   - annonce sans ville            → gardée (on ne peut pas juger, comme avant) ;
//   - même ville que le prestataire → gardée ;
//   - ville située à ≤ maxKm        → gardée (centre-ville, cache puis géocodeur,
//                                     3 villes et 2,5 s au plus par appel) ;
//   - ville située à > maxKm        → masquée ;
//   - ville NON résolue (géocodeur en panne ou lent, plus de 3 villes
//     nouvelles, ville inconnue)    → gardée, comme avant.
// On ne masque donc QUE sur une position trouvée et lointaine : une panne du
// géocodeur ne fait jamais disparaître une annonce voisine (contrôle ZOE du
// 10/11 : la première version masquait dans le doute → bloquant, corrigé).
// Limite connue : une ville homonyme mal placée par le géocodeur peut encore
// masquer une annonce sans position pour ses vrais voisins.
// Rien n'est écrit en base à la lecture.
//
// Coupe-circuit sans rebuild : FEED_NO_COORDS_STRICT=off (Render) → comportement
// d'avant. Même interrupteur pour la conservation de la position à la
// modification d'une annonce (keepOrGeocodeLocation640).

const MAX_GEOCODE_CITIES = 3;
const GEOCODE_BUDGET_MS = 2500;
const EDIT_GEOCODE_BUDGET_MS = 4500;
// Modification : une ville géocodée à moins de 30 km de l'ancienne position
// est la même ville écrite autrement → on garde la position précise d'avant.
const SAME_PLACE_KM = 30;

function strictEnabled640() {
  return String(process.env.FEED_NO_COORDS_STRICT || '').trim().toLowerCase() !== 'off';
}

function coordsOf640(loc) {
  if (!loc || typeof loc !== 'object') return null;
  if (loc.lat === null || loc.lat === undefined || loc.lat === '') return null;
  if (loc.lng === null || loc.lng === undefined || loc.lng === '') return null;
  const lat = Number(loc.lat);
  const lng = Number(loc.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (lat === 0 && lng === 0) return null;
  if (Math.abs(lat) > 90 || Math.abs(lng) > 180) return null;
  return { lat, lng };
}

function _geo() {
  try { return require('./geocodeCity'); } catch (_) { return null; }
}

function _plain(s) {
  return String(s || '')
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toLowerCase().replace(/[^a-z0-9Ѐ-￿]+/g, ' ').trim();
}

// Clé de comparaison d'une ville : nom de base (« Paris 11e » → « Paris »,
// « Parigi » → « Paris ») quand l'outil existe, sans accents ni casse.
function cityKey640(city) {
  const raw = String(city || '').trim();
  if (!raw) return '';
  let base = raw;
  try {
    const g = _geo();
    if (g && typeof g.baseCityName === 'function') base = g.baseCityName(raw) || raw;
  } catch (_) { base = raw; }
  return _plain(base) || _plain(raw);
}

function sameCity640(a, b) {
  const ka = cityKey640(a);
  const kb = cityKey640(b);
  return !!ka && ka === kb;
}

function distKm640(lat1, lng1, lat2, lng2) {
  const r = (x) => (x * Math.PI) / 180;
  const dLat = r(lat2 - lat1);
  const dLng = r(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(r(lat1)) * Math.cos(r(lat2)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function _okPoint(v) {
  return v && typeof v === 'object' ? coordsOf640(v) : null;
}

// Promesse bornée dans le temps (jamais de rejet, minuterie sans effet sur l'arrêt du processus).
function _within(promise, ms) {
  return new Promise((resolve) => {
    let done = false;
    const t = setTimeout(() => { if (!done) { done = true; resolve(undefined); } }, ms);
    if (t && typeof t.unref === 'function') t.unref();
    Promise.resolve(promise).then(
      (v) => { if (!done) { done = true; clearTimeout(t); resolve(v); } },
      () => { if (!done) { done = true; clearTimeout(t); resolve(undefined); } },
    );
  });
}

// villes (noms bruts) → Map nom → {lat,lng} | null (introuvable ou non résolue :
// l'appelant GARDE alors l'annonce).
async function resolveCities640(cities) {
  const out = new Map();
  const g = _geo();
  const pending = [];
  for (const city of cities) {
    let v;
    try {
      if (g && typeof g.peekCity === 'function') v = g.peekCity(city);
    } catch (_) { v = undefined; }
    if (v === undefined) pending.push(city);
    else out.set(city, _okPoint(v));
  }
  if (pending.length && g && typeof g.geocodeCity === 'function') {
    const lot = pending.slice(0, MAX_GEOCODE_CITIES);
    await _within(Promise.all(lot.map(async (city) => {
      try { out.set(city, _okPoint(await g.geocodeCity(city))); } catch (_) { /* non résolue */ }
    })), GEOCODE_BUDGET_MS);
  }
  for (const city of cities) if (!out.has(city)) out.set(city, null);
  return out;
}

/**
 * Annonces SANS coordonnées à masquer pour ce prestataire.
 * @param {Array} posts  annonces sans coordonnées (documents ou objets, `location.city`)
 * @param {{viewerCoords:[number,number]|null, viewerCity?:string, maxKm:number}} ctx  viewerCoords = [lng, lat]
 * @returns {Promise<Set>} les annonces (mêmes références) à retirer du fil
 */
async function noCoordsPostsToHide640(posts, ctx) {
  const hide = new Set();
  const c = ctx || {};
  if (!strictEnabled640()) return hide;
  const vc = Array.isArray(c.viewerCoords) && c.viewerCoords.length === 2
    ? coordsOf640({ lat: c.viewerCoords[1], lng: c.viewerCoords[0] }) : null;
  if (!vc) return hide; // prestataire sans position : rien ne change
  const maxKm = Number.isFinite(Number(c.maxKm)) && Number(c.maxKm) > 0 ? Number(c.maxKm) : 500;
  const toJudge = [];
  for (const post of Array.isArray(posts) ? posts : []) {
    const loc = post && post.location;
    if (coordsOf640(loc)) continue; // a des coordonnées : pas notre sujet
    const city = String((loc && loc.city) || '').trim();
    if (!city) continue; // aucune ville : on garde, comme avant
    if (c.viewerCity && sameCity640(city, c.viewerCity)) continue; // même ville
    toJudge.push({ post, city });
  }
  if (!toJudge.length) return hide;
  const resolved = await resolveCities640([...new Set(toJudge.map((x) => x.city))]);
  for (const { post, city } of toJudge) {
    const p = resolved.get(city);
    if (!p) continue; // ville non résolue : on garde, comme avant (jamais masquer dans le doute)
    if (distKm640(vc.lat, vc.lng, p.lat, p.lng) <= maxKm) continue;
    hide.add(post);
  }
  return hide;
}

/**
 * Modification d'une annonce : ne jamais perdre la position.
 * `next` sans coordonnées → on reprend celles d'avant si la ville n'a pas
 * changé, sinon on géocode (code postal, puis ville). Jamais bloquant.
 */
async function keepOrGeocodeLocation640(prev, next) {
  if (!strictEnabled640()) return next;
  if (!next || typeof next !== 'object' || Array.isArray(next)) return next;
  if (coordsOf640(next)) return next;
  const before = prev && typeof prev === 'object' ? prev : null;
  const beforeCoords = coordsOf640(before);
  const nextCity = String(next.city || '').trim();
  const cityUnchanged = !nextCity || (before && sameCity640(nextCity, before.city));
  if (beforeCoords && cityUnchanged) {
    const kept = { ...next, lat: beforeCoords.lat, lng: beforeCoords.lng };
    if (!nextCity && before.city) kept.city = before.city;
    if (before.geocoded && kept.geocoded === undefined) kept.geocoded = true;
    if (!kept.postalCode && before.postalCode) kept.postalCode = before.postalCode;
    return kept;
  }
  if (!nextCity) return next;
  const postal = next.postalCode || (cityUnchanged && before ? before.postalCode : '');
  if (postal) {
    try {
      const gp = require('./geocodePostal2310');
      if (gp && typeof gp.locationFromPostal === 'function') {
        const fromPostal = await _within(gp.locationFromPostal(postal, { country: next.country, city: nextCity }), EDIT_GEOCODE_BUDGET_MS);
        if (fromPostal && coordsOf640(fromPostal)) return { ...next, ...fromPostal, city: nextCity };
      }
    } catch (_) { /* on essaie la ville */ }
  }
  try {
    const g = _geo();
    if (g && typeof g.geocodeCity === 'function') {
      // Ville déjà connue (cache ou ville fixe) : aucun appel réseau.
      let p = null;
      try { if (typeof g.peekCity === 'function') p = _okPoint(g.peekCity(nextCity)); } catch (_) { p = null; }
      if (!p) p = _okPoint(await _within(g.geocodeCity(nextCity), EDIT_GEOCODE_BUDGET_MS));
      if (p && beforeCoords && distKm640(beforeCoords.lat, beforeCoords.lng, p.lat, p.lng) <= SAME_PLACE_KM) {
        const kept = { ...next, lat: beforeCoords.lat, lng: beforeCoords.lng };
        if (before.geocoded && kept.geocoded === undefined) kept.geocoded = true;
        return kept;
      }
      if (p) return { ...next, lat: p.lat, lng: p.lng, geocoded: true };
    }
  } catch (_) { /* jamais bloquant */ }
  return next;
}

module.exports = {
  strictEnabled640,
  coordsOf640,
  cityKey640,
  sameCity640,
  distKm640,
  resolveCities640,
  noCoordsPostsToHide640,
  keepOrGeocodeLocation640,
};
