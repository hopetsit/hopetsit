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
    // Récompenses abonnement déjà réclamées (1×/user).
    const claimed = await PawRewardRedemption.find({
      userId: req.user.id, rewardKey: { $regex: '^sub_' },
      status: { $ne: 'cancelled' },
    }).select('rewardKey status').lean();
    res.json({
      points: st.lifetime,           // total à vie (= niveau)
      lifetime: st.lifetime,
      spendable: st.spendable,        // solde dépensable
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
async function spendPoints(Model, userId, cost) {
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
  return debited ? Number(debited.pawPointsSpendable) : null;
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
      // 1×/user.
      const already = await PawRewardRedemption.findOne({
        userId: req.user.id, rewardKey: subReward.id, status: { $ne: 'cancelled' },
      }).lean();
      if (already) {
        return res.status(409).json({ error: 'Récompense déjà utilisée.', code: 'ALREADY_CLAIMED' });
      }
      const newBalance = await spendPoints(Model, req.user.id, subReward.cost);
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
        await Model.updateOne({ _id: req.user.id }, { $inc: { pawPointsSpendable: subReward.cost } }).catch(() => {});
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
    const newBalance = await spendPoints(Model, req.user.id, reward.cost);
    if (newBalance === null) {
      return res.status(400).json({ error: 'Pas assez de PawPoints.', code: 'INSUFFICIENT' });
    }
    reward.redeemedCount = (reward.redeemedCount || 0) + 1;
    await reward.save();
    const me = await Model.findById(req.user.id).select('name email').lean();
    const redemption = await PawRewardRedemption.create({
      rewardId: reward._id, title: reward.title, cost: reward.cost,
      userId: req.user.id, userModel, role,
      userName: me?.name || '', userEmail: me?.email || '',
      status: 'pending',
      snapshot: {
        kind: reward.kind, plan: reward.plan, intervalDays: reward.intervalDays,
        boostTier: reward.boostTier, valueLabel: reward.valueLabel,
      },
    });
    logger.info(`🎁 [pawpoints] redeem "${reward.title}" (-${reward.cost}) → ${role}:${req.user.id}`);
    return res.json({
      ok: true, newBalance, applied: 'pending',
      redemptionId: String(redemption._id),
      reward: { id: String(reward._id), title: reward.title, cost: reward.cost },
    });
  } catch (e) {
    logger.error('[pawpoints/redeem]', e);
    res.status(500).json({ error: 'Erreur échange.' });
  }
});

module.exports = router;
