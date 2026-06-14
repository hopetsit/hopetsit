const express = require('express');
const { requireAuth } = require('../middleware/auth');
const PromoCode = require('../models/PromoCode');
const PromoCodeRedemption = require('../models/PromoCodeRedemption');
const UserSubscription = require('../models/UserSubscription');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const logger = require('../utils/logger');

// v402 — Chantier 2 : redemption d'un code promo côté UTILISATEUR.
// 100% additif. L'app ne l'appelle PAS encore (l'onglet "Offre / code promo"
// dans le profil owner/sitter/walker viendra avec un rebuild, après la vidéo).
// Donc : aucun impact sur l'app actuelle.
const router = express.Router();

const roleModel = (role) => (role === 'walker' ? Walker : role === 'sitter' ? Sitter : Owner);
const roleModelName = (role) => (role === 'walker' ? 'Walker' : role === 'sitter' ? 'Sitter' : 'Owner');

// Applique une récompense free_subscription. Réplique SANS risque la logique
// d'activation d'achat (le webhook de paiement n'est pas modifié).
async function grantPromoSubscription({ userId, role, plan, intervalDays, boostTier }) {
  const now = new Date();

  // PawBoost = palier temporaire sur le doc user (pas un timer d'abo).
  if (plan === 'pawboost') {
    const Model = roleModel(role);
    const user = await Model.findById(userId);
    if (!user) throw new Error('User not found');
    const base = user.boostExpiry && new Date(user.boostExpiry) > now
      ? new Date(user.boostExpiry) : now;
    user.boostExpiry = new Date(base.getTime() + (Number(intervalDays) || 30) * 86400000);
    user.boostTier = boostTier || user.boostTier || 'bronze';
    await user.save();
    return { kind: 'pawboost', tier: user.boostTier, expiry: user.boostExpiry };
  }

  // Abonnements (PawFollow / PawFamily / PawPremium / PawSpot) → timers sur
  // UserSubscription, mêmes règles que l'achat (timers découplés).
  const userModelName = roleModelName(role);
  let sub = await UserSubscription.findOne({ userId, userModel: userModelName });
  if (!sub) {
    sub = new UserSubscription({
      userId, userModel: userModelName, plan, status: 'active', activatedAt: now, currency: 'EUR',
    });
  }
  const {
    isFamilyPlan, isPremiumPlan, migrateLegacyFamily, syncSubscriptionAcrossRoles,
  } = require('../models/UserSubscription');
  const planCanonical = plan === 'family' ? 'famille' : plan;
  try { migrateLegacyFamily(sub, now); } catch (_) { /* defensive */ }
  const days = Number(intervalDays) || 30;
  const extendFrom = (d) =>
    new Date((d && new Date(d) > now ? new Date(d) : now).getTime() + days * 86400000);

  if (plan === 'pawspot') {
    sub.pawspotExpiry = extendFrom(sub.pawspotExpiry);
    sub.status = 'active';
  } else if (isFamilyPlan(planCanonical)) {
    sub.familyExpiry = extendFrom(sub.familyExpiry);
    sub.status = 'active';
  } else if (isPremiumPlan(planCanonical)) {
    const e = extendFrom(sub.currentPeriodEnd);
    sub.plan = planCanonical;
    sub.status = 'active';
    sub.currentPeriodStart = sub.currentPeriodStart || now;
    sub.currentPeriodEnd = e;
    sub.expiresAt = e;
    sub.pawspotExpiry = extendFrom(sub.pawspotExpiry);
    sub.premiumExpiry = extendFrom(sub.premiumExpiry);
  } else {
    const e = extendFrom(sub.currentPeriodEnd);
    sub.plan = planCanonical;
    sub.status = 'active';
    sub.currentPeriodStart = sub.currentPeriodStart || now;
    sub.currentPeriodEnd = e;
    sub.expiresAt = e;
  }
  sub.history = sub.history || [];
  sub.history.push({
    plan: planCanonical, paymentProvider: 'promo', activatedAt: now, intervalDays: days,
  });
  await sub.save();
  try { await syncSubscriptionAcrossRoles(userId, userModelName); } catch (_) { /* best-effort */ }
  return { kind: 'subscription', plan: planCanonical, intervalDays: days };
}

// POST /promo/check  { code } — prévisualise sans consommer.
router.post('/check', requireAuth, async (req, res) => {
  try {
    const code = String(req.body?.code || '').trim().toUpperCase();
    if (!code) return res.status(400).json({ error: 'Code requis.' });
    const promo = await PromoCode.findOne({ code });
    if (!promo || !promo.isRedeemable()) {
      return res.status(404).json({ valid: false, error: 'Code invalide ou expiré.' });
    }
    return res.json({
      valid: true,
      rewardType: promo.rewardType,
      plan: promo.plan,
      intervalDays: promo.intervalDays,
      boostTier: promo.boostTier,
      discountPercent: promo.discountPercent,
      campaign: promo.campaign,
    });
  } catch (e) {
    logger.error('[promo/check]', e);
    return res.status(500).json({ error: 'Erreur.' });
  }
});

// POST /promo/redeem  { code } — consomme le code + active la récompense.
router.post('/redeem', requireAuth, async (req, res) => {
  try {
    const code = String(req.body?.code || '').trim().toUpperCase();
    const userId = req.user.id;
    const role = req.user.role;
    if (!code) return res.status(400).json({ error: 'Code requis.' });

    const promo = await PromoCode.findOne({ code });
    if (!promo || !promo.isRedeemable()) {
      return res.status(404).json({ error: 'Code invalide ou expiré.' });
    }
    const already = await PromoCodeRedemption.findOne({ promoCodeId: promo._id, userId });
    if (already) return res.status(409).json({ error: 'Code déjà utilisé.' });

    let reward = {};
    if (promo.rewardType === 'free_subscription') {
      reward = await grantPromoSubscription({
        userId, role, plan: promo.plan, intervalDays: promo.intervalDays, boostTier: promo.boostTier,
      });
    } else {
      reward = { kind: 'percent_discount', discountPercent: promo.discountPercent, plan: promo.plan };
    }

    try {
      await PromoCodeRedemption.create({
        promoCodeId: promo._id, code, userId, userModel: roleModelName(role), role, reward,
      });
    } catch (e) {
      if (e && e.code === 11000) return res.status(409).json({ error: 'Code déjà utilisé.' });
      throw e;
    }
    promo.usedCount = (promo.usedCount || 0) + 1;
    await promo.save();

    return res.json({ ok: true, reward });
  } catch (e) {
    logger.error('[promo/redeem]', e);
    return res.status(500).json({ error: "Impossible d'appliquer le code." });
  }
});

module.exports = router;
