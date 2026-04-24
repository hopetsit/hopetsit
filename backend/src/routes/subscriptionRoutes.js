/**
 * Subscription Routes — Premium plan (Phase 1).
 *
 * Plans:
 *   monthly → €3.90 / 30 days
 *   yearly  → €30.00 / 365 days
 *
 * Phase 1 uses one-time PaymentIntents that extend `currentPeriodEnd`
 * on the UserSubscription doc. The existing Stripe flow from boostRoutes.js
 * is reused so frontend can present a single PaymentSheet.
 *
 * Phase 2 will migrate to proper Stripe Subscriptions with webhooks
 * (`customer.subscription.updated` / `.deleted`) for auto-renewal.
 */

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const UserSubscription = require('../models/UserSubscription');
const {
  PREMIUM_PLAN_INTERVALS,
  PREMIUM_PRICING,
  PREMIUM_FEATURES_DEFAULT,
  getPlanPricing,
} = require('../models/UserSubscription');
const { createPlatformPaymentIntent } = require('../services/stripeService');
const { normalizeCurrency } = require('../utils/currency');
const logger = require('../utils/logger');

const router = express.Router();

// ── Helpers ──────────────────────────────────────────────────────────────────
const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };

function userModelFromRole(role) {
  return ROLE_TO_MODEL_NAME[role] || 'Owner';
}

function serializeSubscription(sub) {
  if (!sub) {
    return {
      plan: 'none',
      status: 'none',
      isPremium: false,
      features: { ...PREMIUM_FEATURES_DEFAULT, mapReportsVisible: false, mapReportsCreate: false, socialFriendsMap: false, socialChat: false, socialProximityAlerts: false, mapBoostMonthlyCredit: 0 },
      currentPeriodEnd: null,
      cancelAtPeriodEnd: false,
      mapBoostCreditsRemaining: 0,
    };
  }
  return {
    plan: sub.plan,
    status: sub.status,
    isPremium: sub.isCurrentlyPremium ? sub.isCurrentlyPremium() : (sub.status === 'active' && sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > new Date()),
    features: sub.features || {},
    currentPeriodStart: sub.currentPeriodStart,
    currentPeriodEnd: sub.currentPeriodEnd,
    cancelAtPeriodEnd: sub.cancelAtPeriodEnd,
    canceledAt: sub.canceledAt,
    mapBoostCreditsRemaining: sub.mapBoostCreditsRemaining || 0,
    payments: (sub.payments || []).slice(-5).reverse(),
  };
}

// ── GET plans (public) — accepts ?currency=EUR|GBP|CHF|USD ─────────────────
router.get('/plans', (req, res) => {
  const currency = normalizeCurrency(req.query.currency);
  const plans = Object.keys(PREMIUM_PLAN_INTERVALS).map((key) => {
    const p = getPlanPricing(key, currency);
    return {
      plan: key,
      amount: p.amount,
      currency: p.currency,
      intervalDays: p.intervalDays,
      label: p.label,
      amountPerDay: +(p.amount / p.intervalDays).toFixed(3),
    };
  });
  res.json({
    plans,
    currency,
    supportedCurrencies: Object.keys(PREMIUM_PRICING),
    features: PREMIUM_FEATURES_DEFAULT,
  });
});

// ── GET my subscription status ──────────────────────────────────────────────
router.get('/status', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;
    const userModel = userModelFromRole(req.user.role);

    const sub = await UserSubscription.findOne({ userId, userModel });

    // v19.1.5 — Staff users (Daniel + employees) get Premium for free.
    const ModelCtor = {
      Owner: require('../models/Owner'),
      Sitter: require('../models/Sitter'),
      Walker: require('../models/Walker'),
    }[userModel];
    if (ModelCtor) {
      const u = await ModelCtor.findById(userId).select('isStaff').lean();
      if (u && u.isStaff) {
        return res.json({
          plan: 'staff',
          status: 'active',
          isPremium: true,
          isStaff: true,
          features: { ...PREMIUM_FEATURES_DEFAULT, mapReportsVisible: true, mapReportsCreate: true, socialFriendsMap: true, socialChat: true, socialProximityAlerts: true, mapBoostMonthlyCredit: 999 },
          currentPeriodStart: new Date(0),
          currentPeriodEnd: new Date('2099-12-31'),
          cancelAtPeriodEnd: false,
          canceledAt: null,
          mapBoostCreditsRemaining: 999,
          payments: [],
        });
      }
    }

    res.json(serializeSubscription(sub));
  } catch (e) {
    logger.error('[subscription/status]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /subscribe — create PaymentIntent for a plan ───────────────────────
router.post('/subscribe', requireAuth, async (req, res) => {
  try {
    const { plan } = req.body;
    const currency = normalizeCurrency(req.body.currency);
    const pricing = getPlanPricing(plan, currency);
    if (!pricing) {
      return res.status(400).json({
        error: `Invalid plan. Choose from: ${Object.keys(PREMIUM_PLAN_INTERVALS).join(', ')}`,
      });
    }

    const userId = req.user.id;
    const role = req.user.role;

    // v20.0.2 — Staff users get Premium FREE forever. Just return success;
    // the /status endpoint already returns a synthetic Premium payload for them.
    const StaffModel = role === 'walker'
      ? require('../models/Walker')
      : role === 'sitter'
        ? require('../models/Sitter')
        : require('../models/Owner');
    const staffUser = await StaffModel.findById(userId).select('isStaff').lean();
    if (staffUser && staffUser.isStaff) {
      logger.info(`[subscription/staff] ${role} ${userId} — Premium free (staff)`);
      return res.json({
        staff: true,
        activated: true,
        plan,
        amount: 0,
        currency: pricing.currency,
        intervalDays: pricing.intervalDays,
      });
    }

    const amountCents = Math.round(pricing.amount * 100);
    const paymentIntent = await createPlatformPaymentIntent({
      amount: amountCents,
      currency: pricing.currency.toLowerCase(),
      metadata: {
        type: 'subscription_purchase',
        userId: String(userId),
        role,
        plan,
        currency: pricing.currency,
        intervalDays: String(pricing.intervalDays),
      },
    });

    res.json({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      plan,
      amount: pricing.amount,
      currency: pricing.currency,
      intervalDays: pricing.intervalDays,
    });
  } catch (e) {
    logger.error('[subscription/subscribe] Error creating PaymentIntent', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /confirm — after Stripe success, extend premium window ─────────────
router.post('/confirm', requireAuth, async (req, res) => {
  try {
    const { plan, paymentIntentId } = req.body;
    const currency = normalizeCurrency(req.body.currency);
    const pricing = getPlanPricing(plan, currency);
    if (!pricing) {
      return res.status(400).json({ error: 'Invalid plan.' });
    }

    const userId = req.user.id;
    const userModel = userModelFromRole(req.user.role);
    const now = new Date();

    // Upsert subscription doc
    let sub = await UserSubscription.findOne({ userId, userModel });
    if (!sub) {
      sub = new UserSubscription({ userId, userModel });
    }

    // Extend from current period end if still premium, else start now
    const startFrom = sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > now
      ? new Date(sub.currentPeriodEnd)
      : now;
    const newPeriodEnd = new Date(startFrom.getTime() + pricing.intervalDays * 86400000);

    sub.plan = plan;
    sub.status = 'active';
    sub.currentPeriodStart = sub.currentPeriodStart || now;
    sub.currentPeriodEnd = newPeriodEnd;
    sub.cancelAtPeriodEnd = false;
    sub.lastPaymentIntentId = paymentIntentId || '';

    // Feature flags (Premium unlocks everything)
    sub.features = { ...PREMIUM_FEATURES_DEFAULT };

    // Top up map-boost credits: 1 per month. For yearly = 12 credits/year.
    const creditsToAdd = plan === 'yearly' ? 12 : 1;
    sub.mapBoostCreditsRemaining = (sub.mapBoostCreditsRemaining || 0) + creditsToAdd;
    sub.mapBoostCreditsResetAt = newPeriodEnd;

    sub.payments = sub.payments || [];
    sub.payments.push({
      plan,
      amount: pricing.amount,
      currency: pricing.currency,
      paidAt: now,
      paymentProvider: 'stripe',
      paymentIntentId: paymentIntentId || '',
      periodStart: startFrom,
      periodEnd: newPeriodEnd,
    });

    await sub.save();

    logger.info(`[subscription] ${req.user.role} ${userId} activated ${plan} → expires ${newPeriodEnd.toISOString()}`);

    res.json({
      message: 'Premium activated!',
      ...serializeSubscription(sub),
    });
  } catch (e) {
    logger.error('[subscription/confirm]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /cancel — cancel at period end (keeps access until then) ───────────
router.post('/cancel', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;
    const userModel = userModelFromRole(req.user.role);

    const sub = await UserSubscription.findOne({ userId, userModel });
    if (!sub || sub.status !== 'active') {
      return res.status(404).json({ error: 'No active subscription to cancel.' });
    }

    sub.cancelAtPeriodEnd = true;
    sub.canceledAt = new Date();
    await sub.save();

    logger.info(`[subscription] ${req.user.role} ${userId} canceled at period end`);
    res.json({
      message: 'Subscription will end at the current period.',
      ...serializeSubscription(sub),
    });
  } catch (e) {
    logger.error('[subscription/cancel]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /resume — undo a pending cancellation ──────────────────────────────
router.post('/resume', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;
    const userModel = userModelFromRole(req.user.role);

    const sub = await UserSubscription.findOne({ userId, userModel });
    if (!sub || !sub.cancelAtPeriodEnd) {
      return res.status(404).json({ error: 'No cancellation to resume.' });
    }

    sub.cancelAtPeriodEnd = false;
    sub.canceledAt = null;
    await sub.save();

    res.json({
      message: 'Subscription resumed.',
      ...serializeSubscription(sub),
    });
  } catch (e) {
    logger.error('[subscription/resume]', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
