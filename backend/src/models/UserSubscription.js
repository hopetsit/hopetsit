const mongoose = require('mongoose');
// Lazy-required inside getPlanPricing to avoid circular dependencies — this
// model is imported by pricingService's transitive dependencies at boot.
let pricingService = null;
function loadPricingService() {
  if (pricingService) return pricingService;
  try {
    pricingService = require('../services/pricingService');
  } catch (e) {
    pricingService = null;
  }
  return pricingService;
}

/**
 * UserSubscription — Tracks Premium subscription for Owners / Sitters / Walkers.
 *
 * Pricing (Phase 1) — multi-currency:
 *   monthly : €3.90 / £3.29 / CHF 3.90 / $4.29  (30-day interval)
 *   yearly  : €30.00 / £24.99 / CHF 29.99 / $32.99  (365-day interval, ~35% off)
 *
 * Payment model:
 *   Phase 1 uses one-time PaymentIntents that extend `currentPeriodEnd` by the
 *   plan duration. This keeps the existing Stripe boost flow re-usable.
 *
 *   Later (Phase 2) we migrate to proper Stripe Subscriptions with webhooks
 *   (`customer.subscription.updated` / `.deleted`) for renewals and failed
 *   payments to auto-update `status`.
 *
 * The `features` object is a snapshot of what this subscription unlocks so the
 * frontend can gate UI without hitting the pricing config on every screen.
 */
const PREMIUM_PLAN_INTERVALS = {
  monthly: { intervalDays: 30, label: 'Premium Mensuel' },
  yearly: { intervalDays: 365, label: 'Premium Annuel' },
};

const PREMIUM_PRICING = {
  EUR: { monthly: 3.90, yearly: 30.00 },
  GBP: { monthly: 3.29, yearly: 24.99 },
  CHF: { monthly: 3.90, yearly: 29.99 },
  USD: { monthly: 4.29, yearly: 32.99 },
};

/** Returns { amount, currency, intervalDays, label } for a (plan, currency) pair.
 *
 * Resolves the amount via pricingService first (DB-backed, editable from
 * admin), then falls back to the hardcoded PREMIUM_PRICING above if the
 * service is not initialized or doesn't have the row.
 */
function getPlanPricing(plan, currency = 'EUR') {
  const interval = PREMIUM_PLAN_INTERVALS[plan];
  if (!interval) return null;
  const upper = String(currency || 'EUR').toUpperCase();
  const svc = loadPricingService();
  const servicePricing = svc && svc.get ? svc.get('premium') || {} : {};
  const currencyRow =
    servicePricing[upper] ||
    servicePricing.EUR ||
    PREMIUM_PRICING[upper] ||
    PREMIUM_PRICING.EUR;
  return {
    amount: currencyRow[plan],
    currency:
      servicePricing[upper] || PREMIUM_PRICING[upper] ? upper : 'EUR',
    intervalDays: interval.intervalDays,
    label: interval.label,
  };
}

/** Legacy export kept for any caller that imports PREMIUM_PLANS — uses EUR. */
const PREMIUM_PLANS = {
  monthly: getPlanPricing('monthly', 'EUR'),
  yearly: getPlanPricing('yearly', 'EUR'),
};

const PREMIUM_FEATURES_DEFAULT = {
  // Couche 1 — always true for everyone (free tier shows it too)
  mapPoiVisible: true,

  // Couche 2 — reports (Premium only)
  mapReportsVisible: true,
  mapReportsCreate: true,

  // Couche 3 — social (Premium only)
  socialFriendsMap: true,
  socialChat: true,
  socialProximityAlerts: true,

  // Couche 4 — one free map-boost per month
  mapBoostMonthlyCredit: 1,
};

const userSubscriptionSchema = new mongoose.Schema(
  {
    // Polymorphic owner ref (same pattern as Block.js)
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      refPath: 'userModel',
      index: true,
    },
    userModel: {
      type: String,
      enum: ['Owner', 'Sitter', 'Walker'],
      required: true,
    },

    plan: {
      type: String,
      enum: ['none', 'monthly', 'yearly'],
      default: 'none',
      index: true,
    },
    status: {
      type: String,
      enum: ['active', 'past_due', 'canceled', 'expired', 'pending'],
      default: 'pending',
      index: true,
    },

    // Period window — renewals push currentPeriodEnd forward
    currentPeriodStart: { type: Date, default: null },
    currentPeriodEnd: { type: Date, default: null, index: true },

    // Cancellation
    cancelAtPeriodEnd: { type: Boolean, default: false },
    canceledAt: { type: Date, default: null },

    // Stripe references
    stripeCustomerId: { type: String, default: null, index: true, sparse: true },
    stripeSubscriptionId: { type: String, default: null, index: true, sparse: true },
    lastPaymentIntentId: { type: String, default: null },

    // Payment history (similar to boostPurchases on User models)
    payments: [
      {
        plan: { type: String, enum: ['monthly', 'yearly'] },
        amount: Number,
        currency: { type: String, default: 'EUR' },
        paidAt: { type: Date, default: Date.now },
        paymentProvider: { type: String, default: 'stripe' },
        paymentIntentId: String,
        periodStart: Date,
        periodEnd: Date,
      },
    ],

    // Feature snapshot
    features: {
      type: Object,
      default: () => ({ ...PREMIUM_FEATURES_DEFAULT }),
    },

    // Map boost monthly credit ledger
    mapBoostCreditsRemaining: { type: Number, default: 0, min: 0 },
    mapBoostCreditsResetAt: { type: Date, default: null },
  },
  { timestamps: true }
);

// One subscription doc per user
userSubscriptionSchema.index({ userId: 1, userModel: 1 }, { unique: true });
userSubscriptionSchema.index({ status: 1, currentPeriodEnd: 1 });

/**
 * Convenience: returns true when the subscription is active AND within its
 * paid window. Handles edge-cases where the cron hasn't flipped status yet.
 */
userSubscriptionSchema.methods.isCurrentlyPremium = function isCurrentlyPremium() {
  if (this.status !== 'active') return false;
  if (!this.currentPeriodEnd) return false;
  return new Date(this.currentPeriodEnd) > new Date();
};

module.exports = mongoose.model('UserSubscription', userSubscriptionSchema);
module.exports.PREMIUM_PLANS = PREMIUM_PLANS;
module.exports.PREMIUM_PLAN_INTERVALS = PREMIUM_PLAN_INTERVALS;
module.exports.PREMIUM_PRICING = PREMIUM_PRICING;
module.exports.PREMIUM_FEATURES_DEFAULT = PREMIUM_FEATURES_DEFAULT;
module.exports.getPlanPricing = getPlanPricing;
