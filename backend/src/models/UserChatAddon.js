const mongoose = require('mongoose');

// Lazy require to avoid circular deps at boot.
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
 * UserChatAddon — session v3.2.
 *
 * Cheap monthly add-on that lets a FREE user chat with accepted friends.
 * Premium users already chat with everyone via UserSubscription.features —
 * this model exists so free users can unlock a subset (friends-only) for a
 * small recurring fee without going full Premium.
 *
 * Interval: 30 days (monthly only). Renewals push currentPeriodEnd forward.
 * Pricing is mirrored from pricingService.get('chat') which is editable from
 * the admin /admin/pricing endpoint; hardcoded defaults below are the last
 * resort fallback if the service isn't initialized yet.
 */

// Session v3.3 — prix aligné sur la décision produit : 1.90 EUR/mois pour
// débloquer le chat entre amis hors paid booking. Admin peut éditer via
// le dashboard pricing editor sans redéploiement.
const CHAT_ADDON_PRICING_DEFAULT = {
  EUR: { monthly: 1.90 },
  GBP: { monthly: 1.69 },
  CHF: { monthly: 1.90 },
  USD: { monthly: 2.09 },
};

const CHAT_ADDON_INTERVAL_DAYS = 30;

/** Returns { amount, currency, intervalDays, label } for currency. */
function getChatAddonPricing(currency = 'EUR') {
  const upper = String(currency || 'EUR').toUpperCase();
  const svc = loadPricingService();
  const servicePricing = svc && svc.get ? svc.get('chat') || {} : {};
  const currencyRow =
    servicePricing[upper] ||
    servicePricing.EUR ||
    CHAT_ADDON_PRICING_DEFAULT[upper] ||
    CHAT_ADDON_PRICING_DEFAULT.EUR;
  return {
    amount: currencyRow.monthly,
    currency:
      servicePricing[upper] || CHAT_ADDON_PRICING_DEFAULT[upper]
        ? upper
        : 'EUR',
    intervalDays: CHAT_ADDON_INTERVAL_DAYS,
    label: 'Chat add-on mensuel',
  };
}

const userChatAddonSchema = new mongoose.Schema(
  {
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

    status: {
      type: String,
      enum: ['active', 'canceled', 'expired', 'pending'],
      default: 'pending',
      index: true,
    },

    // Period window — renewals push currentPeriodEnd forward by 30 days.
    currentPeriodStart: { type: Date, default: null },
    currentPeriodEnd: { type: Date, default: null, index: true },

    cancelAtPeriodEnd: { type: Boolean, default: false },
    canceledAt: { type: Date, default: null },

    // v21.1.1 — Stripe fields removed.

    payments: [
      {
        amount: Number,
        currency: { type: String, default: 'EUR' },
        paidAt: { type: Date, default: Date.now },
        paymentProvider: { type: String, default: 'stripe' },
        paymentIntentId: String,
        periodStart: Date,
        periodEnd: Date,
      },
    ],
  },
  { timestamps: true },
);

userChatAddonSchema.index({ userId: 1, userModel: 1 }, { unique: true });
userChatAddonSchema.index({ status: 1, currentPeriodEnd: 1 });

userChatAddonSchema.methods.isCurrentlyActive = function isCurrentlyActive() {
  if (this.status !== 'active') return false;
  if (!this.currentPeriodEnd) return false;
  return new Date(this.currentPeriodEnd) > new Date();
};

module.exports = mongoose.model('UserChatAddon', userChatAddonSchema);
module.exports.CHAT_ADDON_PRICING_DEFAULT = CHAT_ADDON_PRICING_DEFAULT;
module.exports.CHAT_ADDON_INTERVAL_DAYS = CHAT_ADDON_INTERVAL_DAYS;
module.exports.getChatAddonPricing = getChatAddonPricing;
