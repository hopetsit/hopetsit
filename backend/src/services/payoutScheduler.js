const logger = require('../utils/logger');
/**
 * Payout scheduler.
 *
 * HopeTSIT business rule:
 *   The pet owner pays at booking time, the money is held in escrow, and
 *   the funds are only released to the sitter OR walker at the EXACT start
 *   datetime of the service (hour-exact since Session v17).
 *
 * This module starts a lightweight background job that, every 5 minutes,
 * calls `processScheduledSitterPayouts` to release the funds for any
 * booking whose scheduled payout datetime has been reached.
 *
 * We deliberately use `setInterval` instead of a cron library to avoid a
 * new dependency. If the process crashes between two ticks, the next tick
 * will pick up the missed bookings (the query uses `$lte: now`).
 *
 * Session v17 — the polling interval was reduced from 1h to 5min and the
 * query was tightened from "endOfToday" to "now" so the release happens
 * within ~5 minutes of the booking start time instead of within 24h.
 */

const FIVE_MINUTES_MS = 5 * 60 * 1000;

let timer = null;

/**
 * Start the payout scheduler.
 *
 * @param {object} options
 * @param {number} [options.intervalMs=FIVE_MINUTES_MS] polling interval in ms
 * @param {boolean} [options.runImmediately=true] trigger a first run at boot
 */
function startPayoutScheduler({
  intervalMs = FIVE_MINUTES_MS,
  runImmediately = true,
} = {}) {
  if (timer) {
    return; // already running
  }

  // Lazy require to avoid circular dependency issues at module load time.
  const {
    processScheduledSitterPayouts,
    // v18.5 — #3 hold admin : release les bookings mises en hold quand le
    // provider avait rien configuré, et qui ont depuis ajouté IBAN/PayPal.
    processHeldPayouts,
  } = require('../controllers/bookingController');

  const tick = async () => {
    try {
      await processScheduledSitterPayouts();
    } catch (error) {
      logger.error('❌ Payout scheduler tick (scheduled) failed', error);
    }
    try {
      // Exécuté APRÈS processScheduledSitterPayouts : si on vient de mettre
      // une booking en held au tick courant, elle sera revue au prochain.
      await processHeldPayouts();
    } catch (error) {
      logger.error('❌ Payout scheduler tick (held) failed', error);
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
    `🗓️  Payout scheduler started (every ${Math.round(intervalMs / 60000)} minutes, hour-exact release since v17, hold-admin release since v18.5).`
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
