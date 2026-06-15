/**
 * pawPointsRoutes — v414 (Daniel : "améliore la liste de points et de
 * récompenses", "que je vois le classement", "gérer les offres et récompenses
 * directement de l'admin sans rebuild", "visible sur le site web").
 *
 * Endpoints PUBLICS / utilisateur (la gestion admin des récompenses est dans
 * adminRoutes.js sous /admin/pawpoints/rewards) :
 *   GET  /pawpoints/catalog        → liste des récompenses actives (app + site).
 *                                     Pas d'auth : l'accueil/landing peut l'afficher.
 *   GET  /pawpoints/me             → mes points, badge, prochain badge, comment
 *                                     gagner des points (role-agnostic, auth).
 *   POST /pawpoints/redeem/:id     → échanger mes points contre une récompense.
 *
 * 100% ADDITIF — aucune route existante touchée. L'app LIT le catalogue depuis
 * le backend → on peut ajouter/retirer une récompense sans rebuild.
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
const logger = require('../utils/logger');

const router = express.Router();

const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };
const modelFor = (role) => {
  const r = String(role || '').toLowerCase();
  return r === 'walker' ? Walker : r === 'sitter' ? Sitter : Owner;
};

// Comment gagner des points (miroir de pawPointsService.POINTS, libellés FR).
// Renvoyé tel quel : l'app/site affiche ce que le backend dit → pas de rebuild
// si on change les montants côté service.
const earnRules = () => ([
  { key: 'spotCreated', points: pawPoints.POINTS.spotCreated, label: 'Ajouter un PawSpot', icon: '📍' },
  { key: 'photoAdded', points: pawPoints.POINTS.photoAdded, label: 'Ajouter une photo', icon: '📷' },
  { key: 'spotValidated', points: pawPoints.POINTS.spotValidated, label: 'Spot validé par la communauté', icon: '✅' },
  { key: 'usefulComment', points: pawPoints.POINTS.usefulComment, label: 'Commentaire utile', icon: '💬' },
  { key: 'correctReport', points: pawPoints.POINTS.correctReport, label: 'Signalement confirmé', icon: '🚧' },
  { key: 'spotPopular', points: pawPoints.POINTS.spotPopular, label: 'Spot très populaire (50 likes)', icon: '⭐' },
]);

const badgesList = () => pawPoints.BADGES.map((b) => ({ key: b.key, emoji: b.emoji, min: b.min }))
  .sort((a, b) => a.min - b.min);

// ─── GET /pawpoints/catalog — récompenses actives + barème + badges. PUBLIC.
router.get('/catalog', async (req, res) => {
  try {
    const rewards = await PawReward.find({ isActive: true })
      .sort({ sortOrder: 1, cost: 1 })
      .lean();
    const list = rewards.map((r) => ({
      id: String(r._id),
      title: r.title,
      description: r.description || '',
      icon: r.icon || '🎁',
      cost: r.cost || 0,
      kind: r.kind || 'discount',
      valueLabel: r.valueLabel || '',
      soldOut: !!(r.stock && r.stock > 0 && (r.redeemedCount || 0) >= r.stock),
    }));
    res.json({
      rewards: list,
      earnRules: earnRules(),
      badges: badgesList(),
      goldCreatorMin: pawPoints.GOLD_CREATOR_MIN,
    });
  } catch (e) {
    logger.error('[pawpoints/catalog]', e);
    res.status(500).json({ error: 'Erreur catalogue.' });
  }
});

// ─── GET /pawpoints/me — mes points + badge (tous rôles).
router.get('/me', requireAuth, async (req, res) => {
  try {
    const role = req.user?.role || 'owner';
    const points = await pawPoints.getPoints(req.user.id, role);
    res.json({
      points,
      badge: pawPoints.badgeFor(points),
      nextBadge: pawPoints.nextBadgeFor(points),
      isGoldCreator: pawPoints.isGoldCreator(points),
      goldCreatorMin: pawPoints.GOLD_CREATOR_MIN,
      earnRules: earnRules(),
      badges: badgesList(),
    });
  } catch (e) {
    logger.error('[pawpoints/me]', e);
    res.status(500).json({ error: 'Erreur points.' });
  }
});

// ─── POST /pawpoints/redeem/:id — échanger des points contre une récompense.
router.post('/redeem/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.isValidObjectId(id)) {
      return res.status(400).json({ error: 'Récompense invalide.' });
    }
    const reward = await PawReward.findById(id);
    if (!reward || !reward.isRedeemable()) {
      return res.status(404).json({ error: 'Récompense indisponible.' });
    }
    const role = req.user?.role || 'owner';
    const Model = modelFor(role);
    const me = await Model.findById(req.user.id).select('name email pawPoints');
    if (!me) return res.status(404).json({ error: 'Utilisateur introuvable.' });
    const have = Number(me.pawPoints) || 0;
    if (have < reward.cost) {
      return res.status(400).json({ error: 'Pas assez de PawPoints.', need: reward.cost, have });
    }
    // Débit atomique conditionné au solde (anti double-dépense en concurrence).
    const debited = await Model.findOneAndUpdate(
      { _id: req.user.id, pawPoints: { $gte: reward.cost } },
      { $inc: { pawPoints: -reward.cost } },
      { new: true },
    ).select('pawPoints');
    if (!debited) {
      return res.status(400).json({ error: 'Pas assez de PawPoints.' });
    }
    reward.redeemedCount = (reward.redeemedCount || 0) + 1;
    await reward.save();
    const redemption = await PawRewardRedemption.create({
      rewardId: reward._id,
      title: reward.title,
      cost: reward.cost,
      userId: req.user.id,
      userModel: ROLE_TO_MODEL_NAME[String(role).toLowerCase()] || 'Owner',
      role,
      userName: me.name || '',
      userEmail: me.email || '',
      status: 'pending',
      snapshot: {
        kind: reward.kind, plan: reward.plan, intervalDays: reward.intervalDays,
        boostTier: reward.boostTier, valueLabel: reward.valueLabel,
      },
    });
    logger.info(`🎁 [pawpoints] redeem "${reward.title}" (-${reward.cost}) → ${role}:${req.user.id}`);
    res.json({
      ok: true,
      newBalance: debited.pawPoints,
      redemptionId: String(redemption._id),
      reward: { id: String(reward._id), title: reward.title, cost: reward.cost },
    });
  } catch (e) {
    logger.error('[pawpoints/redeem]', e);
    res.status(500).json({ error: 'Erreur échange.' });
  }
});

module.exports = router;
