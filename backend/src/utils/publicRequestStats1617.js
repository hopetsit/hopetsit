/**
 * 1617 (LEO, 16/10/2026, ordre de BOB — §B.5 de PROCHAIN_BUILD_617) —
 * « N propriétaires cherchent un gardien à Paris cette semaine ».
 *
 * GET /posts/requests/public-stats?city=Paris  (ou ?lat&lng&radius)
 *   → { city, count, bubbles: [{ lat, lng, service, days }] }
 *
 * Ce qui compte : les demandes `postType: 'request'` OUVERTES (mêmes règles que
 * getPublicRequestPosts : non masquées, non fermées, aucune réservation en cours,
 * prestation pas passée), créées dans les 7 derniers jours OU dont la prestation
 * est à venir, de propriétaires RÉELS seulement (ni +test, ni @invalid.example,
 * ni staff), dans la ville repliée (« Paris 11e » compte pour Paris) ou dans le
 * rayon demandé. Positions FLOUTÉES (~1 km, déterministe par id, même floutage
 * que la couche monde), jamais le nom ni l'adresse. 50 bulles au plus.
 * Cache mémoire 5 min par requête (ville ou cercle arrondi). Lecture publique,
 * sans compte : la page Paris et la PawMap publique l'affichent, et seulement si
 * count ≥ 1 (jamais un chiffre inventé : la route rend 0 et le site ne dit rien).
 */
const Post = require('../models/Post');
const { foldCity, ALERT_RADIUS_KM } = require('../services/requestAlert612');
const { blurLngLat } = require('./coarseLocation');
const { haversineKm } = require('./searchRadius');
const { isWalkingService } = require('./requestAlertText612');
const { TEST_EMAIL_RE } = require('./testAccount2809');
const { decrypt } = require('./encryption');

const CACHE_MS = 5 * 60 * 1000;
const MAX_BUBBLES = 50;
const RECENT_DAYS = 7;
const DEFAULT_RADIUS_KM = 25;
const MAX_RADIUS_KM = 100;
const HARD_STAFF_EMAILS = ['dadaciao84@gmail.com', 'hopetsit@gmail.com'];
const NOT_A_PERSON_RE = /@invalid\.example$/i;

const _cache = new Map(); // clé → { t, v }

const plainEmail = (stored) => {
  let e = stored;
  try { e = decrypt(stored); } catch (_) { /* illisible */ }
  return typeof e === 'string' ? e.trim().toLowerCase() : '';
};
const staffEmails = () => new Set([
  ...HARD_STAFF_EMAILS,
  ...String(process.env.STAFF_EMAILS || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean),
]);

/** Propriétaire réel : ni compte de test, ni sonde, ni staff. */
function isRealOwner(owner) {
  if (!owner) return false;
  const email = plainEmail(owner.email);
  if (!email) return false;
  if (TEST_EMAIL_RE.test(email) || NOT_A_PERSON_RE.test(email)) return false;
  if (owner.isStaff === true || staffEmails().has(email)) return false;
  if (owner.status && owner.status !== 'active') return false;
  return true;
}

const coordsOfPost = (p) => {
  const lat = Number(p && p.location && p.location.lat);
  const lng = Number(p && p.location && p.location.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || (lat === 0 && lng === 0)) return null;
  return { lat, lng };
};
const cityOfPost = (p) => String((p && p.location && (p.location.city || p.location.label)) || '').trim();

/** Nombre de jours de prestation (début → fin inclus), null sans date. */
function daysOf(p) {
  const s = p.startDate ? new Date(p.startDate) : null;
  const e = p.endDate ? new Date(p.endDate) : null;
  if (s && !Number.isNaN(s.getTime()) && e && !Number.isNaN(e.getTime())) {
    return Math.max(1, Math.round((e - s) / 86400000) + 1);
  }
  if (s && !Number.isNaN(s.getTime())) return 1;
  return null;
}

/** Filtre Mongo « ouverte » (copie des règles de openRequestFilter) + fenêtre récente / à venir. */
function mongoFilter(now) {
  const since = new Date(now.getTime() - RECENT_DAYS * 86400000);
  return {
    postType: 'request', hidden: { $ne: true }, status: { $ne: 'closed' },
    'reservedBy.bookingId': { $in: [null] },
    $and: [
      { $or: [
        { endDate: { $gte: now } },
        { endDate: { $in: [null] }, startDate: { $gte: now } },
        { endDate: { $in: [null] }, startDate: { $in: [null] } },
      ] },
      { $or: [{ createdAt: { $gte: since } }, { startDate: { $gte: now } }, { endDate: { $gte: now } }] },
    ],
  };
}

/** Calcul sans cache. Ne modifie rien. */
async function computeStats({ city = '', lat = null, lng = null, radiusKm = DEFAULT_RADIUS_KM, now = new Date() }) {
  const wantCity = foldCity(city);
  const hasCircle = Number.isFinite(lat) && Number.isFinite(lng);
  const r = Math.min(MAX_RADIUS_KM, Math.max(1, Number(radiusKm) || DEFAULT_RADIUS_KM));
  const rows = await Post.find(mongoFilter(now))
    .select('_id ownerId location serviceTypes startDate endDate createdAt')
    .sort({ createdAt: -1 }).limit(2000)
    .populate('ownerId', 'email isStaff status')
    .lean();
  const bubbles = [];
  let count = 0;
  let label = String(city || '').trim();
  for (const p of rows) {
    if (!isRealOwner(p.ownerId)) continue;
    const c = coordsOfPost(p);
    let inside = false;
    if (wantCity) inside = foldCity(cityOfPost(p)) === wantCity;
    else if (hasCircle) inside = !!c && haversineKm(lat, lng, c.lat, c.lng) <= r;
    if (!inside) continue;
    count += 1;
    if (!label && cityOfPost(p)) label = cityOfPost(p);
    if (c && bubbles.length < MAX_BUBBLES) {
      const [bLng, bLat] = blurLngLat(c.lat, c.lng, String(p._id));
      const services = Array.isArray(p.serviceTypes) ? p.serviceTypes : [];
      bubbles.push({
        lat: Math.round(bLat * 1e5) / 1e5,
        lng: Math.round(bLng * 1e5) / 1e5,
        service: services.length && services.every((s) => isWalkingService(s)) ? 'walk' : 'sitting',
        days: daysOf(p),
      });
    }
  }
  return { city: label, count, bubbles, radiusKm: ALERT_RADIUS_KM, approxKm: 1 };
}

const cacheKey = ({ city, lat, lng, radiusKm }) => (foldCity(city)
  ? `c:${foldCity(city)}`
  : `g:${Number(lat).toFixed(2)},${Number(lng).toFixed(2)},${Math.round(Number(radiusKm) || DEFAULT_RADIUS_KM)}`);

/** Avec cache 5 min. */
async function getStats(params) {
  const key = cacheKey(params);
  const hit = _cache.get(key);
  if (hit && Date.now() - hit.t < CACHE_MS) return hit.v;
  const v = await computeStats(params);
  _cache.set(key, { t: Date.now(), v });
  if (_cache.size > 500) _cache.clear();
  return v;
}

/** Contrôleur Express. */
async function getPublicRequestStats(req, res) {
  try {
    const q = req.query || {};
    const city = typeof q.city === 'string' ? q.city.trim().slice(0, 80) : '';
    const lat = q.lat != null && q.lat !== '' ? Number(q.lat) : null;
    const lng = q.lng != null && q.lng !== '' ? Number(q.lng) : null;
    const radiusKm = q.radius != null ? Number(q.radius) : (q.radiusKm != null ? Number(q.radiusKm) : DEFAULT_RADIUS_KM);
    if (!city && !(Number.isFinite(lat) && Number.isFinite(lng))) {
      return res.status(400).json({ error: 'city or lat/lng required.' });
    }
    const out = await getStats({ city, lat, lng, radiusKm });
    res.set('Cache-Control', 'public, max-age=300');
    return res.json(out);
  } catch (e) {
    return res.status(500).json({ error: 'Unable to compute request stats.' });
  }
}

function _resetForTest() { _cache.clear(); }

module.exports = {
  CACHE_MS, MAX_BUBBLES, RECENT_DAYS, isRealOwner, daysOf, computeStats, getStats, getPublicRequestStats, _resetForTest,
};
