/**
 * 607 (PAM, 02/10/2026) — MINI-PELUCHES de la PawMap : tirage, liste, capture.
 *
 * Règles (décision de Daniel du 02/10, PROCHAIN_BUILD_607.md § 7 B) :
 *   · tirage QUOTIDIEN par ville ACTIVE = au moins un utilisateur réel avec
 *     une position ces 30 derniers jours (comptes +test, sonde et adresses
 *     internes exclus) ;
 *   · 3 à 5 peluches par ville, posées sur des parcs à chiens PUBLICS
 *     d'OpenStreetMap déjà en base (MapPOI `park`, source `seed`) — jamais
 *     sur une route ni chez quelqu'un ; les « espaces de déjection » sont
 *     écartés ;
 *   · visibles SEULEMENT si l'appelant a une Balade en cours CÔTÉ SERVEUR
 *     (session du direct en mémoire) ; sinon liste vide ;
 *   · capture à moins de 30 m, Balade en cours, vitesse < 25 km/h entre deux
 *     positions, 1 capture par personne et par jour, 1 capture par peluche ;
 *   · récompense : +20 PawPoints par le service existant. Jamais d'argent.
 *
 * Le tirage est PARESSEUX : fait à la première demande du jour d'une ville
 * (aucune tâche planifiée à surveiller), idempotent (index unique
 * { ville, jour, emplacement }) — deux serveurs ne posent jamais 10 peluches.
 */
const PawPlush = require('../models/PawPlush');
const { PLUSH_TYPES, PawPlushBonus } = require('../models/PawPlush');
const MapPOI = require('../models/MapPOI');
const logger = require('../utils/logger');

// Barème (BOB / Daniel, 02/10) — exporté pour le catalogue PawPoints (ZOE).
// 607b — l'ancien index unique (jour, personne) comptait aussi les copies des
// comptes de test : on le retire une fois, le nouveau (sans les copies) est
// créé par Mongoose.
let _indexFixed = false;
async function fixIndexesOnce() {
  if (_indexFixed) return;
  _indexFixed = true;
  try {
    const idx = await PawPlush.collection.indexes();
    if (idx.some((i) => i.name === 'day_1_caughtByPerson_1')) {
      await PawPlush.collection.dropIndex('day_1_caughtByPerson_1');
      logger.info('[plush] ancien index (jour, personne) retiré');
    }
    await PawPlush.createIndexes();
  } catch (e) {
    logger.warn(`[plush] index : ${e.message}`);
  }
}

const REWARD_POINTS = 20;              // chaque peluche (1 par jour)
const GOLDEN_POINTS = 200;             // peluche dorée (1 par ville et par semaine)
const GOLDEN_BOOST_HOURS = 24;         // + 24 h de PawBoost offert
const COLLECTOR_POINTS = 500;          // les 5 types réunis, une seule fois + badge
const STREAK_DAYS = 7;                 // 7 jours de suite avec une capture…
const STREAK_POINTS = 200;             // … = +200 (à chaque série de 7)
const CATCH_RADIUS_M = 30;
const VIEW_RADIUS_M = 5000;
const MAX_SPEED_KMH = 25;
const ACTIVE_DAYS = 30;
const PARK_RADIUS_KM = 5; // parcs retenus autour du centre de la ville
const CITY_REACH_KM = 25; // villes dont on tire les peluches autour de moi
const CITY_CACHE_MS = 30 * 60 * 1000;
const WALK_FRESH_MS = 5 * 60 * 1000; // Balade « en cours » : signal < 5 min
const EXCLUDED_PARK_RE = /d[ée]jection|canisite|sanicanin|toilettes?\b/i;
const INTERNAL_EMAIL_RE = /(\+test|^hopetsit@|^dadaciao84@|@invalid\.example)/i;

// ── outils purs (testés) ────────────────────────────────────────────────────

function metersBetween(aLat, aLng, bLat, bLng) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(bLat - aLat);
  const dLng = toRad(bLng - aLng);
  const x = Math.sin(dLat / 2) ** 2
    + Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(x)));
}

/** « Paris 11e » → « paris », « Saint-Étienne » → « saint etienne ». */
function normalizeCityKey(city) {
  let base = String(city || '').trim();
  try { base = require('../utils/geocodeCity').baseCityName(base); } catch (_) { /* nom brut */ }
  return base
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .split(/[(,/]/)[0]
    .replace(/[-_'’.]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Fuseau horaire approché d'un lieu (heure d'été comprise) — mesuré en prod
 * le 02/10 : avec « longitude / 15 », Paris (UTC+2 en été) changeait de jour
 * à 2 h du matin. Europe et Amérique du Nord : vrais fuseaux ; ailleurs :
 * longitude / 15.
 */
function timeZoneFor(lat, lng) {
  const la = Number(lat);
  const ln = Number(lng);
  if (!Number.isFinite(la) || !Number.isFinite(ln)) return null;
  if (la > 34 && la < 72 && ln > -11 && ln < 41) {
    if (ln < -5.5 || (la > 49.8 && ln < 1.8 && la < 61)) return 'Europe/London';
    if (ln > 22 && la < 60) return 'Europe/Athens';
    return 'Europe/Paris';
  }
  if (la > 14 && la < 72 && ln > -170 && ln < -50) {
    if (ln < -114) return 'America/Los_Angeles';
    if (ln < -101) return 'America/Denver';
    if (ln < -86) return 'America/Chicago';
    return 'America/New_York';
  }
  return null;
}

/** Jour LOCAL d'un lieu, AAAA-MM-JJ. [lat] facultatif (sans : Europe supposée si la longitude y est). */
function dayKeyFor(lng, now = Date.now(), lat = null) {
  const la = lat === null || lat === undefined ? (Number(lng) > -11 && Number(lng) < 41 ? 48 : (Number(lng) < -50 ? 35 : 0)) : lat;
  const tz = timeZoneFor(la, lng);
  if (tz) {
    try {
      return new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' })
        .format(new Date(now));
    } catch (_) { /* repli ci-dessous */ }
  }
  const off = Math.round((Number(lng) || 0) / 15);
  return new Date(now + off * 3600 * 1000).toISOString().slice(0, 10);
}

function hashString(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i += 1) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

/** Générateur déterministe (même ville + même jour = même tirage). */
function seededRandom(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * Choisit 3 à 5 parcs (moins s'il n'y en a pas assez) et un type de peluche
 * pour chacun. [parks] = [{ _id, lat, lng }], déjà filtrés.
 */
function pickPlushies(parks, cityKey, day) {
  const rnd = seededRandom(hashString(`${cityKey}|${day}`));
  const want = 3 + Math.floor(rnd() * 3);
  const pool = [...parks].sort((a, b) => String(a._id).localeCompare(String(b._id)));
  const out = [];
  while (out.length < want && pool.length) {
    const i = Math.floor(rnd() * pool.length);
    const p = pool.splice(i, 1)[0];
    out.push({ slot: out.length, park: p, type: PLUSH_TYPES[Math.floor(rnd() * PLUSH_TYPES.length)] });
  }
  return out;
}

/** Lundi (AAAA-MM-JJ) de la semaine d'un jour AAAA-MM-JJ. */
function weekOf(day) {
  const d = new Date(`${day}T00:00:00Z`);
  const dow = (d.getUTCDay() + 6) % 7; // lundi = 0
  return new Date(d.getTime() - dow * 86400000).toISOString().slice(0, 10);
}

/** Jour de la semaine (0 = lundi … 6) où la ville a SA peluche dorée. */
function goldenWeekday(cityKey, day) {
  return hashString(`gold|${cityKey}|${weekOf(day)}`) % 7;
}

/** Ce jour est-il celui de la peluche dorée de la ville ? */
function isGoldenDay(cityKey, day) {
  const d = new Date(`${day}T00:00:00Z`);
  return ((d.getUTCDay() + 6) % 7) === goldenWeekday(cityKey, day);
}

/** Jour précédent (AAAA-MM-JJ). */
function prevDay(day) {
  return new Date(Date.parse(`${day}T00:00:00Z`) - 86400000).toISOString().slice(0, 10);
}

/** Longueur de la série de jours consécutifs finissant à [day] dans [days]. */
function streakEndingAt(days, day) {
  const set = new Set(days);
  let n = 0;
  let d = day;
  while (set.has(d)) {
    n += 1;
    d = prevDay(d);
  }
  return n;
}

/** Un parc à chiens OSM public, utilisable pour une peluche ? */
function isUsablePark(poi) {
  if (!poi || poi.category !== 'park' || poi.status !== 'active') return false;
  if (poi.source !== 'seed' || !poi.osmId) return false; // OSM seulement
  if (EXCLUDED_PARK_RE.test(String(poi.title || ''))) return false;
  const c = poi.location && poi.location.coordinates;
  return Array.isArray(c) && c.length === 2 && Number.isFinite(c[0]) && Number.isFinite(c[1]);
}

/**
 * Contrôle de vitesse entre deux positions horodatées (ms). Faux si plus de
 * 25 km/h. En dessous de 40 m on ne juge pas (bruit du GPS).
 */
function speedOk(a, b) {
  if (!a || !b) return true;
  const d = metersBetween(a.lat, a.lng, b.lat, b.lng);
  if (d < 40) return true;
  const dt = Math.max(1000, Math.abs(Number(b.t) - Number(a.t)));
  const kmh = (d / 1000) / (dt / 3600000);
  return kmh <= MAX_SPEED_KMH;
}

function isRealEmail(stored) {
  let email = stored;
  try { email = require('../utils/encryption').decrypt(stored); } catch (_) { /* en clair */ }
  return !INTERNAL_EMAIL_RE.test(String(email || '').trim().toLowerCase());
}

// ── villes actives ──────────────────────────────────────────────────────────

let _cities = null;
let _citiesAt = 0;

function _resetForTests() {
  _cities = null;
  _citiesAt = 0;
  _lastPos.clear();
  _testCache.clear();
}

function median(xs) {
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.floor(s.length / 2)];
}

/** [{ key, label, lat, lng, users }] — calculé au plus toutes les 30 min. */
async function activeCities({ now = Date.now(), force = false } = {}) {
  if (!force && _cities && now - _citiesAt < CITY_CACHE_MS) return _cities;
  const since = new Date(now - ACTIVE_DAYS * 86400000);
  const groups = new Map();
  for (const name of ['Owner', 'Sitter', 'Walker']) {
    const Model = require(`../models/${name}`);
    let docs = [];
    try {
      docs = await Model.find({
        'location.coordinates.1': { $exists: true },
        $or: [{ 'location.updatedAt': { $gte: since } }, { updatedAt: { $gte: since } }],
      }).select('email location city').limit(20000).lean();
    } catch (e) {
      logger.warn(`[plush] villes actives (${name}) : ${e.message}`);
    }
    for (const d of docs) {
      if (!isRealEmail(d.email)) continue;
      const label = (d.location && d.location.city) || d.city || '';
      const key = normalizeCityKey(label);
      const c = d.location && d.location.coordinates;
      if (!key || !Array.isArray(c) || c.length !== 2) continue;
      if (!groups.has(key)) groups.set(key, { key, label: String(label).trim(), lats: [], lngs: [] });
      const g = groups.get(key);
      g.lats.push(c[1]);
      g.lngs.push(c[0]);
    }
  }
  _cities = [...groups.values()].map((g) => ({
    key: g.key,
    label: g.label,
    lat: median(g.lats),
    lng: median(g.lngs),
    users: g.lats.length,
  }));
  _citiesAt = now;
  return _cities;
}

// ── tirage ──────────────────────────────────────────────────────────────────

async function ensureDraw(city, { now = Date.now() } = {}) {
  const day = dayKeyFor(city.lng, now, city.lat);
  if (await PawPlush.exists({ cityKey: city.key, day })) return { day, created: 0 };
  const pois = await MapPOI.find({
    category: 'park',
    status: 'active',
    source: 'seed',
    location: { $geoWithin: { $centerSphere: [[city.lng, city.lat], PARK_RADIUS_KM / 6371] } },
  }).select('title category status source osmId location').limit(500).lean();
  // Un parc ne porte qu'UNE peluche par jour, même s'il est proche de deux
  // villes actives (vu en prod le 02/10 : deux peluches au même point).
  const taken = new Set((await PawPlush.find({ day, poiId: { $in: pois.map((p) => p._id) } })
    .select('poiId').lean()).map((x) => String(x.poiId)));
  const parks = pois.filter((p) => isUsablePark(p) && !taken.has(String(p._id))).map((p) => ({
    _id: p._id, lng: p.location.coordinates[0], lat: p.location.coordinates[1],
  }));
  if (!parks.length) return { day, created: 0 };
  const picks = pickPlushies(parks, city.key, day);
  const golden = isGoldenDay(city.key, day);
  const expireAt = new Date(now + 3 * 86400000);
  let created = 0;
  for (const p of picks) {
    try {
      await PawPlush.create({
        cityKey: city.key,
        cityLabel: city.label,
        day,
        slot: p.slot,
        type: p.type,
        golden: golden && p.slot === 0,
        poiId: p.park._id,
        location: { type: 'Point', coordinates: [p.park.lng, p.park.lat] },
        expireAt,
      });
      created += 1;
    } catch (e) {
      if (e && e.code !== 11000) logger.warn(`[plush] tirage ${city.key} : ${e.message}`);
    }
  }
  if (created) logger.info(`🧸 [plush] ${created} peluche(s) posée(s) à ${city.key} (${day})`);
  return { day, created };
}

// ── Balade en cours (côté serveur) ──────────────────────────────────────────

async function personOf(userId) {
  const { personIds } = require('../utils/personScope');
  const ids = await personIds(userId);
  const list = ids.length ? ids : [String(userId)];
  return { ids: list, key: require('../utils/followers589').personKey(list), test: await isTestPerson(list) };
}

/** Un des profils de la personne est un compte de test (+test) ? */
const _testCache = new Map();
async function isTestPerson(ids) {
  const k = [...ids].map(String).sort().join(',');
  if (_testCache.has(k)) return _testCache.get(k);
  const { isTestAccountEmail } = require('../utils/testAccount2809');
  let test = false;
  for (const name of ['Owner', 'Sitter', 'Walker']) {
    try {
      const docs = await require(`../models/${name}`).find({ _id: { $in: ids } }).select('email').lean();
      if (docs.some((d) => isTestAccountEmail(d.email))) test = true;
    } catch (_) { /* id d'un autre modèle */ }
  }
  _testCache.set(k, test);
  return test;
}

/**
 * Peluches attrapées AVANT cette règle par un compte de test : on les rend
 * aux vrais utilisateurs (l'original redevient libre, le compte de test garde
 * une copie). Appelé sur les peluches de la zone affichée.
 */
async function releaseTestCatches(plushes) {
  let released = 0;
  for (const p of plushes) {
    if (!p.caughtByPerson || p.testCopy || !p.caughtBy || !p.caughtBy.userId) continue;
    let ids = [p.caughtBy.userId];
    try { ids = await require('../utils/personScope').personIds(p.caughtBy.userId); } catch (_) { /* id seul */ }
    if (!(await isTestPerson(ids))) continue;
    try {
      await PawPlush.updateOne({ _id: p._id, caughtByPerson: p.caughtByPerson }, { $set: { caughtByPerson: null, 'caughtBy.userId': null, 'caughtBy.role': null, 'caughtBy.at': null, expireAt: new Date(Date.now() + 3 * 86400000) } });
      await PawPlush.create({
        cityKey: `test:${p.cityKey}:${p.caughtByPerson}`, cityLabel: p.cityLabel, day: p.day, slot: p.slot,
        type: p.type, golden: !!p.golden, poiId: p.poiId, location: p.location,
        caughtByPerson: p.caughtByPerson, caughtBy: p.caughtBy, copyOf: p._id, testCopy: true,
      }).catch(() => {});
      released += 1;
    } catch (e) {
      logger.warn(`[plush] libération ${p._id} : ${e.message}`);
    }
  }
  return released;
}

/** Session du direct de la personne si elle est EN COURS (signal récent). */
function walkSessionOf(ids, now = Date.now()) {
  const { getLiveSessionForIds } = require('../sockets/mapSocket');
  const s = getLiveSessionForIds(ids);
  if (!s) return null;
  if (now - Number(s.lastSeenAt || 0) > WALK_FRESH_MS) return null;
  return s;
}

// Dernière position vue par ce service (contrôle de vitesse entre deux appels).
const _lastPos = new Map(); // personKey → { lat, lng, t }

function publicPlush(p) {
  const c = p.location.coordinates;
  return { id: String(p._id), type: p.type, golden: !!p.golden, lat: c[1], lng: c[0], day: p.day };
}

// ── API ─────────────────────────────────────────────────────────────────────

async function listActive({ userId, lat, lng, now = Date.now() }) {
  await fixIndexesOnce();
  const empty = {
    walkActive: false, plushies: [], radiusM: VIEW_RADIUS_M,
    catchRadiusM: CATCH_RADIUS_M, reward: REWARD_POINTS, caughtToday: false,
  };
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return empty;
  const me = await personOf(userId);
  if (!walkSessionOf(me.ids, now)) return empty;
  const cities = (await activeCities({ now }))
    .filter((c) => metersBetween(lat, lng, c.lat, c.lng) <= CITY_REACH_KM * 1000);
  for (const c of cities) {
    try { await ensureDraw(c, { now }); } catch (e) { logger.warn(`[plush] ${c.key} : ${e.message}`); }
  }
  const today = dayKeyFor(lng, now, lat);
  const days = [...new Set([today, ...cities.map((c) => dayKeyFor(c.lng, now, c.lat))])];
  const area = { $geoWithin: { $centerSphere: [[lng, lat], VIEW_RADIUS_M / 6371000] } };
  // Peluches prises par un compte de test avant la règle des copies : rendues.
  try {
    const caught = await PawPlush.find({ day: { $in: days }, caughtByPerson: { $ne: null }, testCopy: { $ne: true }, location: area }).limit(60).lean();
    if (caught.length) await releaseTestCatches(caught);
  } catch (e) { logger.warn(`[plush] libération : ${e.message}`); }
  let found = await PawPlush.find({
    day: { $in: days },
    caughtByPerson: null,
    testCopy: { $ne: true },
    location: area,
  }).limit(30).lean();
  if (me.test) {
    // Le compte de test ne revoit pas celles dont il a déjà une copie.
    const mine = new Set((await PawPlush.find({ caughtByPerson: me.key, testCopy: true, day: { $in: days } })
      .select('copyOf').lean()).map((x) => String(x.copyOf)));
    found = found.filter((p) => !mine.has(String(p._id)));
  }
  // Comptes de test : jamais « déjà attrapée aujourd'hui » (copies illimitées).
  const caughtToday = me.test
    ? false
    : !!(await PawPlush.exists({ caughtByPerson: me.key, day: today, testCopy: { $ne: true } }));
  return { ...empty, walkActive: true, caughtToday, plushies: found.map(publicPlush) };
}

class PlushError extends Error {
  constructor(status, code, extra = {}) {
    super(code);
    this.status = status;
    this.code = code;
    this.extra = extra;
  }
}

async function catchPlush({ userId, role, plushId, lat, lng, now = Date.now() }) {
  await fixIndexesOnce();
  const mongoose = require('mongoose');
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) throw new PlushError(400, 'POSITION_REQUIRED');
  if (!mongoose.isValidObjectId(plushId)) throw new PlushError(404, 'NOT_FOUND');
  const me = await personOf(userId);
  const session = walkSessionOf(me.ids, now);
  if (!session) throw new PlushError(403, 'WALK_REQUIRED');
  const plush = await PawPlush.findById(plushId).lean();
  if (!plush) throw new PlushError(404, 'NOT_FOUND');
  const [pLng, pLat] = plush.location.coordinates;
  if (plush.day !== dayKeyFor(pLng, now, pLat)) throw new PlushError(410, 'EXPIRED');
  if (plush.testCopy) throw new PlushError(404, 'NOT_FOUND');
  if (plush.caughtByPerson && !me.test) throw new PlushError(409, 'ALREADY_CAUGHT');
  const here = { lat, lng, t: now };
  // Vitesse : depuis la dernière position du direct ET depuis mon dernier appel.
  const fromWalk = { lat: session.lat, lng: session.lng, t: Number(session.at) };
  const prev = _lastPos.get(me.key);
  _lastPos.set(me.key, here);
  if (!speedOk(fromWalk, here) || !speedOk(prev, here)) throw new PlushError(422, 'TOO_FAST');
  const distanceM = Math.round(metersBetween(lat, lng, pLat, pLng));
  if (distanceM > CATCH_RADIUS_M) throw new PlushError(422, 'TOO_FAR', { distanceM });
  if (!me.test && await PawPlush.exists({ caughtByPerson: me.key, day: plush.day, testCopy: { $ne: true } })) {
    throw new PlushError(429, 'DAILY_LIMIT');
  }
  let won;
  if (me.test) {
    // Compte de test : une COPIE, l'original reste libre pour les autres.
    if (await PawPlush.exists({ caughtByPerson: me.key, copyOf: plush._id })) {
      throw new PlushError(409, 'ALREADY_CAUGHT');
    }
    try {
      won = (await PawPlush.create({
        cityKey: `test:${plush.cityKey}:${me.key}`, cityLabel: plush.cityLabel, day: plush.day, slot: plush.slot,
        type: plush.type, golden: !!plush.golden, poiId: plush.poiId, location: plush.location,
        caughtByPerson: me.key, caughtBy: { userId: String(userId), role: role || 'owner', at: new Date(now) },
        copyOf: plush._id, testCopy: true,
      })).toObject();
    } catch (e) {
      if (e && e.code === 11000) throw new PlushError(429, 'DAILY_LIMIT');
      throw e;
    }
  }
  if (!won) try {
    won = await PawPlush.findOneAndUpdate(
      { _id: plush._id, caughtByPerson: null },
      {
        $set: { caughtByPerson: me.key, caughtBy: { userId: String(userId), role: role || 'owner', at: new Date(now) } },
        $unset: { expireAt: 1 },
      },
      { new: true },
    ).lean();
  } catch (e) {
    if (e && e.code === 11000) throw new PlushError(429, 'DAILY_LIMIT');
    throw e;
  }
  if (!won) throw new PlushError(409, 'ALREADY_CAUGHT');
  const pp = require('./pawPointsService');
  const golden = !!won.golden;
  const award = await pp.awardPointsDetailed({
    userId, role, points: golden ? GOLDEN_POINTS : REWARD_POINTS,
    reason: `mini-peluche ${golden ? 'dorée ' : ''}${plush.type}`,
  });
  let points = award ? award.credited : 0;
  let lifetime = award ? award.lifetime : null;
  const bonuses = [];
  let boostUntil = null;
  if (golden) {
    boostUntil = await grantBoostHours(userId, role, GOLDEN_BOOST_HOURS, now);
    if (boostUntil) bonuses.push({ kind: 'golden_boost', hours: GOLDEN_BOOST_HOURS });
  }
  // Collection complète (5 types) : +500 une seule fois + badge « Collectionneur ».
  const types = await PawPlush.distinct('type', { caughtByPerson: me.key });
  if (PLUSH_TYPES.every((t) => types.includes(t))) {
    const b = await grantBonusOnce(me.key, 'collector', 'once', COLLECTOR_POINTS, { userId, role });
    if (b) {
      points += b.credited;
      lifetime = b.lifetime;
      bonuses.push({ kind: 'collector', points: b.credited, badge: 'collector' });
    }
  }
  // 7 jours de suite avec une capture : +200 à chaque série complète de 7.
  const days = await PawPlush.distinct('day', { caughtByPerson: me.key });
  const streak = streakEndingAt(days, won.day);
  if (streak > 0 && streak % STREAK_DAYS === 0) {
    const b = await grantBonusOnce(me.key, 'streak7', won.day, STREAK_POINTS, { userId, role });
    if (b) {
      points += b.credited;
      lifetime = b.lifetime;
      bonuses.push({ kind: 'streak7', points: b.credited, days: streak });
    }
  }
  return {
    ok: true,
    plush: { id: String(won._id), type: won.type, golden, day: won.day },
    points,
    lifetime,
    streak,
    bonuses,
    boostUntil: boostUntil ? boostUntil.toISOString() : null,
  };
}

/** Bonus accordé UNE fois (index unique) ; null s'il l'était déjà. */
async function grantBonusOnce(personKey, kind, key, pts, { userId, role }) {
  try {
    await PawPlushBonus.create({ personKey, kind, key, points: pts });
  } catch (e) {
    if (e && e.code === 11000) return null;
    throw e;
  }
  const r = await require('./pawPointsService').awardPointsDetailed({
    userId, role, points: pts, reason: `peluches : bonus ${kind}`,
  });
  return r || { credited: 0, lifetime: null };
}

/**
 * PawBoost offert : prolonge `boostExpiry` du profil (le même champ que
 * l'achat et la récompense « boost » des PawPoints, lu par la carte via
 * mapVisibility.isBoosted).
 */
async function grantBoostHours(userId, role, hours, now = Date.now()) {
  try {
    const r = String(role || '').toLowerCase();
    const Model = require(`../models/${r === 'walker' ? 'Walker' : r === 'sitter' ? 'Sitter' : 'Owner'}`);
    const u = await Model.findById(userId).select('boostExpiry');
    if (!u) return null;
    const base = u.boostExpiry && new Date(u.boostExpiry).getTime() > now ? new Date(u.boostExpiry).getTime() : now;
    u.boostExpiry = new Date(base + hours * 3600000);
    await u.save();
    return u.boostExpiry;
  } catch (e) {
    logger.warn(`[plush] PawBoost offert : ${e.message}`);
    return null;
  }
}

async function collection({ userId }) {
  const me = await personOf(userId);
  const rows = await PawPlush.find({ caughtByPerson: me.key })
    .sort({ 'caughtBy.at': -1 }).limit(500).lean();
  const counts = Object.fromEntries(PLUSH_TYPES.map((t) => [t, 0]));
  let golden = 0;
  for (const r of rows) {
    counts[r.type] = (counts[r.type] || 0) + 1;
    if (r.golden) golden += 1;
  }
  const collector = !!(await PawPlushBonus.exists({ personKey: me.key, kind: 'collector' }));
  const today = rows.length ? rows[0].day : null;
  return {
    total: rows.length,
    counts,
    golden,
    types: PLUSH_TYPES,
    badges: collector ? ['collector'] : [],
    streak: today ? streakEndingAt(rows.map((r) => r.day), today) : 0,
    items: rows.map((r) => ({
      id: String(r._id), type: r.type, golden: !!r.golden, day: r.day, city: r.cityLabel || '',
      at: r.caughtBy && r.caughtBy.at ? new Date(r.caughtBy.at).toISOString() : null,
    })),
  };
}

/** Le badge « Collectionneur » d'une personne (pour la fiche). */
async function hasCollectorBadge(userId) {
  const me = await personOf(userId);
  return !!(await PawPlushBonus.exists({ personKey: me.key, kind: 'collector' }));
}

/** Barème lisible par le catalogue PawPoints (ZOE) et le site (LEO). */
const PLUSH_RULES = Object.freeze({
  perPlush: REWARD_POINTS,
  perDay: 1,
  golden: { points: GOLDEN_POINTS, boostHours: GOLDEN_BOOST_HOURS, perCityPerWeek: 1 },
  collector: { points: COLLECTOR_POINTS, badge: 'collector', types: PLUSH_TYPES.length },
  streak: { days: STREAK_DAYS, points: STREAK_POINTS },
});

module.exports = {
  PLUSH_RULES,
  GOLDEN_POINTS,
  GOLDEN_BOOST_HOURS,
  COLLECTOR_POINTS,
  STREAK_DAYS,
  STREAK_POINTS,
  weekOf,
  isGoldenDay,
  streakEndingAt,
  hasCollectorBadge,
  REWARD_POINTS,
  CATCH_RADIUS_M,
  VIEW_RADIUS_M,
  MAX_SPEED_KMH,
  PLUSH_TYPES,
  PlushError,
  metersBetween,
  timeZoneFor,
  normalizeCityKey,
  dayKeyFor,
  pickPlushies,
  isUsablePark,
  speedOk,
  isRealEmail,
  activeCities,
  ensureDraw,
  listActive,
  catchPlush,
  collection,
  releaseTestCatches,
  _resetForTests,
};
