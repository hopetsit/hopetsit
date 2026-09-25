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
const { pickPersonPosition } = require('./personMapPosition');
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
  if (!pos) return empty;
  const [lng, lat] = pos.coordinates.map(Number);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || (lat === 0 && lng === 0)) return empty;
  const idStr = String(pos.entry.d._id);
  const anchor = pos.city ? cityAnchor(pos.city) : null;
  return {
    mapVisibility: vis,
    location: { coordinates: blurTowardAnchor(lat, lng, idStr, anchor) },
    approx: true,
    approxKm: WORLD_APPROX_KM,
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
    const models = {
      Owner: require('../models/Owner'),
      Sitter: require('../models/Sitter'),
      Walker: require('../models/Walker'),
    };
    const sel = 'location +homeLocation city updatedAt createdAt email '
      + 'preferences.hideFromMap preferences.mapVisibility';
    const rows = (await Promise.all(Object.entries(models).map(([name, M]) => M
      .find({ _id: { $in: all } }).select(sel).lean()
      .then((r) => (r || []).map((d) => ({ d, role: ROLE_BY_MODEL[name] })))
      .catch(() => [])))).flat();
    const byId = new Map(rows.map((x) => [String(x.d._id), x]));
    return lists.map((ids) => {
      const entries = ids.map((id) => byId.get(id)).filter(Boolean);
      return entries.length ? friendPositionOf(entries) : none();
    });
  } catch (e) {
    logger.warn(`[friendPosition587] lecture impossible : ${e?.message || e}`);
    return lists.map(none);
  }
}

module.exports = { friendPositionOf, friendPositionsFor };
