/**
 * v585 (25/09/2026) — OÙ POSER UNE PERSONNE SUR LA CARTE ? (une seule règle)
 *
 * Daniel (build 584, Samsung) : « john C est vers Valence alors qu'il est vers
 * Murcie » puis « une personne hors ligne, tu la mets LÀ OÙ ELLE S'EST
 * INSCRITE ». Deux causes :
 *   1. la couche monde dédoublonnait « une personne = un point » en gardant le
 *      PREMIER rôle lu (toujours le propriétaire), avec sa position à lui ;
 *   2. le partage en direct (sockets, /provider-location) ÉCRASE
 *      `location.coordinates` du profil : une fois le partage terminé, la
 *      personne restait là où elle avait partagé pour la dernière fois.
 *
 * Règle (dans cet ordre) :
 *   · partage en direct ACTIF et récent (< 10 min) → cette position ;
 *   · sinon la position de PROFIL (inscription / « Modifier le profil ») :
 *     `homeLocation` (posé automatiquement par `homeLocationPlugin` à chaque
 *     écriture de position qui ne vient pas d'un partage), ou, pour les
 *     comptes antérieurs, un `location` jamais touché par un partage
 *     (`location.updatedAt` vide) — le plus récent des profils ;
 *   · sinon le CENTRE DE LA VILLE du profil (résolu par l'appelant) ;
 *   · sinon, en dernier recours, la dernière position connue.
 *
 * Fonctions PURES (testées sans base), sauf le plugin Mongoose.
 */

const LIVE_MAX_MS = 10 * 60 * 1000; // même fenêtre que liveState (« signal perdu »)

function validLngLat(c) {
  if (!Array.isArray(c) || c.length < 2) return false;
  const lng = Number(c[0]);
  const lat = Number(c[1]);
  return Number.isFinite(lat) && Number.isFinite(lng)
    && Math.abs(lat) <= 90 && Math.abs(lng) <= 180 && !(lat === 0 && lng === 0);
}

const _t = (d) => {
  const n = d ? new Date(d).getTime() : NaN;
  return Number.isFinite(n) ? n : 0;
};

/** Partage en direct actif et récent ? */
function isLiveNow(doc, now = new Date()) {
  const loc = doc && doc.location;
  if (!loc || loc.liveShareActive !== true || !validLngLat(loc.coordinates)) return false;
  const at = _t(loc.updatedAt);
  return at > 0 && _t(now) - at <= LIVE_MAX_MS;
}

/** Position de PROFIL d'un document (ou null). */
function homeOf(doc) {
  if (!doc) return null;
  const h = doc.homeLocation;
  if (h && validLngLat(h.coordinates)) {
    return {
      coordinates: [Number(h.coordinates[0]), Number(h.coordinates[1])],
      city: h.city || (doc.location && doc.location.city) || doc.city || '',
      at: _t(h.at) || _t(doc.updatedAt),
    };
  }
  const loc = doc.location;
  // Comptes antérieurs à v585 : un `location` sans `updatedAt` n'a jamais été
  // écrit par un partage — c'est celui du formulaire.
  if (loc && validLngLat(loc.coordinates) && !loc.updatedAt) {
    return {
      coordinates: [Number(loc.coordinates[0]), Number(loc.coordinates[1])],
      city: loc.city || doc.city || '',
      at: _t(doc.updatedAt) || _t(doc.createdAt),
    };
  }
  return null;
}

function cityOf(doc) {
  if (!doc) return '';
  const h = doc.homeLocation && doc.homeLocation.city;
  return String(h || doc.city || (doc.location && doc.location.city) || '').trim();
}

/**
 * @param {Array<{d: object, role: string}>} entries tous les profils d'UNE personne
 * @param {object} opts { now, cityAnchor: (city) => {lat,lng}|null }
 * @returns {{entry, coordinates:[lng,lat], source:'live'|'home'|'city'|'last', city}|null}
 */
function pickPersonPosition(entries, { now = new Date(), cityAnchor = null } = {}) {
  const list = (entries || []).filter((e) => e && e.d);
  if (!list.length) return null;

  const live = list.filter((e) => isLiveNow(e.d, now))
    .sort((a, b) => _t(b.d.location.updatedAt) - _t(a.d.location.updatedAt));
  if (live.length) {
    const e = live[0];
    return { entry: e, coordinates: e.d.location.coordinates.map(Number), source: 'live', city: cityOf(e.d) };
  }

  const homes = list.map((e) => ({ e, h: homeOf(e.d) })).filter((x) => x.h)
    .sort((a, b) => b.h.at - a.h.at);
  if (homes.length) {
    return { entry: homes[0].e, coordinates: homes[0].h.coordinates, source: 'home', city: homes[0].h.city };
  }

  // Aucune position de profil : le centre de la ville du profil le plus récent.
  const byRecent = [...list].sort((a, b) => _t(b.d.updatedAt) - _t(a.d.updatedAt));
  if (typeof cityAnchor === 'function') {
    for (const e of byRecent) {
      const city = cityOf(e.d);
      if (!city) continue;
      const a = cityAnchor(city);
      if (a && Number.isFinite(a.lat) && Number.isFinite(a.lng)) {
        return { entry: e, coordinates: [a.lng, a.lat], source: 'city', city };
      }
    }
  }

  const last = list.filter((e) => e.d.location && validLngLat(e.d.location.coordinates))
    .sort((a, b) => _t(b.d.location.updatedAt) - _t(a.d.location.updatedAt));
  if (last.length) {
    return { entry: last[0], coordinates: last[0].d.location.coordinates.map(Number), source: 'last', city: cityOf(last[0].d) };
  }
  return null;
}

/** Clé « personne » : e-mail (insensible à la casse), sinon l'id. */
function personKeyOf(doc) {
  const email = String((doc && doc.email) || '').trim().toLowerCase();
  return email || String(doc && (doc._id || doc.id));
}

/** Regroupe [{d, role}] par personne, en gardant l'ordre de première apparition. */
function groupByPerson(tagged) {
  const map = new Map();
  for (const t of tagged || []) {
    if (!t || !t.d) continue;
    const k = personKeyOf(t.d);
    if (!map.has(k)) map.set(k, []);
    const arr = map.get(k);
    if (!arr.some((x) => String(x.d._id) === String(t.d._id))) arr.push(t);
  }
  return map;
}

/**
 * Bloc `location` à AFFICHER pour un document seul (listes /sitters/nearby,
 * /walkers/nearby, fiches publiques) : le direct s'il est actif, sinon la
 * position de profil, sinon le `location` tel quel.
 */
function displayLocationOf(doc, now = new Date()) {
  if (!doc || !doc.location) return doc ? doc.location || null : null;
  if (isLiveNow(doc, now)) return doc.location;
  const h = homeOf(doc);
  if (h) return { ...doc.location, coordinates: h.coordinates };
  return doc.location;
}

/**
 * Mongoose : mémorise la position de PROFIL (`homeLocation`) à chaque écriture
 * de `location.coordinates` qui ne vient PAS d'un partage en direct. Les
 * écrivains « direct / GPS » posent toujours `location.updatedAt` en même
 * temps ; le formulaire (inscription, Modifier le profil, synchronisation des
 * 3 profils) ne le pose jamais. Aucun appelant à modifier.
 */
function homeLocationPlugin(schema) {
  const mongoose = require('mongoose');
  // `select: false` : la position de profil EXACTE ne sort jamais dans une
  // réponse par accident (fiches publiques, listes) ; seuls les appelants qui
  // la demandent (`+homeLocation`) la lisent, et ils la floutent.
  schema.add({
    homeLocation: {
      type: new mongoose.Schema({
        coordinates: { type: [Number], default: undefined },
        city: { type: String, default: '' },
        at: { type: Date, default: null },
      }, { _id: false }),
      select: false,
      default: undefined,
    },
  });

  schema.pre('save', function homeOnSave(next) {
    try {
      const loc = this.location;
      if (loc && validLngLat(loc.coordinates)
        && this.isModified('location.coordinates')
        && (!loc.updatedAt || !this.isModified('location.updatedAt'))) {
        this.homeLocation = {
          coordinates: [Number(loc.coordinates[0]), Number(loc.coordinates[1])],
          city: loc.city || this.city || '',
          at: new Date(),
        };
      }
    } catch (_) { /* jamais bloquant */ }
    next();
  });

  const onUpdate = function homeOnUpdate(next) {
    try {
      const u = this.getUpdate() || {};
      const hasOps = Object.keys(u).some((k) => k.startsWith('$'));
      const set = hasOps ? (u.$set || {}) : u;
      let coords = set['location.coordinates'];
      let city = set['location.city'];
      let updAt = Object.prototype.hasOwnProperty.call(set, 'location.updatedAt');
      if (!coords && set.location && typeof set.location === 'object') {
        coords = set.location.coordinates;
        city = city || set.location.city;
        updAt = updAt || !!set.location.updatedAt;
      }
      if (validLngLat(coords) && !updAt && !set.homeLocation) {
        const home = {
          coordinates: [Number(coords[0]), Number(coords[1])],
          city: city || set.city || '',
          at: new Date(),
        };
        if (hasOps) {
          u.$set = { ...(u.$set || {}), homeLocation: home };
        } else {
          u.homeLocation = home;
        }
        this.setUpdate(u);
      }
    } catch (_) { /* jamais bloquant */ }
    next();
  };
  schema.pre('updateOne', onUpdate);
  schema.pre('findOneAndUpdate', onUpdate);
  schema.pre('updateMany', onUpdate);
}

/**
 * v585 (bug 11, Daniel : « j'active PawBoost, mon rond garde la couleur du
 * rôle ») — PawBoost est enregistré sur le SEUL profil qui l'a acheté ; il
 * vaut pour la PERSONNE (ses 3 profils). Renvoie le boost le plus lointain
 * de ces documents, ou null.
 */
function personBoost(docs, now = new Date()) {
  let best = null;
  for (const d of docs || []) {
    if (!d || !d.boostExpiry) continue;
    const t = new Date(d.boostExpiry).getTime();
    if (!Number.isFinite(t) || t <= _t(now)) continue;
    if (!best || t > best.t) best = { t, boostExpiry: new Date(t), boostTier: d.boostTier || null };
  }
  return best ? { boostExpiry: best.boostExpiry, boostTier: best.boostTier } : null;
}

module.exports = {
  personBoost,
  LIVE_MAX_MS,
  validLngLat,
  isLiveNow,
  homeOf,
  cityOf,
  pickPersonPosition,
  personKeyOf,
  groupByPerson,
  displayLocationOf,
  homeLocationPlugin,
};
