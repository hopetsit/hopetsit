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
 * NIVEAUX = les 5 RANGS 611 (Chiot → Légende, services/ranks611.js) depuis
 * le 04/10/2026 : les 7 niveaux v416 et leur bonus de points sont retirés
 * (aucun profil n'avait jamais atteint le premier bonus, mesuré).
 */

const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const logger = require('../utils/logger');

// 607 (ZOE, 02/10) — barème UNIQUE app / site / admin : la source de vérité
// est pawPointsCatalog607.EARN_RULES ; POINTS en est la vue « clé → points »
// (mêmes valeurs qu'avant pour les 6 gains PawSpot / carte).
const CATALOG607 = require('./pawPointsCatalog607');
const POINTS = Object.freeze(
  Object.fromEntries(CATALOG607.EARN_RULES.map((r) => [r.key, r.points])),
);

// Source de vérité unique des niveaux. `index` = numéro affiché (1..7).
// 607 — `perks` = avantages RÉELLEMENT accordés (badge + bonus de points).
// Les anciens (coffres, visibilité, PawBoost gratuit, couronne, « avantages
// ultimes ») n'étaient tenus par aucun code : retirés. Clés connues des apps
// ≤ 606 (LEVEL_PERKS_LEGACY) ; le 607 lit le catalogue.
// 611 (PAM, décision BOB du 04/10) — UN SEUL système : les 7 anciens
// niveaux v416 (Explorateur… Paw Legend, bonus +5 à +15 %) sont REMPLACÉS
// par les 5 rangs 611 (services/ranks611.js). Mêmes champs qu'avant, pour
// que les apps déjà installées (607-610) affichent les rangs sans build.
// Aucun bonus : mesuré le 04/10, le plus haut total gagné de TOUS les profils
// (test et staff compris) est 670 ; le premier bonus démarrait à 10 000 →
// jamais versé à personne.
const RANKS611 = require('./ranks611');
const LEVELS = Object.freeze(RANKS611.RANKS.map((r) => Object.freeze({
  index: r.level,
  key: r.key,
  label: r.texts.fr,
  min: r.min,
  emoji: r.level === 5 ? '👑' : '🐾',
  color: r.color,
  bonusPct: 0,
  perks: ['badge'],
})));

// Compat : ancien tableau BADGES (clés réutilisées par l'app/leaderboard).
const BADGES = Object.freeze(
  [...LEVELS].reverse().map((l) => ({ key: l.key, emoji: l.emoji, min: l.min })),
);

const GOLD_CREATOR_MIN = 1000;

// v416 → 607 (ZOE, 02/10) — LISTE LUE PAR LES APPS ≤ 606 (champ
// `subscriptionRewards` du catalogue). Elles n'affichent correctement que
// 'free_month' (30 j → « 1 mois », 90 j → « 3 mois ») : on n'y met donc QUE
// les trois paliers à 30 / 30 / 90 jours. Les réductions -10 / -25 / -50 %
// (tiers 1-3) sont RETIRÉES : impossibles dans les achats Apple (même motif
// 3.1.1 que les codes). Le catalogue complet 607 est dans
// pawPointsCatalog607.REWARDS (jours offerts, PawBoost, cadre doré).
// Celles déjà échangées restent valables : leur définition est copiée dans la
// trace d'échange (`snapshot`) que lit discountReservationService.
const SUBSCRIPTION_REWARDS = Object.freeze(
  CATALOG607.REWARDS
    .filter((r) => r.kind === 'free_days' && r.days >= 30)
    .map((r, i) => ({
      id: r.id,
      tier: 4 + i,
      cost: r.cost,
      kind: 'free_month',
      days: r.days,
      target: r.plan === 'monthly' ? 'PawFollow / PawSpot' : 'Paw Premium',
      plan: r.plan,
    })),
);

const subscriptionRewardById = (id) =>
  SUBSCRIPTION_REWARDS.find((r) => r.id === id) || null;

const _modelFor = (role) => {
  const r = String(role || '').toLowerCase();
  return r === 'walker' ? Walker : r === 'sitter' ? Sitter : Owner;
};

/**
 * v532 — PARTAGE DES POINTS ENTRE LES 3 PROFILS D'UN MÊME COMPTE.
 *
 * `pawPoints` et `pawPointsSpendable` vivaient sur le document de rôle. Or un
 * compte HoPetSit a jusqu'à TROIS documents (propriétaire / gardien /
 * promeneur) reliés par l'email. Conséquence : les points gagnés en ajoutant
 * un PawSpot depuis le profil propriétaire n'existaient pas côté gardien —
 * l'utilisateur voyait son solde « disparaître » en changeant de profil, son
 * niveau retomber à zéro, et il ne pouvait pas dépenser ses points depuis le
 * mauvais rôle. Ces deux compteurs ne figuraient pas non plus dans
 * SHARED_FIELDS (et de toute façon awardPoints écrit en $inc direct, hors du
 * mécanisme de synchronisation).
 *
 * On aligne donc les documents frères sur la valeur la plus élevée après
 * chaque gain et chaque dépense. Prendre le MAX (et non recopier) évite de
 * perdre des points si des profils avaient déjà divergé.
 */
async function syncPointsAcrossRoles(userId, role) {
  try {
    const Model = _modelFor(role);
    const me = await Model.findById(userId)
      .select('email pawPoints pawPointsSpendable')
      .lean();
    if (!me?.email) return;
    const models = [
      ['owner', Owner],
      ['sitter', Sitter],
      ['walker', Walker],
    ];
    const docs = [];
    for (const [r, M] of models) {
      const d = await M.findOne({ email: me.email })
        .select('pawPoints pawPointsSpendable')
        .lean();
      if (d) docs.push({ role: r, Model: M, doc: d });
    }
    if (docs.length < 2) return; // un seul profil : rien à synchroniser
    const maxLifetime = Math.max(...docs.map((d) => Number(d.doc.pawPoints) || 0));
    const maxSpendable = Math.max(
      ...docs.map((d) => Number(d.doc.pawPointsSpendable) || 0),
    );
    await Promise.all(
      docs
        .filter(
          (d) => (Number(d.doc.pawPoints) || 0) !== maxLifetime
            || (Number(d.doc.pawPointsSpendable) || 0) !== maxSpendable,
        )
        .map((d) => d.Model.updateOne(
          { _id: d.doc._id },
          { $set: { pawPoints: maxLifetime, pawPointsSpendable: maxSpendable } },
        )),
    );
  } catch (e) {
    logger.warn(`[pawPoints] sync inter-rôles échouée : ${e?.message || e}`);
  }
}

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
function bonusPctFor(points) { // 611 — plus aucun bonus lié au rang
  void points;
  return 0;
}

/** Compat : badge (= niveau) courant, format {key,emoji,min}. */
function badgeFor(points) {
  // 611 — les 7 anciens badges ne s'affichent plus nulle part (les apps
  // ≤ 610 cachent un badge nul) ; le rang est dans `rank`.
  void points;
  return null;
}

function nextBadgeFor(points) {
  void points;
  return null;
}

function isGoldCreator(points) {
  return (Number(points) || 0) >= GOLD_CREATOR_MIN;
}

/**
 * v567 — « Points doublés dans la communauté » (promesse Paw Premium affichée
 * dans la boutique) : Paw Premium actif sur N'IMPORTE LEQUEL des trois profils
 * du compte (propriétaire / gardien / promeneur).
 *
 * Avant, on ne lisait que l'abonnement du DOCUMENT DE RÔLE actif : un compte
 * ayant acheté Paw Premium en propriétaire et taguant un spot depuis son profil
 * promeneur ne voyait PAS ses points doublés (la synchro inter-rôles n'ayant pas
 * forcément tourné pour ce compte). Même résolution par email que friendRoutes
 * (« mon frère est Premium mais je le vois en promeneur »).
 */
async function hasActivePremiumAnyRole(userId, role) {
  try {
    const UserSubscription = require('../models/UserSubscription');
    const now = new Date();
    const r = String(role || '').toLowerCase();
    const userModel = r === 'walker' ? 'Walker' : r === 'sitter' ? 'Sitter' : 'Owner';
    const own = await UserSubscription.findOne({ userId, userModel })
      .select('premiumExpiry')
      .lean();
    if (own?.premiumExpiry && new Date(own.premiumExpiry) > now) return true;
    // Profils frères du même compte (même email).
    const Model = _modelFor(role);
    const me = await Model.findById(userId).select('email').lean();
    const email = (me?.email || '').toLowerCase().trim();
    if (!email) return false;
    const sibIds = [];
    for (const M of [Owner, Sitter, Walker]) {
      const d = await M.findOne({ email }).select('_id').lean();
      if (d && String(d._id) !== String(userId)) sibIds.push(d._id);
    }
    if (!sibIds.length) return false;
    const sib = await UserSubscription.findOne({
      userId: { $in: sibIds },
      premiumExpiry: { $gt: now },
    }).select('_id').lean();
    return !!sib;
  } catch (_) {
    return false;
  }
}

/**
 * 611 (PAM) — clé lisible d'un gain d'après sa raison (journal d'historique).
 * Les raisons viennent des appelants existants ; une raison inconnue = 'other'.
 */
function logKeyFromReason(reason) {
  const r = String(reason || '');
  const m = r.match(/^607 (\w+)/);
  if (m) return m[1];
  if (/^mini-peluche dorée/.test(r)) return 'plushGolden';
  if (/^mini-peluche/.test(r)) return 'plushCaught';
  if (/bonus collector/.test(r)) return 'plushCollector';
  if (/bonus streak7/.test(r)) return 'plushStreak7';
  if (r === 'spot created') return 'spotCreated';
  if (r === 'spot photo') return 'photoAdded';
  if (r === 'spot comment') return 'usefulComment';
  if (/popular/.test(r)) return 'spotPopular';
  if (/validated/.test(r)) return 'spotValidated';
  if (/map report confirmed/.test(r)) return 'correctReport';
  if (r === 'spot deleted') return 'spotDeleted';
  return 'other';
}

/** 611 — écrit une ligne du journal (jamais bloquant). */
async function logPoints611({ userId, role, points, reason, email }) {
  try {
    // Base pas (encore) connectée : on n'attend jamais (mongoose mettrait
    // l'écriture en file 10 s et ralentirait le gain lui-même).
    if (require('mongoose').connection.readyState !== 1) return;
    const { personKeyFromEmail } = require('./pawPointsActivity607');
    const personKey = personKeyFromEmail(email) || `id:${userId}`;
    await require('../models/PawPointsLog611').create({
      personKey, userId: String(userId), role: String(role || '').toLowerCase(),
      key: logKeyFromReason(reason), points, at: new Date(),
    });
  } catch (e) {
    logger.warn(`[pawPoints] journal 611 : ${e?.message || e}`);
  }
}

/**
 * Crédite des PawPoints (atomique) et retourne `{ credited, lifetime }`.
 * - ×2 pendant un bundle Paw Premium actif (premiumExpiry futur, tous rôles).
 * - +bonus% selon le niveau À VIE courant (Expert+).
 * Incrémente pawPoints (à vie) ET pawPointsSpendable (dépensable).
 */
async function awardPointsDetailed({ userId, role, points, reason = '', skipLog = false }) {
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

    const doubled = await hasActivePremiumAnyRole(userId, role);
    if (doubled) pts *= 2;

    // Bonus de niveau (Expert +5 %, Ambassadeur+ +10 %, Paw Legend +15 %).
    const bonus = bonusPctFor(lifetime);
    if (bonus > 0) pts = Math.round(pts * (1 + bonus / 100));

    const updated = await Model.findByIdAndUpdate(
      userId,
      { $inc: { pawPoints: pts, pawPointsSpendable: pts } },
      { new: true },
    ).select('pawPoints pawPointsSpendable email');
    if (!updated) return null;
    // 611 — journal. Les gains d'activité 607 ont déjà leur ligne
    // (PawPointsEvent, lue aussi par l'historique) : pas de doublon.
    if (!skipLog) await logPoints611({ userId, role, points: pts, reason, email: updated.email });
    // v532 — propage le nouveau solde aux autres profils du même compte.
    await syncPointsAcrossRoles(userId, role);
    logger.info(
      `🐾 [pawPoints] +${pts}${doubled ? ' (×2 Premium)' : ''}${bonus ? ' (+' + bonus + '% niveau)' : ''} → ${role}:${userId} (à vie ${updated.pawPoints}) ${reason ? '— ' + reason : ''}`,
    );
    return { credited: pts, lifetime: updated.pawPoints, doubled };
  } catch (e) {
    logger.warn(`[pawPoints] award failed (${reason}): ${e?.message || e}`);
    return null;
  }
}

/** Compat : ancienne signature (retourne le total à vie, ou null). */
async function awardPoints(args) {
  const r = await awardPointsDetailed(args);
  return r ? r.lifetime : null;
}

/**
 * v567 — REPRISE de points (suppression d'une contribution). Les deux
 * compteurs redescendent, plancher à 0, puis les trois profils du compte sont
 * réalignés. Sans ça, « créer un spot / le supprimer / recommencer » était une
 * ferme à PawPoints illimitée (le classement et les récompenses à points
 * n'avaient plus aucun sens).
 */
async function revokePoints({ userId, role, points, reason = '' }) {
  try {
    const pts = Number(points) || 0;
    if (!userId || pts <= 0) return null;
    const Model = _modelFor(role);
    const cur = await Model.findById(userId)
      .select('pawPoints pawPointsSpendable')
      .lean();
    if (!cur) return null;
    const lifetime = Math.max(0, (Number(cur.pawPoints) || 0) - pts);
    const spendable = Math.max(
      0,
      (cur.pawPointsSpendable === undefined || cur.pawPointsSpendable === null
        ? Number(cur.pawPoints) || 0
        : Number(cur.pawPointsSpendable) || 0) - pts,
    );
    await Model.updateOne(
      { _id: userId },
      { $set: { pawPoints: lifetime, pawPointsSpendable: spendable } },
    );
    // 611 — la reprise apparaît aussi dans « D'où viennent mes points ».
    try {
      const em = await Model.findById(userId).select('email').lean();
      await logPoints611({ userId, role, points: -pts, reason, email: em?.email });
    } catch (_) { /* best-effort */ }
    // Les profils frères doivent DESCENDRE aussi : syncPointsAcrossRoles prend
    // le MAX, il ne peut donc pas baisser un solde. On écrit explicitement.
    try {
      const me = await Model.findById(userId).select('email').lean();
      if (me?.email) {
        await Promise.all(
          [Owner, Sitter, Walker].map((M) => M.updateOne(
            { email: me.email },
            { $set: { pawPoints: lifetime, pawPointsSpendable: spendable } },
          ).catch(() => {})),
        );
      }
    } catch (_) { /* best-effort */ }
    logger.info(
      `🐾 [pawPoints] -${pts} → ${role}:${userId} (à vie ${lifetime}) ${reason ? '— ' + reason : ''}`,
    );
    return lifetime;
  } catch (e) {
    logger.warn(`[pawPoints] revoke failed (${reason}): ${e?.message || e}`);
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
  // v532 — AUTO-RÉPARATION. Les comptes créés avant ce correctif ont des
  // soldes différents sur chacun de leurs trois profils (les points étaient
  // crédités sur le seul document du rôle actif). On réaligne à la lecture :
  // l'utilisateur retrouve son solde complet dès qu'il ouvre l'écran
  // PawPoints, sans migration de base.
  await syncPointsAcrossRoles(userId, role);
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
  CATALOG607,
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
  awardPointsDetailed,
  revokePoints,
  hasActivePremiumAnyRole,
  getPoints,
  getPawState,
  syncPointsAcrossRoles,
  logKeyFromReason,
};
