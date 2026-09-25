/**
 * v584 (lot C du chantier du 24/09) — RÈGLES DE VISIBILITÉ DE LA CARTE.
 *
 * Une seule source pour toutes les réponses qui posent des personnes sur une
 * carte ou une liste publique (/friends/members/nearby, /friends/members/world,
 * /sitters/nearby, /walkers/nearby, /posts/requests/nearby) :
 *
 *   1. « visible par mes amis seulement » (`preferences.hideFromMap`, réglage
 *      du profil, synchronisé sur les 3 rôles) : la personne n'apparaît QUE
 *      pour ses amis acceptés (et pour elle-même) — y compris à travers un
 *      cache partagé, qui ne doit donc jamais la contenir ;
 *   2. position : EXACTE pour un ami et pour soi-même ; FLOUTÉE à ~1 km (grille
 *      en kilomètres + décalage stable, `coarseLocation.js`) pour tout autre
 *      lecteur, connecté ou non ;
 *   3. comptes de test (`+test` dans l'e-mail), staff et comptes masqués par
 *      la modération (`hiddenFromPublic`) ne sortent jamais dans une réponse
 *      publique.
 *
 * Plus les petits drapeaux que la PawMap affiche sur une épingle :
 * `isBoosted` (PawBoost = lueur turquoise), `kycVerified` (identité vérifiée),
 * `availableToday` (idée 4 : filtre « Disponible aujourd'hui »).
 *
 * Fonctions PURES (sauf `friendIdsOf`, qui lit les amitiés) : testées sans base.
 */
const logger = require('./logger');
const { coarsenLocation } = require('./coarseLocation');

const WEEKDAYS = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

/** Compte de test, staff ou masqué par la modération → jamais en public. */
function isTestOrStaff(doc) {
  if (!doc) return true;
  const email = String(doc.email || '').toLowerCase();
  if (/\+test/.test(email)) return true;
  if (email === 'probe-565@invalid.example') return true;
  if (doc.isStaff === true) return true;
  if (doc.hiddenFromPublic === true) return true;
  return false;
}

/**
 * Le lecteur peut-il voir cette personne sur la carte ?
 * @param {object} doc         document Owner/Sitter/Walker (lean)
 * @param {object} viewer      { viewerIds: Set<string>, friendIds: Set<string> }
 */
function visibleToViewer(doc, { viewerIds, friendIds } = {}) {
  if (!doc) return false;
  const id = String(doc._id || doc.id || '');
  if (viewerIds && viewerIds.has(id)) return true;
  if (doc.preferences && doc.preferences.hideFromMap === true) {
    return !!(friendIds && friendIds.has(id));
  }
  return true;
}

/** Position à renvoyer : exacte pour un ami / soi-même, floutée sinon. */
function publicLocationFor(doc, { viewerIds, friendIds } = {}) {
  if (!doc) return null;
  const id = String(doc._id || doc.id || '');
  const exact = !!((viewerIds && viewerIds.has(id)) || (friendIds && friendIds.has(id)));
  // v585 — hors partage en direct actif, la position de PROFIL (inscription /
  // Modifier le profil), jamais la dernière position de partage.
  const { displayLocationOf } = require('./personMapPosition');
  return coarsenLocation(displayLocationOf(doc) || null, id, exact);
}

function isBoosted(doc, now = new Date()) {
  return !!(doc && doc.boostExpiry && new Date(doc.boostExpiry) > now);
}

function isKycVerified(doc) {
  if (!doc) return false;
  return doc.kycStatus === 'verified'
    || !!(doc.identityVerification && doc.identityVerification.status === 'verified');
}

/**
 * Disponible aujourd'hui ? Vrai si :
 *   · le calendrier `availableDates` contient aujourd'hui (jour UTC), ou
 *   · un créneau hebdo `availableTimeSlots` / un jour `availableDays` tombe
 *     sur le jour de la semaine courant,
 * et que `unavailableDates` ne contient pas aujourd'hui. Un profil sans
 * aucune information de disponibilité n'est PAS « disponible aujourd'hui »
 * (on ne promet rien qu'on ne sait pas).
 */
function isAvailableToday(doc, now = new Date()) {
  if (!doc) return false;
  const dayKey = now.toISOString().slice(0, 10);
  const sameDay = (d) => {
    try { return new Date(d).toISOString().slice(0, 10) === dayKey; } catch (_) { return false; }
  };
  if (Array.isArray(doc.unavailableDates) && doc.unavailableDates.some(sameDay)) return false;
  if (Array.isArray(doc.availableDates) && doc.availableDates.some(sameDay)) return true;
  const weekday = WEEKDAYS[now.getUTCDay()];
  if (Array.isArray(doc.availableTimeSlots)
    && doc.availableTimeSlots.some((s) => s && String(s.day).toLowerCase() === weekday)) {
    return true;
  }
  if (Array.isArray(doc.availableDays)
    && doc.availableDays.some((d) => String(d).toLowerCase() === weekday)) {
    return true;
  }
  return false;
}

/** Drapeaux d'épingle pour la PawMap. */
function pinFlags(doc, now = new Date()) {
  return {
    isBoosted: isBoosted(doc, now),
    kycVerified: isKycVerified(doc),
    availableToday: isAvailableToday(doc, now),
  };
}

/**
 * Applique les trois règles à une liste de documents PUBLICS (nearby des
 * gardiens / promeneurs). Renvoie une nouvelle liste : filtrée (test / staff /
 * amis seulement), avec `location` floutée pour les non-amis. Les autres
 * champs ne sont pas touchés (le contrôleur sérialise ensuite).
 */
function applyPublicPrivacy(docs, { viewerIds, friendIds } = {}) {
  const out = [];
  for (const d of docs || []) {
    if (isTestOrStaff(d)) continue;
    if (!visibleToViewer(d, { viewerIds, friendIds })) continue;
    // v585 — `homeLocation` (position de profil exacte) ne sort jamais :
    // les agrégations ($geoNear) ignorent le `select: false` du schéma.
    const { homeLocation, ...rest } = d;
    out.push({ ...rest, location: publicLocationFor(d, { viewerIds, friendIds }) });
  }
  return out;
}

/**
 * Ids (tous rôles confondus) des amis ACCEPTÉS d'une personne — utilisé par
 * la carte pour « un membre masqué reste visible de ses amis ». Ne lève
 * jamais : en cas d'échec, aucun ami (le masqué reste masqué : sûr).
 */
async function friendIdsOf(userId) {
  try {
    const Friendship = require('../models/Friendship');
    const { personIds, personIndex } = require('./personScope');
    const mine = await personIds(userId);
    const mineSet = new Set(mine.map(String));
    const rows = await Friendship.find({
      status: 'accepted',
      $or: [
        { requesterId: { $in: mine } },
        { addresseeId: { $in: mine } },
      ],
    })
      .select('requesterId addresseeId')
      .lean();
    const others = [];
    for (const r of rows) {
      const a = String(r.requesterId);
      const b = String(r.addresseeId);
      const other = mineSet.has(a) ? b : a;
      if (!mineSet.has(other)) others.push(other);
    }
    if (!others.length) return new Set();
    const idx = await personIndex(others);
    const set = new Set();
    for (const id of others) {
      const e = idx.get(id);
      if (e) e.ids.forEach((x) => set.add(x));
      else set.add(id);
    }
    return set;
  } catch (e) {
    logger.warn(`[mapVisibility] friendIds lookup failed : ${e?.message || e}`);
    return new Set();
  }
}

module.exports = {
  isTestOrStaff,
  visibleToViewer,
  publicLocationFor,
  isBoosted,
  isKycVerified,
  isAvailableToday,
  pinFlags,
  applyPublicPrivacy,
  friendIdsOf,
  PUBLIC_PRIVACY_SELECT: 'email isStaff hiddenFromPublic preferences.hideFromMap',
};
