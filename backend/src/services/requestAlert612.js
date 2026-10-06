/**
 * 612 (ZOE, 05/10/2026) — ALERTE DES ANNONCES À 100 KM.
 *
 * Ordre de Daniel (05/10 au soir) : « quand quelqu'un poste une annonce, que tous
 * les gens à un rayon de 100 km du post reçoivent l'annonce par mail,
 * notification tel, etc., qu'on loupe plus d'annonce ».
 *
 * CE QUE FAISAIT LE SERVEUR AVANT (lu dans postController.notifyNearbyProviders) :
 *   · rôle : promeneurs si l'annonce contient « dog_walking », sinon gardiens ;
 *   · zone : même NOM de ville (100 profils au plus) OU dans le rayon de
 *     couverture DU PRESTATAIRE (10 km au moins, 20 km par défaut gardien, 3 km
 *     par défaut promeneur ramenés à 10, plafond 100) — jamais « 100 km » ;
 *   · canaux : cloche + notification du téléphone + un e-mail générique (sans
 *     service ni dates, sans lien de désabonnement) ;
 *   · jamais l'auteur ; mais comptes de test, staff, suspendus et bloqués
 *     n'étaient PAS écartés ; aucun registre : une relance ou une annonce
 *     republiée reprévenait tout le monde.
 *
 * MAINTENANT :
 *   · qui : le rôle qui correspond au service (gardien pour une garde, promeneur
 *     pour une balade ; une annonce qui demande les deux prévient les deux) ; une
 *     personne qui a les deux profils est prévenue UNE fois ;
 *   · où : à 100 km au plus de l'annonce, distance réelle entre coordonnées.
 *     REPLI quand le profil n'a pas de coordonnées : le centre de SA ville
 *     (géocodé, mémorisé) ; si sa ville est introuvable, même nom de ville que
 *     l'annonce ; s'il n'a ni coordonnées ni ville, il n'est pas prévenu ;
 *   · jamais : l'auteur (ses 3 profils), les comptes de test, le staff, les
 *     comptes suspendus ou bannis, les personnes bloquées (dans un sens ou
 *     l'autre). Un compte supprimé n'existe plus en base ;
 *   · canaux : cloche + notification du téléphone + e-mail dans la langue du
 *     destinataire. E-mail coupé pour qui s'est désabonné (`marketingOptOut`) ;
 *     catégorie « Réservations » coupée dans l'app → ni téléphone ni e-mail ;
 *   · UN envoi par annonce et par personne : registre RequestAlert612.
 *   · annonce d'un compte de test : seuls des comptes de test sont prévenus
 *     (essais sans déranger personne).
 */
const crypto = require('crypto');
const logger = require('../utils/logger');
const { decrypt } = require('../utils/encryption');
const { haversineKm, withinRadiusKm } = require('../utils/searchRadius');
const { isWalkingService } = require('../utils/requestAlertText612');
const { TEST_EMAIL_RE } = require('../utils/testAccount2809');

const ALERT_RADIUS_KM = 100;
const MAX_RECIPIENTS = 500;
const MAX_CITIES_GEOCODED = 40;
const SAME_REQUEST_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;
const HARD_STAFF_EMAILS = ['dadaciao84@gmail.com', 'hopetsit@gmail.com'];
// Adresse de sonde technique (« Probe <probe-565@invalid.example> ») : jamais prévenue.
const NOT_A_PERSON_RE = /@invalid\.example$/i;

const sha = (v) => crypto.createHash('sha256').update(String(v)).digest('hex').slice(0, 40);
const plainEmail = (stored) => {
  let e = stored;
  try { e = decrypt(stored); } catch (_) { /* illisible */ }
  return typeof e === 'string' ? e.trim().toLowerCase() : '';
};
const staffEmails = () => new Set([
  ...HARD_STAFF_EMAILS,
  ...String(process.env.STAFF_EMAILS || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean),
]);
const personKeyOf = (doc) => {
  const e = plainEmail(doc && doc.email);
  return e ? `e:${sha(e)}` : `i:${String(doc && doc._id)}`;
};
const coordsOf = (doc) => {
  const c = doc && doc.location && doc.location.coordinates;
  if (!Array.isArray(c) || c.length < 2) return null;
  const lng = Number(c[0]); const lat = Number(c[1]);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || (lat === 0 && lng === 0)) return null;
  return { lat, lng };
};
const cityOf = (doc) => String(
  (doc && doc.city) || (doc && doc.location && doc.location.city) || (doc && doc.coverageCity) || '',
).trim();
const foldCity = (name) => {
  let base = String(name || '');
  try { base = require('../utils/geocodeCity').baseCityName(base) || base; } catch (_) { /* nom brut */ }
  return base.split(/[(,/]/)[0].normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
};

/** Rôles à prévenir pour ces services : balade → promeneurs, le reste → gardiens. */
const rolesForServices = (services) => {
  const list = (Array.isArray(services) ? services : [services]).map((s) => String(s || '').trim()).filter(Boolean);
  const roles = [];
  if (list.some((s) => isWalkingService(s))) roles.push('walker');
  if (!list.length || list.some((s) => !isWalkingService(s))) roles.push('sitter');
  // Le rôle du PREMIER service passe en tête (profil choisi quand une personne a les deux).
  if (list.length && !isWalkingService(list[0]) && roles[0] !== 'sitter') roles.reverse();
  return roles;
};

/** Empreinte « la même demande » : même propriétaire, services, ville, jours. */
const alertKeyOf = ({ ownerKey, services, city, startDate, endDate }) => {
  const day = (v) => {
    if (!v) return '';
    const d = v instanceof Date ? v : new Date(v);
    return Number.isNaN(d.getTime()) ? '' : d.toISOString().slice(0, 10);
  };
  const sv = (Array.isArray(services) ? services : []).map((s) => String(s || '').trim().toLowerCase()).filter(Boolean).sort();
  return sha([ownerKey, sv.join('+'), foldCity(city), day(startDate), day(endDate)].join('|'));
};

const SELECT = '_id oldId email status isStaff marketingOptOut city coverageCity location';
const modelOf = (role) => (role === 'walker' ? require('../models/Walker') : require('../models/Sitter'));

/**
 * Choisit les destinataires. Ne modifie rien, n'envoie rien.
 *
 * @param {Object} a
 * @param {{lat:number,lng:number}|null} a.center  position de l'annonce (réelle ou ville géocodée)
 * @param {string} a.city            ville de l'annonce (nom canonique si possible)
 * @param {string[]} a.services      services demandés
 * @param {Set<string>} a.selfIds    ids des profils de l'auteur
 * @param {boolean} a.ownerIsTest    annonce d'un compte de test
 * @param {(city:string)=>Promise<{lat,lng}|null>} [a.geocode]
 */
const selectRecipients = async ({ center, city, services, selfIds, ownerIsTest = false, geocode = null, radiusKm = ALERT_RADIUS_KM }) => {
  const roles = rolesForServices(services);
  const excluded = { self: 0, test: 0, notTest: 0, staff: 0, inactive: 0, blocked: 0, tooFar: 0, noPosition: 0, samePerson: 0 };
  const hasCenter = !!(center && Number.isFinite(center.lat) && Number.isFinite(center.lng));
  const postCity = foldCity(city);
  const staff = staffEmails();
  const self = selfIds instanceof Set ? selfIds : new Set();
  const geo = typeof geocode === 'function' ? geocode : async () => null;

  // 1) Candidats bruts par rôle : ceux qui ont des coordonnées dans le cercle,
  //    et ceux qui n'en ont pas (repli par la ville).
  const raw = []; // { doc, role, km, via }
  for (const role of roles) {
    const Model = modelOf(role);
    const seen = new Set();
    if (hasCenter) {
      let near = [];
      try {
        near = await Model.find({
          location: { $geoWithin: { $centerSphere: [[center.lng, center.lat], (radiusKm + 2) / 6371] } },
        }).select(SELECT).limit(5000).lean();
      } catch (e) {
        logger.warn(`[alert612] requête géo ${role} : ${e && e.message ? e.message : e}`);
      }
      for (const d of near) {
        const c = coordsOf(d);
        if (!c) continue;
        seen.add(String(d._id));
        const km = haversineKm(center.lat, center.lng, c.lat, c.lng);
        if (withinRadiusKm(km, radiusKm)) raw.push({ doc: d, role, km, via: 'coords' });
        else excluded.tooFar += 1;
      }
    }
    // Profils SANS coordonnées (ou sans centre d'annonce : tous, par le nom de ville).
    let others = [];
    try {
      const q = hasCenter
        ? { $or: [{ 'location.coordinates': { $exists: false } }, { 'location.coordinates': { $size: 0 } }, { 'location.coordinates': [0, 0] }, { location: null }] }
        : {};
      others = await Model.find(q).select(SELECT).limit(5000).lean();
    } catch (e) {
      logger.warn(`[alert612] requête ville ${role} : ${e && e.message ? e.message : e}`);
    }
    const cityCenters = new Map(); // ville pliée → {lat,lng}|null
    for (const d of others) {
      if (seen.has(String(d._id))) continue;
      if (hasCenter && coordsOf(d)) { continue; } // a des coordonnées, hors cercle : déjà compté ou trop loin
      const own = coordsOf(d);
      if (!hasCenter && own) {
        // Annonce sans position : seul le nom de ville peut rapprocher.
        if (postCity && foldCity(cityOf(d)) === postCity) raw.push({ doc: d, role, km: null, via: 'city_name' });
        else excluded.noPosition += 1;
        continue;
      }
      const name = cityOf(d);
      if (!name) { excluded.noPosition += 1; continue; }
      const folded = foldCity(name);
      if (hasCenter) {
        if (!cityCenters.has(folded)) {
          if (cityCenters.size >= MAX_CITIES_GEOCODED) cityCenters.set(folded, null);
          else {
            let g = null;
            try { g = await geo(name); } catch (_) { g = null; }
            cityCenters.set(folded, g && Number.isFinite(g.lat) && Number.isFinite(g.lng) ? g : null);
          }
        }
        const g = cityCenters.get(folded);
        if (g) {
          const km = haversineKm(center.lat, center.lng, g.lat, g.lng);
          if (withinRadiusKm(km, radiusKm)) raw.push({ doc: d, role, km, via: 'city_center' });
          else excluded.tooFar += 1;
          continue;
        }
      }
      if (postCity && folded === postCity) raw.push({ doc: d, role, km: null, via: 'city_name' });
      else excluded.noPosition += 1;
    }
  }

  // 2) Personnes bloquées (dans un sens ou l'autre) avec l'auteur.
  const blockedIds = new Set();
  const blockedEmails = new Set();
  try {
    const Block = require('../models/Block');
    const mine = [...self].filter((v) => /^[a-f0-9]{24}$/i.test(v));
    if (mine.length) {
      const rows = await Block.find({ $or: [{ blockerId: { $in: mine } }, { blockedId: { $in: mine } }] })
        .select('blockerId blockedId').lean();
      for (const r of rows) {
        for (const v of [r.blockerId, r.blockedId]) if (v && !self.has(String(v))) blockedIds.add(String(v));
      }
      if (blockedIds.size) {
        const ids = [...blockedIds];
        const all = await Promise.all(['Owner', 'Sitter', 'Walker'].map((m) => require(`../models/${m}`)
          .find({ _id: { $in: ids } }).select('email').lean()));
        for (const d of all.flat()) { const e = plainEmail(d.email); if (e) blockedEmails.add(e); }
      }
    }
  } catch (e) {
    logger.warn(`[alert612] lecture des blocages : ${e && e.message ? e.message : e}`);
  }

  // 3) Exclusions puis une ligne par PERSONNE (le rôle du premier service d'abord, puis le plus proche).
  const byPerson = new Map();
  for (const c of raw) {
    const d = c.doc;
    const id = String(d._id);
    const email = plainEmail(d.email);
    if (self.has(id) || (d.oldId != null && self.has(String(d.oldId)))) { excluded.self += 1; continue; }
    const isTest = TEST_EMAIL_RE.test(email) || NOT_A_PERSON_RE.test(email);
    if (ownerIsTest && !TEST_EMAIL_RE.test(email)) { excluded.notTest += 1; continue; }
    if (!ownerIsTest && isTest) { excluded.test += 1; continue; }
    if (d.isStaff === true || staff.has(email)) { excluded.staff += 1; continue; }
    if (d.status && d.status !== 'active') { excluded.inactive += 1; continue; }
    if (blockedIds.has(id) || (email && blockedEmails.has(email))) { excluded.blocked += 1; continue; }
    const key = personKeyOf(d);
    const cand = {
      id, role: c.role, personKey: key, km: c.km == null ? null : Math.round(c.km * 10) / 10, via: c.via,
      emailOptOut: d.marketingOptOut === true, _email: d.email,
    };
    const prev = byPerson.get(key);
    if (!prev) { byPerson.set(key, cand); continue; }
    excluded.samePerson += 1;
    const rank = (x) => roles.indexOf(x.role) * 1e6 + (x.km == null ? 9e5 : x.km);
    const keep = rank(cand) < rank(prev) ? cand : prev;
    keep.emailOptOut = prev.emailOptOut || cand.emailOptOut;
    byPerson.set(key, keep);
  }

  // 4) Désabonnement PAR PERSONNE : le lien d'un e-mail pose `marketingOptOut`
  //    sur UN profil (souvent le propriétaire) — on regarde les 3.
  let list = [...byPerson.values()];
  try {
    const emails = [...new Set(list.map((r) => r._email).filter(Boolean))];
    if (emails.length) {
      const all = await Promise.all(['Owner', 'Sitter', 'Walker'].map((m) => require(`../models/${m}`)
        .find({ email: { $in: emails }, marketingOptOut: true }).select('email').lean()));
      const out = new Set(all.flat().map((d) => String(d.email)));
      for (const r of list) if (out.has(String(r._email))) r.emailOptOut = true;
    }
  } catch (e) {
    logger.warn(`[alert612] lecture des désabonnements : ${e && e.message ? e.message : e}`);
  }
  list.sort((a, b) => (a.km == null ? 1e9 : a.km) - (b.km == null ? 1e9 : b.km));
  const truncated = Math.max(0, list.length - MAX_RECIPIENTS);
  if (truncated) {
    logger.warn(`[alert612] ${list.length} destinataires, ${truncated} au-delà du plafond ${MAX_RECIPIENTS} (les plus proches d'abord)`);
    list = list.slice(0, MAX_RECIPIENTS);
  }
  for (const r of list) delete r._email;
  return { roles, radiusKm, hasCenter, recipients: list, excluded, truncated };
};

/** Lien de désabonnement (même jeton que les e-mails du cycle de vie). */
const unsubscribeUrlFor = (role, id) => {
  try {
    const { unsubscribeToken } = require('./lifecycleEmailScheduler');
    const base = process.env.PUBLIC_API_URL || 'https://hopetsit-backend.onrender.com/api/v1';
    return `${base}/lifecycle/unsubscribe?r=${role}&u=${id}&t=${unsubscribeToken(role, id)}`;
  } catch (_) {
    return '';
  }
};

/**
 * Réserve l'envoi dans le registre. `false` = cette personne a déjà reçu cette
 * annonce (ou la même demande republiée depuis moins de 30 jours).
 */
const claim = async ({ postId, alertKey, recipient, type, resend = false }) => {
  const RequestAlert = require('../models/RequestAlert612');
  if (!resend && alertKey) {
    const twin = await RequestAlert.exists({
      alertKey, personKey: recipient.personKey, postId: { $ne: postId },
      createdAt: { $gt: new Date(Date.now() - SAME_REQUEST_WINDOW_MS) },
    });
    if (twin) return { ok: false, why: 'same_request' };
  }
  try {
    const doc = await RequestAlert.create({
      postId, alertKey: alertKey || '', personKey: recipient.personKey,
      recipientId: recipient.id, recipientRole: recipient.role, type,
      km: recipient.km, via: recipient.via,
    });
    return { ok: true, id: doc._id };
  } catch (e) {
    if (e && e.code === 11000) {
      if (!resend) return { ok: false, why: 'already' };
      const doc = await RequestAlert.findOneAndUpdate(
        { postId, personKey: recipient.personKey }, { $set: { resend: true } }, { new: true },
      );
      return { ok: true, id: doc && doc._id, resent: true };
    }
    throw e;
  }
};

const recordChannels = async (id, result) => {
  if (!id) return;
  try {
    const RequestAlert = require('../models/RequestAlert612');
    const r = result || {};
    await RequestAlert.updateOne({ _id: id }, {
      $set: {
        'channels.bell': !!r.bell,
        'channels.push': r.push || 'failed',
        'channels.email': r.email || 'failed',
      },
    });
  } catch (e) {
    logger.warn(`[alert612] registre non mis à jour : ${e && e.message ? e.message : e}`);
  }
};

/** Compte par canal pour une annonce (admin). */
const channelSummary = async (postId) => {
  const RequestAlert = require('../models/RequestAlert612');
  const rows = await RequestAlert.find({ postId }).select('recipientId recipientRole km via channels createdAt').lean();
  const out = { people: rows.length, bell: 0, push: 0, email: 0, emailUnsubscribed: 0, pushNoToken: 0, rows };
  for (const r of rows) {
    const c = r.channels || {};
    if (c.bell) out.bell += 1;
    if (c.push === 'sent') out.push += 1;
    if (c.push === 'no_token') out.pushNoToken += 1;
    if (c.email === 'sent') out.email += 1;
    if (c.email === 'unsubscribed') out.emailUnsubscribed += 1;
  }
  return out;
};

module.exports = {
  ALERT_RADIUS_KM,
  MAX_RECIPIENTS,
  SAME_REQUEST_WINDOW_MS,
  rolesForServices,
  alertKeyOf,
  personKeyOf,
  selectRecipients,
  unsubscribeUrlFor,
  claim,
  recordChannels,
  channelSummary,
  foldCity,
};
