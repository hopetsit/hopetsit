/**
 * 04/10/2026 (ZOE, mission BOB) — toutes les ÉCRITURES de ville passent par
 * `canonicalCityName` (voir utils/canonicalCity0410.js), quel que soit le
 * chemin : création, `save()`, `updateOne`, `findOneAndUpdate`, `updateMany`.
 *
 * Plugin Mongoose posé sur les modèles qui portent une ville (profils des
 * 3 rôles, demandes, PawSpots, signalements, POI, directs). Champs traités :
 * `city`, `location.city`, `coverageCity`, `address.city` — et ce même champ
 * quand l'objet `location`/`address` entier est remplacé.
 *
 * Il ne fait que REMPLACER un exonyme connu par le nom local (« Parigi » →
 * « Paris ») ; tout autre texte passe intact. Les coordonnées présentes
 * servent de garde-fou (autre lieu du même nom → inchangé). Jamais d'erreur :
 * un souci dans le plugin laisse l'écriture se faire telle quelle.
 */
const { canonicalCityName, coordsOfLocation } = require('./canonicalCity0410');

const OBJ_FIELDS = ['location', 'address'];

function _fixObj(obj, coords) {
  if (!obj || typeof obj !== 'object' || typeof obj.city !== 'string') return false;
  const c = coordsOfLocation(obj) || coords;
  const v = canonicalCityName(obj.city, c);
  if (v !== obj.city) { obj.city = v; return true; }
  return false;
}

/** Corrige un objet « à plat » (doc ou $set) ; renvoie true si modifié. */
function _fixFlat(target, coords) {
  let changed = false;
  for (const k of ['city', 'coverageCity', 'location.city', 'address.city']) {
    if (typeof target[k] === 'string') {
      const v = canonicalCityName(target[k], coords);
      if (v !== target[k]) { target[k] = v; changed = true; }
    }
  }
  for (const f of OBJ_FIELDS) {
    if (target[f] && typeof target[f] === 'object') changed = _fixObj(target[f], coords) || changed;
  }
  return changed;
}

function _coordsFromUpdate(u) {
  if (!u || typeof u !== 'object') return null;
  const set = u.$set || {};
  return coordsOfLocation(set.location) || coordsOfLocation(u.location)
    || coordsOfLocation({ lat: set['location.lat'], lng: set['location.lng'] })
    || coordsOfLocation({ coordinates: set['location.coordinates'] })
    || null;
}

function cityCanonicalPlugin(schema) {
  schema.pre('save', function canonCitySave(next) {
    try {
      const coords = coordsOfLocation(this.location);
      for (const k of ['city', 'coverageCity']) {
        const cur = this.get ? this.get(k) : undefined;
        if (typeof cur === 'string') {
          const v = canonicalCityName(cur, coords);
          if (v !== cur) this.set(k, v);
        }
      }
      for (const f of OBJ_FIELDS) {
        const obj = this.get ? this.get(f) : undefined;
        if (obj && typeof obj === 'object' && typeof obj.city === 'string') {
          const v = canonicalCityName(obj.city, coordsOfLocation(obj) || coords);
          if (v !== obj.city) {
            this.set(`${f}.city`, v);
            if (typeof this.markModified === 'function') this.markModified(f);
          }
        }
      }
    } catch (_) { /* jamais bloquant */ }
    next();
  });

  const onUpdate = function canonCityUpdate(next) {
    try {
      const u = this.getUpdate();
      if (u && typeof u === 'object' && !Array.isArray(u)) {
        const coords = _coordsFromUpdate(u);
        let changed = false;
        if (u.$set && typeof u.$set === 'object') changed = _fixFlat(u.$set, coords) || changed;
        if (u.$setOnInsert && typeof u.$setOnInsert === 'object') changed = _fixFlat(u.$setOnInsert, coords) || changed;
        changed = _fixFlat(u, coords) || changed;
        if (changed) this.setUpdate(u);
      }
    } catch (_) { /* jamais bloquant */ }
    next();
  };
  schema.pre(['updateOne', 'updateMany', 'findOneAndUpdate'], onUpdate);
}

module.exports = { cityCanonicalPlugin, _fixFlat };
