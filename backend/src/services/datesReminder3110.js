/**
 * 3110 (ADA, ordre de Daniel via BOB, 31/10/2026 soir : « règle tout, que les propriétaires
 * revenus PAIENT ») — E-MAIL « N GARDIENS SONT PRÊTS — POSEZ VOS DATES ».
 *
 * Mesure de BOB (requests613, 31/10) : sur 16 propriétaires revenus, 5 ont une demande « dates à
 * prévoir » avec des candidats → aucun prix total, aucun « payer » possible tant que les dates ne
 * sont pas posées. Rien ne les y ramenait par e-mail (le rappel 620 est cloche + téléphone, et la
 * relance 2810 s'arrête dès que le propriétaire a ouvert ses candidats).
 *
 * RÈGLES (tests/datesReminder3110.test.js) :
 *   · demande ouverte, non masquée, non réservée, `dateMode: 'tbd'` (explicite), ≥ 1 candidature
 *     en attente dont la 1re a ≥ 24 h ;
 *   · propriétaire NON revenu depuis 24 h : aucune vraie session (app/web, cf. ownerReturn2610 ;
 *     nos scripts et l'admin ne comptent pas) ni ouverture de ses candidats depuis 24 h ;
 *   · UNE seule fois par demande (place `dates` du registre CandidatesReminder2810, prise AVANT
 *     l'envoi) ; registre COMMUN avec 2810 : jamais plus de 3 e-mails de relance par demande AU
 *     TOTAL (règle de Daniel du 28/10), jamais deux relances à moins de 24 h ;
 *   · jamais la nuit (22 h – 8 h, heure locale, règle du 615) : attend le matin ;
 *   · jamais pour un compte +test, staff, sonde ou suspendu ;
 *   · arrêt de fait dès que les dates sont posées (dateMode ≠ tbd), la demande close ou réservée.
 * Contenu (utils/datesReminderText3110) : langue du propriétaire, 2-3 cartes (photo, prénom, tarif
 * indicatif du moteur unique), un bouton « Poser mes dates » → /application/<id> signé `k=` par le
 * notificationSender (session sans mot de passe), mention « fêtes » si les dates
 * indicatives touchent le 15/12 → 06/01.
 * ACTIVÉE PAR DÉFAUT (ordre de Daniel du 31/10) : DATES_REMINDER_3110=off pour couper.
 * Simulation : GET /admin/dates-reminder-3110 (rien écrit, rien envoyé).
 */
const logger = require('../utils/logger');
const { decrypt } = require('../utils/encryption');
const { TEST_EMAIL_RE } = require('../utils/testAccount2809');

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;
const MIN_AGE = DAY;          // 1re candidature en attente depuis ≥ 24 h
const AWAY = DAY;             // propriétaire non revenu depuis 24 h
const GAP = DAY;              // ≥ 24 h après toute autre relance de la demande
const MAX_TOTAL = 3;          // toutes relances e-mail confondues (registre commun avec 2810)
const SLOT = 'dates';
const MAX_POSTS_PER_RUN = 300;
const TICK_MS = 30 * 60 * 1000;
const MAX_CARDS = 3;
const HARD_STAFF_EMAILS = ['dadaciao84@gmail.com', 'hopetsit@gmail.com'];
const NOT_A_PERSON_RE = /@invalid\.example$/i;

const enabled = () => String(process.env.DATES_REMINDER_3110 || 'off').toLowerCase() !== 'off'; // ÉTAPE 1 : simulation en prod d'abord

const plainEmail = (stored) => {
  let e = stored;
  try { e = decrypt(stored); } catch (_) { /* illisible */ }
  return typeof e === 'string' ? e.trim().toLowerCase() : '';
};

/** Dernier VRAI retour du propriétaire (session app/web ou ouverture de ses candidats), ou null. */
async function lastRealReturn(ownerId, postId) {
  const ActivityEvent = require('../models/ActivityEvent');
  const CandidatesView = require('../models/CandidatesView2610');
  const { REAL_SESSION_FILTER } = require('../utils/ownerReturn2610');
  const [ev, view] = await Promise.all([
    ActivityEvent.findOne({ userId: String(ownerId), ...REAL_SESSION_FILTER }).sort({ at: -1 }).select('at').lean(),
    CandidatesView.findOne({ postId: String(postId), origin: { $in: ['app', 'web'] } }).sort({ at: -1 }).select('at').lean(),
  ]);
  const ts = [ev && ev.at, view && view.at].filter(Boolean).map((d) => new Date(d).getTime());
  return ts.length ? new Date(Math.max(...ts)) : null;
}

/** E-mail : cartes des candidats en attente + texte « posez vos dates ». */
async function sendFor({ post, ownerId, apps, send }) {
  const email2610 = require('./applicationEmail2610');
  const text = require('../utils/datesReminderText3110');
  const newest = apps.slice().sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
  const cards = await email2610.cardsFor(newest.slice(0, MAX_CARDS), post);
  if (!cards.length) return { sent: false, reason: 'no_provider' };
  let lang = 'fr';
  try {
    const ns = require('./notificationSender');
    if (typeof ns.resolveRecipientLocale === 'function') lang = (await ns.resolveRecipientLocale('owner', ownerId)) || lang;
  } catch (_) { /* fr */ }
  const appId = String(newest[0]._id);
  const data = {
    applicationId: appId,
    postId: String(post._id),
    candidates: String(apps.length),
    reminder3110: 'dates',
    ...text.buildEmailData({ lang, post, cards, totalPending: apps.length }),
  };
  // Bouton : le type `application_new` + applicationId mène à /application/<id> (page candidats → payer,
  // bloc « dates à prévoir » en tête), signé `k=` par leadOwnerEmailLink (session sans mot de passe).
  const sender = typeof send === 'function' ? send : require('./notificationSender').sendEmailOnly;
  const r = await sender({ userId: String(ownerId), role: 'owner', type: 'application_new', templateType: email2610.TEMPLATE, data });
  return r && r.sent ? { sent: true } : { sent: false, reason: (r && r.reason) || 'not_sent' };
}

const runDatesReminders = async (opts = {}) => {
  const now = opts.now instanceof Date ? opts.now : new Date();
  const dryRun = opts.dryRun === true;
  const report = { enabled: enabled(), dryRun, examined: 0, sent: [], wouldSend: [], skipped: {}, byPost: [] };
  if (!dryRun && !enabled() && opts.force !== true) return report;
  const Post = require('../models/Post');
  const Application = require('../models/Application');
  const Owner = require('../models/Owner');
  const Reminder = require('../models/CandidatesReminder2810');
  const r615 = require('./applicationReminder615');
  const skip = (why) => { report.skipped[why] = (report.skipped[why] || 0) + 1; };

  let posts = [];
  try {
    posts = await Post.find({
      postType: 'request', dateMode: 'tbd', hidden: { $ne: true }, status: { $ne: 'closed' }, 'reservedBy.bookingId': null,
    }).sort({ createdAt: -1 }).limit(MAX_POSTS_PER_RUN).lean();
  } catch (e) {
    logger.warn(`[relance3110] lecture des demandes : ${e && e.message ? e.message : e}`);
    return report;
  }
  const staff = new Set(HARD_STAFF_EMAILS);

  for (const post of posts) {
    report.examined += 1;
    try {
      // eslint-disable-next-line no-await-in-loop
      const apps = await Application.find({ postId: post._id, status: 'pending' }).sort({ createdAt: 1 }).lean();
      if (!apps.length) { skip('no_candidate'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const all = await Reminder.find({ postId: post._id }).select('slot createdAt').lean();
      const line = {
        postId: String(post._id), slot: SLOT, candidates: apps.length,
        remindersBefore: all.length, slotsBefore: all.map((s) => s.slot).sort(),
      };
      if (dryRun) report.byPost.push({ postId: line.postId, candidates: apps.length, remindersBefore: all.length });
      if (all.some((s) => s.slot === SLOT)) { skip('already'); continue; }
      if (all.length >= MAX_TOTAL) { skip('max_3'); continue; }
      if (all.some((s) => now.getTime() - new Date(s.createdAt).getTime() < GAP)) { skip('recent_other'); continue; }
      if (now.getTime() - new Date(apps[0].createdAt).getTime() < MIN_AGE) { skip('not_due'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const owner = await Owner.findById(post.ownerId).select('email status isStaff location country').lean();
      if (!owner) { skip('no_owner'); continue; }
      const oe = plainEmail(owner.email);
      if (TEST_EMAIL_RE.test(oe) || NOT_A_PERSON_RE.test(oe)) { skip('test'); continue; }
      if (owner.isStaff === true || staff.has(oe)) { skip('staff'); continue; }
      if (owner.status && owner.status !== 'active') { skip('inactive'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const back = await lastRealReturn(post.ownerId, post._id);
      if (back && now.getTime() - back.getTime() < AWAY) { skip('owner_back_24h'); continue; }
      const tz = r615.ownerTimeZone(post, owner);
      if (r615.isNight(tz, now.getTime())) { skip('night'); continue; }
      line.ownerReturned = !!back;
      if (dryRun) { report.wouldSend.push(line); continue; }
      let claim;
      try {
        // eslint-disable-next-line no-await-in-loop
        claim = await Reminder.create({ postId: post._id, slot: SLOT, ownerId: post.ownerId, candidates: apps.length, createdAt: now });
      } catch (e) {
        if (e && e.code === 11000) { skip('already'); continue; }
        throw e;
      }
      // Course avec la relance 2810 : recompte APRÈS la réservation, on rend la place si > 3.
      // eslint-disable-next-line no-await-in-loop
      if (await Reminder.countDocuments({ postId: post._id }) > MAX_TOTAL) {
        // eslint-disable-next-line no-await-in-loop
        await Reminder.deleteOne({ _id: claim._id });
        skip('max_3'); continue;
      }
      // eslint-disable-next-line no-await-in-loop
      const r = await sendFor({ post, ownerId: post.ownerId, apps, send: opts.send });
      if (r && r.sent) {
        report.sent.push(line);
        logger.info(`[relance3110] « posez vos dates » envoyé : demande ${post._id}, ${apps.length} candidat(s)`);
      } else {
        // eslint-disable-next-line no-await-in-loop
        await Reminder.updateOne({ _id: claim._id }, { $set: { status: 'failed', error: String((r && r.reason) || 'not_sent').slice(0, 300) } });
        skip(`not_sent:${(r && r.reason) || '?'}`);
      }
    } catch (e) {
      skip('error');
      logger.warn(`[relance3110] demande ${post && post._id} : ${e && e.message ? e.message : e}`);
    }
  }
  return report;
};

let timer = null;
let running = false;
const tick = async () => {
  if (running) return;
  running = true;
  try {
    const r = await runDatesReminders();
    if (r.sent.length) logger.info(`[relance3110] passage : ${r.sent.length} e-mail(s), ${r.examined} demande(s) examinée(s)`);
  } catch (e) {
    logger.warn(`[relance3110] passage échoué : ${e && e.message ? e.message : e}`);
  } finally {
    running = false;
  }
};
/** Balayage toutes les 30 min (décalé de 2810), sauf si DATES_REMINDER_3110=off. */
const startDatesReminderScheduler = (opts = {}) => {
  if (timer) return;
  if (!enabled()) { logger.info('[relance3110] désactivé (DATES_REMINDER_3110=off)'); return; }
  const first = setTimeout(tick, opts.firstDelayMs != null ? opts.firstDelayMs : 12 * 60 * 1000);
  if (typeof first.unref === 'function') first.unref();
  timer = setInterval(tick, opts.intervalMs || TICK_MS);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info('📅 Relance « posez vos dates » 3110 démarrée (toutes les 30 min)');
};
const stopDatesReminderScheduler = () => { if (timer) { clearInterval(timer); timer = null; } };

module.exports = {
  enabled, runDatesReminders, sendFor, lastRealReturn, startDatesReminderScheduler, stopDatesReminderScheduler,
  MIN_AGE, AWAY, GAP, MAX_TOTAL, SLOT,
};
