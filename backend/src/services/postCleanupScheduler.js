/**
 * postCleanupScheduler.js — v23.1.288.
 *
 * Daniel : "après 48h que le service soit FINI, les annonces publiées
 * s'effacent automatiquement."
 *
 * A published request post (annonce) becomes stale once its service is over.
 * "Service over" is detected two ways:
 *   1. closedAt — set by completeBooking() when the related booking is marked
 *      'completed' (the precise "service finished" signal).
 *   2. endDate — the requested service window's end. Even if the booking was
 *      never explicitly completed (or the request was never booked), once the
 *      end date is 48h in the past the annonce is moot and should disappear.
 *
 * 48h after EITHER of those, the post is HARD-deleted (Daniel wants it erased,
 * not just hidden). Media posts (no endDate, never closed) are never matched.
 *
 * Runs hourly, mirrors the structure of mapReportTtlScheduler / payoutScheduler.
 */

const logger = require('../utils/logger');
const Post = require('../models/Post');

const ONE_HOUR_MS = 60 * 60 * 1000;
const GRACE_MS = 48 * 60 * 60 * 1000; // 48h after the service ends.

let timer = null;

/**
 * Delete annonces whose service finished more than 48h ago.
 * @returns {Promise<number>} number of posts deleted.
 */
async function purgeFinishedPosts() {
  const now = Date.now();
  const cutoff = new Date(now - GRACE_MS);
  // Either the booking was completed (closedAt) OR the requested period ended
  // (endDate), and that happened more than 48h ago.
  const filter = {
    $or: [
      { closedAt: { $ne: null, $lt: cutoff } },
      { endDate: { $ne: null, $lt: cutoff } },
    ],
  };

  // Capture the ids first so we can clean up dangling Applications too.
  const stale = await Post.find(filter).select('_id').lean();
  if (!stale.length) return 0;
  const ids = stale.map((p) => p._id);

  const result = await Post.deleteMany({ _id: { $in: ids } });

  // Best-effort: drop orphaned Applications pointing at the deleted posts so
  // they don't linger in candidate feeds. Never let this fail the purge.
  try {
    const Application = require('../models/Application');
    await Application.deleteMany({ postId: { $in: ids } });
  } catch (e) {
    logger.warn(`[postCleanup] application cleanup skipped: ${e.message}`);
  }

  if (result.deletedCount > 0) {
    logger.info(
      `🧹 [postCleanup] Deleted ${result.deletedCount} annonce(s) finished >48h ago`,
    );
  }
  return result.deletedCount || 0;
}

async function tick() {
  try {
    await purgeFinishedPosts();
  } catch (error) {
    logger.error('[postCleanup] sweep failed', error);
  }
}

/**
 * Start the post-cleanup scheduler.
 * @param {{intervalMs?: number, runImmediately?: boolean}} opts
 */
function startPostCleanupScheduler(opts = {}) {
  const intervalMs = opts.intervalMs || ONE_HOUR_MS;
  const runImmediately = opts.runImmediately !== false;

  if (timer) return;

  if (runImmediately) tick(); // fire-and-forget

  timer = setInterval(tick, intervalMs);
  if (typeof timer.unref === 'function') {
    timer.unref();
  }

  logger.info(
    `🗓️ Post cleanup scheduler started (every ${Math.round(intervalMs / 60000)}m, 48h grace)`,
  );
}

function stopPostCleanupScheduler() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}

module.exports = {
  startPostCleanupScheduler,
  stopPostCleanupScheduler,
  // exported for tests / manual runs
  purgeFinishedPosts,
};
