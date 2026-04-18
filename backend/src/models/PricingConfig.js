const mongoose = require('mongoose');

/**
 * PricingConfig — singleton document holding the shop pricing grid.
 *
 * Stored as a single document keyed by `key: 'singleton'`. All three
 * categories live on the same doc so admin can update them in one PATCH.
 *
 * - boost      : { EUR|GBP|CHF|USD : { bronze, silver, gold, platinum } }
 * - mapBoost   : { EUR|GBP|CHF|USD : { bronze, silver, gold, platinum } }
 * - premium    : { EUR|GBP|CHF|USD : { monthly, yearly } }
 *
 * Server boots → pricingService.init() reads this doc; if absent it is seeded
 * with hardcoded defaults, if present the values override the defaults in
 * memory. Every time admin patches the grid, the doc is updated in Mongo and
 * the in-memory cache is mutated in place, so existing route handlers see the
 * new prices immediately without a restart.
 */

const TierAmountsSchema = new mongoose.Schema(
  {
    bronze: Number,
    silver: Number,
    gold: Number,
    platinum: Number,
  },
  { _id: false },
);

const PremiumPlansSchema = new mongoose.Schema(
  {
    monthly: Number,
    yearly: Number,
  },
  { _id: false },
);

// Session v3.2 — new chat add-on tier. Cheap unlock that lets free users
// chat with approved friends (Premium users still get chat with everyone).
// Keyed monthly so admin can price it independently per currency.
const ChatPlansSchema = new mongoose.Schema(
  {
    monthly: Number,
  },
  { _id: false },
);

const CurrencyBucketSchema = new mongoose.Schema(
  {
    EUR: TierAmountsSchema,
    GBP: TierAmountsSchema,
    CHF: TierAmountsSchema,
    USD: TierAmountsSchema,
  },
  { _id: false },
);

const PremiumCurrencyBucketSchema = new mongoose.Schema(
  {
    EUR: PremiumPlansSchema,
    GBP: PremiumPlansSchema,
    CHF: PremiumPlansSchema,
    USD: PremiumPlansSchema,
  },
  { _id: false },
);

const ChatCurrencyBucketSchema = new mongoose.Schema(
  {
    EUR: ChatPlansSchema,
    GBP: ChatPlansSchema,
    CHF: ChatPlansSchema,
    USD: ChatPlansSchema,
  },
  { _id: false },
);

const PricingConfigSchema = new mongoose.Schema(
  {
    key: {
      type: String,
      default: 'singleton',
      unique: true,
      required: true,
    },
    boost: CurrencyBucketSchema,
    mapBoost: CurrencyBucketSchema,
    premium: PremiumCurrencyBucketSchema,
    chat: ChatCurrencyBucketSchema, // session v3.2 add-on
  },
  { timestamps: true },
);

module.exports = mongoose.model('PricingConfig', PricingConfigSchema);
