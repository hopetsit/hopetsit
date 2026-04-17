/**
 * Boost Routes — Coin Shop & Profile Boosting
 *
 * Tiers:
 *   bronze   → €25  → 3 days
 *   silver   → €50  → 7 days
 *   gold     → €100 → 15 days
 *   platinum → €200 → 30 days
 *
 * Both owners and sitters can boost their profile.
 * Boosted profiles appear first in search/feed results.
 */

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const Sitter = require('../models/Sitter');
const Owner = require('../models/Owner');
const { createPaymentIntent } = require('../services/stripeService');
const logger = require('../utils/logger');

const router = express.Router();

// ── BOOST PACKAGES ───────────────────────────────────────────────────────────
const BOOST_PACKAGES = {
  bronze:   { amount: 25,  days: 3,  label: '3 days'  },
  silver:   { amount: 50,  days: 7,  label: '1 week'  },
  gold:     { amount: 100, days: 15, label: '2 weeks' },
  platinum: { amount: 200, days: 30, label: '1 month' },
};

// ── GET PACKAGES (public info) ───────────────────────────────────────────────
router.get('/packages', (req, res) => {
  const packages = Object.entries(BOOST_PACKAGES).map(([tier, pkg]) => ({
    tier,
    amount: pkg.amount,
    days: pkg.days,
    label: pkg.label,
    currency: 'EUR',
  }));
  res.json({ packages });
});

// ── GET MY BOOST STATUS ──────────────────────────────────────────────────────
router.get('/status', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;
    const role = req.user.role;

    const Model = role === 'sitter' ? Sitter : Owner;
    const user = await Model.findById(userId).select('boostExpiry boostTier boostPurchases').lean();
    if (!user) return res.status(404).json({ error: 'User not found.' });

    const now = new Date();
    const isActive = user.boostExpiry && new Date(user.boostExpiry) > now;
    const remainingMs = isActive ? new Date(user.boostExpiry).getTime() - now.getTime() : 0;
    const remainingHours = Math.max(0, Math.ceil(remainingMs / 3600000));
    const remainingDays = Math.max(0, Math.ceil(remainingMs / 86400000));

    res.json({
      isActive,
      tier: isActive ? user.boostTier : null,
      expiresAt: isActive ? user.boostExpiry : null,
      remainingDays,
      remainingHours,
      purchaseHistory: (user.boostPurchases || []).slice(-10).reverse(),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── PURCHASE BOOST (create Stripe PaymentIntent) ─────────────────────────────
router.post('/purchase', requireAuth, async (req, res) => {
  try {
    const { tier } = req.body;
    const pkg = BOOST_PACKAGES[tier];
    if (!pkg) {
      return res.status(400).json({ error: `Invalid tier. Choose from: ${Object.keys(BOOST_PACKAGES).join(', ')}` });
    }

    const userId = req.user.id;
    const role = req.user.role;

    // Create Stripe PaymentIntent for the boost amount
    const amountCents = pkg.amount * 100; // EUR to cents
    const paymentIntent = await createPaymentIntent({
      amount: amountCents,
      currency: 'eur',
      metadata: {
        type: 'boost_purchase',
        userId,
        role,
        tier,
        days: pkg.days,
      },
    });

    res.json({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      amount: pkg.amount,
      currency: 'EUR',
      tier,
      days: pkg.days,
    });
  } catch (e) {
    logger.error('[boost/purchase] Error creating payment intent', e);
    res.status(500).json({ error: e.message });
  }
});

// ── CONFIRM BOOST (after Stripe payment succeeds) ────────────────────────────
router.post('/confirm', requireAuth, async (req, res) => {
  try {
    const { tier, paymentIntentId } = req.body;
    const pkg = BOOST_PACKAGES[tier];
    if (!pkg) {
      return res.status(400).json({ error: 'Invalid tier.' });
    }

    const userId = req.user.id;
    const role = req.user.role;
    const Model = role === 'sitter' ? Sitter : Owner;

    const user = await Model.findById(userId);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    // Calculate new expiry: extend from current expiry if still active, else from now
    const now = new Date();
    const currentExpiry = user.boostExpiry && new Date(user.boostExpiry) > now
      ? new Date(user.boostExpiry)
      : now;
    const newExpiry = new Date(currentExpiry.getTime() + pkg.days * 86400000);

    user.boostExpiry = newExpiry;
    user.boostTier = tier;
    if (!user.boostPurchases) user.boostPurchases = [];
    user.boostPurchases.push({
      tier,
      amount: pkg.amount,
      currency: 'EUR',
      days: pkg.days,
      purchasedAt: now,
      paymentProvider: 'stripe',
      paymentId: paymentIntentId || '',
    });

    await user.save();

    logger.info(`[boost] ${role} ${userId} purchased ${tier} boost (${pkg.days} days) — expires ${newExpiry.toISOString()}`);

    res.json({
      message: 'Boost activated!',
      tier,
      days: pkg.days,
      expiresAt: newExpiry,
      remainingDays: pkg.days,
    });
  } catch (e) {
    logger.error('[boost/confirm] Error', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
