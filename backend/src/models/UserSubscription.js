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
 * UserSubscription — Tracks PawPass subscription for Owners / Sitters / Walkers,
 * and PawFollow subscriptions for tracking features.
 *
 * Pricing (Phase 1) — multi-currency:
 *   PawPass monthly : €6.99 / £5.89 / CHF 6.99 / $7.69  (30-day interval)
 *   PawPass yearly  : €49.99 / £42.19 / CHF 49.99 / $54.99  (365-day interval)
 *
 *   Chat add-on     : €2.99 / £2.59 / CHF 2.99 / $3.29 (monthly, free with booking)
 *
 *   PawFollow Solo  : €6.99 / £5.89 / CHF 6.99 / $7.69 (monthly)
 *   PawFollow Family: €9.99 / £8.49 / CHF 9.99 / $10.99 (monthly, POPULAIRE badge)
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
  monthly: { intervalDays: 30, label: 'PawPass Mensuel' },
  yearly: { intervalDays: 365, label: 'PawPass Annuel' },
  // v22.1 — PawPass Famille : même PawPass premium mais partagé avec
  // jusqu'à 5 membres de la famille. Mensuel uniquement pour l'instant.
  family: { intervalDays: 30, label: 'PawPass Famille' },
};

const PREMIUM_PRICING = {
  EUR: { monthly: 6.99, yearly: 49.99, family: 9.90 },
  GBP: { monthly: 5.89, yearly: 42.19, family: 8.39 },
  CHF: { monthly: 6.99, yearly: 49.99, family: 9.90 },
  USD: { monthly: 7.69, yearly: 54.99, family: 10.89 },
};

const PAWFOLLOW_PLAN_INTERVALS = {
  solo: { intervalDays: 30, label: 'PawFollow Solo' },
  famille: { intervalDays: 30, label: 'PawFollow Famille' },
};

const PAWFOLLOW_PRICING = {
  EUR: { solo: 6.99, famille: 9.99 },
  GBP: { solo: 5.89, famille: 8.49 },
  CHF: { solo: 6.99, famille: 9.99 },
  USD: { solo: 7.69, famille: 10.99 },
};

const PAWFOLLOW_FEATURES = {
  solo: {
    slug: 'pawfollow_solo',
    name: 'PawFollow Solo',
    badge: null,
    features: [
      'live position 10s',
      'history journey',
      'safety zone alert',
      'direct chat walker/sitter',
    ],
  },
  famille: {
    slug: 'pawfollow_family',
    name: 'PawFollow Famille',
    badge: 'POPULAIRE',
    features: [
      'all PawFollow Solo',
      '5 family members tracking',
      'see who walks the pet',
      'shared real-time notifications',
      'family group chat with walker/sitter',
    ],
  },
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

function getPawFollowPricing(plan, currency = 'EUR') {
  const interval = PAWFOLLOW_PLAN_INTERVALS[plan];
  if (!interval) return null;
  const upper = String(currency || 'EUR').toUpperCase();
  const svc = loadPricingService();
  const servicePricing = svc && svc.get ? svc.get('pawfollow') || {} : {};
  const currencyRow =
    servicePricing[upper] ||
    servicePricing.EUR ||
    PAWFOLLOW_PRICING[upper] ||
    PAWFOLLOW_PRICING.EUR;
  return {
    amount: currencyRow[plan],
    currency:
      servicePricing[upper] || PAWFOLLOW_PRICING[upper] ? upper : 'EUR',
    intervalDays: interval.intervalDays,
    label: interval.label,
    ...PAWFOLLOW_FEATURES[plan],
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

  // Couche 2 — reports (PawPass only)
  mapReportsVisible: true,
  mapReportsCreate: true,

  // Couche 3 — social (PawPass only)
  socialFriendsMap: true,
  socialChat: true,
  socialProximityAlerts: true,

  // Couche 4 — one free PawSpot per month
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

    // Plan type: pawpass (formerly premium), pawfollow, or none
    plan: {
      type: String,
      enum: ['none', 'monthly', 'yearly', 'solo', 'famille'],
      default: 'none',
      index: true,
    },
    planType: {
      type: String,
      enum: ['pawpass', 'pawfollow', 'chat'],
      default: 'pawpass',
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

    // v21.1.1 — Stripe references removed.

    // Payment history (similar to boostPurchases on User models)
    payments: [
      {
        plan: { type: String, enum: ['monthly', 'yearly', 'solo', 'famille'] },
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

    // PawSpot monthly credit ledger
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
module.exports.PAWFOLLOW_PLAN_INTERVALS = PAWFOLLOW_PLAN_INTERVALS;
module.exports.PAWFOLLOW_PRICING = PAWFOLLOW_PRICING;
module.exports.PAWFOLLOW_FEATURES = PAWFOLLOW_FEATURES;
module.exports.getPawFollowPricing = getPawFollowPricing;
