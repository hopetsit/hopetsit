'use strict';

/**
 * 2211 — « RÉSERVER <prénom>, PAYER PLUS TARD » (mesure du 22/11/2026 : 55 propriétaires voient leurs
 * candidats en 30 jours, 2 cliquent « Choisir et payer », 0 paie ; on exigeait la carte tout de suite pour une
 * garde à 38 jours en médiane, avant d'avoir pu parler au gardien).
 *
 * Le propriétaire s'engage sur un gardien SANS carte, lui parle, puis paie — avec une échéance courte :
 *   · POST /applications/:id/respond { action: 'accept', payLater: true } = l'acceptation existante + un bloc
 *     `payLater2211 { at, deadline }` sur la réservation. AUCUNE intention de paiement n'est créée à ce moment
 *     (elle l'est quand il appuie sur « Payer maintenant » : POST /bookings/:id/create-payment-intent) ;
 *   · échéance = 48 h après le choix, ou le début du service moins 2 h si c'est plus tôt ; début dans moins de
 *     6 h → 409 PAY_LATER_TOO_LATE (il ne reste que « Choisir et payer ») ;
 *   · une seule réservation « payer plus tard » par candidature : libérée une fois, elle ne se re-réserve pas
 *     sans payer (409 PAY_LATER_ALREADY_USED) — sinon un gardien pourrait être bloqué indéfiniment ;
 *   · relances de paiement (services/paymentReminder2910, inchangé pour les autres réservations) : à la moitié
 *     du délai puis à 44/48 du délai, soit 24 h et 44 h pour un délai de 48 h ; 2 au maximum, jamais la nuit ;
 *   · échéance dépassée sans paiement : la réservation est LIBÉRÉE par le balayage (toutes les 30 min) — même
 *     effet qu'une annulation par le propriétaire d'une réservation non payée (bookingController.
 *     releaseUnpaidBooking, la fonction que cancelBooking utilise) ; la candidature choisie redevient « en
 *     attente », donc sélectionnable ; les autres candidats n'ont jamais été fermés (siblings1011) ;
 *   · jamais d'effet sur une réservation payée, ni sur une réservation sans `payLater2211`.
 *
 * Notifications : AUCUN nouveau type (l'app installée, build 643, ne connaît pas les types inconnus) — des types
 * existants avec un autre gabarit (`templateType`, mécanisme 615 du notificationSender) :
 *   gardien, au choix      → type application_accepted        gabarit application_accepted_paylater_2211
 *   propriétaire, relance  → type booking_accepted            gabarit pay_later_reminder_2211
 *   propriétaire, libérée  → type application_new             gabarit pay_later_released_owner_2211
 *   gardien, libérée       → type booking_cancelled_by_owner  gabarit pay_later_released_provider_2211
 *
 * Interrupteur PAY_LATER_2211 (allumé par défaut ; `off` : l'option est refusée 409 PAY_LATER_DISABLED et le site
 * masque le bouton ; les réservations déjà faites gardent leur échéance et sont libérées normalement).
 * L'option suppose que les autres candidats restent en attente jusqu'au paiement : SIBLINGS_KEEP_1011=off la coupe.
 * Aucun prix, aucune commission, aucun mouvement d'argent ici.
 */
const logger = require('../utils/logger');

const HOUR = 60 * 60 * 1000;
const HOLD_MS = 48 * HOUR;            // délai pour payer
const BEFORE_START_MS = 2 * HOUR;     // … ou 2 h avant le début du service
const MIN_LEAD_MS = 6 * HOUR;         // début dans moins de 6 h : pas de « payer plus tard »
const TICK_MS = 30 * 60 * 1000;
const CLAIM_MS = 10 * 60 * 1000;      // verrou d'un passage (deux instances ne libèrent pas deux fois)
const INTENT_GRACE_MS = 6 * HOUR;     // intention de paiement illisible : on attend au plus 6 h après l'échéance
const R1_SHARE = 0.5;                 // 24 h sur 48
const R2_SHARE = 44 / 48;             // 44 h sur 48
const OPEN_STATUSES = ['agreed', 'accepted'];
const TEMPLATES = {
  providerChosen: 'application_accepted_paylater_2211',
  ownerReminder: 'pay_later_reminder_2211',
  ownerReleased: 'pay_later_released_owner_2211',
  providerReleased: 'pay_later_released_provider_2211',
};

const switchedOn = () => String(process.env.PAY_LATER_2211 || '').trim().toLowerCase() !== 'off';
/** L'option est proposée : interrupteur allumé ET autres candidats gardés jusqu'au paiement (1011). */
const enabled = () => switchedOn() && require('./siblings1011').enabled();

const ms = (d) => {
  if (!d) return NaN;
  const t = d instanceof Date ? d.getTime() : new Date(d).getTime();
  return Number.isFinite(t) ? t : NaN;
};
const idOf = (x) => (x && typeof x === 'object' && (x._id || x.id) ? String(x._id || x.id) : (x ? String(x) : ''));
const isPaid = (b) => !!b && (b.status === 'paid' || b.paymentStatus === 'paid' || !!b.paidAt);
const firstName = (n) => String(n || '').trim().split(/\s+/)[0] || '';

/** Début du service d'une candidature ou d'une réservation (ms), sinon NaN. */
function startMs(doc) {
  if (!doc) return NaN;
  for (const k of ['startDate', 'serviceDate', 'date']) {
    const t = ms(doc[k]);
    if (Number.isFinite(t)) return t;
  }
  return NaN;
}

/**
 * Échéance d'un « payer plus tard » décidé maintenant.
 * @returns {{ok:true, deadline:Date, holdMs:number} | {ok:false, code:'PAY_LATER_TOO_LATE'}}
 */
function computeDeadline(serviceStartMs, now = new Date()) {
  const t = now.getTime();
  let deadline = t + HOLD_MS;
  if (Number.isFinite(serviceStartMs)) {
    if (serviceStartMs - t < MIN_LEAD_MS) return { ok: false, code: 'PAY_LATER_TOO_LATE' };
    deadline = Math.min(deadline, serviceStartMs - BEFORE_START_MS);
  }
  return { ok: true, deadline: new Date(deadline), holdMs: deadline - t };
}

const MESSAGES = {
  PAY_LATER_DISABLED: 'Pay later is not available. Choose and pay to book.',
  PAY_LATER_TOO_LATE: 'The service starts too soon to book without paying. Choose and pay to book.',
  PAY_LATER_ALREADY_USED: 'This booking was already held once without payment. Choose and pay to book.',
};
const refusal = (code) => ({ ok: false, status: 409, code, error: MESSAGES[code] });

/** Cette candidature a-t-elle déjà été réservée « plus tard » puis libérée faute de paiement ? */
async function alreadyReleased(applicationId) {
  if (!applicationId) return false;
  const Booking = require('../models/Booking');
  return !!(await Booking.exists({ 'payLater2211.applicationId': applicationId, 'payLater2211.releasedAt': { $ne: null } }));
}

/**
 * Contrôle AVANT toute écriture de l'acceptation « payer plus tard ».
 * @returns {{ok:true, at:Date, deadline:Date, holdMs:number} | {ok:false, status:number, code:string, error:string}}
 */
async function checkAccept(application, now = new Date()) {
  if (!enabled()) return refusal('PAY_LATER_DISABLED');
  const d = computeDeadline(startMs(application), now);
  if (!d.ok) return refusal(d.code);
  if (await alreadyReleased(application && application._id)) return refusal('PAY_LATER_ALREADY_USED');
  return { ok: true, at: now, deadline: d.deadline, holdMs: d.holdMs };
}

/** Le bloc écrit sur la réservation au moment du choix. */
const block = (check, application) => ({ at: check.at, deadline: check.deadline, applicationId: application._id });

/** Nombre d'heures (arrondi, ≥ 1) annoncé au gardien et au propriétaire. */
const holdHours = (holdMs) => Math.max(1, Math.round(holdMs / HOUR));

/**
 * Créneau de relance dû maintenant pour une réservation « payer plus tard » ('r1' | 'r2' | null) :
 * moitié du délai, puis 44/48 du délai (24 h et 44 h pour 48 h). Jamais après l'échéance, 2 au maximum.
 */
function dueReminderSlot(payLater, sent, now = new Date()) {
  const at = ms(payLater && payLater.at);
  const deadline = ms(payLater && payLater.deadline);
  if (!Number.isFinite(at) || !Number.isFinite(deadline) || deadline <= at) return null;
  const t = now.getTime();
  if (t >= deadline) return null;
  const done = (sent || []).length;
  if (done >= 2) return null;
  const hold = deadline - at;
  if (done === 0) return t >= at + hold * R1_SHARE ? 'r1' : null;
  return t >= at + hold * R2_SHARE ? 'r2' : null;
}

/** Ce que la relance envoie au propriétaire pour une réservation « payer plus tard ». */
function reminderExtras(payLater, now = new Date()) {
  const left = ms(payLater && payLater.deadline) - now.getTime();
  return { templateType: TEMPLATES.ownerReminder, data: { hoursLeft: Math.max(1, Math.round(left / HOUR)), payLater2211: true } };
}

/**
 * Ce que le site doit savoir pour UNE candidature (lecture pure) :
 *   canReserve — le bouton « Réserver <prénom>, payer plus tard » peut être montré ;
 *   status     — 'waiting' (réservé, à payer avant `deadline`) | 'paid' | 'released' | null.
 * @param {object} app  candidature (brute ou assainie), réservation peuplée ou non
 * @param {object} [ctx] { now, releasedIds:Set<string> } — candidatures déjà libérées une fois
 */
function ownerView(app, ctx = {}) {
  const now = ctx.now instanceof Date ? ctx.now : new Date();
  const on = enabled();
  const out = { enabled: on, canReserve: false, status: null, deadline: null, at: null, holdHours: null };
  if (!app) return out;
  const appId = idOf(app);
  const bk = [app.booking, app.bookingId].find((x) => x && typeof x === 'object' && (x._id || x.id)) || null;
  const pl = bk && bk.payLater2211 && bk.payLater2211.at ? bk.payLater2211 : null;
  const released = !!(ctx.releasedIds && ctx.releasedIds.has(appId));
  if (pl && app.status === 'accepted') {
    out.at = new Date(pl.at).toISOString();
    out.deadline = new Date(pl.deadline).toISOString();
    if (isPaid(bk)) out.status = 'paid';
    else if (OPEN_STATUSES.includes(bk.status) && !pl.releasedAt) out.status = 'waiting';
    return out;
  }
  if (released) out.status = 'released';
  if (!on || released || app.status !== 'pending') return out;
  const p = app.pricing || {};
  if (p.indicative === true || p.stale === true || p.priceToConfirm === true || !(Number(p.totalPrice) > 0)) return out;
  const d = computeDeadline(startMs(app), now);
  if (!d.ok) return out;
  out.canReserve = true;
  out.holdHours = holdHours(d.holdMs);
  return out;
}

/** Les candidatures (parmi `ids`) déjà réservées « plus tard » puis libérées : une requête pour toute la liste. */
async function releasedApplicationIds(ids) {
  const list = (ids || []).filter(Boolean);
  if (!list.length) return new Set();
  const Booking = require('../models/Booking');
  const rows = await Booking.find({ 'payLater2211.applicationId': { $in: list }, 'payLater2211.releasedAt': { $ne: null } })
    .select('payLater2211.applicationId').lean();
  return new Set(rows.map((r) => String(r.payLater2211.applicationId)));
}

/**
 * L'intention de paiement de la réservation a-t-elle abouti chez Airwallex sans que la réservation soit encore
 * marquée payée (confirmation en route) ? 'paid' → on ne libère pas ; 'unknown' → on attend ; 'open' → on libère.
 */
async function intentState(booking, deps = {}) {
  const pid = booking.airwallexPaymentIntentId;
  if (!pid) return 'open';
  try {
    const airwallex = deps.airwallex || require('./airwallexService');
    const pi = await airwallex.retrievePaymentIntent(pid);
    const st = String((pi && pi.status) || '').toUpperCase();
    return PAID_LIKE.includes(st) ? 'paid' : 'open';
  } catch (e) {
    logger.warn(`[payLater2211] intention ${pid} illisible (réservation ${booking._id}) : ${e && e.message ? e.message : e}`);
    return 'unknown';
  }
}

const PAID_LIKE = ['SUCCEEDED', 'REQUIRES_CAPTURE', 'PENDING'];
/**
 * Ferme l'intention de paiement avant la libération : 'closed' (annulée, ou déjà annulée) | 'paid' (aboutie ou en
 * cours de confirmation : ne pas libérer) | 'unknown' (Airwallex illisible : réessayer plus tard).
 */
async function closeIntent(pid, booking, airwallex) {
  try {
    await airwallex.cancelPaymentIntent(pid, { reason: 'requested_by_customer' });
    return 'closed';
  } catch (e) {
    logger.warn(`[payLater2211] intention ${pid} non annulée (réservation ${booking._id}) : ${e && e.message ? e.message : e}`);
  }
  try {
    const pi = await airwallex.retrievePaymentIntent(pid);
    const st = String((pi && pi.status) || '').toUpperCase();
    if (PAID_LIKE.includes(st)) return 'paid';
    return st === 'CANCELLED' ? 'closed' : 'unknown';
  } catch (_) {
    return 'unknown';
  }
}

/**
 * Balayage : réservations « payer plus tard » dont l'échéance est passée sans paiement → libérées.
 * Idempotent (une réservation libérée est annulée : elle ne ressort plus), comptes de test inclus.
 */
async function runRelease(opts = {}) {
  const now = opts.now instanceof Date ? opts.now : new Date();
  const dryRun = opts.dryRun === true;
  const notify = opts.notify || ((n) => require('./notificationSender').sendNotification(n));
  const Booking = require('../models/Booking');
  const Application = require('../models/Application');
  const report = { dryRun, examined: 0, released: [], wouldRelease: [], skipped: {} };
  const skip = (why) => { report.skipped[why] = (report.skipped[why] || 0) + 1; };
  const due = await Booking.find({
    'payLater2211.deadline': { $lte: now },
    status: { $in: OPEN_STATUSES },
    paymentStatus: { $ne: 'paid' },
    paidAt: null,
  }).select('_id').lean();
  for (const row of due) {
    report.examined += 1;
    try {
      const seen = await Booking.findById(row._id);
      if (!seen || !seen.payLater2211 || !seen.payLater2211.at) { skip('no_pay_later'); continue; }
      if (isPaid(seen) || !OPEN_STATUSES.includes(seen.status)) { skip('not_open'); continue; }
      const st = await intentState(seen, opts.deps);
      if (st === 'paid') { skip('intent_succeeded'); continue; }
      if (st === 'unknown' && now.getTime() - ms(seen.payLater2211.deadline) < INTENT_GRACE_MS) { skip('intent_unknown'); continue; }
      const line = {
        bookingId: String(seen._id),
        applicationId: idOf(seen.payLater2211.applicationId),
        deadline: new Date(seen.payLater2211.deadline).toISOString(),
      };
      if (dryRun) { report.wouldRelease.push(line); continue; }
      // Verrou : une seule exécution libère cette réservation, et jamais une réservation payée entre-temps.
      const claimed = await Booking.findOneAndUpdate({
        _id: seen._id,
        status: { $in: OPEN_STATUSES },
        paymentStatus: { $ne: 'paid' },
        paidAt: null,
        $or: [{ 'payLater2211.claimAt': null }, { 'payLater2211.claimAt': { $exists: false } }, { 'payLater2211.claimAt': { $lt: new Date(now.getTime() - CLAIM_MS) } }],
      }, { $set: { 'payLater2211.claimAt': now } }, { new: true });
      if (!claimed) { skip('claimed_or_paid'); continue; }
      // ZOE 22/11 — l'intention ouverte est annulée chez Airwallex AVANT de libérer : une fois annulée, plus aucun
      // paiement ne peut aboutir sur une réservation libérée. Si l'annulation est refusée, on relit l'intention :
      // payée (ou en cours) entre-temps → on ne libère PAS ; illisible → on réessaie au prochain passage.
      const airwallex2211 = (opts.deps && opts.deps.airwallex) || require('./airwallexService');
      if (claimed.airwallexPaymentIntentId) {
        const closed = await closeIntent(claimed.airwallexPaymentIntentId, claimed, airwallex2211);
        if (closed !== 'closed') {
          await Booking.updateOne({ _id: claimed._id }, { $set: { 'payLater2211.claimAt': null } });
          skip(closed === 'paid' ? 'intent_succeeded' : 'intent_unknown');
          continue;
        }
      }
      // Même effet qu'une annulation par le propriétaire d'une réservation non payée (fonction de cancelBooking).
      const { releaseUnpaidBooking } = require('../controllers/bookingController');
      const done = await releaseUnpaidBooking(claimed);
      if (!done) { skip('paid_meanwhile'); continue; }
      // La candidature choisie (celle qui pointe sur CETTE réservation) redevient « en attente ».
      const apps = await Application.find({ bookingId: claimed._id, status: 'accepted' });
      // ZOE 22/11 — réservation en double (double appui) ou candidature retirée entre-temps : aucune candidature ne
      // pointe sur elle → annulée sans bruit (pas de « libérée » envoyé pour une réservation qui n'est pas la vraie).
      if (!apps.length) { skip('orphan'); continue; }
      await Booking.updateOne({ _id: claimed._id }, { $set: { 'payLater2211.releasedAt': now } });
      // Une intention créée PENDANT ce passage (« Payer maintenant » au même instant) est annulée aussi.
      try {
        const after = await Booking.findById(claimed._id).select('airwallexPaymentIntentId').lean();
        const late = after && after.airwallexPaymentIntentId;
        if (late && late !== claimed.airwallexPaymentIntentId) await airwallex2211.cancelPaymentIntent(late, { reason: 'requested_by_customer' });
      } catch (e) {
        logger.warn(`[payLater2211] intention tardive non annulée (réservation ${claimed._id}) : ${e && e.message ? e.message : e}`);
      }
      // Le propriétaire peut encore choisir ce candidat (et payer).
      let postId = '';
      let applicationId = line.applicationId;
      for (const a of apps) {
        a.status = 'pending';
        a.bookingId = null;
        await a.save();
        postId = postId || idOf(a.postId);
        applicationId = applicationId || String(a._id);
      }
      line.applicationsReopened = apps.length;
      const isWalker = !!claimed.walkerId;
      const providerRole = isWalker ? 'walker' : 'sitter';
      const providerId = idOf(isWalker ? claimed.walkerId : claimed.sitterId);
      const ownerId = idOf(claimed.ownerId);
      let providerName = '';
      try {
        const PM = isWalker ? require('../models/Walker') : require('../models/Sitter');
        const prov = providerId ? await PM.findById(providerId).select('name firstName').lean() : null;
        providerName = firstName(prov && (prov.firstName || prov.name));
      } catch (_) { /* sans prénom */ }
      const common = { bookingId: String(claimed._id), ...(applicationId ? { applicationId } : {}), ...(postId ? { postId } : {}), payLater2211: 'released' };
      if (ownerId) {
        await Promise.resolve(notify({
          userId: ownerId, role: 'owner', type: 'application_new', templateType: TEMPLATES.ownerReleased,
          data: { ...common, providerName, providerRole },
        })).catch((e) => logger.warn(`[payLater2211] notification propriétaire : ${e && e.message ? e.message : e}`));
      }
      if (providerId) {
        await Promise.resolve(notify({
          userId: providerId, role: providerRole, type: 'booking_cancelled_by_owner', templateType: TEMPLATES.providerReleased,
          data: { ...common, providerRole },
        })).catch((e) => logger.warn(`[payLater2211] notification prestataire : ${e && e.message ? e.message : e}`));
      }
      report.released.push(line);
    } catch (e) {
      skip('error');
      logger.warn(`[payLater2211] réservation ${row && row._id} : ${e && e.message ? e.message : e}`);
    }
  }
  if (report.released.length) logger.info(`[payLater2211] ${report.released.length} réservation(s) libérée(s) faute de paiement à l'échéance`);
  return report;
}

/** Admin, lecture seule : compteurs + dernières lignes. Jamais d'e-mail, de téléphone ni de nom. */
async function adminSummary({ now = new Date(), limit = 50 } = {}) {
  const Booking = require('../models/Booking');
  const rows = await Booking.find({ 'payLater2211.at': { $ne: null } })
    .sort({ 'payLater2211.at': -1 })
    .select('ownerId sitterId walkerId status paymentStatus paidAt pricing.totalPrice pricing.currency startDate date payLater2211 paymentReminder2910')
    .lean();
  const stateOf = (b) => {
    if (isPaid(b)) return 'paid';
    if (b.payLater2211.releasedAt) return 'released';
    if (OPEN_STATUSES.includes(b.status)) return ms(b.payLater2211.deadline) <= now.getTime() ? 'due' : 'waiting';
    return 'cancelled';
  };
  const counts = { waiting: 0, due: 0, paid: 0, released: 0, cancelled: 0 };
  const lines = [];
  for (const b of rows) {
    const state = stateOf(b);
    counts[state] += 1;
    if (lines.length < limit) {
      lines.push({
        bookingId: String(b._id),
        applicationId: idOf(b.payLater2211.applicationId) || null,
        ownerId: idOf(b.ownerId),
        providerRole: b.walkerId ? 'walker' : 'sitter',
        providerId: idOf(b.walkerId || b.sitterId),
        amount: (b.pricing && b.pricing.totalPrice) || null,
        currency: (b.pricing && b.pricing.currency) || null,
        state,
        at: b.payLater2211.at,
        deadline: b.payLater2211.deadline,
        paidAt: b.paidAt || null,
        releasedAt: b.payLater2211.releasedAt || null,
        reminders: ((b.paymentReminder2910 && b.paymentReminder2910.sent) || []).length,
      });
    }
  }
  return { enabled: enabled(), switch: switchedOn() ? 'on' : 'off', total: rows.length, counts, lines };
}

let timer = null;
let running = false;
const tick = async () => {
  if (running) return;
  running = true;
  try { await runRelease(); } catch (e) { logger.warn(`[payLater2211] passage échoué : ${e && e.message ? e.message : e}`); } finally { running = false; }
};
/** Balayage toutes les 30 min — même éteint (PAY_LATER_2211=off) : les réservations déjà faites gardent leur échéance. */
const startPayLaterScheduler = (opts = {}) => {
  if (timer) return;
  const first = setTimeout(tick, opts.firstDelayMs != null ? opts.firstDelayMs : 6 * 60 * 1000);
  if (typeof first.unref === 'function') first.unref();
  timer = setInterval(tick, opts.intervalMs || TICK_MS);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info('⏳ Réserver, payer plus tard (2211) : libération à l’échéance, balayage toutes les 30 min');
};
const stopPayLaterScheduler = () => { if (timer) { clearInterval(timer); timer = null; } };

module.exports = {
  HOLD_MS, BEFORE_START_MS, MIN_LEAD_MS, TICK_MS, TEMPLATES,
  enabled, switchedOn, startMs, computeDeadline, checkAccept, block, holdHours, alreadyReleased,
  dueReminderSlot, reminderExtras, ownerView, releasedApplicationIds, runRelease, adminSummary,
  startPayLaterScheduler, stopPayLaterScheduler,
};
