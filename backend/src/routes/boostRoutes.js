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
const { createPlatformPaymentIntent } = require('../services/stripeService');
const { normalizeCurrency } = require('../utils/currency');
const logger = require('../utils/logger');

const router = express.Router();

// ── BOOST PACKAGES — multi-currency pricing ──────────────────────────────────
// Base amounts in EUR; other currencies scale to clean local values.
const BOOST_PACKAGES = {
  bronze:   { days: 3,  label: '3 days'  },
  silver:   { days: 7,  label: '1 week'  },
  gold:     { days: 15, label: '2 weeks' },
  platinum: { days: 30, label: '1 month' },
};

const BOOST_PRICING = {
  EUR: { bronze: 25,  silver: 50,  gold: 100, platinum: 200 },
  GBP: { bronze: 22,  silver: 44,  gold: 89,  platinum: 179 },
  CHF: { bronze: 25,  silver: 49,  gold: 99,  platinum: 199 },
  USD: { bronze: 27,  silver: 54,  gold: 109, platinum: 219 },
};

function getBoostPricing(tier, currency = 'EUR') {
  const pkg = BOOST_PACKAGES[tier];
  if (!pkg) return null;
  const upper = String(currency || 'EUR').toUpperCase();
  const row = BOOST_PRICING[upper] || BOOST_PRICING.EUR;
  return {
    tier,
    amount: row[tier],
    currency: BOOST_PRICING[upper] ? upper : 'EUR',
    days: pkg.days,
    label: pkg.label,
  };
}

// ── GET PACKAGES (public info) — accepts ?currency=EUR|GBP|CHF|USD ──────────
router.get('/packages', (req, res) => {
  const currency = normalizeCurrency(req.query.currency);
  const packages = Object.keys(BOOST_PACKAGES).map((tier) => getBoostPricing(tier, currency));
  res.json({
    packages,
    currency,
    supportedCurrencies: Object.keys(BOOST_PRICING),
  });
});

// ── GET MY BOOST STATUS ──────────────────────────────────────────────────────
router.get('/status', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;
    const role = req.user.role;

    let Model;
    if (role === 'walker') {
      Model = require('../models/Walker');
    } else if (role === 'sitter') {
      Model = Sitter;
    } else {
      Model = Owner;
    }
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
    const currency = normalizeCurrency(req.body.currency);
    const pricing = getBoostPricing(tier, currency);
    if (!pricing) {
      return res.status(400).json({ error: `Invalid tier. Choose from: ${Object.keys(BOOST_PACKAGES).join(', ')}` });
    }

    const userId = req.user.id;
    const role = req.user.role;

    const amountCents = Math.round(pricing.amount * 100);
    const paymentIntent = await createPlatformPaymentIntent({
      amount: amountCents,
      currency: pricing.currency.toLowerCase(),
      metadata: {
        type: 'boost_purchase',
        userId,
        role,
        tier,
        currency: pricing.currency,
        days: pricing.days,
      },
    });

    res.json({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      amount: pricing.amount,
      currency: pricing.currency,
      tier,
      days: pricing.days,
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
    const currency = normalizeCurrency(req.body.currency);
    const pricing = getBoostPricing(tier, currency);
    if (!pricing) {
      return res.status(400).json({ error: 'Invalid tier.' });
    }

    const userId = req.user.id;
    const role = req.user.role;
    // Route Walker to Walker model; Sitter to Sitter; else Owner.
    let Model;
    if (role === 'walker') {
      Model = require('../models/Walker');
    } else if (role === 'sitter') {
      Model = Sitter;
    } else {
      Model = Owner;
    }

    const user = await Model.findById(userId);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    const now = new Date();
    const currentExpiry = user.boostExpiry && new Date(user.boostExpiry) > now
      ? new Date(user.boostExpiry)
      : now;
    const newExpiry = new Date(currentExpiry.getTime() + pricing.days * 86400000);

    user.boostExpiry = newExpiry;
    user.boostTier = tier;
    if (!user.boostPurchases) user.boostPurchases = [];
    user.boostPurchases.push({
      tier,
      amount: pricing.amount,
      currency: pricing.currency,
      days: pricing.days,
      purchasedAt: now,
      paymentProvider: 'stripe',
      paymentId: paymentIntentId || '',
    });

    await user.save();

    logger.info(`[boost] ${role} ${userId} purchased ${tier} boost (${pricing.days} days, ${pricing.currency} ${pricing.amount}) — expires ${newExpiry.toISOString()}`);

    res.json({
      message: 'Boost activated!',
      tier,
      days: pricing.days,
      currency: pricing.currency,
      amount: pricing.amount,
      expiresAt: newExpiry,
      remainingDays: pricing.days,
    });
  } catch (e) {
    logger.error('[boost/confirm] Error', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
