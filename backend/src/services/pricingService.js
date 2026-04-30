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
    EUR: { bronze: 6.99,  silver: 12.99, gold: 19.99, platinum: 34.99 },
    GBP: { bronze: 6.19,  silver: 11.59, gold: 17.79, platinum: 31.19 },
    CHF: { bronze: 6.99,  silver: 12.99, gold: 19.99, platinum: 34.99 },
    USD: { bronze: 7.69,  silver: 14.29, gold: 21.99, platinum: 38.49 },
  },
  mapBoost: {
    // v23.1 — aligned with website PawMap pricing:
    // bronze = "PawSpot 24h" (1.99 €), silver = "PawSpot 7 jours" (8.99 €),
    // gold = intermediate (kept for legacy), platinum = "PawSpot 30 jours" (24.99 €).
    EUR: { bronze: 1.99,  silver: 8.99,  gold: 14.99, platinum: 24.99 },
    GBP: { bronze: 1.69,  silver: 7.99,  gold: 13.29, platinum: 21.99 },
    CHF: { bronze: 1.99,  silver: 8.99,  gold: 14.99, platinum: 24.99 },
    USD: { bronze: 2.19,  silver: 9.89,  gold: 16.49, platinum: 27.49 },
  },
  premium: {
    // v23.1 — family added to admin/api so it can be edited from the dashboard.
    EUR: { monthly: 6.99, yearly: 49.99, family: 9.99 },
    GBP: { monthly: 5.89, yearly: 42.19, family: 8.49 },
    CHF: { monthly: 6.99, yearly: 49.99, family: 9.99 },
    USD: { monthly: 7.69, yearly: 54.99, family: 10.99 },
  },
  chat: {
    EUR: { monthly: 2.99 },
    GBP: { monthly: 2.59 },
    CHF: { monthly: 2.99 },
    USD: { monthly: 3.29 },
  },
  pawfollow: {
    EUR: { solo: 6.99, famille: 9.99 },
    GBP: { solo: 5.89, famille: 8.49 },
    CHF: { solo: 6.99, famille: 9.99 },
    USD: { solo: 7.69, famille: 10.99 },
  },
});

const CATEGORIES = ['boost', 'mapBoost', 'premium', 'chat', 'pawfollow'];
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

// v23.1 — la version courante des tarifs. Bumper cette valeur force une
// remise à jour de la DB depuis DEFAULTS au prochain boot (admin perd ses
// éventuelles édits manuelles, c'est intentionnel sur un version bump).
const PRICING_VERSION = 'v23.1';

async function init() {
  try {
    const doc = await PricingConfig.findOne({ key: 'singleton' }).lean();
    if (!doc) {
      // First boot — seed the DB with defaults.
      await PricingConfig.create({
        key: 'singleton',
        ...DEFAULTS,
        version: PRICING_VERSION,
      });
      logger.info?.(
        `[pricingService] seeded DB with default pricing (${PRICING_VERSION})`,
      );
      return;
    }

    // v23.1 — version-based migration. If the DB doc is older than the
    // current PRICING_VERSION, force-overwrite all pricing categories
    // with DEFAULTS so price updates committed in code (e.g. align with
    // hopetsit.com) actually propagate after a deploy. Without this,
    // the DB cache always wins and stale prices persist forever.
    if (doc.version !== PRICING_VERSION) {
      await PricingConfig.findOneAndUpdate(
        { key: 'singleton' },
        {
          $set: {
            boost: DEFAULTS.boost,
            mapBoost: DEFAULTS.mapBoost,
            premium: DEFAULTS.premium,
            chat: DEFAULTS.chat,
            pawfollow: DEFAULTS.pawfollow,
            version: PRICING_VERSION,
          },
        },
      );
      // Also refresh in-memory cache to the new DEFAULTS.
      for (const cat of CATEGORIES) {
        cache[cat] = JSON.parse(JSON.stringify(DEFAULTS[cat]));
      }
      logger.info?.(
        `[pricingService] migrated DB pricing from "${doc.version || 'pre-v23.1'}" → "${PRICING_VERSION}"`,
      );
      return;
    }

    // Same version → load DB values into cache (admin edits respected).
    for (const cat of CATEGORIES) {
      if (doc[cat]) cache[cat] = doc[cat];
    }
    logger.info?.(`[pricingService] loaded pricing from DB (${PRICING_VERSION})`);
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
    pawfollow: cache.pawfollow,
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
        pawfollow: cache.pawfollow,
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
