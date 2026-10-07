'use strict';

/**
 * 616 (ZOE, 08/10/2026) — POSITION DE PROFIL DEPUIS LA VILLE.
 *
 * Mesuré en production par BOB (admin, 08/10) : 43 vrais comptes sur 185 n'ont
 * AUCUNE position (`location.coordinates` vide) alors qu'ils ont une ville —
 * Paris, Asnières, Neuilly-sur-Marne, Montpellier, New York, Copenhague,
 * Stockholm… Conséquences : la couche monde de la PawMap ne les lit même pas
 * (filtre `location.coordinates.1` existe), « X gardiens près de chez vous » ne
 * les compte que si leur ville s'écrit pareil, et l'alerte 100 km (612) ne les
 * trouve que si le géocodage de leur ville répond au moment de l'envoi.
 *
 * Règle (accord écrit de Daniel du 08/10 : « oui fais-le, sur le serveur ») :
 *   · un profil SANS position mais AVEC une ville reçoit comme position de
 *     profil le CENTRE DE SA VILLE (Nominatim / OpenStreetMap, gratuit) —
 *     jamais une adresse ; la carte la floute comme toutes les autres ;
 *   · ce point est marqué « approximatif, source ville » (`positionFromCity`) :
 *     la première vraie position GPS envoyée par l'app le remplace TOUJOURS
 *     (même à moins de 50 km — règle v590 adaptée dans homePosition590.js),
 *     et jamais l'inverse : un profil qui a déjà une position n'est jamais
 *     touché (filtre dans la requête d'écriture, donc même en concurrence) ;
 *   · si un AUTRE profil de la même personne (même e-mail) a déjà une position
 *     de profil, on reprend celle-là (c'est la sienne) plutôt que le centre-ville ;
 *   · ville vide, « — », adresse e-mail, région (« West Virginia ») ou nom
 *     ambigu → on ne pose rien et on le note ;
 *   · comptes +test, sonde et comptes internes : jamais placés dans une vraie ville ;
 *   · AUCUN e-mail, AUCUNE notification : seule la base change.
 *
 * Deux portes :
 *   1. automatique — `attachCityPositionHooks(schema)` (appelé par
 *      homeLocationPlugin) : après l'enregistrement d'un profil sans position
 *      (inscription, modification du profil), le centre-ville est posé en tâche
 *      de fond (jamais d'attente pour l'utilisateur) ;
 *   2. rattrapage — `backfillPositionsFromCity()` derrière la route admin
 *      `POST /api/v1/admin/positions-from-city?dryRun=1`.
 *
 * Nominatim : User-Agent identifiant, 1 requête par seconde au plus (file
 * unique pour tout le processus), cache par nom de ville normalisé (+ pays).
 * Interrupteur sans rebuild : CITY_POSITION=off (Render).
 */

const logger = require('./logger');

const NOMINATIM = 'https://nominatim.openstreetmap.org/search';
const UA = 'HoPetSit/1.0 (contact: hopetsit@gmail.com)';
const MIN_GAP_MS = 1100; // > 1 s entre deux requêtes Nominatim
const TIMEOUT_MS = 8000;
const CACHE_MAX = 2000;
const MISS_TTL_MS = 6 * 60 * 60 * 1000;

// Types de lieu acceptés comme « ville » (jamais une région, un pays, une rue).
const SETTLEMENT_TYPES = new Set([
  'city', 'town', 'village', 'municipality', 'hamlet', 'suburb', 'borough',
  'city_district', 'quarter',
]);

const TEST_EMAIL_RE = /\+test/i;
const INTERNAL_EMAIL_RE = /(^hopetsit@|^dadaciao84@|@invalid\.example$|^probe-)/i;

const enabled = () => String(process.env.CITY_POSITION || '').toLowerCase() !== 'off';
const autoEnabled = () => enabled()
  && (process.env.NODE_ENV !== 'test' || process.env.CITY_POSITION_AUTO_IN_TESTS === '1');

// ── Géométrie ────────────────────────────────────────────────────────────────
function validLngLat(c) {
  if (!Array.isArray(c) || c.length < 2) return false;
  const lng = Number(c[0]);
  const lat = Number(c[1]);
  return Number.isFinite(lat) && Number.isFinite(lng)
    && Math.abs(lat) <= 90 && Math.abs(lng) <= 180 && !(lat === 0 && lng === 0);
}

const sameCoords = (a, b) => validLngLat(a) && validLngLat(b)
  && Math.abs(Number(a[0]) - Number(b[0])) < 1e-6 && Math.abs(Number(a[1]) - Number(b[1])) < 1e-6;

/**
 * La position de profil de ce document vient-elle de sa VILLE (approximative) ?
 * Vrai tant que les coordonnées de profil sont exactement le centre-ville posé
 * par ce module : si l'app renvoie ces mêmes coordonnées en enregistrant le
 * profil, le point reste « approximatif » ; une vraie position (autres
 * coordonnées) cesse de l'être.
 */
function isCityApprox(doc) {
  const p = doc && doc.positionFromCity;
  if (!p || !validLngLat(p.coordinates)) return false;
  const h = doc.homeLocation && doc.homeLocation.coordinates;
  const l = doc.location && doc.location.coordinates;
  if (validLngLat(h)) return sameCoords(h, p.coordinates);
  return sameCoords(l, p.coordinates);
}

// ── Ville ────────────────────────────────────────────────────────────────────
/** Nom de ville utilisable, ou '' (vide, « — », e-mail, adresse web…). */
function usableCity(raw) {
  let s = String(raw == null ? '' : raw).trim();
  if (!s) return '';
  try { if (require('./publicCity607').isUnsafeCity(s)) return ''; } catch (_) { /* règle indisponible */ }
  if (!/\p{L}/u.test(s)) return '';
  try { s = require('./geocodeCity').baseCityName(s) || s; } catch (_) { /* nom brut */ }
  return s.replace(/\s+/g, ' ').trim().slice(0, 120);
}

function cityOfDoc(doc) {
  if (!doc) return '';
  return usableCity((doc.location && doc.location.city) || doc.city || '')
    || usableCity(doc.coverageCity || '');
}

const countryOfDoc = (doc) => {
  const c = String((doc && doc.country) || '').trim().toUpperCase();
  return /^[A-Z]{2}$/.test(c) ? c : '';
};

const normKey = (city, country = '') => `${String(city || '').normalize('NFD').replace(/[̀-ͯ]/g, '')
  .toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim()}|${country || ''}`;

// ── Nominatim (file unique, 1 requête/s, cache) ──────────────────────────────
const _cache = new Map(); // clé → { t, v } ; v = {lat,lng,label,type} | {miss:reason}
let _queue = Promise.resolve();
let _lastAt = 0;
let _fetchImpl = null; // tests : géocodage simulé

function _cacheGet(key) {
  const hit = _cache.get(key);
  if (!hit) return undefined;
  if (hit.v && hit.v.miss && Date.now() - hit.t > MISS_TTL_MS) { _cache.delete(key); return undefined; }
  return hit.v;
}
function _cacheSet(key, v) {
  if (_cache.size >= CACHE_MAX) _cache.delete(_cache.keys().next().value);
  _cache.set(key, { t: Date.now(), v });
}

const _sleep = (ms) => new Promise((r) => { setTimeout(r, ms); });

async function _nominatim(city) {
  const url = `${NOMINATIM}?format=jsonv2&limit=5&addressdetails=1&accept-language=en`
    + `&q=${encodeURIComponent(city)}`;
  const run = async () => {
    const wait = _lastAt + MIN_GAP_MS - Date.now();
    if (wait > 0) await _sleep(wait);
    _lastAt = Date.now();
    if (_fetchImpl) return _fetchImpl(city);
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), TIMEOUT_MS);
    try {
      const r = await fetch(url, {
        headers: { 'User-Agent': UA, Accept: 'application/json', 'Accept-Language': 'en' },
        signal: ctl.signal,
      });
      if (!r.ok) throw new Error(`http ${r.status}`);
      return await r.json();
    } finally { clearTimeout(timer); }
  };
  // File unique : jamais deux requêtes Nominatim en même temps.
  const p = _queue.then(run, run);
  _queue = p.catch(() => {});
  return p;
}

const _typeOf = (row) => String((row && (row.addresstype || row.type)) || '').toLowerCase();
const _isSettlement = (row) => {
  if (!row) return false;
  const t = _typeOf(row);
  if (SETTLEMENT_TYPES.has(t)) return true;
  // Une commune décrite comme limite administrative (ex. « Asnières-sur-Seine »).
  return row.category === 'boundary' && row.type === 'administrative'
    && Number(row.place_rank) >= 12 && Number(row.place_rank) <= 20
    && SETTLEMENT_TYPES.has(String(row.addresstype || '').toLowerCase());
};
const _km = (a, b) => {
  const R = 6371;
  const [la1, lo1, la2, lo2] = [a.lat, a.lon, b.lat, b.lon].map((v) => (Number(v) * Math.PI) / 180);
  const s = Math.sin((la2 - la1) / 2) ** 2 + Math.cos(la1) * Math.cos(la2) * Math.sin((lo2 - lo1) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
};
const _cc = (row) => String((row && row.address && row.address.country_code) || '').toUpperCase();

/**
 * Choisit le centre-ville parmi les réponses Nominatim, ou explique pourquoi non.
 * Pure (testée sans réseau).
 */
function pickSettlement(rows, country = '') {
  const list = Array.isArray(rows) ? rows : [];
  if (!list.length) return { miss: 'not_found' };
  const towns = list.filter(_isSettlement)
    .filter((r) => Number.isFinite(Number(r.lat)) && Number.isFinite(Number(r.lon)));
  if (!towns.length) return { miss: `not_a_city:${_typeOf(list[0]) || 'unknown'}` };
  // Le premier résultat n'est pas une ville (région, rue…) alors qu'une
  // ville plus loin dans la liste porte le nom : on n'y croit que si le
  // premier n'est pas bien plus « important » (West Virginia ≠ un hameau).
  const top = list[0];
  if (!_isSettlement(top)) {
    const ti = Number(top.importance) || 0;
    const si = Number(towns[0].importance) || 0;
    if (ti - si > 0.15) return { miss: `not_a_city:${_typeOf(top) || 'unknown'}` };
  }
  let pool = towns;
  if (country) {
    const inCountry = towns.filter((r) => _cc(r) === country);
    if (inCountry.length) pool = inCountry;
  }
  const [chosen] = pool;
  // Deux lieux du même nom, loin l'un de l'autre (> 50 km), d'importance
  // voisine (« Springfield » : Illinois, Massachusetts, Missouri…) → ambigu,
  // on ne devine pas.
  const rival = pool.slice(1).find((r) => String(r.name || '').toLowerCase() === String(chosen.name || '').toLowerCase()
    && _km(chosen, r) > 50);
  if (rival && (Number(chosen.importance) || 0) - (Number(rival.importance) || 0) < 0.1) return { miss: 'ambiguous' };
  const lat = Math.round(Number(chosen.lat) * 1e6) / 1e6;
  const lng = Math.round(Number(chosen.lon) * 1e6) / 1e6;
  if (!validLngLat([lng, lat])) return { miss: 'not_found' };
  return {
    lat,
    lng,
    type: _typeOf(chosen),
    country: _cc(chosen),
    label: String(chosen.name || '').slice(0, 80),
  };
}

const CROSS_CHECK_KM = 30;

/**
 * Centre de la ville (cache, file 1 req/s) : {lat,lng,type,country,label} ou {miss}.
 *
 * Contre-vérification par Photon (le géocodeur déjà utilisé par l'alerte 612 et
 * la carte, mémorisé en base) : mesuré le 08/10, Nominatim place « Asnières »
 * dans un village de l'Eure quand Photon trouve Asnières-sur-Seine. Si les deux
 * sources sont à plus de 30 km l'une de l'autre, on ne devine pas : « ambiguous_sources ».
 * Photon muet (village absent de sa liste villes/bourgs) → Nominatim seul.
 * `query` permet à l'admin de préciser le nom à chercher (« Asnières-sur-Seine »).
 */
async function cityCenter(cityRaw, country = '', { query = '' } = {}) {
  const city = usableCity(query || cityRaw);
  if (!city) return { miss: 'empty_city' };
  const key = normKey(city, country);
  const hit = _cacheGet(key);
  if (hit !== undefined) return hit;
  let v;
  try {
    v = pickSettlement(await _nominatim(city), country);
  } catch (e) {
    logger.warn(`[cityPosition616] Nominatim indisponible pour « ${city} » : ${e && e.message ? e.message : e}`);
    return { miss: 'geocoder_unavailable' }; // pas mis en cache : on réessaiera
  }
  if (v && !v.miss) {
    let p = null;
    try { p = await require('./geocodeCity').geocodeCity(city); } catch (_) { p = null; }
    if (p && Number.isFinite(p.lat) && Number.isFinite(p.lng)) {
      const d = _km({ lat: v.lat, lon: v.lng }, { lat: p.lat, lon: p.lng });
      if (d > CROSS_CHECK_KM) {
        v = { miss: 'ambiguous_sources', nominatim: { lat: v.lat, lng: v.lng, label: v.label }, photon: { lat: p.lat, lng: p.lng }, km: Math.round(d) };
      } else v.checked = true;
    }
  }
  _cacheSet(key, v);
  return v;
}

// ── Écriture ─────────────────────────────────────────────────────────────────
const MODELS = () => ({
  Owner: require('../models/Owner'),
  Sitter: require('../models/Sitter'),
  Walker: require('../models/Walker'),
});
const ROLE_OF = { Owner: 'owner', Sitter: 'sitter', Walker: 'walker' };

/** Filtre « ce profil n'a AUCUNE position » (posé dans la requête d'écriture). */
const NO_POSITION = {
  $and: [
    { $or: [
      { 'location.coordinates': { $exists: false } },
      { 'location.coordinates': { $size: 0 } },
      { 'location.coordinates': [0, 0] },
      { location: null },
    ] },
    { $or: [
      { 'homeLocation.coordinates': { $exists: false } },
      { 'homeLocation.coordinates': { $size: 0 } },
      { homeLocation: null },
    ] },
  ],
};

const SELECT = '_id email city coverageCity country location +homeLocation +positionFromCity updatedAt createdAt';

function plainEmail(stored) {
  if (!stored) return '';
  let e = stored;
  try { e = require('./encryption').decrypt(stored); } catch (_) { /* illisible */ }
  return typeof e === 'string' ? e.trim().toLowerCase() : '';
}
const isExcludedEmail = (email) => TEST_EMAIL_RE.test(email) || INTERNAL_EMAIL_RE.test(email);

/** Position de profil RÉELLE d'un autre profil de la même personne, ou null. */
async function siblingHome(doc, modelName) {
  try {
    const { identityGroup } = require('./identityGroup');
    const { homeOf } = require('./personMapPosition');
    const g = await identityGroup(String(doc._id));
    const M = MODELS();
    const homes = [];
    for (const d of g.docs || []) {
      if (d.model === modelName && String(d.id) === String(doc._id)) continue;
      const Model = M[d.model];
      if (!Model) continue;
      // eslint-disable-next-line no-await-in-loop
      const sib = await Model.findById(d.id).select(SELECT).lean();
      const h = homeOf(sib);
      if (h && validLngLat(h.coordinates)) homes.push({ h, approx: isCityApprox(sib), sib });
    }
    homes.sort((a, b) => (a.approx - b.approx) || (b.h.at - a.h.at)); // une vraie position d'abord
    return homes[0] || null;
  } catch (_) { return null; }
}

/**
 * Décide (et, si `apply`, pose) la position d'UN profil sans position.
 * @returns {{ id, role, city, country, status, source?, lat?, lng?, label?, reason? }}
 *   status : 'set' | 'would_set' | 'skipped'
 */
async function positionFromCityFor(modelName, docOrId, { apply = false, now = new Date(), overrides = null } = {}) {
  const Model = MODELS()[modelName];
  const doc = docOrId && docOrId._id ? docOrId : await Model.findById(docOrId).select(SELECT).lean();
  const base = { id: doc ? String(doc._id) : String(docOrId), role: ROLE_OF[modelName] };
  if (!doc) return { ...base, status: 'skipped', reason: 'not_found' };
  const city = cityOfDoc(doc);
  const country = countryOfDoc(doc);
  const out = { ...base, city, country };
  const h = doc.homeLocation && doc.homeLocation.coordinates;
  if (validLngLat(doc.location && doc.location.coordinates) || validLngLat(h)) {
    return { ...out, status: 'skipped', reason: 'has_position' };
  }
  if (isExcludedEmail(plainEmail(doc.email))) return { ...out, status: 'skipped', reason: 'test_or_internal' };

  let coords = null;
  let approx = true;
  let source = 'city';
  let label = '';
  const sib = await siblingHome(doc, modelName);
  if (sib) {
    coords = sib.h.coordinates.map(Number);
    approx = sib.approx;
    source = sib.approx ? 'city' : 'other_profile';
  } else {
    if (!city) return { ...out, status: 'skipped', reason: 'empty_city' };
    const query = overrides ? overrides[normKey(city, '').slice(0, -1)] || '' : '';
    const c = await cityCenter(city, country, { query });
    if (!c || c.miss) {
      const r = { ...out, status: 'skipped', reason: (c && c.miss) || 'not_found' };
      if (c && c.miss === 'ambiguous_sources') r.candidates = { nominatim: c.nominatim, photon: c.photon, km: c.km };
      return r;
    }
    coords = [c.lng, c.lat];
    label = c.label;
  }
  const res = { ...out, source, lat: coords[1], lng: coords[0], label };
  if (!apply) return { ...res, status: 'would_set' };

  const set = { 'location.type': 'Point', 'location.coordinates': coords };
  if (city && !(doc.location && doc.location.city)) set['location.city'] = city;
  if (approx) set.positionFromCity = { coordinates: coords, city, at: now, provider: sib ? 'profile' : 'nominatim' };
  // Le filtre NO_POSITION protège une vraie position arrivée entre-temps.
  // `location.updatedAt` absent → homeLocationPlugin pose la position de profil.
  const r = await Model.updateOne({ _id: doc._id, ...NO_POSITION }, { $set: set }, { timestamps: false });
  const n = r && (r.modifiedCount != null ? r.modifiedCount : r.nModified);
  if (!n) return { ...res, status: 'skipped', reason: 'has_position' };
  return { ...res, status: 'set' };
}

/**
 * Rattrapage des profils existants. Aucun e-mail, aucune notification.
 * @param {{ dryRun?: boolean, limit?: number, budgetMs?: number }} o
 */
async function backfillPositionsFromCity({ dryRun = true, limit = 300, budgetMs = 75000, cityQueries = null } = {}) {
  // { "Asnières": "Asnières-sur-Seine" } : nom à chercher pour une ville écrite
  // de façon ambiguë (décidé par un humain après la simulation, jamais deviné).
  const overrides = {};
  for (const [k, v] of Object.entries(cityQueries || {})) {
    const key = normKey(usableCity(k), '').slice(0, -1);
    if (key && typeof v === 'string' && v.trim()) overrides[key] = v.trim().slice(0, 120);
  }
  const started = Date.now();
  const M = MODELS();
  const rows = [];
  let remaining = 0;
  for (const name of ['Sitter', 'Walker', 'Owner']) {
    // eslint-disable-next-line no-await-in-loop
    const docs = await M[name].find(NO_POSITION).select(SELECT).sort({ createdAt: -1 }).limit(2000).lean();
    for (const d of docs) {
      if (rows.length >= limit || Date.now() - started > budgetMs) { remaining += 1; continue; }
      // eslint-disable-next-line no-await-in-loop
      rows.push(await positionFromCityFor(name, d, { apply: !dryRun, overrides }));
    }
  }
  const count = (st) => rows.filter((r) => r.status === st).length;
  const reasons = {};
  for (const r of rows) if (r.status === 'skipped') reasons[r.reason] = (reasons[r.reason] || 0) + 1;
  // Cache des centres-villes de la carte (Photon) : sans effet sur la position,
  // seulement pour que le floutage parte du même centre dès la 1re reconstruction.
  if (!dryRun && count('set')) {
    try {
      const { warmCities } = require('./geocodeCity');
      if (process.env.NODE_ENV !== 'test') warmCities(rows.filter((r) => r.status === 'set').map((r) => r.city));
    } catch (_) { /* jamais bloquant */ }
  }
  return {
    dryRun: !!dryRun,
    examined: rows.length,
    set: count('set'),
    wouldSet: count('would_set'),
    skipped: count('skipped'),
    reasons,
    remaining,
    tookMs: Date.now() - started,
    rows,
  };
}

// ── Porte automatique (inscription, modification du profil) ──────────────────
const _pending = new Set();
const _inflight = new Set();
function scheduleCityPosition(modelName, id) {
  if (!autoEnabled() || !id || !MODELS()[modelName]) return null;
  const key = `${modelName}:${id}`;
  if (_pending.has(key)) return null;
  _pending.add(key);
  const p = (async () => {
    try {
      await _sleep(0);
      const r = await positionFromCityFor(modelName, String(id), { apply: true });
      if (r.status === 'set') logger.info(`[cityPosition616] ${r.role} ${r.id} → centre de « ${r.city} » (${r.source})`);
      return r;
    } catch (e) {
      logger.warn(`[cityPosition616] ${key} : ${e && e.message ? e.message : e}`);
      return null;
    } finally { _pending.delete(key); }
  })();
  _inflight.add(p);
  p.finally(() => _inflight.delete(p));
  return p;
}

const _modelNameOf = (m) => {
  const n = m && m.modelName;
  return n === 'Owner' || n === 'Sitter' || n === 'Walker' ? n : null;
};
const TOUCHES = ['city', 'coverageCity', 'country', 'location', 'location.city', 'location.coordinates'];

/** Branché par homeLocationPlugin sur Owner / Sitter / Walker. */
function attachCityPositionHooks(schema) {
  schema.post('save', function cityPosAfterSave(doc) {
    try {
      if (!autoEnabled()) return;
      const name = _modelNameOf(doc && doc.constructor);
      if (!name) return;
      if (validLngLat(doc.location && doc.location.coordinates)) return;
      if (!cityOfDoc(doc)) return;
      scheduleCityPosition(name, String(doc._id));
    } catch (_) { /* jamais bloquant */ }
  });
  const afterUpdate = function cityPosAfterUpdate() {
    try {
      if (!autoEnabled()) return;
      const name = _modelNameOf(this.model);
      if (!name) return;
      const u = this.getUpdate() || {};
      const set = { ...(u.$set || {}), ...Object.fromEntries(Object.entries(u).filter(([k]) => !k.startsWith('$'))) };
      const keys = Object.keys(set);
      if (!keys.some((k) => TOUCHES.includes(k))) return;
      if (validLngLat(set['location.coordinates']) || validLngLat(set.location && set.location.coordinates)) return;
      const f = this.getFilter() || {};
      if (!f._id || typeof f._id === 'object' && !(f._id instanceof require('mongoose').Types.ObjectId)) return;
      scheduleCityPosition(name, String(f._id));
    } catch (_) { /* jamais bloquant */ }
  };
  schema.post('updateOne', afterUpdate);
  schema.post('findOneAndUpdate', afterUpdate);
}

// ── Tests uniquement ─────────────────────────────────────────────────────────
const _test = {
  setFetch(fn) { _fetchImpl = fn; },
  reset() { _cache.clear(); _queue = Promise.resolve(); _lastAt = 0; _fetchImpl = null; },
  idle: () => Promise.all([..._inflight]),
  setGap(ms) { _lastAt = Date.now() - MIN_GAP_MS + (ms || 0); },
};

module.exports = {
  UA,
  MIN_GAP_MS,
  usableCity,
  pickSettlement,
  cityCenter,
  isCityApprox,
  positionFromCityFor,
  backfillPositionsFromCity,
  scheduleCityPosition,
  attachCityPositionHooks,
  NO_POSITION,
  _test,
};
