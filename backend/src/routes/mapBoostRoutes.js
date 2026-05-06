/**
 * Map Boost Routes — Phase 5 Couche 4 of the PawMap.
 *
 * Different from the profile boost (boostRoutes.js): this boost highlights the
 * user's PIN on PawMap so nearby owners/sitters/walkers see them first.
 *
 * Tiers (multi-currency — same shape as profile boost, cheaper tiers):
 *   bronze   → 3 days
 *   silver   → 7 days
 *   gold     → 15 days
 *   platinum → 30 days
 *
 * Premium users can claim 1 free monthly map-boost day via the
 * mapBoostCreditsRemaining field on UserSubscription (yearly = 12 credits).
 */

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const airwallex = require('../services/airwallexService');
const UserSubscription = require('../models/UserSubscription');
const { normalizeCurrency } = require('../utils/currency');
const logger = require('../utils/logger');
const pricingService = require('../services/pricingService');

const router = express.Router();

// v21.1.1 — Stripe purgé. Default 'airwallex'.
const PROVIDER = (process.env.PAYMENT_PROVIDER || 'airwallex').toLowerCase();

// v23.1 — aligned with website hopetsit.com/pawmap :
//   bronze   = "PawSpot 24h"    → 1 day
//   silver   = "PawSpot 7 jours" → 7 days
//   gold     = legacy intermediate tier (15 days, kept for back-compat)
//   platinum = "PawSpot 30 jours" → 30 days
const MAP_BOOST_PACKAGES = {
  bronze: { days: 1, label: '24h' },
  silver: { days: 7, label: '1 week' },
  gold: { days: 15, label: '2 weeks' },
  platinum: { days: 30, label: '1 month' },
};

// v23.1 — fallback aligned with website pricing AND with pricingService DEFAULTS.
// Source of truth = pricingService.get('mapBoost'). This list is only used if
// pricingService is not initialized yet (rare).
const MAP_BOOST_PRICING = {
  EUR: { bronze: 1.99, silver: 8.99,  gold: 14.99, platinum: 24.99 },
  GBP: { bronze: 1.69, silver: 7.99,  gold: 13.29, platinum: 21.99 },
  CHF: { bronze: 1.99, silver: 8.99,  gold: 14.99, platinum: 24.99 },
  USD: { bronze: 2.19, silver: 9.89,  gold: 16.49, platinum: 27.49 },
};

function getMapBoostPricing(tier, currency = 'EUR') {
  const pkg = MAP_BOOST_PACKAGES[tier];
  if (!pkg) return null;
  const upper = String(currency || 'EUR').toUpperCase();
  // Live prices via pricingService (DB-backed); MAP_BOOST_PRICING stays as
  // a compile-time fallback if the service is not initialized yet.
  const servicePricing = pricingService.get('mapBoost') || {};
  const row =
    servicePricing[upper] ||
    servicePricing.EUR ||
    MAP_BOOST_PRICING[upper] ||
    MAP_BOOST_PRICING.EUR;
  return {
    tier,
    amount: row[tier],
    currency:
      servicePricing[upper] || MAP_BOOST_PRICING[upper] ? upper : 'EUR',
    days: pkg.days,
    label: pkg.label,
  };
}

function roleToModel(role) {
  if (role === 'walker') return require('../models/Walker');
  if (role === 'sitter') return Sitter;
  return Owner;
}

function roleToModelName(role) {
  if (role === 'walker') return 'Walker';
  if (role === 'sitter') return 'Sitter';
  return 'Owner';
}

// ── GET /packages — multi-currency pricing ─────────────────────────────────
router.get('/packages', (req, res) => {
  const currency = normalizeCurrency(req.query.currency);
  const packages = Object.keys(MAP_BOOST_PACKAGES).map((tier) =>
    getMapBoostPricing(tier, currency),
  );
  const servicePricing = pricingService.get('mapBoost');
  res.json({
    packages,
    currency,
    supportedCurrencies: servicePricing
      ? Object.keys(servicePricing)
      : Object.keys(MAP_BOOST_PRICING),
  });
});

// ── GET /status — current map boost status ─────────────────────────────────
router.get('/status', requireAuth, async (req, res) => {
  try {
    const Model = roleToModel(req.user.role);
    const user = await Model.findById(req.user.id)
      .select('mapBoostExpiry mapBoostTier boostPurchases')
      .lean();
    if (!user) return res.status(404).json({ error: 'User not found.' });

    const now = new Date();
    const isActive = user.mapBoostExpiry && new Date(user.mapBoostExpiry) > now;
    const remainingMs = isActive
      ? new Date(user.mapBoostExpiry).getTime() - now.getTime()
      : 0;
    const remainingDays = Math.max(0, Math.ceil(remainingMs / 86_400_000));

    // Check premium credits
    const sub = await UserSubscription.findOne({
      userId: req.user.id,
      userModel: roleToModelName(req.user.role),
    }).lean();
    const mapBoostCreditsRemaining = sub?.mapBoostCreditsRemaining || 0;

    res.json({
      isActive,
      tier: isActive ? user.mapBoostTier : null,
      expiresAt: isActive ? user.mapBoostExpiry : null,
      remainingDays,
      mapBoostCreditsRemaining,
      purchaseHistory: (user.boostPurchases || [])
        .filter((p) => p.kind === 'map')
        .slice(-10)
        .reverse(),
    });
  } catch (e) {
    logger.error('[mapBoost/status]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /purchase — Stripe PaymentIntent ──────────────────────────────────
router.post('/purchase', requireAuth, async (req, res) => {
  try {
    const { tier } = req.body;
    const currency = normalizeCurrency(req.body.currency);
    const pricing = getMapBoostPricing(tier, currency);
    if (!pricing) {
      return res.status(400).json({
        error: `Invalid tier. Choose from: ${Object.keys(MAP_BOOST_PACKAGES).join(', ')}`,
      });
    }

    // v20.0.2 — Staff users (Daniel + employees) get Map Boost for free.
    // We short-circuit Stripe entirely: activate expiry directly and return
    // a `staff: true` flag so the frontend skips the payment sheet.
    const Model = roleToModel(req.user.role);
    const userDoc = await Model.findById(req.user.id);
    if (!userDoc) return res.status(404).json({ error: 'User not found.' });
    if (userDoc.isStaff) {
      const now = new Date();
      const currentExpiry = userDoc.mapBoostExpiry && new Date(userDoc.mapBoostExpiry) > now
        ? new Date(userDoc.mapBoostExpiry)
        : now;
      const newExpiry = new Date(currentExpiry.getTime() + pricing.days * 86_400_000);
      userDoc.mapBoostExpiry = newExpiry;
      userDoc.mapBoostTier = tier;
      userDoc.boostPurchases = userDoc.boostPurchases || [];
      userDoc.boostPurchases.push({
        tier,
        amount: 0,
        currency: pricing.currency,
        days: pricing.days,
        purchasedAt: now,
        paymentProvider: 'staff_free',
        paymentId: '',
        kind: 'map',
      });
      await userDoc.save();
      logger.info(
        `[mapBoost/staff] ${req.user.role} ${req.user.id} activated ${tier} FREE (staff) → ${newExpiry.toISOString()}`,
      );
      return res.json({
        staff: true,
        activated: true,
        tier,
        days: pricing.days,
        currency: pricing.currency,
        amount: 0,
        expiresAt: newExpiry,
      });
    }

    const amountCents = Math.round(pricing.amount * 100);

    // ─── Airwallex flow ────────────────────────────────────────────────────
    if (PROVIDER === 'airwallex') {
      try {
        // v23.1 part 62 — attach customer_id so the HPP auto-displays the
        // user's saved cards on PawMap boost purchases (no manual CB
        // re-entry). userDoc was loaded above for the staff path.
        let airwallexCustomerId = null;
        try {
          if (userDoc && userDoc.email) {
            const customer = await airwallex.findOrCreateCustomer({
              userId: String(req.user.id),
              email: userDoc.email,
              firstName: (userDoc.name || '').split(' ')[0] || userDoc.name || '',
              lastName: (userDoc.name || '').split(' ').slice(1).join(' ') || '',
            });
            airwallexCustomerId = customer?.id || null;
          }
        } catch (custErr) {
          logger.warn(`[mapBoost] customer ensure failed: ${custErr?.message || custErr}`);
        }

        const intent = await airwallex.createPlatformPaymentIntent({
          amount: amountCents,
          currency: pricing.currency,
          ...(airwallexCustomerId ? { customer_id: airwallexCustomerId } : {}),
          metadata: {
            type: 'map_boost_purchase',
            userId: String(req.user.id),
            role: req.user.role,
            tier,
            currency: pricing.currency,
            days: String(pricing.days),
          },
        });

        logger.info(
          `[mapBoost] airwallex PI created ${intent.id} ${pricing.amount} ${pricing.currency} ` +
          `tier ${tier} by ${req.user.role} ${req.user.id}`,
        );

        return res.json({
          clientSecret: intent.client_secret,
          paymentIntentId: intent.id,
          provider: 'airwallex',
          tier,
          amount: pricing.amount,
          currency: pricing.currency,
          days: pricing.days,
        });
      } catch (e) {
        logger.error('[mapBoost] airwallex create-intent failed', e);
        return res.status(502).json({
          error: 'Unable to start map boost purchase right now. Please try again later.',
        });
      }
    }

    // ─── Stripe disabled (v21.1.1 purge) ─────────────────────────────────
    return res.status(502).json({ error: 'Stripe payment disabled — Airwallex only' });
  } catch (e) {
    logger.error('[mapBoost/purchase]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /confirm — after Stripe succeeds, extend the user's mapBoostExpiry ─
router.post('/confirm', requireAuth, async (req, res) => {
  try {
    const { tier, paymentIntentId } = req.body;
    const currency = normalizeCurrency(req.body.currency);
    const pricing = getMapBoostPricing(tier, currency);
    if (!pricing) return res.status(400).json({ error: 'Invalid tier.' });

    const Model = roleToModel(req.user.role);
    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    const now = new Date();
    const currentExpiry = user.mapBoostExpiry && new Date(user.mapBoostExpiry) > now
      ? new Date(user.mapBoostExpiry)
      : now;
    const newExpiry = new Date(currentExpiry.getTime() + pricing.days * 86_400_000);

    user.mapBoostExpiry = newExpiry;
    user.mapBoostTier = tier;
    if (!user.boostPurchases) user.boostPurchases = [];
    user.boostPurchases.push({
      tier,
      amount: pricing.amount,
      currency: pricing.currency,
      days: pricing.days,
      purchasedAt: now,
      paymentProvider: 'stripe',
      paymentId: paymentIntentId || '',
      kind: 'map',
    });
    await user.save();

    logger.info(
      `[mapBoost] ${req.user.role} ${req.user.id} activated ${tier} (${pricing.days}d, ${pricing.currency} ${pricing.amount}) → ${newExpiry.toISOString()}`,
    );

    res.json({
      message: 'Map boost activated!',
      tier,
      days: pricing.days,
      amount: pricing.amount,
      currency: pricing.currency,
      expiresAt: newExpiry,
    });
  } catch (e) {
    logger.error('[mapBoost/confirm]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /claim-credit — Premium users redeem 1 monthly map-boost credit ───
router.post('/claim-credit', requireAuth, async (req, res) => {
  try {
    const sub = await UserSubscription.findOne({
      userId: req.user.id,
      userModel: roleToModelName(req.user.role),
    });
    if (!sub) {
      return res.status(402).json({
        error: 'Premium subscription required.',
        code: 'PREMIUM_REQUIRED',
      });
    }
    if (!sub.mapBoostCreditsRemaining || sub.mapBoostCreditsRemaining <= 0) {
      return res.status(400).json({
        error: 'No map-boost credits remaining this period.',
      });
    }

    // 1 credit = 3 days (bronze-equivalent) on the map.
    const CREDIT_DAYS = 3;
    const Model = roleToModel(req.user.role);
    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    const now = new Date();
    const currentExpiry = user.mapBoostExpiry && new Date(user.mapBoostExpiry) > now
      ? new Date(user.mapBoostExpiry)
      : now;
    user.mapBoostExpiry = new Date(currentExpiry.getTime() + CREDIT_DAYS * 86_400_000);
    user.mapBoostTier = user.mapBoostTier || 'bronze';
    user.boostPurchases = user.boostPurchases || [];
    user.boostPurchases.push({
      tier: 'bronze',
      amount: 0,
      currency: 'EUR',
      days: CREDIT_DAYS,
      purchasedAt: now,
      paymentProvider: 'premium_credit',
      paymentId: '',
      kind: 'map',
    });
    await user.save();

    sub.mapBoostCreditsRemaining -= 1;
    await sub.save();

    logger.info(
      `[mapBoost] ${req.user.role} ${req.user.id} redeemed Premium credit → expires ${user.mapBoostExpiry.toISOString()}`,
    );

    res.json({
      message: 'Premium credit redeemed.',
      daysAdded: CREDIT_DAYS,
      expiresAt: user.mapBoostExpiry,
      mapBoostCreditsRemaining: sub.mapBoostCreditsRemaining,
    });
  } catch (e) {
    logger.error('[mapBoost/claim-credit]', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
