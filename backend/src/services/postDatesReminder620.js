/**
 * 620 (ZOE, 24/10/2026 — ordre de Daniel « dates à prévoir ») — RAPPEL AU PROPRIÉTAIRE
 * D'UNE DEMANDE SANS DATES QUI A DES CANDIDATS : « Pose tes dates pour valider ».
 *
 * RÈGLES (testées dans tests/dates620.test.js) :
 *   · demande (postType 'request') ouverte, non masquée, non réservée, `dateMode: 'tbd'`
 *     (explicite), avec ≥ 1 candidature EN ATTENTE ;
 *   · deux créneaux, une fois chacun : `d1` = 24 h après la publication, `d3` = 72 h après ;
 *     registre PostDatesReminder620 (postId, slot) unique, place réservée avant l'envoi ;
 *   · jamais entre 22 h et 8 h, heure locale du propriétaire (règle du 615) : le rappel
 *     attend le matin ;
 *   · jamais pour un compte +test, staff, sonde, suspendu ;
 *   · canal : cloche + notification du téléphone, PAS d'e-mail (règle de Daniel du 28/09
 *     « pas de spam ») — l'e-mail « candidature reçue » porte déjà le tarif et le lien ;
 *   · type `post_dates_required` (9 langues), data { postId, candidates } : l'app 620 et
 *     le site ouvrent l'édition des dates de la demande.
 */
const logger = require('../utils/logger');
const { decrypt } = require('../utils/encryption');
const { TEST_EMAIL_RE } = require('../utils/testAccount2809');

const HOUR = 60 * 60 * 1000;
const SLOTS = [['d1', 24 * HOUR], ['d3', 72 * HOUR]];
const MAX_POSTS_PER_RUN = 300;
const TICK_MS = 30 * 60 * 1000;
const TYPE = 'post_dates_required';
const HARD_STAFF_EMAILS = ['dadaciao84@gmail.com', 'hopetsit@gmail.com'];
const NOT_A_PERSON_RE = /@invalid\.example$/i;

const plainEmail = (stored) => {
  let e = stored;
  try { e = decrypt(stored); } catch (_) { /* illisible */ }
  return typeof e === 'string' ? e.trim().toLowerCase() : '';
};

/** Créneau dû maintenant (le plus récent non envoyé), ou null. */
const dueSlot = (createdAt, now, sent) => {
  const done = new Set((sent || []).map((s) => s.slot));
  let slot = null;
  for (const [name, delay] of SLOTS) {
    if (now.getTime() >= new Date(createdAt).getTime() + delay && !done.has(name)) slot = name;
  }
  return slot;
};

const runPostDatesReminders = async (opts = {}) => {
  const now = opts.now instanceof Date ? opts.now : new Date();
  const send = typeof opts.send === 'function' ? opts.send : require('./notificationSender').sendNotification;
  const Post = require('../models/Post');
  const Application = require('../models/Application');
  const Owner = require('../models/Owner');
  const Reminder = require('../models/PostDatesReminder620');
  const r615 = require('./applicationReminder615');
  const report = { examined: 0, sent: [], skipped: {} };
  const skip = (why) => { report.skipped[why] = (report.skipped[why] || 0) + 1; };

  let posts = [];
  try {
    posts = await Post.find({
      dateMode: 'tbd', postType: 'request', hidden: { $ne: true }, status: { $ne: 'closed' },
      'reservedBy.bookingId': null, createdAt: { $lte: new Date(now.getTime() - SLOTS[0][1]) },
    }).select('ownerId createdAt location').sort({ createdAt: 1 }).limit(MAX_POSTS_PER_RUN).lean();
  } catch (e) {
    logger.warn(`[dates620] lecture des demandes : ${e && e.message ? e.message : e}`);
    return report;
  }
  const staff = new Set(HARD_STAFF_EMAILS);

  for (const post of posts) {
    report.examined += 1;
    try {
      // eslint-disable-next-line no-await-in-loop
      const candidates = await Application.countDocuments({ postId: post._id, status: 'pending' });
      if (!candidates) { skip('no_candidate'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const sent = await Reminder.find({ postId: post._id }).select('slot').lean();
      const slot = dueSlot(post.createdAt, now, sent);
      if (!slot) { skip('not_due'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const owner = await Owner.findById(post.ownerId).select('email status isStaff location country').lean();
      if (!owner) { skip('no_owner'); continue; }
      const oe = plainEmail(owner.email);
      if (TEST_EMAIL_RE.test(oe) || NOT_A_PERSON_RE.test(oe)) { skip('test'); continue; }
      if (owner.isStaff === true || staff.has(oe)) { skip('staff'); continue; }
      if (owner.status && owner.status !== 'active') { skip('inactive'); continue; }
      const tz = r615.ownerTimeZone(post, owner);
      if (r615.isNight(tz, now.getTime())) { skip('night'); continue; }
      let claim;
      try {
        // eslint-disable-next-line no-await-in-loop
        claim = await Reminder.create({ postId: post._id, slot, ownerId: post.ownerId, candidates, createdAt: now });
      } catch (e) {
        if (e && e.code === 11000) { skip('already'); continue; }
        throw e;
      }
      try {
        // eslint-disable-next-line no-await-in-loop
        await send({
          userId: String(post.ownerId),
          role: 'owner',
          type: TYPE,
          data: { postId: String(post._id), candidates: String(candidates), datesReminder620: slot },
          channels: { email: false },
        });
        report.sent.push({ postId: String(post._id), slot, candidates });
        logger.info(`[dates620] ${slot} envoyé : demande ${post._id}, ${candidates} candidat(s)`);
      } catch (e) {
        // eslint-disable-next-line no-await-in-loop
        await Reminder.updateOne({ _id: claim._id }, { $set: { status: 'failed', error: String(e && e.message ? e.message : e).slice(0, 300) } });
        skip('send_failed');
      }
    } catch (e) {
      skip('error');
      logger.warn(`[dates620] demande ${post && post._id} : ${e && e.message ? e.message : e}`);
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
    const r = await runPostDatesReminders();
    if (r.sent.length) logger.info(`[dates620] passage : ${r.sent.length} rappel(s), ${r.examined} demande(s) examinée(s)`);
  } catch (e) {
    logger.warn(`[dates620] passage échoué : ${e && e.message ? e.message : e}`);
  } finally {
    running = false;
  }
};
/** Balayage toutes les 30 min. `POST_DATES_REMINDERS=off` le coupe sans rebuild. */
const startPostDatesReminderScheduler = (opts = {}) => {
  if (timer) return;
  if (String(process.env.POST_DATES_REMINDERS || '').toLowerCase() === 'off') {
    logger.info('[dates620] désactivé (POST_DATES_REMINDERS=off)');
    return;
  }
  const first = setTimeout(tick, opts.firstDelayMs != null ? opts.firstDelayMs : 3 * 60 * 1000);
  if (typeof first.unref === 'function') first.unref();
  timer = setInterval(tick, opts.intervalMs || TICK_MS);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info('🗓️ Rappel « pose tes dates » 620 démarré (toutes les 30 min)');
};
const stopPostDatesReminderScheduler = () => { if (timer) { clearInterval(timer); timer = null; } };

module.exports = { runPostDatesReminders, startPostDatesReminderScheduler, stopPostDatesReminderScheduler, dueSlot, TYPE, SLOTS };
