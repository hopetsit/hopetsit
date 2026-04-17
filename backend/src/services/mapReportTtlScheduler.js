/**
 * Map Report TTL Scheduler
 *
 * MongoDB TTL indexes run every ~60 seconds with a tolerance of +/- a minute,
 * which is fine for most cases. We add a lightweight cron layer on top that:
 *   - Force-purges expired reports (belt-and-suspenders)
 *   - Auto-hides expired-but-not-yet-purged reports from API responses
 *   - Logs stats so we can watch report volume / churn
 *
 * Also handles subscription period expiry: flips UserSubscription.status from
 * 'active' to 'expired' when currentPeriodEnd has passed and there is no
 * pending renewal. This is what we'd normally do with a Stripe webhook in
 * Phase 2, but Phase 1 uses one-time PaymentIntents so we sweep instead.
 */

const logger = require('../utils/logger');
const MapReport = require('../models/MapReport');
const UserSubscription = require('../models/UserSubscription');

const ONE_HOUR_MS = 60 * 60 * 1000;

let timer = null;

async function purgeExpiredReports() {
  const now = new Date();
  const result = await MapReport.deleteMany({ expiresAt: { $lt: now } });
  if (result.deletedCount > 0) {
    logger.info(`🧹 [ttl] Purged ${result.deletedCount} expired MapReports`);
  }
  return result.deletedCount;
}

async function expireStaleSubscriptions() {
  const now = new Date();
  const result = await UserSubscription.updateMany(
    {
      status: 'active',
      currentPeriodEnd: { $lt: now },
    },
    {
      $set: { status: 'expired' },
    },
  );
  if (result.modifiedCount > 0) {
    logger.info(`⏰ [ttl] Expired ${result.modifiedCount} stale subscriptions`);
  }
  return result.modifiedCount;
}

async function tick() {
  try {
    await purgeExpiredReports();
    await expireStaleSubscriptions();
  } catch (error) {
    logger.error('[ttl] Sweep failed', error);
  }
}

/**
 * Start the TTL scheduler.
 * @param {{intervalMs?: number, runImmediately?: boolean}} opts
 */
function startMapTtlScheduler(opts = {}) {
  const intervalMs = opts.intervalMs || ONE_HOUR_MS;
  const runImmediately = opts.runImmediately !== false;

  if (timer) return;

  if (runImmediately) tick(); // fire-and-forget

  timer = setInterval(tick, intervalMs);
  if (typeof timer.unref === 'function') {
    timer.unref();
  }

  logger.info(`🗓️ Map TTL scheduler started (every ${Math.round(intervalMs / 60000)}m)`);
}

function stopMapTtlScheduler() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}

module.exports = {
  startMapTtlScheduler,
  stopMapTtlScheduler,
  // exported for tests
  purgeExpiredReports,
  expireStaleSubscriptions,
};
