/**
 * pawPointsService — v23.1.353 (refonte PawSpot, Daniel).
 *
 * Système PawPoints :
 *   +10 pts : ajouter un nouveau PawSpot
 *   +5  pts : photo ajoutée
 *   +10 pts : spot validé par la communauté (3 validations)
 *   +2  pts : commentaire utile
 *   +1  pt  : signalement correct (confirmation d'un map report)
 *   +25 pts : spot très populaire (50 likes)
 *
 * Badges (profil + spots) :
 *   🥉 Explorateur  : 100 pts
 *   🥈 Expert       : 500 pts
 *   🥇 Ambassadeur  : 1 500 pts
 *   👑 PawMaster    : 5 000 pts
 *   🥇 Gold Creator : >= 1 000 pts → empreinte DORÉE sur tous ses spots.
 */

const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const logger = require('../utils/logger');

const POINTS = Object.freeze({
  spotCreated: 10,
  photoAdded: 5,
  spotValidated: 10,
  usefulComment: 2,
  correctReport: 1,
  spotPopular: 25,
});

const BADGES = Object.freeze([
  { key: 'pawmaster', emoji: '👑', min: 5000 },
  { key: 'ambassador', emoji: '🥇', min: 1500 },
  { key: 'expert', emoji: '🥈', min: 500 },
  { key: 'explorer', emoji: '🥉', min: 100 },
]);

const GOLD_CREATOR_MIN = 1000;

const _modelFor = (role) => {
  const r = String(role || '').toLowerCase();
  return r === 'walker' ? Walker : r === 'sitter' ? Sitter : Owner;
};

/** Badge courant pour un total de points (ou null si < 100). */
function badgeFor(points) {
  const p = Number(points) || 0;
  for (const b of BADGES) {
    if (p >= b.min) return { key: b.key, emoji: b.emoji, min: b.min };
  }
  return null;
}

/** Prochain badge à atteindre (ou null si PawMaster). */
function nextBadgeFor(points) {
  const p = Number(points) || 0;
  const upcoming = [...BADGES].reverse().find((b) => p < b.min);
  return upcoming ? { key: upcoming.key, emoji: upcoming.emoji, min: upcoming.min } : null;
}

function isGoldCreator(points) {
  return (Number(points) || 0) >= GOLD_CREATOR_MIN;
}

/**
 * Crédite des PawPoints (atomique) et retourne le nouveau total.
 * Retourne null si user introuvable. Ne throw jamais (best-effort).
 *
 * v23.1.387 — Paw Premium : points communauté DOUBLÉS pendant toute la
 * durée du bundle (premiumExpiry futur). C'est LE chokepoint unique
 * d'attribution (create/like/comment/visit/validate passent tous ici)
 * → un seul endroit à maintenir.
 */
async function awardPoints({ userId, role, points, reason = '' }) {
  try {
    if (!userId || !points) return null;
    let pts = Number(points) || 0;
    let doubled = false;
    try {
      const UserSubscription = require('../models/UserSubscription');
      const r = String(role || '').toLowerCase();
      const userModel = r === 'walker' ? 'Walker' : r === 'sitter' ? 'Sitter' : 'Owner';
      const sub = await UserSubscription.findOne({ userId, userModel })
        .select('premiumExpiry')
        .lean();
      if (sub?.premiumExpiry && new Date(sub.premiumExpiry) > new Date()) {
        pts *= 2;
        doubled = true;
      }
    } catch (_) { /* best-effort : sans lookup on crédite le montant simple */ }
    const Model = _modelFor(role);
    const updated = await Model.findByIdAndUpdate(
      userId,
      { $inc: { pawPoints: pts } },
      { new: true },
    ).select('pawPoints');
    if (!updated) return null;
    logger.info(
      `🐾 [pawPoints] +${pts}${doubled ? ' (×2 Paw Premium)' : ''} → ${role}:${userId} (total ${updated.pawPoints}) ${reason ? '— ' + reason : ''}`,
    );
    return updated.pawPoints;
  } catch (e) {
    logger.warn(`[pawPoints] award failed (${reason}): ${e?.message || e}`);
    return null;
  }
}

/** Lit les points d'un user (0 si introuvable). */
async function getPoints(userId, role) {
  try {
    const Model = _modelFor(role);
    const doc = await Model.findById(userId).select('pawPoints').lean();
    return Number(doc?.pawPoints) || 0;
  } catch (_) {
    return 0;
  }
}

module.exports = {
  POINTS,
  BADGES,
  GOLD_CREATOR_MIN,
  badgeFor,
  nextBadgeFor,
  isGoldCreator,
  awardPoints,
  getPoints,
};
