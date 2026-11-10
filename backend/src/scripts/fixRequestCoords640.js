// 10/11/2026 (BOB, accord de Daniel : « ok fais le si ya pas besoin de build »)
// Correction UNE FOIS au démarrage (marqueur `migrations`, non bloquante) :
// UNE demande publiée à São Paulo n'a qu'un nom de ville, sans position.
// Le serveur la cache déjà aux prestataires d'une autre ville (feedNoCoords640) ;
// ici on lui donne la position du centre de sa ville pour qu'elle soit triée par
// distance comme les autres. Même écriture que la publication (postController,
// v591) : location.lat / location.lng / location.geocoded.
//
// Garde-fous :
//   - une seule annonce, désignée par son identifiant ; aucun autre champ touché ;
//   - jamais d'écrasement : si l'annonce a déjà une position, on ne fait rien ;
//   - la position vient de la table des villes du serveur (utils/geocodeCity,
//     `peekCity` : table fixe d'abord, sinon mémoire), sans appel réseau ;
//     ville inconnue → on ne fait rien (vérifié le 10/11 : la ville enregistrée
//     est exactement « São Paulo », présente dans la table fixe) ;
//   - la date de modification de l'annonce n'est pas changée ;
//   - coupe-circuit Render : FIX_REQUEST_COORDS_640=off.
const POST_IDS_640 = ['6ae919848caf664e65af7b32'];
const KEY_640 = 'v640_request_coords_sao_paulo';

function enabled640() {
  return String(process.env.FIX_REQUEST_COORDS_640 || '').trim().toLowerCase() !== 'off';
}

/** Règle pure : la position à écrire, ou null s'il ne faut rien écrire. */
function coordsToSet640(location, peekCity, coordsOf) {
  if (!location || typeof location !== 'object' || Array.isArray(location)) return null;
  if (coordsOf(location)) return null;
  const city = String(location.city || '').trim();
  if (!city) return null;
  let p = null;
  try { p = peekCity(city); } catch (_) { p = null; }
  const ok = coordsOf(p);
  return ok ? { lat: ok.lat, lng: ok.lng } : null;
}

async function runFixRequestCoords640(db, logger = console, deps = {}) {
  if (!enabled640()) return null;
  try {
    const mig = db.collection('migrations');
    if (await mig.findOne({ _id: KEY_640 })) return null;
    const Post = deps.Post || require('../models/Post');
    const peekCity = deps.peekCity || require('../utils/geocodeCity').peekCity;
    const coordsOf = deps.coordsOf || require('../utils/feedNoCoords640').coordsOf640;
    const stats = { found: 0, alreadySet: 0, cityUnknown: 0, updated: 0 };
    for (const id of POST_IDS_640) {
      const post = await Post.findById(id).select('location postType').lean();
      if (!post) continue;
      stats.found += 1;
      if (coordsOf(post.location)) { stats.alreadySet += 1; continue; }
      const p = coordsToSet640(post.location, peekCity, coordsOf);
      if (!p) { stats.cityUnknown += 1; continue; }
      const r = await Post.updateOne(
        { _id: id, $or: [{ 'location.lat': { $exists: false } }, { 'location.lat': null }, { 'location.lat': '' }] },
        { $set: { 'location.lat': p.lat, 'location.lng': p.lng, 'location.geocoded': true } },
        { timestamps: false },
      );
      stats.updated += (r && r.modifiedCount) || 0;
    }
    await mig.insertOne({ _id: KEY_640, at: new Date(), stats });
    logger.info(`[boot] migration ${KEY_640}: ${JSON.stringify(stats)}`);
    return stats;
  } catch (e) {
    logger.error(`[boot] migration ${KEY_640} failed (non-fatal)`, e);
    return null;
  }
}

module.exports = { runFixRequestCoords640, coordsToSet640, POST_IDS_640, KEY_640 };
