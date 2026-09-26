/**
 * v589 — SUIVRE LA BALADE D'UNE PRESTATION (Daniel, 26/09 : « quand on me suit
 * il y a le tracé ? il est aussi activé pour suivre les balades de chien ? »,
 * puis « fais le mieux, carte blanche »).
 *
 * Constat : pendant une garde ou une promenade RÉSERVÉE, le propriétaire ne
 * voyait le direct du prestataire que s'ils étaient AMIS (l'écran de balade
 * des prestataires n'était ouvert nulle part dans l'app).
 *
 * Règle : pendant une prestation EN COURS — animal récupéré (ou service
 * démarré) et pas encore rendu, réservation ni annulée ni remboursée, démarrée
 * il y a moins de 24 h — le direct du prestataire part aussi vers le
 * propriétaire de CETTE réservation, amis ou non, et même si le prestataire
 * est « Masqué » sur la carte publique (c'est le suivi du service payé, pas
 * la carte communautaire). Rien ne part avant la récupération ni après le
 * rendu.
 */
const MAX_AGE_MS = 24 * 60 * 60 * 1000;

/** Base joignable ? Sinon on ne lance pas de requête (Mongoose attendrait 10 s). */
function _dbReady(Booking) {
  try {
    const conn = Booking && Booking.db;
    return !conn || conn.readyState === undefined || conn.readyState === 1;
  } catch (_) {
    return true;
  }
}
const DEAD = ['cancelled', 'refunded', 'rejected', 'payment_failed'];

/** Filtre Mongo « prestation en cours » (pure, testée). */
function activeServiceFilter(now = new Date()) {
  const since = new Date(now.getTime() - MAX_AGE_MS);
  return {
    status: { $nin: DEAD },
    $and: [
      {
        $or: [
          { 'handover.pickupProviderAt': { $gte: since } },
          { serviceStartedAt: { $gte: since } },
        ],
      },
      { 'handover.returnProviderAt': null },
      { serviceEndedAt: null },
    ],
  };
}

/** Propriétaires des prestations en cours de ce prestataire (tous ses profils). */
async function activeServiceOwnersFor(providerIds, { now = new Date() } = {}) {
  const ids = (providerIds || []).map(String).filter(Boolean);
  if (!ids.length) return [];
  const Booking = require('../models/Booking');
  if (!_dbReady(Booking)) return [];
  const rows = await Booking.find({
    ...activeServiceFilter(now),
    $or: [{ sitterId: { $in: ids } }, { walkerId: { $in: ids } }],
  }).select('_id ownerId sitterId walkerId').limit(20).lean();
  const out = [];
  const seen = new Set();
  for (const b of rows || []) {
    const owner = String(b.ownerId || '');
    if (!owner || seen.has(owner)) continue;
    seen.add(owner);
    out.push({
      userId: owner,
      role: 'owner',
      bookingId: String(b._id),
      // L'id que l'app du propriétaire connaît : celui de la réservation.
      providerId: String(b.walkerId || b.sitterId || ''),
    });
  }
  return out;
}

/** Prestataires en service pour ce propriétaire (tous ses profils). */
async function activeServiceProvidersFor(ownerIds, { now = new Date() } = {}) {
  const ids = (ownerIds || []).map(String).filter(Boolean);
  if (!ids.length) return [];
  const Booking = require('../models/Booking');
  if (!_dbReady(Booking)) return [];
  const rows = await Booking.find({
    ...activeServiceFilter(now),
    ownerId: { $in: ids },
  }).select('_id sitterId walkerId').limit(20).lean();
  const out = [];
  const seen = new Set();
  for (const b of rows || []) {
    const walker = b.walkerId ? String(b.walkerId) : '';
    const sitter = b.sitterId ? String(b.sitterId) : '';
    const id = walker || sitter;
    if (!id || seen.has(id)) continue;
    seen.add(id);
    out.push({ id, role: walker ? 'walker' : 'sitter', bookingId: String(b._id) });
  }
  return out;
}

module.exports = { activeServiceFilter, activeServiceOwnersFor, activeServiceProvidersFor, MAX_AGE_MS };
