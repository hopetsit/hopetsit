'use strict';

/**
 * 2910 (BOB, ordre de Daniel « fais tout pour que les propriétaires reviennent et paient ») —
 * RELANCE DE PAIEMENT : un propriétaire a CHOISI un gardien (réservation `agreed` / `accepted`,
 * paiement `pending`) puis s'est arrêté devant la page de carte. Rien ne le rattrapait.
 *
 *   · r1 : 1 h après le choix ; r2 : 24 h après r1 ; 2 au maximum, jamais 2 fois le même créneau ;
 *   · arrêt dès que la réservation est payée, annulée, refusée, ou que le service a commencé ;
 *   · jamais la nuit (21 h → 9 h, fuseau du propriétaire : New York pour une réservation en USD,
 *     Paris sinon) ; comptes test et staff exclus ;
 *   · contenu = la notification existante `booking_accepted` (« Réservation acceptée · procède au
 *     paiement », bouton Payer → /bookings/<id>), dans la langue du compte, par les 3 canaux du
 *     notificationSender (e-mail, cloche, téléphone si l'app est installée).
 * Registre sur la réservation : `paymentReminder2910.sent[]`. PAYMENT_REMINDER_2910=off pour couper.
 * Simulation : GET /admin/payment-reminder-2910 (routes/adminPaymentReminder2910.js).
 */
const logger = require('../utils/logger');
const { decrypt } = require('../utils/encryption');
const { TEST_EMAIL_RE } = require('../utils/testAccount2809');

const TICK_MS = 30 * 60 * 1000;
const R1_DELAY = 60 * 60 * 1000;          // 1 h après le choix
const R2_DELAY = 24 * 60 * 60 * 1000;     // 24 h après r1
const MAX = 2;
const enabled = () => String(process.env.PAYMENT_REMINDER_2910 || 'on').toLowerCase() !== 'off';

const plainEmail = (stored) => {
  let e = stored;
  try { e = decrypt(stored); } catch (_) { /* illisible */ }
  return typeof e === 'string' ? e.trim().toLowerCase() : '';
};

/** Heure locale du propriétaire : 21 h → 9 h = nuit. */
function isNight(currency, now) {
  const tz = String(currency || 'EUR').toUpperCase() === 'USD' ? 'America/New_York' : 'Europe/Paris';
  try {
    const h = Number(new Intl.DateTimeFormat('en-GB', { hour: 'numeric', hour12: false, timeZone: tz }).format(now));
    return h >= 21 || h < 9;
  } catch (_) { return false; }
}

/** Créneau dû maintenant ('r1' | 'r2') ou null. */
function dueSlot(chosenAt, sent, now) {
  const t = now.getTime();
  const done = (sent || []).map((s) => new Date(s.at || s).getTime()).filter((x) => Number.isFinite(x));
  if (done.length >= MAX) return null;
  if (done.length === 0) return t >= new Date(chosenAt).getTime() + R1_DELAY ? 'r1' : null;
  return t >= Math.max(...done) + R2_DELAY ? 'r2' : null;
}

const serviceStarted = (b, now) => {
  const d = b.startDate ? new Date(b.startDate) : (b.serviceDate ? new Date(b.serviceDate) : null);
  return !!(d && !isNaN(d) && d.getTime() <= now.getTime());
};

async function runPaymentReminders(opts = {}) {
  const now = opts.now instanceof Date ? opts.now : new Date();
  const dryRun = opts.dryRun === true;
  const report = { enabled: enabled(), dryRun, examined: 0, sent: [], wouldSend: [], skipped: {} };
  if (!dryRun && !enabled() && opts.force !== true) return report;
  const Booking = require('../models/Booking');
  const Owner = require('../models/Owner');
  const skip = (why) => { report.skipped[why] = (report.skipped[why] || 0) + 1; };
  const bookings = await Booking.find({
    status: { $in: ['agreed', 'accepted'] },
    paymentStatus: 'pending',
  }).select('ownerId sitterId walkerId status paymentStatus startDate serviceDate createdAt acceptedAt agreedAt pricing paymentReminder2910').lean();
  for (const b of bookings) {
    report.examined += 1;
    try {
      if (serviceStarted(b, now)) { skip('service_started'); continue; }
      const chosenAt = b.agreedAt || b.acceptedAt || b.createdAt;
      if (!chosenAt) { skip('no_date'); continue; }
      const slot = dueSlot(chosenAt, (b.paymentReminder2910 && b.paymentReminder2910.sent) || [], now);
      if (!slot) { skip('not_due'); continue; }
      const owner = await Owner.findById(b.ownerId).select('email isStaff').lean();
      if (!owner) { skip('no_owner'); continue; }
      const oe = plainEmail(owner.email);
      if (owner.isStaff || !oe || TEST_EMAIL_RE.test(oe)) { skip('test'); continue; }
      const currency = (b.pricing && b.pricing.currency) || 'EUR';
      if (isNight(currency, now)) { skip('night'); continue; }
      const line = { bookingId: String(b._id), slot, amount: b.pricing && b.pricing.totalPrice, currency };
      if (dryRun) { report.wouldSend.push(line); continue; }
      const ns = require('./notificationSender');
      const r = await ns.sendNotification({
        userId: String(b.ownerId),
        role: 'owner',
        type: 'booking_accepted',
        data: { bookingId: String(b._id), amount: line.amount, currency, reminder: slot },
      });
      await Booking.updateOne({ _id: b._id }, { $push: { 'paymentReminder2910.sent': { at: now, slot } } });
      report.sent.push({ ...line, result: r && (r.ok !== undefined ? r.ok : true) });
    } catch (e) {
      logger.warn(`[relancePaiement2910] réservation ${b && b._id} : ${e && e.message ? e.message : e}`);
    }
  }
  return report;
}

let timer = null;
let running = false;
const tick = async () => {
  if (running) return;
  running = true;
  try {
    const r = await runPaymentReminders();
    if (r.sent.length) logger.info(`[relancePaiement2910] passage : ${r.sent.length} relance(s), ${r.examined} réservation(s) examinée(s)`);
  } catch (e) {
    logger.warn(`[relancePaiement2910] passage échoué : ${e && e.message ? e.message : e}`);
  } finally {
    running = false;
  }
};
/** Balayage toutes les 30 min, sauf si PAYMENT_REMINDER_2910=off. */
const startPaymentReminderScheduler = (opts = {}) => {
  if (timer) return;
  if (!enabled()) { logger.info('[relancePaiement2910] désactivé (PAYMENT_REMINDER_2910 = off)'); return; }
  const first = setTimeout(tick, opts.firstDelayMs != null ? opts.firstDelayMs : 4 * 60 * 1000);
  if (typeof first.unref === 'function') first.unref();
  timer = setInterval(tick, opts.intervalMs || TICK_MS);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info('💳 Relance de paiement 2910 démarrée (toutes les 30 min)');
};
const stopPaymentReminderScheduler = () => { if (timer) { clearInterval(timer); timer = null; } };

module.exports = { enabled, dueSlot, isNight, runPaymentReminders, startPaymentReminderScheduler, stopPaymentReminderScheduler, R1_DELAY, R2_DELAY, MAX };
