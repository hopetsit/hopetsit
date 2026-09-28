/**
 * v599 — LA PHOTO DANS LE ROND DU DIRECT (Daniel, 28/09 : capture « Po de la
 * Isla », rond violet vide sur la personne suivie).
 *
 * Constat : les positions en direct (/friends/live-positions, événements
 * socket `map:friend-position`, /conversations/:id/peer-position) ne portaient
 * ni nom ni photo. L'app les cherchait dans SA liste d'amis ou de famille :
 * pour un prestataire suivi pendant une réservation, un contact ouvert depuis
 * le chat, ou avant que la liste d'amis soit chargée, le rond restait vide.
 *
 * Ici : la « carte de visite » minimale d'une personne (nom + photo), lue une
 * fois puis gardée 10 min en mémoire vive, quel que soit le profil sous lequel
 * elle diffuse. Jamais d'erreur levée : sans document lisible, carte vide.
 */
const TTL_MS = 10 * 60 * 1000;
const SELECT = 'name firstName lastName avatar profilePicture';
const cache = new Map(); // userId → { card, at }

/** URL d'un champ photo Mongoose (chaîne ou { url }). */
function avatarUrl(a) {
  if (!a) return '';
  if (typeof a === 'object') return String(a.url || '');
  return String(a);
}

/** Nom + photo d'un document de profil (pure, testée). */
function pickCard(doc) {
  if (!doc) return { name: '', avatar: '' };
  const composed = `${doc.firstName || ''} ${doc.lastName || ''}`.trim();
  const name = String(doc.name || composed || '').trim();
  const avatar = avatarUrl(doc.profilePicture) || avatarUrl(doc.avatar);
  return { name, avatar };
}

function models() {
  return {
    Owner: require('../models/Owner'),
    Sitter: require('../models/Sitter'),
    Walker: require('../models/Walker'),
  };
}

/**
 * Carte de visite d'une personne à partir d'un de ses ids de profil.
 * `roleHint` (owner|sitter|walker) est lu en premier ; sinon les 3 modèles.
 */
async function cardFor(userId, roleHint) {
  const id = String(userId || '');
  if (!id) return { name: '', avatar: '' };
  const now = Date.now();
  const hit = cache.get(id);
  if (hit && now - hit.at < TTL_MS) return hit.card;
  const M = models();
  const order = ['Owner', 'Sitter', 'Walker'];
  const r = String(roleHint || '').toLowerCase();
  const first = r === 'sitter' ? 'Sitter' : r === 'walker' ? 'Walker' : r === 'owner' ? 'Owner' : null;
  const names = first ? [first, ...order.filter((n) => n !== first)] : order;
  let card = { name: '', avatar: '' };
  for (const n of names) {
    let doc = null;
    try {
      doc = await M[n].findById(id).select(SELECT).lean();
    } catch (_) { doc = null; }
    if (!doc) continue;
    const c = pickCard(doc);
    if (!card.name && c.name) card.name = c.name;
    if (!card.avatar && c.avatar) card.avatar = c.avatar;
    if (card.name && card.avatar) break;
  }
  cache.set(id, { card, at: now });
  return card;
}

function forget(userId) {
  cache.delete(String(userId || ''));
}

function _resetForTests() {
  cache.clear();
}

module.exports = { cardFor, pickCard, avatarUrl, forget, TTL_MS, _resetForTests };
