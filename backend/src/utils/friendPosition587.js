/**
 * v587 (25/09/2026) — POSITION D'UN AMI SUR LA PAWMAP, hors direct.
 *
 * Décision écrite de Daniel (25/09, « Amis OK, je l'active ») :
 *   · « Visible par tous » ou « Amis seulement » → ses amis reçoivent sa
 *     position de PROFIL, floutée à ~1 km, exactement comme la couche monde
 *     (grille en km tirée vers le centre-ville, `approxKm`, `positionSource`) ;
 *   · « Masqué » → aucune position, pour personne, amis compris ;
 *   · en direct → le GPS exact passe par /friends/live-positions (pas ici).
 * Les comptes de test restent visibles de LEURS amis (la vitrine publique les
 * exclut, pas la liste d'amis).
 *
 * `friendPositionOf` est PURE (testée sans base) ; `friendPositionsFor` lit
 * les 3 profils de chaque ami en 3 requêtes.
 */
const logger = require('./logger');
const mapVisibility = require('./mapVisibility');
const { pickPersonPosition, validLngLat } = require('./personMapPosition');
const { WORLD_APPROX_KM, blurTowardAnchor } = require('./coarseLocation');

const ROLE_BY_MODEL = { Owner: 'owner', Sitter: 'sitter', Walker: 'walker' };

function _anchorOf(city) {
  try {
    const { peekCity } = require('./geocodeCity');
    const v = peekCity(city);
    return v && Number.isFinite(v.lat) && Number.isFinite(v.lng) ? v : null;
  } catch (_) {
    return null;
  }
}

/** 614 — fraîcheur maximale du GPS d'un ami hors direct (même fenêtre que le
 *  « déménagement » v590 : au-delà, la position de profil reprend la main). */
const FRIEND_GPS_MAX_MS = 12 * 60 * 60 * 1000;

/** 614 — GPS le plus récent (< 12 h) parmi les profils d'une personne, ou null. */
function freshGpsOf(docs, now = new Date()) {
  const t0 = new Date(now).getTime();
  let best = null;
  for (const d of docs || []) {
    const g = d && d.lastGps;
    if (!g || !validLngLat(g.coordinates)) continue;
    const t = g.at ? new Date(g.at).getTime() : NaN;
    if (!Number.isFinite(t) || t > t0 + 60000 || t0 - t > FRIEND_GPS_MAX_MS) continue;
    if (!best || t > best.at) best = { coordinates: g.coordinates.map(Number), at: t };
  }
  return best;
}

/** Le document sans son partage en direct : on ne garde que le PROFIL. */
function _withoutLive(d) {
  if (!d || !d.location || d.location.liveShareActive !== true) return d;
  return { ...d, location: { ...d.location, liveShareActive: false } };
}

/**
 * @param {Array<{d: object, role: string}>} entries tous les profils d'UN ami
 * @returns {{ mapVisibility, location, approx, approxKm, positionSource, city } }
 *   `location` vaut null quand l'ami est « Masqué » ou sans position connue.
 */
function friendPositionOf(entries, { now = new Date(), cityAnchor = _anchorOf } = {}) {
  const docs = (entries || []).map((e) => e && e.d).filter(Boolean);
  const vis = mapVisibility.strictestVisibility(docs);
  const empty = {
    mapVisibility: vis,
    location: null,
    approx: true,
    approxKm: WORLD_APPROX_KM,
    positionSource: null,
    city: '',
  };
  if (vis === 'hidden' || !docs.length) return empty;
  const pos = pickPersonPosition(
    entries.map((e) => ({ ...e, d: _withoutLive(e.d) })),
    { now, cityAnchor },
  );
  // 614 (PAM, 07/10) — GPS de l'app ouverte (< 12 h) : là où l'ami EST, pas
  // là où il s'est inscrit. Un AMI seulement (cette fonction ne sert qu'aux
  // amis) ; « Masqué » est déjà sorti plus haut.
  const gps = freshGpsOf(docs, now);
  if (gps) {
    return {
      mapVisibility: vis,
      location: { coordinates: gps.coordinates },
      approx: false,
      approxKm: 0,
      positionSource: 'gps',
      positionAt: new Date(gps.at).toISOString(),
      city: (pos && pos.city) || '',
    };
  }
  if (!pos) return empty;
  const [lng, lat] = pos.coordinates.map(Number);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || (lat === 0 && lng === 0)) return empty;
  // 610 — RÈGLE A (Daniel, 04/10) : un AMI voit la VRAIE position de profil
  // (avant : floutée ~1 km). « Masqué » reste sans position (plus haut).
  void blurTowardAnchor;
  return {
    mapVisibility: vis,
    location: { coordinates: [lng, lat] },
    approx: false,
    approxKm: 0,
    positionSource: pos.source,
    city: pos.city || '',
  };
}

/**
 * @param {Array<string[]>} idLists pour chaque ami, les ids de tous ses profils
 * @returns {Promise<Array<object>>} un résultat `friendPositionOf` par ami
 *   (même ordre). Ne lève jamais : en cas d'échec, aucune position (sûr).
 */
async function friendPositionsFor(idLists) {
  const lists = (idLists || []).map((l) => [...new Set((l || []).map(String).filter(Boolean))]);
  const all = [...new Set(lists.flat())];
  const none = () => ({
    mapVisibility: 'all', location: null, approx: true, approxKm: WORLD_APPROX_KM, positionSource: null, city: '',
  });
  if (!all.length) return lists.map(none);
  try {
    // v594 — centres-villes gardés en base : même point après un redémarrage.
    const { ensureAnchorsLoaded, peekCity, warmCities } = require('./geocodeCity');
    await ensureAnchorsLoaded();
    const models = {
      Owner: require('../models/Owner'),
      Sitter: require('../models/Sitter'),
      Walker: require('../models/Walker'),
    };
    const sel = 'location +homeLocation +lastGps city updatedAt createdAt email '
      + 'preferences.hideFromMap preferences.mapVisibility';
    const rows = (await Promise.all(Object.entries(models).map(([name, M]) => M
      .find({ _id: { $in: all } }).select(sel).lean()
      .then((r) => (r || []).map((d) => ({ d, role: ROLE_BY_MODEL[name] })))
      .catch(() => [])))).flat();
    const byId = new Map(rows.map((x) => [String(x.d._id), x]));
    const out = lists.map((ids) => {
      const entries = ids.map((id) => byId.get(id)).filter(Boolean);
      return entries.length ? friendPositionOf(entries) : none();
    });
    // Villes encore inconnues : résolues en tâche de fond pour la suite.
    const unknown = out.map((p) => p.city).filter((c) => c && peekCity(c) === undefined);
    if (unknown.length && process.env.NODE_ENV !== 'test') warmCities(unknown);
    return out;
  } catch (e) {
    logger.warn(`[friendPosition587] lecture impossible : ${e?.message || e}`);
    return lists.map(none);
  }
}

module.exports = { friendPositionOf, friendPositionsFor, freshGpsOf, FRIEND_GPS_MAX_MS };
