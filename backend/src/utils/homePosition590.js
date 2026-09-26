/**
 * v590 — « mon frère vit vers Murcia et ça le met vers Valencia » (Daniel,
 * 26/09). La position de PROFIL (inscription) ne suivait pas un déménagement.
 * À l'ouverture de la carte, l'app envoie la position GPS du téléphone ; si
 * elle est à plus de 50 km de la position de profil de la personne, on la
 * prend comme nouvelle position de profil sur ses 3 profils (jamais pendant
 * un direct actif : seul `homeLocation` bouge alors). Dans la même ville, rien
 * ne change : les trajets du quotidien ne sont jamais enregistrés.
 */
const { distanceKm, MOVED_KM, homeOf, isLiveNow, validLngLat } = require('./personMapPosition');

const MODELS = () => ({
  Owner: require('../models/Owner'),
  Sitter: require('../models/Sitter'),
  Walker: require('../models/Walker'),
});

/** Décision pure : faut-il déplacer la position de profil ? */
function shouldMoveHome(currentHome, next, km = MOVED_KM) {
  if (!validLngLat(next)) return false;
  if (!currentHome || !validLngLat(currentHome)) return true;
  return distanceKm(currentHome, next) > km;
}

async function updateHomePosition(userId, { lat, lng, city = '' } = {}, now = new Date()) {
  const next = [Number(lng), Number(lat)];
  if (!validLngLat(next)) return { updated: 0, reason: 'invalid' };
  const { identityGroup } = require('./identityGroup');
  const g = await identityGroup(userId);
  const M = MODELS();
  const docs = [];
  for (const d of g.docs) {
    const Model = M[d.model];
    if (!Model) continue;
    const doc = await Model.findById(d.id).select('+homeLocation location city updatedAt createdAt').lean();
    if (doc) docs.push({ Model, doc });
  }
  if (!docs.length) return { updated: 0, reason: 'none' };
  // Position de profil ACTUELLE de la personne = la plus récente de ses profils.
  const homes = docs.map((x) => homeOf(x.doc)).filter(Boolean).sort((a, b) => b.at - a.at);
  const current = homes.length ? homes[0].coordinates : null;
  if (!shouldMoveHome(current, next)) return { updated: 0, reason: 'same_city' };
  const cleanCity = String(city || '').trim().slice(0, 120);
  let updated = 0;
  for (const { Model, doc } of docs) {
    const home = { coordinates: next, city: cleanCity || (doc.location && doc.location.city) || doc.city || '', at: now };
    const set = { homeLocation: home };
    const update = { $set: set };
    if (!isLiveNow(doc, now)) {
      // Hors direct : la position de profil (recherche « près de chez moi »)
      // suit aussi, marquée « profil » (sans horodatage de partage).
      set['location.type'] = 'Point';
      set['location.coordinates'] = next;
      if (cleanCity) set['location.city'] = cleanCity;
      update.$unset = { 'location.updatedAt': '' };
    }
    try {
      await Model.updateOne({ _id: doc._id }, update);
      updated += 1;
    } catch (_) { /* un profil illisible n'empêche pas les autres */ }
  }
  return { updated, reason: 'moved', fromKm: current ? Math.round(distanceKm(current, next)) : null };
}

module.exports = { shouldMoveHome, updateHomePosition };
