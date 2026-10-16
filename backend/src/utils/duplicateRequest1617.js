/**
 * 1617 (LEO, 16/10/2026, ordre de BOB — §D.2 de PROCHAIN_BUILD_617) — DOUBLON
 * DE PUBLICATION REFUSÉ.
 *
 * Cas réel : deux balades identiques publiées à Tallinn le 15/10 par le même
 * propriétaire (même service, mêmes jours, même ville). Chaque gardien recevait
 * l'alerte une fois (registre 612), mais la 2e demande restait dans le feed, la
 * PawMap et « Mes annonces » : deux lignes pour une seule garde.
 *
 * Règle : même propriétaire, mêmes services (triés), même ville (nom replié
 * comme `foldCity` de requestAlert612 : « Paris 11e » = « Paris », accents
 * ignorés), mêmes jours de début et de fin, et une demande EXISTANTE encore
 * ouverte (non masquée, non fermée, non réservée, prestation pas passée)
 * → 409 { error (langue du propriétaire, 9 langues), code: 'DUPLICATE_REQUEST',
 * existingPostId }. Appliqué à createPost ET createPostWithMedia.
 * Une demande dont les dates diffèrent, ou dans une autre ville, passe.
 * DUPLICATE_REQUEST_CHECK=off coupe le contrôle (jamais utilisé en prod).
 */
const Post = require('../models/Post');
const { foldCity, ALERT_RADIUS_KM } = require('../services/requestAlert612');
const { LANGS, localeOf } = require('./applicationDistance1610');

const MESSAGES = {
  fr: 'Tu as déjà publié cette demande (même service, mêmes dates, même ville). Elle est toujours en ligne : les gardiens la voient déjà.',
  en: 'You have already posted this request (same service, same dates, same city). It is still live: sitters can already see it.',
  es: 'Ya has publicado esta solicitud (mismo servicio, mismas fechas, misma ciudad). Sigue en línea: los cuidadores ya la ven.',
  de: 'Du hast diese Anfrage bereits veröffentlicht (gleicher Service, gleiche Daten, gleiche Stadt). Sie ist noch online: die Betreuer sehen sie bereits.',
  it: 'Hai già pubblicato questa richiesta (stesso servizio, stesse date, stessa città). È ancora online: i pet sitter la vedono già.',
  pt: 'Já publicaste este pedido (mesmo serviço, mesmas datas, mesma cidade). Continua online: os cuidadores já o veem.',
  ko: '이미 같은 요청을 올렸어요 (같은 서비스, 같은 날짜, 같은 도시). 아직 게시 중이며 펫시터들이 이미 보고 있어요.',
  ja: 'この依頼はすでに投稿されています（同じサービス・同じ日程・同じ都市）。まだ掲載中で、シッターにはすでに表示されています。',
  pl: 'To ogłoszenie już zostało opublikowane (ta sama usługa, te same daty, to samo miasto). Nadal jest widoczne: opiekunowie już je widzą.',
};

const enabled = () => String(process.env.DUPLICATE_REQUEST_CHECK || '').toLowerCase() !== 'off';

const dayOf = (v) => {
  if (!v) return '';
  const d = v instanceof Date ? v : new Date(v);
  return Number.isNaN(d.getTime()) ? '' : d.toISOString().slice(0, 10);
};
const servicesKey = (services) => (Array.isArray(services) ? services : [])
  .map((s) => String(s || '').trim().toLowerCase()).filter(Boolean).sort().join('+');
const cityOfPost = (p) => String((p && p.location && (p.location.city || p.location.label)) || '').trim();

/** Empreinte d'une demande : services + ville repliée + jours. */
function fingerprint({ services, city, startDate, endDate }) {
  return [servicesKey(services), foldCity(city), dayOf(startDate), dayOf(endDate)].join('|');
}

/** Vrai si la demande existante peut encore recevoir des candidatures (mêmes règles que openRequestFilter). */
function isStillOpen(p, now = new Date()) {
  if (!p || p.hidden === true || p.status === 'closed') return false;
  if (p.reservedBy && p.reservedBy.bookingId) return false;
  const end = p.endDate ? new Date(p.endDate) : null;
  const start = p.startDate ? new Date(p.startDate) : null;
  if (end && !Number.isNaN(end.getTime())) return end >= now;
  if (start && !Number.isNaN(start.getTime())) return start >= now;
  return true;
}

/**
 * Cherche une demande ouverte identique du même propriétaire. Ne modifie rien.
 * @returns {Promise<null|{existingPostId:string}>}
 */
async function findOpenDuplicate({ ownerId, services, city, startDate, endDate, now = new Date() }) {
  if (!enabled() || !ownerId) return null;
  const wanted = fingerprint({ services, city, startDate, endDate });
  const rows = await Post.find({
    ownerId, postType: 'request', hidden: { $ne: true }, status: { $ne: 'closed' },
    'reservedBy.bookingId': { $in: [null] },
  }).select('_id location serviceTypes startDate endDate hidden status reservedBy').sort({ createdAt: -1 }).limit(50).lean();
  for (const p of rows) {
    if (!isStillOpen(p, now)) continue;
    const fp = fingerprint({ services: p.serviceTypes, city: cityOfPost(p), startDate: p.startDate, endDate: p.endDate });
    if (fp === wanted) return { existingPostId: String(p._id) };
  }
  return null;
}

function duplicateMessage(lang) {
  return MESSAGES[LANGS.includes(lang) ? lang : 'en'];
}

/** Corps de la réponse 409. */
function duplicateResponse(owner, existingPostId) {
  return { error: duplicateMessage(localeOf(owner)), code: 'DUPLICATE_REQUEST', existingPostId };
}

module.exports = {
  ALERT_RADIUS_KM, MESSAGES, fingerprint, isStillOpen, findOpenDuplicate, duplicateMessage, duplicateResponse,
};
