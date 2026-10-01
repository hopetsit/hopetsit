'use strict';

/**
 * 607b (ZOE, 01/10/2026) — listes PUBLIQUES `GET /sitters` et `GET /walkers`
 * (sans connexion, aussi lues par le site et le mode invité).
 *
 * Mesuré le 01/10 en base de test : ces deux listes renvoyaient encore le NOM
 * COMPLET et la position EXACTE (lat/lng + coordinates, donc le domicile, ou
 * la position en direct pendant un partage), alors que la fiche
 * `GET /sitters/:id` et `GET /sitters|walkers/nearby` appliquent déjà les deux
 * règles : prénom + initiale (28/09) et position floutée à ~1 km (22/09),
 * position de PROFIL hors direct (v585). Même règle ici, mêmes fonctions.
 */
const { applyPublicName } = require('./publicName2809');
const { coarsenLocation } = require('./coarseLocation');
const { displayLocationOf } = require('./personMapPosition');

/**
 * @param {object} raw  document d'origine (mongoose ou lean)
 * @param {object} safe sortie de sanitizeUser (modifiée sur place et rendue)
 */
function toPublicListEntry(raw, safe) {
  if (!safe) return safe;
  applyPublicName(safe);
  const plain = raw && typeof raw.toObject === 'function' ? raw.toObject() : raw;
  const shown = displayLocationOf(plain || {});
  const c = shown && Array.isArray(shown.coordinates) ? shown.coordinates : null;
  if (c && c.length >= 2) {
    const id = String((plain && plain._id) || safe.id || '');
    const blurred = coarsenLocation({ coordinates: c }, id, false);
    if (blurred && blurred.approxKm) {
      safe.location = {
        ...(safe.location || {}),
        coordinates: blurred.coordinates,
        lng: blurred.coordinates[0],
        lat: blurred.coordinates[1],
        approxKm: blurred.approxKm,
      };
    }
  }
  return safe;
}

module.exports = { toPublicListEntry };
