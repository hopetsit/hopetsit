/**
 * Map Report TTL Scheduler (post-2026-avril data retention update).
 *
 * Originally deleted expired reports every hour. That was reversed: all
 * reports are now kept indefinitely as a historical analytics dataset
 * (community hotspots, recurring hazards, etc.). The visibility window is
 * still enforced by the `/nearby` endpoint filtering on `expiresAt > now`.
 *
 * This scheduler now only:
 *   - Logs report volume stats (live / expired / hidden) once per tick
 *   - Flips expired UserSubscription rows from `active` → `expired` (same
 *     logic as before — subscription renewal fallback when Stripe webhooks
 *     aren't plugged in yet).
 *
 * Note the module still exports `purgeExpiredReports` for backwards-compat
 * tests and emergency manual cleanup, but it's no longer called from tick().
 */

const logger = require('../utils/logger');
const MapReport = require('../models/MapReport');
const UserSubscription = require('../models/UserSubscription');

const ONE_HOUR_MS = 60 * 60 * 1000;

let timer = null;

/**
 * Legacy helper — DO NOT call from tick() anymore. Kept for the rare case
 * where an admin explicitly wants to wipe all expired reports (manual
 * cleanup script, test fixtures, etc.). Production flow keeps all data.
 */
async function purgeExpiredReports() {
  const now = new Date();
  const result = await MapReport.deleteMany({ expiresAt: { $lt: now } });
  if (result.deletedCount > 0) {
    logger.info(`🧹 [ttl] Manual purge removed ${result.deletedCount} expired MapReports`);
  }
  return result.deletedCount;
}

/**
 * Periodic visibility stats — useful to watch the live/expired ratio and
 * catch spikes (e.g. spam).
 */
async function logReportStats() {
  try {
    const now = new Date();
    const [live, expired, hidden] = await Promise.all([
      MapReport.countDocuments({ expiresAt: { $gt: now }, hidden: false }),
      MapReport.countDocuments({ expiresAt: { $lte: now } }),
      MapReport.countDocuments({ hidden: true }),
    ]);
    logger.info(
      `📊 [mapReports] live=${live} expired=${expired} hidden=${hidden}`,
    );
  } catch (e) {
    logger.error('[mapReports/stats] log failed', e);
  }
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
    // Retention policy: KEEP expired reports (analytics dataset).
    // We only log counts and expire stale subscriptions here.
    await logReportStats();
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
