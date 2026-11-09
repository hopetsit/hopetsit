'use strict';

/**
 * 1011 (BOB, constat de ZOE du 09/11 — « Choisir et payer » fermait tout AVANT le paiement).
 *
 * Avant : dès que le propriétaire choisissait un gardien, les autres candidats étaient refusés
 * et prévenus (« annonce pourvue »). S'il s'arrêtait devant la carte, il n'avait plus personne.
 *
 * Maintenant (SIBLINGS_KEEP_1011, « on » par défaut, « off » = ancien comportement) :
 *   · au choix : les autres candidatures RESTENT en attente, personne n'est prévenu ;
 *   · si le propriétaire choisit ensuite quelqu'un d'autre (rien de payé) : l'ancien choix est
 *     libéré (réservation non payée annulée, candidature refusée, gardien prévenu) ;
 *   · si la demande est déjà PAYÉE : plus aucun autre choix possible (409 ALREADY_PAID) ;
 *   · une fois le paiement reçu : les autres candidats sont refusés et prévenus, par un balayage
 *     toutes les 10 min (aucun des chemins de paiement n'est touché).
 * Aucun prix, aucune commission, aucun mouvement d'argent ici.
 */
const logger = require('../utils/logger');

const TICK_MS = 10 * 60 * 1000;
const LOOKBACK_MS = 45 * 24 * 60 * 60 * 1000;
const enabled = () => String(process.env.SIBLINGS_KEEP_1011 || 'on').toLowerCase() !== 'off';
const isPaid = (b) => !!b && (b.status === 'paid' || b.paymentStatus === 'paid' || !!b.paidAt);

const providerOf = (app) => {
  const raw = app.walkerId || app.sitterId;
  const id = raw && raw._id ? raw._id : raw;
  return id ? { role: app.walkerId ? 'walker' : 'sitter', id: String(id) } : null;
};

/** Les autres candidatures déjà « acceptées » de la même demande, avec leur réservation. */
async function previousChoices(application) {
  if (!application || !application.postId) return [];
  const Application = require('../models/Application');
  const Booking = require('../models/Booking');
  const apps = await Application.find({ postId: application.postId, _id: { $ne: application._id }, status: 'accepted' });
  const out = [];
  for (const a of apps) {
    const booking = a.bookingId ? await Booking.findById(a.bookingId) : null;
    out.push({ app: a, booking });
  }
  return out;
}

/** Vrai si la demande a déjà un gardien PAYÉ : on ne choisit plus personne d'autre. */
async function hasPaidChoice(application) {
  return (await previousChoices(application)).some((c) => isPaid(c.booking));
}

/** Le propriétaire change d'avis avant d'avoir payé : on libère l'ancien choix. Renvoie le nombre libéré. */
async function releasePreviousChoices(application, { ownerId, notify } = {}) {
  let n = 0;
  for (const { app, booking } of await previousChoices(application)) {
    if (isPaid(booking)) continue;                       // garde-fou : jamais une réservation payée
    if (booking && booking.status !== 'cancelled') {
      booking.status = 'cancelled';
      booking.paymentStatus = 'cancelled';
      await booking.save();
    }
    app.status = 'rejected';
    await app.save();
    n += 1;
    const p = providerOf(app);
    if (p && typeof notify === 'function') {
      Promise.resolve(notify({
        userId: p.id, role: p.role, type: 'application_rejected_other_accepted',
        data: { applicationId: String(app._id), postId: String(application.postId), providerRole: p.role },
        actor: { role: 'owner', id: ownerId },
      })).catch(() => {});
    }
  }
  if (n) logger.info(`[siblings1011] ancien choix libéré : ${n} (demande ${application.postId})`);
  return n;
}

/** Balayage : demandes dont le gardien choisi est PAYÉ → les autres candidats en attente sont refusés et prévenus. */
async function closeSiblingsOfPaid(opts = {}) {
  const now = opts.now instanceof Date ? opts.now : new Date();
  const dryRun = opts.dryRun === true;
  const notify = opts.notify || require('./notificationSender').sendNotification;
  const Application = require('../models/Application');
  const Booking = require('../models/Booking');
  const report = { enabled: enabled(), dryRun, paidRequests: 0, closed: 0 };
  const paid = await Booking.find({
    $or: [{ paymentStatus: 'paid' }, { status: 'paid' }],
    updatedAt: { $gte: new Date(now.getTime() - LOOKBACK_MS) },
  }).select('_id ownerId').lean();
  if (!paid.length) return report;
  const chosen = await Application.find({
    bookingId: { $in: paid.map((b) => b._id) }, status: 'accepted', postId: { $ne: null },
  }).select('_id postId ownerId').lean();
  for (const c of chosen) {
    const others = await Application.find({ postId: c.postId, _id: { $ne: c._id }, status: 'pending' });
    if (!others.length) continue;
    report.paidRequests += 1;
    for (const o of others) {
      report.closed += 1;
      if (dryRun) continue;
      o.status = 'rejected';
      await o.save();
      const p = providerOf(o);
      if (p) {
        Promise.resolve(notify({
          userId: p.id, role: p.role, type: 'application_rejected_other_accepted',
          data: { applicationId: String(o._id), postId: String(c.postId), providerRole: p.role },
          actor: { role: 'owner', id: String(c.ownerId) },
        })).catch(() => {});
      }
    }
  }
  if (report.closed && !dryRun) logger.info(`[siblings1011] après paiement : ${report.closed} autre(s) candidature(s) close(s) sur ${report.paidRequests} demande(s)`);
  return report;
}

let timer = null;
const tick = () => { closeSiblingsOfPaid().catch((e) => logger.warn(`[siblings1011] balayage : ${e?.message || e}`)); };
const startSiblingsScheduler = (opts = {}) => {
  if (timer) return;
  if (!enabled()) { logger.info('[siblings1011] désactivé (SIBLINGS_KEEP_1011 = off)'); return; }
  const first = setTimeout(tick, opts.firstDelayMs != null ? opts.firstDelayMs : 5 * 60 * 1000);
  if (typeof first.unref === 'function') first.unref();
  timer = setInterval(tick, opts.intervalMs || TICK_MS);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info('🤝 Candidats gardés jusqu’au paiement (1011) : balayage toutes les 10 min');
};
const stopSiblingsScheduler = () => { if (timer) { clearInterval(timer); timer = null; } };

module.exports = { enabled, isPaid, hasPaidChoice, releasePreviousChoices, closeSiblingsOfPaid, startSiblingsScheduler, stopSiblingsScheduler };
