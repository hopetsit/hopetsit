/**
 * pawPointsService — v416 (refonte niveaux + récompenses, Daniel).
 *
 * GAINS (POINTS) — chokepoint unique awardPoints :
 *   +10 : ajouter un PawSpot         +5  : photo
 *   +10 : spot validé (communauté)   +2  : commentaire utile
 *   +1  : signalement confirmé       +25 : spot très populaire (50 likes)
 *
 * DEUX COMPTEURS (décision Daniel v416) :
 *   • pawPoints          = points GAGNÉS À VIE → détermine le NIVEAU/badge.
 *                          Ne baisse JAMAIS (dépenser une récompense ne fait
 *                          pas perdre de niveau).
 *   • pawPointsSpendable = solde DÉPENSABLE → échangé contre des récompenses.
 *
 * 7 NIVEAUX (paliers de points À VIE) avec avantages :
 *   1 Explorateur   1 000     badge + accès coffres basiques
 *   2 Contributeur  5 000     badge + visibilité sur la carte
 *   3 Expert        10 000    badge + points bonus +5 %
 *   4 Ambassadeur   20 000    badge + points bonus +10 %
 *   5 PawMaster     50 000    badge + PawBoost gratuit
 *   6 Légendaire    200 000   cadre légendaire + statut Légendaire
 *   7 Paw Legend    1 000 000 couronne rose + avantages ultimes
 *
 * Bonus de points : à partir d'Expert, awardPoints multiplie les gains
 * (+5 %, +10 %, +15 %) selon le niveau À VIE courant.
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

// Source de vérité unique des niveaux. `index` = numéro affiché (1..7).
const LEVELS = Object.freeze([
  { index: 1, key: 'explorer',    label: 'Explorateur',  min: 1000,    emoji: '🧭', color: '#22C55E', bonusPct: 0,  perks: ['badge', 'chests_basic'] },
  { index: 2, key: 'contributor', label: 'Contributeur', min: 5000,    emoji: '🐾', color: '#3B82F6', bonusPct: 0,  perks: ['badge', 'map_visibility'] },
  { index: 3, key: 'expert',      label: 'Expert',       min: 10000,   emoji: '⭐', color: '#8B5CF6', bonusPct: 5,  perks: ['badge', 'bonus_5'] },
  { index: 4, key: 'ambassador',  label: 'Ambassadeur',  min: 20000,   emoji: '🦴', color: '#F97316', bonusPct: 10, perks: ['badge', 'bonus_10'] },
  { index: 5, key: 'pawmaster',   label: 'PawMaster',    min: 50000,   emoji: '👑', color: '#7C3AED', bonusPct: 10, perks: ['badge', 'free_pawboost'] },
  { index: 6, key: 'legend',      label: 'Légendaire',   min: 200000,  emoji: '👑', color: '#111827', bonusPct: 10, perks: ['legendary_frame', 'legendary_status'] },
  { index: 7, key: 'paw_legend',  label: 'Paw Legend',   min: 1000000, emoji: '👑', color: '#EC4899', bonusPct: 15, perks: ['pink_crown', 'ultimate'] },
]);

// Compat : ancien tableau BADGES (clés réutilisées par l'app/leaderboard).
const BADGES = Object.freeze(
  [...LEVELS].reverse().map((l) => ({ key: l.key, emoji: l.emoji, min: l.min })),
);

const GOLD_CREATOR_MIN = 1000;

// v416 — récompenses "abonnement" ÉCHANGEABLES contre des points dépensables.
// Auto-appliquées (mois gratuit = crédité tout de suite ; réduction = au
// prochain achat). 1 seule fois par utilisateur (cf pawPointsRoutes).
//   tier : 1..6 → icône (médailles bronze/argent/or puis pièces violet/or/rose)
//   kind : 'discount' (percent + plans éligibles) | 'free_month' (days + plan)
const SUBSCRIPTION_REWARDS = Object.freeze([
  { id: 'sub_disc_10', tier: 1, cost: 20000,   kind: 'discount',   percent: 10, target: 'PawFollow / PawSpot', plans: ['monthly', 'yearly', 'pawspot'] },
  { id: 'sub_disc_25', tier: 2, cost: 50000,   kind: 'discount',   percent: 25, target: 'Paw Premium',         plans: ['premium_monthly', 'premium_yearly'] },
  { id: 'sub_disc_50', tier: 3, cost: 100000,  kind: 'discount',   percent: 50, target: 'Paw Premium',         plans: ['premium_monthly', 'premium_yearly'] },
  { id: 'sub_free_pf_1m', tier: 4, cost: 200000,  kind: 'free_month', days: 30, target: 'PawFollow / PawSpot', plan: 'monthly' },
  { id: 'sub_free_pp_1m', tier: 5, cost: 500000,  kind: 'free_month', days: 30, target: 'Paw Premium',         plan: 'premium_monthly' },
  { id: 'sub_free_pp_3m', tier: 6, cost: 1000000, kind: 'free_month', days: 90, target: 'Paw Premium',         plan: 'premium_monthly' },
]);

const subscriptionRewardById = (id) =>
  SUBSCRIPTION_REWARDS.find((r) => r.id === id) || null;

const _modelFor = (role) => {
  const r = String(role || '').toLowerCase();
  return r === 'walker' ? Walker : r === 'sitter' ? Sitter : Owner;
};

/** Niveau courant pour un total À VIE (ou null si < 1 000). */
function levelFor(points) {
  const p = Number(points) || 0;
  let cur = null;
  for (const l of LEVELS) {
    if (p >= l.min) cur = l;
  }
  return cur;
}

/** Prochain niveau à atteindre (null si déjà Paw Legend). */
function nextLevelFor(points) {
  const p = Number(points) || 0;
  return LEVELS.find((l) => p < l.min) || null;
}

/** Bonus % de points lié au niveau À VIE courant. */
function bonusPctFor(points) {
  const l = levelFor(points);
  return l ? l.bonusPct : 0;
}

/** Compat : badge (= niveau) courant, format {key,emoji,min}. */
function badgeFor(points) {
  const l = levelFor(points);
  return l ? { key: l.key, emoji: l.emoji, min: l.min } : null;
}

function nextBadgeFor(points) {
  const l = nextLevelFor(points);
  return l ? { key: l.key, emoji: l.emoji, min: l.min } : null;
}

function isGoldCreator(points) {
  return (Number(points) || 0) >= GOLD_CREATOR_MIN;
}

/**
 * Crédite des PawPoints (atomique) et retourne le nouveau total À VIE.
 * - ×2 pendant un bundle Paw Premium actif (premiumExpiry futur).
 * - +bonus% selon le niveau À VIE courant (Expert+).
 * Incrémente pawPoints (à vie) ET pawPointsSpendable (dépensable).
 */
async function awardPoints({ userId, role, points, reason = '' }) {
  try {
    if (!userId || !points) return null;
    let pts = Number(points) || 0;
    const Model = _modelFor(role);

    // Lecture du total à vie courant (pour le bonus de niveau).
    let lifetime = 0;
    try {
      const cur = await Model.findById(userId).select('pawPoints').lean();
      lifetime = Number(cur?.pawPoints) || 0;
    } catch (_) { /* defensive */ }

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
    } catch (_) { /* best-effort */ }

    // Bonus de niveau (Expert +5 %, Ambassadeur+ +10 %, Paw Legend +15 %).
    const bonus = bonusPctFor(lifetime);
    if (bonus > 0) pts = Math.round(pts * (1 + bonus / 100));

    const updated = await Model.findByIdAndUpdate(
      userId,
      { $inc: { pawPoints: pts, pawPointsSpendable: pts } },
      { new: true },
    ).select('pawPoints pawPointsSpendable');
    if (!updated) return null;
    logger.info(
      `🐾 [pawPoints] +${pts}${doubled ? ' (×2 Premium)' : ''}${bonus ? ' (+' + bonus + '% niveau)' : ''} → ${role}:${userId} (à vie ${updated.pawPoints}) ${reason ? '— ' + reason : ''}`,
    );
    return updated.pawPoints;
  } catch (e) {
    logger.warn(`[pawPoints] award failed (${reason}): ${e?.message || e}`);
    return null;
  }
}

/** Lit le total à vie (0 si introuvable). */
async function getPoints(userId, role) {
  try {
    const Model = _modelFor(role);
    const doc = await Model.findById(userId).select('pawPoints').lean();
    return Number(doc?.pawPoints) || 0;
  } catch (_) {
    return 0;
  }
}

/**
 * État complet PawPoints d'un user : total à vie, solde dépensable, niveau,
 * progression. Backfill paresseux : si pawPointsSpendable absent (anciens
 * comptes), on l'initialise au total à vie (ils n'ont encore rien dépensé).
 */
async function getPawState(userId, role) {
  const Model = _modelFor(role);
  let doc = await Model.findById(userId)
    .select('pawPoints pawPointsSpendable')
    .lean();
  if (!doc) {
    return {
      lifetime: 0, spendable: 0, level: null, nextLevel: nextLevelFor(0),
      bonusPct: 0, isGoldCreator: false, goldCreatorMin: GOLD_CREATOR_MIN,
    };
  }
  const lifetime = Number(doc.pawPoints) || 0;
  let spendable = doc.pawPointsSpendable;
  if (spendable === undefined || spendable === null) {
    // Backfill une fois : dépensable = total à vie.
    spendable = lifetime;
    try {
      await Model.updateOne(
        { _id: userId, pawPointsSpendable: { $exists: false } },
        { $set: { pawPointsSpendable: lifetime } },
      );
    } catch (_) { /* best-effort */ }
  }
  return {
    lifetime,
    spendable: Number(spendable) || 0,
    level: levelFor(lifetime),
    nextLevel: nextLevelFor(lifetime),
    bonusPct: bonusPctFor(lifetime),
    isGoldCreator: isGoldCreator(lifetime),
    goldCreatorMin: GOLD_CREATOR_MIN,
  };
}

module.exports = {
  POINTS,
  LEVELS,
  BADGES,
  SUBSCRIPTION_REWARDS,
  subscriptionRewardById,
  GOLD_CREATOR_MIN,
  levelFor,
  nextLevelFor,
  bonusPctFor,
  badgeFor,
  nextBadgeFor,
  isGoldCreator,
  awardPoints,
  getPoints,
  getPawState,
};
