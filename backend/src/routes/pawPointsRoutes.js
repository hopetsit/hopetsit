/**
 * pawPointsRoutes — v416 (refonte niveaux + récompenses, Daniel).
 *
 *   GET  /pawpoints/catalog   → niveaux, barème, récompenses abonnement (fixes)
 *                               + récompenses admin custom. PUBLIC.
 *   GET  /pawpoints/me        → mon état (points à vie + dépensables + niveau +
 *                               progression) + récompenses déjà réclamées. AUTH.
 *   POST /pawpoints/redeem/:id → échange. id = sub_* (abonnement, auto-appliqué,
 *                               1×/user) OU ObjectId (récompense admin custom).
 *
 * 100% ADDITIF. L'app + le site LISENT le catalogue → modif admin sans rebuild.
 */

const express = require('express');
const mongoose = require('mongoose');
const { requireAuth } = require('../middleware/auth');
const PawReward = require('../models/PawReward');
const PawRewardRedemption = require('../models/PawRewardRedemption');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const pawPoints = require('../services/pawPointsService');
const { grantFreePeriod } = require('../services/subscriptionGrantService');
const logger = require('../utils/logger');

const router = express.Router();

const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };

/**
 * v532 — identité complète d'un compte : son email et les identifiants de ses
 * TROIS documents de rôle. Un compte HoPetSit possède un document par rôle
 * (propriétaire / gardien / promeneur) reliés par l'email ; tout ce qui était
 * calculé sur le seul document du rôle actif (points, contributions,
 * récompenses déjà réclamées) « disparaissait » au changement de profil.
 */
async function _identity(userId, role) {
  const out = { email: '', ids: [] };
  try {
    const r = String(role || '').toLowerCase();
    const Model = r === 'walker' ? Walker : r === 'sitter' ? Sitter : Owner;
    const me = await Model.findById(userId).select('email name').lean();
    if (!me) return out;
    out.email = me.email || '';
    out.name = me.name || '';
    if (!out.email) {
      out.ids = [userId];
      return out;
    }
    const docs = await Promise.all(
      [Owner, Sitter, Walker].map((M) => M.findOne({ email: out.email }).select('_id').lean()),
    );
    out.ids = docs.filter(Boolean).map((d) => d._id);
    if (!out.ids.length) out.ids = [userId];
  } catch (_) { /* best-effort */ }
  return out;
}
const modelFor = (role) => {
  const r = String(role || '').toLowerCase();
  return r === 'walker' ? Walker : r === 'sitter' ? Sitter : Owner;
};

const earnRules = () => ([
  { key: 'spotCreated', points: pawPoints.POINTS.spotCreated, label: 'Ajouter un PawSpot', icon: '📍' },
  { key: 'photoAdded', points: pawPoints.POINTS.photoAdded, label: 'Ajouter une photo', icon: '📷' },
  { key: 'spotValidated', points: pawPoints.POINTS.spotValidated, label: 'Spot validé par la communauté', icon: '✅' },
  { key: 'usefulComment', points: pawPoints.POINTS.usefulComment, label: 'Commentaire utile', icon: '💬' },
  { key: 'correctReport', points: pawPoints.POINTS.correctReport, label: 'Signalement confirmé', icon: '🚧' },
  { key: 'spotPopular', points: pawPoints.POINTS.spotPopular, label: 'Spot très populaire (50 likes)', icon: '⭐' },
]);

// Niveaux exposés (avec index, label, seuil, couleur, emoji, bonus, perks).
const levelsList = () => pawPoints.LEVELS.map((l) => ({
  index: l.index, key: l.key, label: l.label, min: l.min,
  emoji: l.emoji, color: l.color, bonusPct: l.bonusPct, perks: l.perks,
}));

// ─── GET /catalog ───────────────────────────────────────────────────────────
router.get('/catalog', async (req, res) => {
  try {
    const customRewards = await PawReward.find({ isActive: true })
      .sort({ sortOrder: 1, cost: 1 }).lean();
    res.json({
      subscriptionRewards: pawPoints.SUBSCRIPTION_REWARDS,
      rewards: customRewards.map((r) => ({
        id: String(r._id), title: r.title, description: r.description || '',
        icon: r.icon || '🎁', cost: r.cost || 0, kind: r.kind || 'discount',
        valueLabel: r.valueLabel || '',
        soldOut: !!(r.stock && r.stock > 0 && (r.redeemedCount || 0) >= r.stock),
      })),
      levels: levelsList(),
      earnRules: earnRules(),
      goldCreatorMin: pawPoints.GOLD_CREATOR_MIN,
    });
  } catch (e) {
    logger.error('[pawpoints/catalog]', e);
    res.status(500).json({ error: 'Erreur catalogue.' });
  }
});

// ─── GET /me ─────────────────────────────────────────────────────────────────
router.get('/me', requireAuth, async (req, res) => {
  try {
    const role = req.user?.role || 'owner';
    const st = await pawPoints.getPawState(req.user.id, role);
    // v532 — identité complète du compte (email + les 3 documents de rôle).
    const me = await _identity(req.user.id, role);
    // v416 — stats contributions (design : "Tes contributions" + "Spots aimés").
    let contributions = 0;
    let spotsLiked = 0;
    try {
      const MapReport = require('../models/MapReport');
      const PawSpot = require('../models/PawSpot');
      // v532 — les contributions étaient comptées sur le seul document du rôle
      // actif : un PawSpot ajouté depuis le profil propriétaire n'apparaissait
      // plus après un changement de profil. On compte sur les 3 profils.
      const ids = me.ids.length ? me.ids : [req.user.id];
      contributions = await MapReport.countDocuments({ reporterId: { $in: ids } });
      const spots = await PawSpot.find({ creatorId: { $in: ids } }).select('likesCount').lean();
      spotsLiked = spots.reduce((s, x) => s + (Number(x.likesCount) || 0), 0);
    } catch (_) { /* best-effort */ }
    // Récompenses abonnement déjà réclamées (1×/user).
    // v532 — la limite « 1 fois par utilisateur » se basait sur l'id du
    // DOCUMENT DE RÔLE. Un même compte ayant trois profils (propriétaire /
    // gardien / promeneur), il suffisait de changer de profil pour réclamer
    // une troisième fois la même récompense. On déduplique sur l'email.
    const claimed = await PawRewardRedemption.find({
      ...(me?.email
        ? { userEmail: me.email }
        : { userId: req.user.id }),
      rewardKey: { $regex: '^sub_' },
      status: { $ne: 'cancelled' },
    }).select('rewardKey status').lean();
    res.json({
      points: st.lifetime,           // total à vie (= niveau)
      lifetime: st.lifetime,
      spendable: st.spendable,        // solde dépensable
      contributions,                  // nb de signalements créés
      spotsLiked,                     // total de likes sur mes PawSpots
      level: st.level,
      nextLevel: st.nextLevel,
      bonusPct: st.bonusPct,
      isGoldCreator: st.isGoldCreator,
      goldCreatorMin: st.goldCreatorMin,
      levels: levelsList(),
      earnRules: earnRules(),
      claimedRewardKeys: claimed.map((c) => c.rewardKey),
    });
  } catch (e) {
    logger.error('[pawpoints/me]', e);
    res.status(500).json({ error: 'Erreur points.' });
  }
});

// Débit atomique du solde dépensable (anti double-dépense).
async function spendPoints(Model, userId, cost, role) {
  // Backfill paresseux : si pawPointsSpendable absent, = pawPoints (à vie).
  await Model.updateOne(
    { _id: userId, pawPointsSpendable: { $exists: false } },
    [{ $set: { pawPointsSpendable: { $ifNull: ['$pawPoints', 0] } } }],
  ).catch(() => {});
  const debited = await Model.findOneAndUpdate(
    { _id: userId, pawPointsSpendable: { $gte: cost } },
    { $inc: { pawPointsSpendable: -cost } },
    { new: true },
  ).select('pawPointsSpendable');
  if (!debited) return null;
  // v532 — SANS CECI, LES MÊMES POINTS ÉTAIENT DÉPENSABLES TROIS FOIS. Le
  // débit ne touchait que le document du rôle actif ; les profils frères du
  // même compte gardaient leur solde intact, il suffisait de changer de profil
  // pour réclamer à nouveau la récompense. On aligne les trois documents
  // (le nouveau solde étant le plus bas, la synchro par MAX ne peut pas le
  // relever : on écrit donc explicitement la valeur débitée).
  try {
    const { syncPointsAcrossRoles } = require('../services/pawPointsService');
    const newBalance = Number(debited.pawPointsSpendable);
    const me = await Model.findById(userId).select('email pawPoints').lean();
    if (me?.email) {
      await Promise.all(
        [Owner, Sitter, Walker].map((M) => M.updateOne(
          { email: me.email },
          { $set: { pawPointsSpendable: newBalance } },
        ).catch(() => {})),
      );
      // Réaligne aussi le total À VIE (qui, lui, ne baisse jamais).
      await syncPointsAcrossRoles(userId, role);
    }
  } catch (_) { /* best-effort : le débit principal a déjà eu lieu */ }
  return Number(debited.pawPointsSpendable);
}

/**
 * v532 — remboursement des points quand l'octroi de la récompense échoue.
 * Doit toucher les TROIS profils, comme le débit : sinon le solde du rôle
 * actif remontait mais restait plus bas sur les autres, et la synchro par MAX
 * les réalignait ensuite… en rendant les points là où ils n'avaient pas été
 * repris. On recrédite partout la même valeur.
 */
async function _refundPoints(userId, role, cost) {
  try {
    const Model = modelFor(role);
    const back = await Model.findByIdAndUpdate(
      userId,
      { $inc: { pawPointsSpendable: Number(cost) || 0 } },
      { new: true },
    ).select('email pawPointsSpendable');
    if (!back?.email) return;
    await Promise.all(
      [Owner, Sitter, Walker].map((M) => M.updateOne(
        { email: back.email },
        { $set: { pawPointsSpendable: Number(back.pawPointsSpendable) || 0 } },
      ).catch(() => {})),
    );
  } catch (e) {
    logger.error('[pawpoints] remboursement des points échoué', e);
  }
}

// ─── POST /redeem/:id ─────────────────────────────────────────────────────────
router.post('/redeem/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const role = String(req.user?.role || 'owner').toLowerCase();
    const userModel = ROLE_TO_MODEL_NAME[role] || 'Owner';
    const Model = modelFor(role);

    // ── Récompense ABONNEMENT (code-définie) ───────────────────────────────
    const subReward = pawPoints.subscriptionRewardById(id);
    if (subReward) {
      // 1×/user — v532 : dédup sur l'EMAIL, pas sur le document de rôle
      // (sinon la même récompense était réclamable une fois par profil).
      const ident = await _identity(req.user.id, role);
      const already = await PawRewardRedemption.findOne({
        ...(ident.email ? { userEmail: ident.email } : { userId: req.user.id }),
        rewardKey: subReward.id,
        status: { $ne: 'cancelled' },
      }).lean();
      if (already) {
        return res.status(409).json({ error: 'Récompense déjà utilisée.', code: 'ALREADY_CLAIMED' });
      }
      const newBalance = await spendPoints(Model, req.user.id, subReward.cost, role);
      if (newBalance === null) {
        return res.status(400).json({ error: 'Pas assez de PawPoints.', code: 'INSUFFICIENT' });
      }

      let applied = 'pending';
      try {
        if (subReward.kind === 'free_month') {
          // Choix de plan possible (200k : PawFollow ou PawSpot).
          const chosen = typeof req.body?.plan === 'string' && req.body.plan
            ? req.body.plan : subReward.plan;
          await grantFreePeriod({ userId: req.user.id, role, plan: chosen, days: subReward.days });
          applied = 'fulfilled';
        }
        // discount → reste 'pending', consommé au prochain /subscribe.
      } catch (e) {
        // Si l'octroi échoue, on rembourse les points dépensés.
        logger.error('[pawpoints/redeem] grant failed, refunding', e);
        await _refundPoints(req.user.id, role, subReward.cost);
        return res.status(500).json({ error: 'Échec de l\'application, points remboursés.' });
      }

      const me = await Model.findById(req.user.id).select('name email').lean();
      const redemption = await PawRewardRedemption.create({
        rewardKey: subReward.id,
        title: subReward.kind === 'discount'
          ? `-${subReward.percent}% ${subReward.target}`
          : `${subReward.days >= 90 ? '3 mois' : '1 mois'} gratuit ${subReward.target}`,
        cost: subReward.cost,
        userId: req.user.id, userModel, role,
        userName: me?.name || '', userEmail: me?.email || '',
        status: applied,
        snapshot: { ...subReward },
      });
      logger.info(`🎁 [pawpoints] redeem ${subReward.id} (-${subReward.cost}) → ${role}:${req.user.id} (${applied})`);
      return res.json({
        ok: true, newBalance, applied,
        redemptionId: String(redemption._id),
        reward: { id: subReward.id, kind: subReward.kind, cost: subReward.cost },
      });
    }

    // ── Récompense ADMIN custom (ObjectId) ──────────────────────────────────
    if (!mongoose.isValidObjectId(id)) {
      return res.status(404).json({ error: 'Récompense indisponible.' });
    }
    const reward = await PawReward.findById(id);
    if (!reward || !reward.isRedeemable()) {
      return res.status(404).json({ error: 'Récompense indisponible.' });
    }
    const newBalance = await spendPoints(Model, req.user.id, reward.cost, role);
    if (newBalance === null) {
      return res.status(400).json({ error: 'Pas assez de PawPoints.', code: 'INSUFFICIENT' });
    }

    // v450 — Daniel : « vérifie que les récompenses fonctionnent ». RACINE :
    // une récompense admin custom de type `subscription`/`boost` débitait les
    // points mais ne créait qu'une redemption `pending` JAMAIS honorée
    // automatiquement → l'utilisateur perdait ses points pour rien. On
    // OCTROIE désormais immédiatement (comme les récompenses abo intégrées) :
    //   subscription → grantFreePeriod (jours d'abo offerts)
    //   boost        → prolonge boostExpiry du user
    //   discount/badge/goodie → reste 'pending' (réduction consommée à l'achat
    //   ou remise/goodie traités à la main par l'admin).
    let applied = 'pending';
    try {
      if (reward.kind === 'subscription' && reward.plan) {
        await grantFreePeriod({
          userId: req.user.id,
          role,
          plan: reward.plan,
          days: Number(reward.intervalDays) || 30,
        });
        applied = 'fulfilled';
      } else if (reward.kind === 'boost') {
        const now = new Date();
        const u = await Model.findById(req.user.id).select('boostExpiry boostTier');
        if (u) {
          const base = u.boostExpiry && new Date(u.boostExpiry) > now
            ? new Date(u.boostExpiry) : now;
          u.boostExpiry = new Date(base.getTime() + (Number(reward.intervalDays) || 7) * 86400000);
          if (reward.boostTier) u.boostTier = reward.boostTier;
          await u.save();
          applied = 'fulfilled';
        }
      }
    } catch (e) {
      // Octroi échoué → on rembourse les points dépensés.
      logger.error('[pawpoints/redeem] admin reward grant failed, refunding', e);
      await _refundPoints(req.user.id, role, reward.cost);
      return res.status(500).json({ error: 'Échec de l\'application, points remboursés.' });
    }

    reward.redeemedCount = (reward.redeemedCount || 0) + 1;
    await reward.save();
    const me = await Model.findById(req.user.id).select('name email').lean();
    const redemption = await PawRewardRedemption.create({
      rewardId: reward._id, title: reward.title, cost: reward.cost,
      userId: req.user.id, userModel, role,
      userName: me?.name || '', userEmail: me?.email || '',
      status: applied,
      snapshot: {
        kind: reward.kind, plan: reward.plan, intervalDays: reward.intervalDays,
        boostTier: reward.boostTier, valueLabel: reward.valueLabel,
      },
    });
    logger.info(`🎁 [pawpoints] redeem "${reward.title}" (-${reward.cost}) → ${role}:${req.user.id} (${applied})`);
    return res.json({
      ok: true, newBalance, applied,
      redemptionId: String(redemption._id),
      reward: { id: String(reward._id), title: reward.title, cost: reward.cost },
    });
  } catch (e) {
    logger.error('[pawpoints/redeem]', e);
    res.status(500).json({ error: 'Erreur échange.' });
  }
});

module.exports = router;
