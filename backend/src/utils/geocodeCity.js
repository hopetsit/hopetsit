/**
 * 22/09/2026 — OÙ EST CETTE VILLE ? (une seule implémentation)
 *
 * Extrait de routes/supplyRoutes.js pour servir aussi aux notifications :
 * quand un propriétaire publie une demande depuis le SITE, celle-ci ne porte
 * qu'un nom de ville (le navigateur ne donne pas de GPS sans autorisation).
 * Or `createPost` ne prévenait alors que les prestataires dont la ville
 * s'écrit pareil : une demande « Paris » atteignait 3 gardiens au lieu des 12
 * qui desservent Paris depuis Boulogne, Courbevoie, Asnières ou Bois-d'Arcy.
 *
 * Photon (Komoot, même donnée OpenStreetMap que l'autocomplétion de la
 * PawMap) : sans clé, sans coût. Mémorisé 24 h — une ville ne bouge pas.
 * En cas d'échec on renvoie null et l'appelant retombe sur le nom seul :
 * jamais d'erreur visible par l'utilisateur.
 */

const logger = require('./logger');

const PHOTON = 'https://photon.komoot.io/api/';
const UA = 'HoPetSit/23.1 (https://www.hopetsit.com; contact@hopetsit.com)';
const TTL_MS = 24 * 60 * 60 * 1000;
const TIMEOUT_MS = 4000;
const CACHE_MAX = 500;

const _cache = new Map();
// v594 — un échec Photon n'est retenu qu'une heure (avant : 24 h sans ancre).
const MISS_TTL_MS = 60 * 60 * 1000;

function _cacheSet(key, v, perm = false) {
  if (_cache.size >= CACHE_MAX) _cache.delete(_cache.keys().next().value);
  _cache.set(key, { t: Date.now(), v, perm });
}

function _persist(key, v) {
  try {
    const CityAnchor = require('../models/CityAnchor');
    CityAnchor.updateOne({ key }, { $set: { lat: v.lat, lng: v.lng, at: new Date() } }, { upsert: true })
      .catch((e) => logger.warn(`[geocodeCity] sauvegarde « ${key} » : ${e?.message || e}`));
  } catch (_) { /* modèle indisponible (tests sans base) */ }
}

/**
 * v594 — recharge UNE fois par processus les centres-villes gardés en base
 * (après chaque redémarrage du serveur, le floutage retombe au même endroit).
 */
let _loading = null;
function ensureAnchorsLoaded() {
  if (_loading) return _loading;
  // Base pas (encore) connectée : on n'attend jamais, on réessaiera plus tard.
  try {
    if (require('mongoose').connection.readyState !== 1) return Promise.resolve();
  } catch (_) { return Promise.resolve(); }
  _loading = (async () => {
    try {
      const CityAnchor = require('../models/CityAnchor');
      const rows = await CityAnchor.find({}).select('key lat lng').limit(CACHE_MAX)
        .maxTimeMS(1500).lean();
      for (const r of rows) {
        if (Number.isFinite(r.lat) && Number.isFinite(r.lng)) _cacheSet(r.key, { lat: r.lat, lng: r.lng }, true);
      }
    } catch (e) {
      logger.warn(`[geocodeCity] lecture des centres-villes : ${e?.message || e}`);
      _loading = null; // on réessaiera au prochain appel
    }
  })();
  return _loading;
}

// 04/10/2026 (ZOE) — « Parigi » partait en Indonésie, « Londra » en Australie
// (mesuré sur Photon) : on géocode toujours le nom LOCAL de la ville.
function _canon(city, coords) {
  try { return require('./canonicalCity0410').canonicalCityName(String(city || '').trim(), coords); } catch (_) { return String(city || '').trim(); }
}

async function geocodeCity(city) {
  const nom = _canon(city);
  if (!nom) return null;
  const key = nom.toLowerCase();
  const hit = _cache.get(key);
  if (hit && (hit.perm || Date.now() - hit.t < (hit.v ? TTL_MS : MISS_TTL_MS))) return hit.v;

  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), TIMEOUT_MS);
  try {
    const url = `${PHOTON}?limit=1&osm_tag=place:city&osm_tag=place:town`
      + `&q=${encodeURIComponent(nom)}`;
    const r = await fetch(url, {
      headers: { 'User-Agent': UA, Accept: 'application/json' },
      signal: ctl.signal,
    });
    if (!r.ok) throw new Error(`http ${r.status}`);
    const j = await r.json();
    const c = (((j.features || [])[0] || {}).geometry || {}).coordinates || [];
    const lat = Number(c[1]);
    const lng = Number(c[0]);
    const v = Number.isFinite(lat) && Number.isFinite(lng) ? { lat, lng } : null;
    _cacheSet(key, v, !!v);
    if (v) _persist(key, v);
    return v;
  } catch (e) {
    logger.warn(`[geocodeCity] indisponible pour « ${nom} » : ${e && e.message ? e.message : e}`);
    _cacheSet(key, null);
    return null;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * 22/09/2026 (Daniel : « Paris avec tous les arrondissements autour, bien sûr »).
 *
 * Paris, Lyon et Marseille s'écrivent avec un arrondissement. Une demande
 * publiée depuis « Paris 11e » ne correspondait à AUCUN gardien écrivant
 * « Paris » : la comparaison est ancrée au début du nom. Dans l'autre sens ça
 * marchait déjà (« Paris » retrouve « Paris 15e »). On ramène donc toujours au
 * nom de la commune : un gardien du 15e dessert une demande du 11e, et
 * réciproquement — c'est la même ville.
 *
 * On ne touche qu'à ces trois communes : ailleurs, un nombre à la fin d'un nom
 * de ville n'est pas un arrondissement et ne doit pas être retiré.
 */
const COMMUNES_A_ARRONDISSEMENTS = /^(paris|lyon|marseille)\b/i;

function baseCityName(city, coords) {
  const nom = _canon(city, coords);
  if (!COMMUNES_A_ARRONDISSEMENTS.test(nom)) return nom;
  // « Paris 11e », « Paris 1er », « Paris 11ème », « Paris 75011 », « Lyon 3 »
  const sans = nom.replace(/\s*\d+\s*(er|ere|ère|e|eme|ème|th|st|nd|rd)?\s*$/i, '').trim();
  return sans || nom;
}

/**
 * v585 — lecture SANS réseau du cache (la couche monde ne doit jamais attendre
 * Photon) : `undefined` = inconnu, `null` = introuvable, sinon { lat, lng }.
 */
function peekCity(city) {
  const key = _canon(city).toLowerCase();
  if (!key) return undefined;
  const hit = _cache.get(key);
  if (!hit) return undefined;
  if (!hit.perm && Date.now() - hit.t >= (hit.v ? TTL_MS : MISS_TTL_MS)) return undefined;
  return hit.v;
}

/**
 * v585 — remplit le cache en tâche de fond, par petits lots (jamais plus de
 * `max` villes par appel, 4 à la fois) : la reconstruction suivante de la
 * couche monde (5 min) trouvera les centres-villes.
 */
let _warming = false;
function warmCities(cities, max = 40) {
  if (_warming) return;
  const todo = [...new Set((cities || []).map((c) => String(c || '').trim()).filter(Boolean))]
    .filter((c) => peekCity(c) === undefined)
    .slice(0, max);
  if (!todo.length) return;
  _warming = true;
  (async () => {
    try {
      for (let i = 0; i < todo.length; i += 4) {
        await Promise.all(todo.slice(i, i + 4).map((c) => geocodeCity(c)));
      }
    } catch (_) { /* jamais bloquant */ } finally { _warming = false; }
  })();
}

/** Tests uniquement : vide la mémoire (simule un redémarrage). */
function _resetForTest() { _cache.clear(); _loading = null; }

module.exports = { geocodeCity, baseCityName, peekCity, warmCities, ensureAnchorsLoaded, _resetForTest };
