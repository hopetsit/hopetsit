const logger = require('../utils/logger');
/**
 * Payout scheduler.
 *
 * HopeTSIT business rule:
 *   The pet owner pays at booking time, the money is held in escrow, and the
 *   funds are only released to the pet sitter on the first day of the pet
 *   sitting service.
 *
 * This module starts a lightweight background job that, every hour, calls
 * `processScheduledSitterPayouts` to release the funds for any booking whose
 * scheduled payout date has been reached.
 *
 * We deliberately use `setInterval` instead of a cron library to avoid a new
 * dependency. If the process crashes between two ticks, the next tick will
 * pick up the missed bookings (the query uses `$lte: now`).
 */

const ONE_HOUR_MS = 60 * 60 * 1000;

let timer = null;

/**
 * Start the payout scheduler.
 *
 * @param {object} options
 * @param {number} [options.intervalMs=ONE_HOUR_MS] polling interval in ms
 * @param {boolean} [options.runImmediately=true] trigger a first run at boot
 */
function startPayoutScheduler({
  intervalMs = ONE_HOUR_MS,
  runImmediately = true,
} = {}) {
  if (timer) {
    return; // already running
  }

  // Lazy require to avoid circular dependency issues at module load time.
  const { processScheduledSitterPayouts } = require('../controllers/bookingController');

  const tick = async () => {
    try {
      await processScheduledSitterPayouts();
    } catch (error) {
      logger.error('❌ Payout scheduler tick failed', error);
    }
  };

  if (runImmediately) {
    // Fire-and-forget: first run should not block the boot sequence.
    tick();
  }

  timer = setInterval(tick, intervalMs);
  // Do not keep the event loop alive just for the scheduler.
  if (typeof timer.unref === 'function') {
    timer.unref();
  }

  logger.info(
    `🗓️  Payout scheduler started (every ${Math.round(intervalMs / 60000)} minutes).`
  );
}

function stopPayoutScheduler() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}

module.exports = {
  startPayoutScheduler,
  stopPayoutScheduler,
};
