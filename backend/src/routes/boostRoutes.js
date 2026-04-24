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
const pricingService = require('../services/pricingService');

const router = express.Router();

// ── BOOST PACKAGES — multi-currency pricing ──────────────────────────────────
// Base amounts in EUR; other currencies scale to clean local values.
const BOOST_PACKAGES = {
  bronze:   { days: 3,  label: '3 days'  },
  silver:   { days: 7,  label: '1 week'  },
  gold:     { days: 15, label: '2 weeks' },
  platinum: { days: 30, label: '1 month' },
};

// Phase-1 price cut (session avril 2026) — previous prices (25/50/100/200 EUR)
// were too aggressive and killed conversion. Lowered to a .99 psychological
// range to make the boost much more attractive. Phase 2 will move these into
// DB-backed PricingConfig so admin can tweak from the dashboard without code
// changes; these values remain as fallback defaults.
const BOOST_PRICING = {
  EUR: { bronze: 4.99,  silver: 9.99,  gold: 14.99, platinum: 24.99 },
  GBP: { bronze: 4.39,  silver: 8.79,  gold: 13.29, platinum: 21.99 },
  CHF: { bronze: 4.99,  silver: 9.99,  gold: 14.99, platinum: 24.99 },
  USD: { bronze: 5.49,  silver: 10.99, gold: 16.49, platinum: 27.49 },
};

function getBoostPricing(tier, currency = 'EUR') {
  const pkg = BOOST_PACKAGES[tier];
  if (!pkg) return null;
  const upper = String(currency || 'EUR').toUpperCase();
  // Pull live prices from pricingService (DB-backed, admin-editable). The
  // hardcoded BOOST_PRICING constant above is now just a last-resort fallback
  // if the service somehow has no row for this currency.
  const servicePricing = pricingService.get('boost') || {};
  const row =
    servicePricing[upper] ||
    servicePricing.EUR ||
    BOOST_PRICING[upper] ||
    BOOST_PRICING.EUR;
  return {
    tier,
    amount: row[tier],
    currency: servicePricing[upper] || BOOST_PRICING[upper] ? upper : 'EUR',
    days: pkg.days,
    label: pkg.label,
  };
}

// ── GET PACKAGES (public info) — accepts ?currency=EUR|GBP|CHF|USD ──────────
router.get('/packages', (req, res) => {
  const currency = normalizeCurrency(req.query.currency);
  const packages = Object.keys(BOOST_PACKAGES).map((tier) => getBoostPricing(tier, currency));
  const servicePricing = pricingService.get('boost');
  res.json({
    packages,
    currency,
    supportedCurrencies: servicePricing
      ? Object.keys(servicePricing)
      : Object.keys(BOOST_PRICING),
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

// v19.1.3 — BUY BOOST WITH WALLET BALANCE (sitter/walker only).
// Debits the wallet atomically and applies the boost in one call, so the
// provider's earnings can fund their own visibility upgrade without touching
// Stripe. Fails with 402 INSUFFICIENT_BALANCE if the wallet is short.
const { debitWallet } = require('../services/walletService');
router.post('/purchase/wallet', requireAuth, async (req, res) => {
  try {
    const { tier } = req.body;
    const currency = normalizeCurrency(req.body.currency);
    const pricing = getBoostPricing(tier, currency);
    if (!pricing) {
      return res.status(400).json({ error: 'Invalid tier.' });
    }
    const userId = req.user.id;
    const role = req.user.role;
    if (role !== 'sitter' && role !== 'walker') {
      return res.status(403).json({
        error: 'Wallet payment is only available for sitters and walkers.',
      });
    }

    // Debit first so we never activate a boost we couldn't charge for.
    try {
      await debitWallet({
        userId,
        userRole: role,
        amount: pricing.amount,
        currency: pricing.currency,
        type: 'debit_shop',
        productType: `boost_${tier}`,
        meta: { tier, days: pricing.days, source: 'boost/purchase/wallet' },
      });
    } catch (err) {
      if (err.code === 'INSUFFICIENT_BALANCE') {
        return res
          .status(402)
          .json({ error: 'Insufficient wallet balance.', code: 'INSUFFICIENT_BALANCE' });
      }
      throw err;
    }

    const Model = role === 'walker' ? require('../models/Walker') : Sitter;
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
      paymentProvider: 'wallet',
      paymentId: '',
    });
    await user.save();

    logger.info(
      `[boost/wallet] ${role} ${userId} bought ${tier} via wallet (${pricing.currency} ${pricing.amount}) — expires ${newExpiry.toISOString()}`,
    );

    res.json({
      message: 'Boost activated with wallet balance.',
      paymentMethod: 'wallet',
      tier,
      days: pricing.days,
      amount: pricing.amount,
      currency: pricing.currency,
      expiresAt: newExpiry,
      remainingDays: pricing.days,
    });
  } catch (e) {
    logger.error('[boost/purchase/wallet] Error', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
