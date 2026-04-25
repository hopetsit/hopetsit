/**
 * Chat Add-on Routes — session v3.2.
 *
 * Cheap monthly add-on (~€0.99/mo) that lets a FREE user chat with accepted
 * friends. Premium users don't need this — their UserSubscription already
 * includes chat with everyone.
 *
 * Mirrors subscriptionRoutes.js almost 1:1 but monthly-only.
 */

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const UserChatAddon = require('../models/UserChatAddon');
const {
  CHAT_ADDON_PRICING_DEFAULT,
  CHAT_ADDON_INTERVAL_DAYS,
  getChatAddonPricing,
} = require('../models/UserChatAddon');
const { createPlatformPaymentIntent } = require('../services/stripeService');
const airwallex = require('../services/airwallexService');
const { normalizeCurrency } = require('../utils/currency');
const logger = require('../utils/logger');

const router = express.Router();

const PROVIDER = (process.env.PAYMENT_PROVIDER || 'stripe').toLowerCase();

const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };
const userModelFromRole = (role) => ROLE_TO_MODEL_NAME[role] || 'Owner';

function serialize(addon) {
  if (!addon) {
    return {
      status: 'none',
      isActive: false,
      currentPeriodEnd: null,
      cancelAtPeriodEnd: false,
    };
  }
  const active = addon.isCurrentlyActive
    ? addon.isCurrentlyActive()
    : addon.status === 'active' &&
      addon.currentPeriodEnd &&
      new Date(addon.currentPeriodEnd) > new Date();
  return {
    status: addon.status,
    isActive: active,
    currentPeriodStart: addon.currentPeriodStart,
    currentPeriodEnd: addon.currentPeriodEnd,
    cancelAtPeriodEnd: addon.cancelAtPeriodEnd,
    canceledAt: addon.canceledAt,
    payments: (addon.payments || []).slice(-5).reverse(),
  };
}

// ── GET /plans — public pricing (accepts ?currency=…) ───────────────────────
router.get('/plans', (req, res) => {
  const currency = normalizeCurrency(req.query.currency);
  const p = getChatAddonPricing(currency);
  res.json({
    plan: 'monthly',
    amount: p.amount,
    currency: p.currency,
    intervalDays: p.intervalDays,
    label: p.label,
    supportedCurrencies: Object.keys(CHAT_ADDON_PRICING_DEFAULT),
  });
});

// ── GET /status — my chat add-on state ──────────────────────────────────────
router.get('/status', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;
    const userModel = userModelFromRole(req.user.role);
    const addon = await UserChatAddon.findOne({ userId, userModel });
    res.json(serialize(addon));
  } catch (e) {
    logger.error('[chatAddon/status]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /subscribe — create PaymentIntent ──────────────────────────────────
router.post('/subscribe', requireAuth, async (req, res) => {
  try {
    const currency = normalizeCurrency(req.body.currency);
    const pricing = getChatAddonPricing(currency);
    if (!pricing || !pricing.amount) {
      return res.status(400).json({ error: 'Chat add-on pricing unavailable.' });
    }

    const userId = req.user.id;
    const role = req.user.role;
    const amountCents = Math.round(pricing.amount * 100);

    // ─── Airwallex flow ────────────────────────────────────────────────────
    if (PROVIDER === 'airwallex') {
      try {
        const intent = await airwallex.createPlatformPaymentIntent({
          amount: amountCents,
          currency: pricing.currency,
          metadata: {
            type: 'chat_addon_purchase',
            userId: String(userId),
            role,
            currency: pricing.currency,
            intervalDays: String(pricing.intervalDays),
          },
        });

        logger.info(
          `[chatAddon] airwallex PI created ${intent.id} ${pricing.amount} ${pricing.currency} ` +
          `by ${role} ${userId}`,
        );

        return res.json({
          clientSecret: intent.client_secret,
          paymentIntentId: intent.id,
          provider: 'airwallex',
          amount: pricing.amount,
          currency: pricing.currency,
          intervalDays: pricing.intervalDays,
        });
      } catch (e) {
        logger.error('[chatAddon] airwallex create-intent failed', e);
        return res.status(502).json({
          error: 'Unable to start chat add-on purchase right now. Please try again later.',
        });
      }
    }

    // ─── Stripe flow (default / rollback) ──────────────────────────────────
    const paymentIntent = await createPlatformPaymentIntent({
      amount: amountCents,
      currency: pricing.currency.toLowerCase(),
      metadata: {
        type: 'chat_addon_purchase',
        userId: String(userId),
        role,
        currency: pricing.currency,
        intervalDays: String(pricing.intervalDays),
      },
    });

    res.json({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      provider: 'stripe',
      amount: pricing.amount,
      currency: pricing.currency,
      intervalDays: pricing.intervalDays,
    });
  } catch (e) {
    logger.error('[chatAddon/subscribe]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /confirm — extend the chat add-on window after Stripe success ──────
router.post('/confirm', requireAuth, async (req, res) => {
  try {
    const { paymentIntentId } = req.body;
    const currency = normalizeCurrency(req.body.currency);
    const pricing = getChatAddonPricing(currency);

    const userId = req.user.id;
    const userModel = userModelFromRole(req.user.role);
    const now = new Date();

    let addon = await UserChatAddon.findOne({ userId, userModel });
    if (!addon) {
      addon = new UserChatAddon({ userId, userModel });
    }

    // Stack on top of any remaining window so renewals don't lose days.
    const startFrom =
      addon.currentPeriodEnd && new Date(addon.currentPeriodEnd) > now
        ? new Date(addon.currentPeriodEnd)
        : now;
    const newPeriodEnd = new Date(
      startFrom.getTime() + CHAT_ADDON_INTERVAL_DAYS * 86400000,
    );

    addon.status = 'active';
    addon.currentPeriodStart = addon.currentPeriodStart || now;
    addon.currentPeriodEnd = newPeriodEnd;
    addon.cancelAtPeriodEnd = false;
    addon.lastPaymentIntentId = paymentIntentId || '';

    addon.payments = addon.payments || [];
    addon.payments.push({
      amount: pricing.amount,
      currency: pricing.currency,
      paidAt: now,
      paymentProvider: 'stripe',
      paymentIntentId: paymentIntentId || '',
      periodStart: startFrom,
      periodEnd: newPeriodEnd,
    });

    await addon.save();

    logger.info(
      `[chatAddon] ${req.user.role} ${userId} activated chat add-on → ${newPeriodEnd.toISOString()}`,
    );

    res.json({ message: 'Chat add-on activated!', ...serialize(addon) });
  } catch (e) {
    logger.error('[chatAddon/confirm]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /cancel — cancel at period end ─────────────────────────────────────
router.post('/cancel', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;
    const userModel = userModelFromRole(req.user.role);
    const addon = await UserChatAddon.findOne({ userId, userModel });
    if (!addon || addon.status !== 'active') {
      return res.status(404).json({ error: 'No active chat add-on to cancel.' });
    }
    addon.cancelAtPeriodEnd = true;
    addon.canceledAt = new Date();
    await addon.save();
    res.json({ message: 'Chat add-on will end at period end.', ...serialize(addon) });
  } catch (e) {
    logger.error('[chatAddon/cancel]', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
