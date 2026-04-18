const PricingConfig = require('../models/PricingConfig');
const logger = require('../utils/logger');

/**
 * Pricing service — single source of truth for Boost / Map Boost / Premium
 * prices. Seeded from DB on server boot, mutable at runtime via admin API.
 *
 * Design:
 *   - `DEFAULTS` are the hardcoded fallback prices (also used as the seed when
 *     the DB has no document yet).
 *   - `cache` holds the current live values the rest of the app reads. It is
 *     mutated in place so route files that grabbed a reference at require()
 *     time see updates without a restart.
 *   - `init()` runs once at server startup (after mongoose connects) and loads
 *     the DB values into cache. If the DB is empty it seeds it with defaults.
 *   - `update(patch)` deep-merges the patch into cache and persists to DB.
 *
 * Consumers (boostRoutes, mapBoostRoutes, UserSubscription) import `get()` and
 * use the returned object exactly like the legacy hardcoded const. Only the
 * source changes.
 */

const DEFAULTS = Object.freeze({
  boost: {
    EUR: { bronze: 4.99,  silver: 9.99,  gold: 14.99, platinum: 24.99 },
    GBP: { bronze: 4.39,  silver: 8.79,  gold: 13.29, platinum: 21.99 },
    CHF: { bronze: 4.99,  silver: 9.99,  gold: 14.99, platinum: 24.99 },
    USD: { bronze: 5.49,  silver: 10.99, gold: 16.49, platinum: 27.49 },
  },
  mapBoost: {
    EUR: { bronze: 2.99,  silver: 5.99,  gold: 9.99,  platinum: 14.99 },
    GBP: { bronze: 2.59,  silver: 5.29,  gold: 8.79,  platinum: 12.99 },
    CHF: { bronze: 2.99,  silver: 5.99,  gold: 9.99,  platinum: 14.99 },
    USD: { bronze: 3.29,  silver: 6.59,  gold: 10.99, platinum: 16.49 },
  },
  premium: {
    EUR: { monthly: 3.90, yearly: 30.00 },
    GBP: { monthly: 3.29, yearly: 24.99 },
    CHF: { monthly: 3.90, yearly: 29.99 },
    USD: { monthly: 4.29, yearly: 32.99 },
  },
  // Session v3.3 — Chat add-on aligned with Daniel's pricing decision:
  // chat entre amis = 1.90 EUR/mois (was 0.99 in v3.2). Gratuit dès qu'un
  // paid booking existe entre les deux parties (règle métier baked into
  // conversationService.sendMessage + startConversation).
  chat: {
    EUR: { monthly: 1.90 },
    GBP: { monthly: 1.69 },
    CHF: { monthly: 1.90 },
    USD: { monthly: 2.09 },
  },
});

const CATEGORIES = ['boost', 'mapBoost', 'premium', 'chat'];
const CURRENCIES = ['EUR', 'GBP', 'CHF', 'USD'];

// Deep clone of DEFAULTS used as the live in-memory state. Mutated in place
// on admin updates so existing references keep pointing at fresh values.
let cache = JSON.parse(JSON.stringify(DEFAULTS));

function mergeInto(target, patch) {
  for (const cat of CATEGORIES) {
    if (!patch[cat]) continue;
    target[cat] = target[cat] || {};
    for (const cur of CURRENCIES) {
      if (!patch[cat][cur]) continue;
      target[cat][cur] = { ...(target[cat][cur] || {}), ...patch[cat][cur] };
    }
  }
  return target;
}

async function init() {
  try {
    const doc = await PricingConfig.findOne({ key: 'singleton' }).lean();
    if (doc) {
      // Override cache with DB values, falling back to defaults per-category
      // in case an older doc is missing a category.
      for (const cat of CATEGORIES) {
        if (doc[cat]) cache[cat] = doc[cat];
      }
      logger.info?.('[pricingService] loaded pricing from DB');
    } else {
      // First boot — seed the DB with defaults.
      await PricingConfig.create({ key: 'singleton', ...DEFAULTS });
      logger.info?.('[pricingService] seeded DB with default pricing');
    }
  } catch (e) {
    // Don't crash the server if pricing can't load — fallback defaults are
    // already in cache, so the shop keeps working.
    logger.error?.('[pricingService] init failed, using defaults', e);
  }
}

function get(category) {
  return cache[category];
}

function getAll() {
  return {
    boost: cache.boost,
    mapBoost: cache.mapBoost,
    premium: cache.premium,
    chat: cache.chat,
  };
}

async function update(patch) {
  if (!patch || typeof patch !== 'object') {
    throw new Error('pricingService.update: patch must be an object');
  }
  // Basic sanity: reject non-numeric or negative prices.
  for (const cat of CATEGORIES) {
    if (!patch[cat]) continue;
    for (const cur of Object.keys(patch[cat])) {
      const row = patch[cat][cur];
      if (!row || typeof row !== 'object') continue;
      for (const tier of Object.keys(row)) {
        const v = row[tier];
        if (typeof v !== 'number' || Number.isNaN(v) || v < 0) {
          throw new Error(
            `pricingService.update: invalid price ${cat}.${cur}.${tier} = ${v}`,
          );
        }
      }
    }
  }

  // Merge into the live cache so consumers see the new values immediately.
  mergeInto(cache, patch);

  // Persist. Use the full cache to keep the doc consistent.
  await PricingConfig.findOneAndUpdate(
    { key: 'singleton' },
    {
      $set: {
        boost: cache.boost,
        mapBoost: cache.mapBoost,
        premium: cache.premium,
        chat: cache.chat,
      },
    },
    { upsert: true, new: true },
  );

  return getAll();
}

async function resetToDefaults() {
  cache = JSON.parse(JSON.stringify(DEFAULTS));
  await PricingConfig.findOneAndUpdate(
    { key: 'singleton' },
    { $set: { ...DEFAULTS } },
    { upsert: true, new: true },
  );
  return getAll();
}

module.exports = {
  init,
  get,
  getAll,
  update,
  resetToDefaults,
  DEFAULTS,
  CATEGORIES,
  CURRENCIES,
};
