const logger = require('../utils/logger');

/**
 * v565 — point 24 : PLANIFICATEUR DE REMISE / RENDU DE L'ANIMAL (contrat §7)
 *                   + tick du partage en direct (contrat §8, mapSocket.tickLiveShare).
 *
 * Tourne toutes les 60 s. Idempotent : chaque jalon est une date `handover.*At`
 * réclamée ATOMIQUEMENT (findOneAndUpdate sur « encore null ») avant tout envoi,
 * donc jamais deux notifications pour le même jalon, même avec deux instances.
 *
 * Jalons (réservations PAYÉES, confirmationStatus awaiting_start / in_progress /
 * awaiting_confirmation, et 'confirmed' pour l'auto-confirmation du rendu) :
 *   - T-30 min avant le début   → handover_pickup_soon    (les DEUX parties)
 *   - début + 1 h sans « récupéré » → handover_pickup_overdue (les DEUX parties)
 *   - « récupéré » + 2 h sans confirmation owner → pickupAutoConfirmedAt
 *                                                 + handover_pickup_auto (les DEUX)
 *   - T-30 min avant la fin     → handover_return_soon    (les DEUX parties)
 *   - « rendu » (avec preuve) + 2 h sans confirmation owner → le planificateur de
 *     paiement existant libère le séquestre à autoReleaseAt (= +2 h, posé par
 *     completeService) et auto-confirme ; ici on pose returnAutoConfirmedAt et on
 *     envoie handover_return_auto (les DEUX). Sans preuve : règle 48 h inchangée,
 *     même notification au moment de l'auto-libération.
 *
 * Début/fin calculés par resolveBookingStartDate / resolveBookingEndDate
 * (serviceDate/startDate/endDate/timeSlot). Les réservations dont le jalon est
 * dépassé de plus de 7 jours (données d'avant la fonctionnalité) sont marquées
 * sans notification (anti-spam).
 */

const ONE_MINUTE_MS = 60 * 1000;
const REMINDER_LEAD_MS = 30 * ONE_MINUTE_MS;
const PICKUP_OVERDUE_MS = 60 * ONE_MINUTE_MS;
const LEGACY_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;
const LOOKBACK_PAID_MS = 60 * 24 * 60 * 60 * 1000; // borne la requête : payées < 60 j
const BATCH_LIMIT = 300;

let timer = null;
let running = false;

const _ctrl = () => require('../controllers/bookingController');

const _providerOf = (booking) => {
  if (booking.walkerId) {
    return { id: String(booking.walkerId._id || booking.walkerId), role: 'walker' };
  }
  if (booking.sitterId) {
    return { id: String(booking.sitterId._id || booking.sitterId), role: 'sitter' };
  }
  return { id: null, role: null };
};

/** Notifie le propriétaire ET le prestataire (push + e-mail + cloche). */
async function notifyBoth(booking, type, extra = {}) {
  const { sendNotification } = require('../services/notificationSender');
  const { buildEmailLink } = require('../utils/emailLinkBuilder');
  const bookingId = String(booking._id);
  const data = {
    bookingId,
    emailLink: buildEmailLink('booking', { bookingId }),
    ...extra,
  };
  const ownerId = booking.ownerId ? String(booking.ownerId._id || booking.ownerId) : null;
  const prov = _providerOf(booking);
  const jobs = [];
  if (ownerId) {
    jobs.push(sendNotification({
      userId: ownerId, role: 'owner', type,
      data: { ...data, recipientRole: 'owner' },
      actor: { role: 'system', id: null },
    }));
  }
  if (prov.id) {
    jobs.push(sendNotification({
      userId: prov.id, role: prov.role, type,
      data: { ...data, recipientRole: prov.role, providerRole: prov.role },
      actor: { role: 'system', id: null },
    }));
  }
  const results = await Promise.allSettled(jobs);
  results.forEach((r) => {
    if (r.status === 'rejected') {
      logger.warn(`[handover] ${type} notif failed booking=${bookingId}: ${r.reason?.message || r.reason}`);
    }
  });
}

/** Réclame atomiquement un jalon `handover.<field>` encore null. */
async function claim(Booking, bookingId, field, extraSet = {}) {
  const now = new Date();
  const doc = await Booking.findOneAndUpdate(
    {
      _id: bookingId,
      $or: [{ [`handover.${field}`]: null }, { [`handover.${field}`]: { $exists: false } }],
    },
    { $set: { [`handover.${field}`]: now, ...extraSet } },
    { new: true },
  ).select('_id');
  return !!doc;
}

const _baseFilter = (now, statuses) => ({
  paymentStatus: 'paid',
  status: 'paid',
  confirmationStatus: { $in: statuses },
  paidAt: { $gte: new Date(now.getTime() - LOOKBACK_PAID_MS) },
});

async function processHandoverMilestones() {
  const Booking = require('../models/Booking');
  const { resolveBookingStartDate, resolveBookingEndDate } = _ctrl();
  const now = new Date();
  const t = now.getTime();
  const counts = { pickupSoon: 0, pickupOverdue: 0, pickupAuto: 0, returnSoon: 0, returnAuto: 0 };

  // ── 1) Avant le début : rappel T-30 min + retard H+1 h ────────────────────
  try {
    const candidates = await Booking.find({
      ..._baseFilter(now, ['awaiting_start']),
      serviceStartedAt: null,
      $or: [
        { 'handover.pickupReminderAt': null },
        { 'handover.pickupReminderAt': { $exists: false } },
        { 'handover.pickupOverdueAt': null },
        { 'handover.pickupOverdueAt': { $exists: false } },
      ],
    }).limit(BATCH_LIMIT);
    for (const b of candidates) {
      try {
        const startAt = resolveBookingStartDate(b);
        if (!startAt) continue;
        const s = startAt.getTime();
        const h = b.handover || {};
        // Rappel T-30 min (les DEUX parties), fenêtre [début-30 min ; début].
        if (!h.pickupReminderAt && t >= s - REMINDER_LEAD_MS) {
          if (await claim(Booking, b._id, 'pickupReminderAt')) {
            // Début déjà passé → pas de rappel « dans 30 min » (jalon posé quand même).
            if (t <= s) {
              await notifyBoth(b, 'handover_pickup_soon');
              counts.pickupSoon += 1;
            }
          }
        }
        // Retard : 1 h après le début sans « récupéré ».
        if (!h.pickupOverdueAt && t >= s + PICKUP_OVERDUE_MS) {
          if (await claim(Booking, b._id, 'pickupOverdueAt')) {
            if (t - s <= LEGACY_MAX_AGE_MS) {
              await notifyBoth(b, 'handover_pickup_overdue');
              counts.pickupOverdue += 1;
            }
          }
        }
      } catch (e) {
        logger.warn(`[handover] pickup milestones failed booking=${b._id}: ${e?.message || e}`);
      }
    }
  } catch (e) {
    logger.error('[handover] pickup query failed', e);
  }

  // ── 2) Récupéré + 2 h sans confirmation du propriétaire → auto-confirmation ─
  try {
    const { HANDOVER_AUTO_CONFIRM_MS } = _ctrl();
    const limit = new Date(t - HANDOVER_AUTO_CONFIRM_MS);
    const candidates = await Booking.find({
      ..._baseFilter(now, ['in_progress', 'awaiting_confirmation', 'confirmed']),
      'handover.pickupProviderAt': { $ne: null, $lte: limit },
      'handover.pickupOwnerConfirmedAt': null,
      'handover.pickupAutoConfirmedAt': null,
    }).limit(BATCH_LIMIT);
    for (const b of candidates) {
      try {
        if (await claim(Booking, b._id, 'pickupAutoConfirmedAt')) {
          const since = t - new Date(b.handover.pickupProviderAt).getTime();
          if (since <= LEGACY_MAX_AGE_MS) {
            await notifyBoth(b, 'handover_pickup_auto');
            counts.pickupAuto += 1;
          }
        }
      } catch (e) {
        logger.warn(`[handover] pickup auto-confirm failed booking=${b._id}: ${e?.message || e}`);
      }
    }
  } catch (e) {
    logger.error('[handover] pickup auto query failed', e);
  }

  // ── 3) Rappel T-30 min avant la fin (service en cours) ─────────────────────
  try {
    const candidates = await Booking.find({
      ..._baseFilter(now, ['in_progress']),
      $or: [
        { 'handover.returnReminderAt': null },
        { 'handover.returnReminderAt': { $exists: false } },
      ],
    }).limit(BATCH_LIMIT);
    for (const b of candidates) {
      try {
        const endAt = resolveBookingEndDate(b);
        if (!endAt) continue;
        const e = endAt.getTime();
        if (t < e - REMINDER_LEAD_MS) continue;
        if (await claim(Booking, b._id, 'returnReminderAt')) {
          if (t - e <= LEGACY_MAX_AGE_MS) {
            await notifyBoth(b, 'handover_return_soon');
            counts.returnSoon += 1;
          }
        }
      } catch (err) {
        logger.warn(`[handover] return reminder failed booking=${b._id}: ${err?.message || err}`);
      }
    }
  } catch (e) {
    logger.error('[handover] return reminder query failed', e);
  }

  // ── 4) Rendu auto-confirmé (libération faite par le planificateur de paiement) ─
  // completeService pose autoReleaseAt = +2 h (avec preuve) ou +48 h (sans) ;
  // processScheduledSitterPayouts libère puis passe confirmationStatus à
  // 'confirmed' sans ownerConfirmed « humain » → on stampe et on prévient.
  try {
    const candidates = await Booking.find({
      ..._baseFilter(now, ['confirmed']),
      'handover.returnProviderAt': { $ne: null },
      'handover.returnOwnerConfirmedAt': null,
      'handover.returnAutoConfirmedAt': null,
    }).limit(BATCH_LIMIT);
    for (const b of candidates) {
      try {
        if (await claim(Booking, b._id, 'returnAutoConfirmedAt')) {
          const since = t - new Date(b.handover.returnProviderAt).getTime();
          if (since <= LEGACY_MAX_AGE_MS) {
            await notifyBoth(b, 'handover_return_auto');
            counts.returnAuto += 1;
          }
        }
      } catch (e) {
        logger.warn(`[handover] return auto-confirm failed booking=${b._id}: ${e?.message || e}`);
      }
    }
  } catch (e) {
    logger.error('[handover] return auto query failed', e);
  }

  const total = Object.values(counts).reduce((a, v) => a + v, 0);
  if (total > 0) {
    logger.info(`🐾 [handover] tick: ${JSON.stringify(counts)}`);
  }
  return counts;
}

async function tick() {
  if (running) return; // un tick lent ne se chevauche pas avec le suivant
  running = true;
  try {
    await processHandoverMilestones();
  } catch (e) {
    logger.error('❌ Handover scheduler tick failed', e);
  }
  try {
    // v565 — contrat §8 : fin des durées choisies + rappels « toujours actif ».
    await require('../sockets/mapSocket').tickLiveShare();
  } catch (e) {
    logger.error('❌ Live share tick failed', e);
  }
  running = false;
}

function startHandoverScheduler({ intervalMs = ONE_MINUTE_MS, runImmediately = true } = {}) {
  if (timer) return;
  if (runImmediately) tick();
  timer = setInterval(tick, intervalMs);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info(`🐾 Handover scheduler started (every ${Math.round(intervalMs / 1000)} s, v565 §7 + live share §8).`);
}

function stopHandoverScheduler() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}

module.exports = {
  startHandoverScheduler,
  stopHandoverScheduler,
  processHandoverMilestones,
  tick,
};
