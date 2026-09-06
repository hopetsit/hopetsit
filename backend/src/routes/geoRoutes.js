/**
 * v554 — Suggestions de villes pour la barre de recherche de la PawMap.
 *
 * Daniel : « la barre de recherche ville plus moderne, et quand on tape ça
 * propose la ville ». Le plugin `geocoding` de Flutter ne sait faire QUE du
 * géocodage exact (une chaîne → des coordonnées) : aucune autocomplétion.
 *
 * Pourquoi Photon et pas Nominatim : `/search` de Nominatim cherche un nom
 * COMPLET — vérifié ici, « asnie » ne renvoie rien et « par » renvoie un
 * hameau anglais nommé Par. Photon (même donnée OSM, moteur Elasticsearch de
 * Komoot) est fait pour l'autocomplétion au fil de la frappe et accepte un
 * biais géographique : « asnie » près de Paris sort Asnières-sur-Seine en
 * premier. Aucune clé, aucun coût. Nominatim reste en secours.
 *
 * Pourquoi un proxy serveur plutôt qu'un appel direct depuis l'app :
 *   - un seul User-Agent identifiable et un cache commun à tous les
 *     téléphones (les mêmes villes sont tapées en boucle) ;
 *   - si le fournisseur change, rien à republier sur les stores.
 *
 * GET /api/v1/geo/cities?q=asnie&lang=fr&lat=48.85&lng=2.35
 *   → [{ name, admin, country, label, lat, lng }]
 */

const express = require('express');

const router = express.Router();

const PHOTON = 'https://photon.komoot.io/api/';
const NOMINATIM = 'https://nominatim.openstreetmap.org/search';
const UA = 'HoPetSit/23.1 (https://www.hopetsit.com; contact@hopetsit.com)';
const CACHE_TTL_MS = 60 * 60 * 1000; // 1 h : une ville ne bouge pas.
const CACHE_MAX = 500;
const TIMEOUT_MS = 4000;
const MAX_RESULTS = 6;

/** Cache mémoire simple (clé = `${lang}:${q}:${zone}`). */
const _cache = new Map();

function _cacheGet(key) {
  const hit = _cache.get(key);
  if (!hit) return null;
  if (Date.now() - hit.at > CACHE_TTL_MS) {
    _cache.delete(key);
    return null;
  }
  return hit.data;
}

function _cacheSet(key, data) {
  if (_cache.size >= CACHE_MAX) {
    // Purge la plus ancienne entrée (Map conserve l'ordre d'insertion).
    const oldest = _cache.keys().next().value;
    if (oldest !== undefined) _cache.delete(oldest);
  }
  _cache.set(key, { at: Date.now(), data });
}

function _entry(name, admin, country, lat, lng) {
  if (!name || !Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  return {
    name,
    admin: admin || '',
    country: country || '',
    label: [admin, country].filter(Boolean).join(', '),
    lat,
    lng,
  };
}

async function _fetchJson(url) {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), TIMEOUT_MS);
  try {
    const r = await fetch(url, {
      headers: { 'User-Agent': UA, Accept: 'application/json' },
      signal: ctl.signal,
    });
    if (!r.ok) throw new Error(`http ${r.status}`);
    return await r.json();
  } finally {
    clearTimeout(timer);
  }
}

/** Photon : autocomplétion au fil de la frappe, avec biais de proximité. */
async function _photon(q, lang, lat, lng) {
  // Photon ne connaît que quelques langues d'interface ; en dehors il
  // renvoie le nom local, ce qui reste correct.
  const supported = ['fr', 'en', 'de', 'it'];
  const l = supported.includes(lang) ? lang : 'en';
  let url =
    `${PHOTON}?limit=12&lang=${l}` +
    '&osm_tag=place:city&osm_tag=place:town&osm_tag=place:village' +
    `&q=${encodeURIComponent(q)}`;
  if (Number.isFinite(lat) && Number.isFinite(lng)) {
    url += `&lat=${lat.toFixed(4)}&lon=${lng.toFixed(4)}`;
  }
  const j = await _fetchJson(url);
  const out = [];
  for (const f of (j && j.features) || []) {
    const p = f.properties || {};
    const c = (f.geometry && f.geometry.coordinates) || [];
    const e = _entry(
      p.name,
      p.state || p.county || '',
      p.country || '',
      Number(c[1]),
      Number(c[0])
    );
    if (e) out.push(e);
  }
  return out;
}

/** Secours si Photon est indisponible : recherche exacte Nominatim. */
async function _nominatim(q, lang) {
  const url =
    `${NOMINATIM}?format=jsonv2&addressdetails=1&limit=8&featureType=city` +
    `&accept-language=${encodeURIComponent(lang)}&q=${encodeURIComponent(q)}`;
  const j = await _fetchJson(url);
  const out = [];
  for (const item of Array.isArray(j) ? j : []) {
    const a = item.address || {};
    const name =
      a.city ||
      a.town ||
      a.village ||
      a.municipality ||
      (item.display_name || '').split(',')[0].trim();
    const e = _entry(
      name,
      a.state || a.region || a.county || '',
      a.country || '',
      Number(item.lat),
      Number(item.lon)
    );
    if (e) out.push(e);
  }
  return out;
}

router.get('/cities', async (req, res) => {
  const q = String(req.query.q || '').trim();
  // Sous 2 caractères, toute recherche mondiale n'est que du bruit.
  if (q.length < 2) return res.json([]);
  const lang = String(req.query.lang || 'fr').slice(0, 5);
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  // Le biais est arrondi au degré : deux utilisateurs de la même région
  // partagent la même entrée de cache.
  const zone =
    Number.isFinite(lat) && Number.isFinite(lng)
      ? `${Math.round(lat)},${Math.round(lng)}`
      : '-';
  const key = `${lang}:${q.toLowerCase()}:${zone}`;

  const cached = _cacheGet(key);
  if (cached) return res.json(cached);

  let list = [];
  try {
    list = await _photon(q, lang, lat, lng);
  } catch (e) {
    console.warn('[geo] photon failed:', e.message);
    try {
      list = await _nominatim(q, lang);
    } catch (e2) {
      console.warn('[geo] nominatim failed:', e2.message);
      // Jamais d'erreur remontée à l'app : sans suggestion, la recherche
      // classique (touche Entrée → géocodage) continue de fonctionner.
      return res.json([]);
    }
  }

  // La même ville revient souvent en plusieurs objets OSM (relation + nœud).
  const seen = new Set();
  const out = [];
  for (const e of list) {
    const dedupe = `${e.name}|${e.admin}|${e.country}`.toLowerCase();
    if (seen.has(dedupe)) continue;
    seen.add(dedupe);
    out.push(e);
    if (out.length >= MAX_RESULTS) break;
  }

  _cacheSet(key, out);
  return res.json(out);
});

module.exports = router;
