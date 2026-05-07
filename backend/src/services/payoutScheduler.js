const logger = require('../utils/logger');
/**
 * Payout scheduler.
 *
 * HopeTSIT business rule (v23.1 part 66 — Daniel) :
 *   The owner pays at booking time. The money is held in escrow until
 *   the DAY THE SERVICE STARTS, at which point we release it to the
 *   provider. Default offset is 0 hours (release at exact start time).
 *   Overridable via env var PAYOUT_RELEASE_OFFSET_HOURS.
 *
 * Rationale : in the pet-sitting market, providers expect to be paid
 * on the day they take charge of the animal. Refund-window protection
 * for the owner stays in place via :
 *   - the cancel < 72h auto-refund flow,
 *   - the "Signaler un problème" admin manual refund.
 *
 * This module starts a lightweight background job that, every 5 minutes,
 * calls `processScheduledSitterPayouts` to release the funds for any
 * booking whose scheduled payout datetime has been reached.
 *
 * We deliberately use `setInterval` instead of a cron library to avoid a
 * new dependency. If the process crashes between two ticks, the next tick
 * will pick up the missed bookings (the query uses `$lte: now`).
 *
 * History:
 *   v17    — interval reduced from 1h to 5min, hour-exact release at start.
 *   v23.1  — release moved temporarily to "service end + 24h".
 *   v23.1.66 — back to "service start" (Daniel's pet-market policy).
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

  // v23.1 part 78 — Daniel : "payout walker reste en attente". Auto-
  // process pending wallet withdrawals via Airwallex Payout API on the
  // same tick as booking payouts.
  const { processPendingWithdrawals } = require('./walletService');

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
    try {
      await processPendingWithdrawals();
    } catch (error) {
      logger.error('❌ Payout scheduler tick (withdrawals) failed', error);
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
    `🗓️  Payout scheduler started (every ${Math.round(intervalMs / 60000)} minutes, service-start release since v23.1.66, hold-admin release since v18.5).`
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
