/**
 * 16/10/2026 (ADA, demande de Daniel) — DISTANCE ENTRE UN CANDIDAT ET LA DEMANDE.
 *
 * Mesuré en production sur la demande de New York du 04/10 : 3 candidatures,
 * venues de New York (8 km), Hartford (≈ 180 km) et Busan, Corée (≈ 11 000 km).
 * Cause : l'accueil gardien montre « Les plus proches de toi » sans aucune
 * limite de distance quand rien n'est dans le rayon (sitter_homescreen.dart,
 * section `home571_nearest`), et le feed serveur laisse passer toute annonce
 * sans coordonnées (plafond 500 km « fail-open »). Une candidature impossible à
 * honorer fait perdre le propriétaire : le serveur la refuse désormais.
 *
 *   · limite = APPLY_MAX_KM (env), défaut 200 km (décision de Daniel, 16/10) :
 *     plus large que le rayon d'alerte (100 km), donc on ne refuse jamais
 *     quelqu'un qu'on a prévenu. APPLY_MAX_KM=0 coupe le refus sans redéploiement.
 *   · position de la demande : location.lat/lng de l'annonce, sinon le centre
 *     de sa ville (géocodé, mémorisé). Position du candidat : ses coordonnées
 *     de profil. Si l'une des deux manque, on laisse passer (vieux comptes).
 *   · message dans la langue du candidat (9 langues de l'API), code TOO_FAR.
 */
const { haversineKm } = require('./searchRadius');

// Décision de Daniel du 16/10/2026 (chat) : 200 km. Hartford (≈ 190 km de New
// York) passe, Busan (≈ 11 000 km) est refusée. Modifiable sans redéploiement
// par APPLY_MAX_KM ; 0 coupe le refus.
const DEFAULT_MAX_KM = 200;

const LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

const MESSAGES = {
  fr: 'Cette demande est à {km} km de toi : les candidatures sont réservées aux prestataires à moins de {max} km.',
  en: 'This request is {km} km away from you: applications are limited to providers within {max} km.',
  es: 'Esta solicitud está a {km} km de ti: las candidaturas se reservan a cuidadores a menos de {max} km.',
  de: 'Diese Anfrage ist {km} km von dir entfernt: Bewerbungen sind Anbietern im Umkreis von {max} km vorbehalten.',
  it: 'Questa richiesta è a {km} km da te: le candidature sono riservate ai prestatori entro {max} km.',
  pt: 'Este pedido está a {km} km de ti: as candidaturas são reservadas a prestadores a menos de {max} km.',
  ko: '이 요청은 회원님과 {km} km 떨어져 있습니다. 지원은 {max} km 이내의 제공자만 할 수 있습니다.',
  ja: 'この依頼はあなたから {km} km 離れています。応募は {max} km 以内のプロバイダーに限られます。',
  pl: 'To zgłoszenie jest {km} km od Ciebie: zgłaszać się mogą tylko opiekunowie w promieniu {max} km.',
};

const maxKm = () => {
  const raw = process.env.APPLY_MAX_KM;
  if (raw === undefined || raw === null || String(raw).trim() === '') return DEFAULT_MAX_KM;
  const n = Number(raw);
  return Number.isFinite(n) && n >= 0 ? n : DEFAULT_MAX_KM;
};

const num = (v) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};
const validPair = (lat, lng) => lat !== null && lng !== null && !(lat === 0 && lng === 0)
  && Math.abs(lat) <= 90 && Math.abs(lng) <= 180;

/** Position d'une annonce : lat/lng, latitude/longitude ou coordinates [lng, lat]. */
function postCenter(post) {
  const loc = post && post.location;
  if (!loc || typeof loc !== 'object') return null;
  let lat = num(loc.lat !== undefined ? loc.lat : loc.latitude);
  let lng = num(loc.lng !== undefined ? loc.lng : loc.longitude);
  if (!validPair(lat, lng) && Array.isArray(loc.coordinates) && loc.coordinates.length >= 2) {
    lng = num(loc.coordinates[0]); lat = num(loc.coordinates[1]);
  }
  return validPair(lat, lng) ? { lat, lng } : null;
}

/** Position d'un profil (Owner/Sitter/Walker) : location.coordinates [lng, lat]. */
function profileCoords(doc) {
  const loc = doc && doc.location;
  if (!loc) return null;
  const c = loc.coordinates;
  if (Array.isArray(c) && c.length >= 2) {
    const lng = num(c[0]); const lat = num(c[1]);
    if (validPair(lat, lng)) return { lat, lng };
  }
  const lat = num(loc.lat); const lng = num(loc.lng);
  return validPair(lat, lng) ? { lat, lng } : null;
}

const postCityOf = (post) => {
  const loc = post && post.location;
  return String((loc && (loc.city || loc.label)) || '').trim();
};

/** Langue (2 lettres) d'un profil, parmi les 9 de l'API ; anglais sinon. */
function localeOf(doc) {
  const raw = String((doc && (doc.appLocale || doc.language)) || '').trim().toLowerCase().slice(0, 2);
  return LANGS.includes(raw) ? raw : 'en';
}

function tooFarMessage(lang, km, limitKm) {
  const tpl = MESSAGES[LANGS.includes(lang) ? lang : 'en'];
  const shown = km >= 100 ? Math.round(km).toLocaleString('en-US') : String(Math.round(km * 10) / 10);
  return tpl.replace('{km}', shown).replace('{max}', String(Math.round(limitKm)));
}

/**
 * Distance candidat ↔ demande. Ne modifie rien.
 * @returns {{ok:boolean, km:number|null, limitKm:number, reason:string}}
 *   reason : 'within' | 'too_far' | 'disabled' | 'no_post_position' | 'no_provider_position'
 */
async function checkApplicantDistance({ post, provider, geocode } = {}) {
  const limitKm = maxKm();
  if (limitKm <= 0) return { ok: true, km: null, limitKm, reason: 'disabled' };
  const here = profileCoords(provider);
  if (!here) return { ok: true, km: null, limitKm, reason: 'no_provider_position' };
  let center = postCenter(post);
  if (!center) {
    const city = postCityOf(post);
    if (city) {
      try {
        const geo = typeof geocode === 'function' ? geocode : require('./geocodeCity').geocodeCity;
        const g = await geo(city);
        if (g && Number.isFinite(Number(g.lat)) && Number.isFinite(Number(g.lng))) center = { lat: Number(g.lat), lng: Number(g.lng) };
      } catch (_) { center = null; }
    }
  }
  if (!center) return { ok: true, km: null, limitKm, reason: 'no_post_position' };
  const km = Math.round(haversineKm(center.lat, center.lng, here.lat, here.lng) * 10) / 10;
  return { ok: km <= limitKm, km, limitKm, reason: km <= limitKm ? 'within' : 'too_far' };
}

/** Distance (km, 1 décimale) entre une annonce et un profil, ou null. Sans géocodage. */
function distanceKm(post, doc) {
  const a = postCenter(post); const b = profileCoords(doc);
  if (!a || !b) return null;
  return Math.round(haversineKm(a.lat, a.lng, b.lat, b.lng) * 10) / 10;
}

module.exports = {
  DEFAULT_MAX_KM, LANGS, MESSAGES, maxKm, postCenter, profileCoords, localeOf, tooFarMessage, checkApplicantDistance, distanceKm,
};
