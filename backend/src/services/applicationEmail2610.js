/**
 * 2610 (ZOE, 26/10/2026 — décision de Daniel, proposition A de SAM) — E-MAIL « CANDIDATS
 * REÇUS » AU PROPRIÉTAIRE, REGROUPÉ.
 *
 * Avant : un e-mail « <Prénom> a répondu — HoPetSit » par candidature (3 à 7 par demande),
 * sans service, ville, photo ni prix, avec « choisis et paie en 2 minutes ».
 * Maintenant (push et cloche INCHANGÉS, ils restent envoyés à chaque candidature) :
 *   · 1re candidature d'une demande → e-mail TOUT DE SUITE ;
 *   · candidatures suivantes → mises en file, UN e-mail par jour au plus et par demande
 *     (balayage toutes les 15 min, ≥ 24 h après le précédent) qui en montre 1 à 3 ;
 *   · jamais plus d'e-mails qu'avant : au plus 1 par candidature, en pratique bien moins ;
 *   · une candidature qui n'est plus en attente au moment du regroupement n'est pas annoncée,
 *     et une demande close/réservée n'en reçoit plus ;
 *   · AUCUN rattrapage : seules les candidatures créées après le déploiement entrent ici.
 * Le registre (models/ApplicationEmail2610) est réservé AVANT l'envoi → jamais deux fois.
 * Coupe-circuit : APPLICATION_EMAIL_2610=off (retour à l'e-mail par candidature).
 */
const logger = require('../utils/logger');
const text = require('../utils/applicationEmailText2610');

const TEMPLATE = 'application_new_2610';
const DAY_MS = 24 * 60 * 60 * 1000;
const TICK_MS = 15 * 60 * 1000;
const MAX_CARDS = 3;

const enabled = () => String(process.env.APPLICATION_EMAIL_2610 || '').toLowerCase() !== 'off';

const idOf = (v) => String(v && v._id ? v._id : v);

/** Cartes (photo, prénom, rôle, prix, km, note) pour une liste de candidatures. */
async function cardsFor(apps, post) {
  const Sitter = require('../models/Sitter');
  const Walker = require('../models/Walker');
  const DIST = require('../utils/applicationDistance1610');
  const { firstNameOf } = require('../utils/applicationNewText617');
  const out = [];
  for (const a of apps) {
    const role = a.walkerId ? 'walker' : 'sitter';
    const Model = role === 'walker' ? Walker : Sitter;
    // eslint-disable-next-line no-await-in-loop
    const p = await Model.findById(idOf(role === 'walker' ? a.walkerId : a.sitterId))
      .select('name firstName avatar rating averageRating reviewsCount location city').lean();
    if (!p) continue;
    let km = null;
    try { km = DIST.distanceKm(post, p); } catch (_) { km = null; }
    out.push({
      name: firstNameOf(p) || 'HoPetSit',
      role,
      avatar: p.avatar && p.avatar.url ? p.avatar.url : '',
      pricing: a.pricing || null,
      km: Number.isFinite(Number(km)) ? Number(km) : null,
      rating: Number(p.averageRating) || Number(p.rating) || 0,
      reviews: Number(p.reviewsCount) || 0,
    });
  }
  return out;
}

/**
 * Envoie l'e-mail pour une liste de candidatures (déjà réservées dans le registre).
 * @returns {Promise<{sent:boolean, reason?:string}>}
 */
async function sendFor({ post, ownerId, apps, send }) {
  const Application = require('../models/Application');
  const Owner = require('../models/Owner');
  const pending = apps.filter((a) => a && a.status === 'pending');
  if (!pending.length) return { sent: false, reason: 'no_pending' };
  const totalPending = await Application.countDocuments({ postId: post._id, status: 'pending' });
  const newest = pending.slice().sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
  const cards = await cardsFor(newest.slice(0, MAX_CARDS), post);
  if (!cards.length) return { sent: false, reason: 'no_provider' };
  let lang = 'fr';
  try {
    const o = await Owner.findById(ownerId).select('appLocale language').lean();
    lang = (o && (o.appLocale || o.language)) || 'fr';
  } catch (_) { /* fr */ }
  // Le notificationSender re-détermine la langue (appLocale des 3 profils) : on rend les
  // textes dans la MÊME résolution pour que l'objet et les cartes soient dans sa langue.
  try {
    const ns = require('./notificationSender');
    if (typeof ns.resolveRecipientLocale === 'function') lang = await ns.resolveRecipientLocale('owner', ownerId) || lang;
  } catch (_) { /* repli */ }
  const data = {
    applicationId: String(newest[0]._id),
    postId: String(post._id),
    candidates: String(Math.max(1, totalPending)),
    ...text.buildEmailData({ lang, post, cards, newCount: pending.length, totalPending }),
  };
  const sender = typeof send === 'function' ? send : require('./notificationSender').sendEmailOnly;
  const r = await sender({ userId: String(ownerId), role: 'owner', type: 'application_new', templateType: TEMPLATE, data });
  return r && r.sent ? { sent: true } : { sent: false, reason: (r && r.reason) || 'not_sent' };
}

const postIsOpen = (post) => !!post && post.status !== 'closed' && !(post.reservedBy && post.reservedBy.bookingId);

/**
 * À appeler à chaque NOUVELLE candidature sur une demande (jamais bloquant).
 * @returns {Promise<{mode:'immediate'|'queued'|'skipped', sent?:boolean, reason?:string}>}
 */
async function onApplicationCreated(application, opts = {}) {
  try {
    if (!enabled()) return { mode: 'skipped', reason: 'off' };
    if (!application || !application.postId) return { mode: 'skipped', reason: 'no_post' };
    const Registry = require('../models/ApplicationEmail2610');
    const Post = require('../models/Post');
    const postId = idOf(application.postId);
    const ownerId = idOf(application.ownerId);
    const now = new Date();
    // Réservation atomique : la 1re candidature crée la ligne (upsert) ; les suivantes la trouvent.
    const before = await Registry.findOneAndUpdate(
      { postId },
      { $setOnInsert: { postId, ownerId, sentIds: [application._id], queuedIds: [], lastSentAt: now, emails: 1, createdAt: now } },
      { upsert: true, new: false },
    ).lean();
    if (before) {
      await Registry.updateOne({ postId }, { $addToSet: { queuedIds: application._id } });
      return { mode: 'queued' };
    }
    const post = await Post.findById(postId).lean();
    if (!postIsOpen(post)) {
      await Registry.updateOne({ postId }, { $set: { lastResult: 'post_closed' } });
      return { mode: 'skipped', reason: 'post_closed' };
    }
    const app = application.toObject ? application.toObject() : application;
    const r = await sendFor({ post, ownerId, apps: [{ ...app, status: app.status || 'pending' }], send: opts.send });
    await Registry.updateOne({ postId }, { $set: { lastResult: r.sent ? 'sent' : r.reason } });
    return { mode: 'immediate', sent: r.sent, reason: r.reason };
  } catch (e) {
    logger.warn(`[appEmail2610] candidature ${application && application._id} : ${e && e.message ? e.message : e}`);
    return { mode: 'skipped', reason: 'error' };
  }
}

/**
 * Regroupement : pour chaque demande dont la file n'est pas vide et dont le dernier e-mail a
 * ≥ 24 h, réserve la file (déplacée dans sentIds, lastSentAt = maintenant) puis envoie UN e-mail.
 */
async function runDigest(opts = {}) {
  const out = { checked: 0, sent: 0, skipped: 0 };
  if (!enabled()) return out;
  const Registry = require('../models/ApplicationEmail2610');
  const Application = require('../models/Application');
  const Post = require('../models/Post');
  const now = opts.now instanceof Date ? opts.now : new Date();
  const due = new Date(now.getTime() - DAY_MS);
  const rows = await Registry.find({ 'queuedIds.0': { $exists: true }, lastSentAt: { $lte: due } }).limit(200).lean();
  for (const row of rows) {
    out.checked += 1;
    try {
      // Réservation : seule l'instance qui déplace la file envoie.
      // eslint-disable-next-line no-await-in-loop
      const claimed = await Registry.findOneAndUpdate(
        { _id: row._id, lastSentAt: row.lastSentAt, 'queuedIds.0': { $exists: true } },
        { $set: { lastSentAt: now, queuedIds: [] }, $addToSet: { sentIds: { $each: row.queuedIds } } },
        { new: false },
      ).lean();
      if (!claimed) { out.skipped += 1; continue; }
      // eslint-disable-next-line no-await-in-loop
      const post = await Post.findById(row.postId).lean();
      if (!postIsOpen(post)) {
        // eslint-disable-next-line no-await-in-loop
        await Registry.updateOne({ _id: row._id }, { $set: { lastResult: 'post_closed' } });
        out.skipped += 1; continue;
      }
      // eslint-disable-next-line no-await-in-loop
      const apps = await Application.find({ _id: { $in: claimed.queuedIds }, status: 'pending' }).lean();
      // eslint-disable-next-line no-await-in-loop
      const r = await sendFor({ post, ownerId: row.ownerId, apps, send: opts.send });
      // eslint-disable-next-line no-await-in-loop
      await Registry.updateOne({ _id: row._id }, { $set: { lastResult: r.sent ? 'sent' : r.reason }, ...(r.sent ? { $inc: { emails: 1 } } : {}) });
      if (r.sent) out.sent += 1; else out.skipped += 1;
    } catch (e) {
      out.skipped += 1;
      logger.warn(`[appEmail2610] regroupement ${row.postId} : ${e && e.message ? e.message : e}`);
    }
  }
  if (out.sent || out.checked) logger.info(`[appEmail2610] regroupement : ${out.sent} e-mail(s), ${out.checked} demande(s) vue(s)`);
  return out;
}

let timer = null;
const tick = () => { runDigest().catch((e) => logger.warn(`[appEmail2610] ${e && e.message ? e.message : e}`)); };
const startApplicationEmailScheduler = (opts = {}) => {
  if (timer) return;
  if (!enabled()) { logger.info('[appEmail2610] désactivé (APPLICATION_EMAIL_2610=off)'); return; }
  const first = setTimeout(tick, opts.firstDelayMs != null ? opts.firstDelayMs : 4 * 60 * 1000);
  if (typeof first.unref === 'function') first.unref();
  timer = setInterval(tick, opts.intervalMs || TICK_MS);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info('📬 E-mail « candidats reçus » 2610 regroupé (balayage toutes les 15 min)');
};
const stopApplicationEmailScheduler = () => { if (timer) { clearInterval(timer); timer = null; } };

module.exports = {
  TEMPLATE, DAY_MS, MAX_CARDS, enabled, onApplicationCreated, runDigest, sendFor, cardsFor,
  startApplicationEmailScheduler, stopApplicationEmailScheduler,
};
