/**
 * 2810 (BOB) — E-MAIL « N GARDIENS ONT RÉPONDU — CHOISISSEZ LE VÔTRE » AU PROPRIÉTAIRE QUI
 * N'A JAMAIS OUVERT SES CANDIDATS.
 *
 * Mesure du 28/10 : 15 demandes « dates à prévoir » portent 65 candidatures ; 12 propriétaires
 * sur 15 n'ont jamais ouvert leurs candidats, 14 n'ont pas l'app. L'e-mail « candidats reçus »
 * (2610) part déjà à la 1re candidature ; ceci ajoute au plus 3 e-mails par demande :
 *   · e1 : ≥ 2 h après la 1re candidature en attente (rattrapage : dès l'activation) ;
 *   · e2 : 2 jours après e1 ;  e3 : 5 jours après e1 ;
 *   · ARRÊT dès que le propriétaire a ouvert la page de ses candidats (CandidatesView2610,
 *     hors scripts), ou que la demande est close, masquée ou réservée, ou sans candidature en
 *     attente ; jamais la nuit (22 h – 8 h, heure locale) ; jamais pour un compte +test, staff,
 *     sonde ou suspendu. Lien de désinscription : celui du notificationSender (pied + en-tête).
 * Contenu : celui de l'e-mail 2610 (2-3 cartes : photo, prénom, prix du moteur unique, note ;
 * lien direct « Choisir » qui ouvre la session sans mot de passe quand c'est permis ; ligne
 * « posez vos dates » pour une demande sans dates), dans la langue du propriétaire.
 *
 * DÉSACTIVÉ PAR DÉFAUT : rien n'est envoyé tant que CANDIDATES_REMINDER_2810 ≠ 'on'.
 * La simulation (dryRun) liste ce qui partirait, sans rien écrire ni envoyer.
 */
const logger = require('../utils/logger');
const { decrypt } = require('../utils/encryption');
const { TEST_EMAIL_RE } = require('../utils/testAccount2809');

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;
const FIRST_DELAY = 2 * HOUR;
const FOLLOW_UPS = [['e2', 2 * DAY], ['e3', 5 * DAY]];
const MAX_POSTS_PER_RUN = 300;
const TICK_MS = 30 * 60 * 1000;
const HARD_STAFF_EMAILS = ['dadaciao84@gmail.com', 'hopetsit@gmail.com'];
const NOT_A_PERSON_RE = /@invalid\.example$/i;

const enabled = () => String(process.env.CANDIDATES_REMINDER_2810 || '').toLowerCase() === 'on';

const plainEmail = (stored) => {
  let e = stored;
  try { e = decrypt(stored); } catch (_) { /* illisible */ }
  return typeof e === 'string' ? e.trim().toLowerCase() : '';
};

/**
 * Envoi dû maintenant, ou null.
 * @param {Date} firstAppAt  1re candidature en attente
 * @param {Date} now
 * @param {{slot:string, createdAt:Date}[]} sent  envois déjà faits pour la demande
 */
const dueSlot = (firstAppAt, now, sent) => {
  const done = new Map((sent || []).map((s) => [s.slot, new Date(s.createdAt)]));
  const t = now.getTime();
  if (!done.has('e1')) return t >= new Date(firstAppAt).getTime() + FIRST_DELAY ? 'e1' : null;
  const e1 = done.get('e1').getTime();
  let slot = null;
  for (const [name, delay] of FOLLOW_UPS) {
    if (!done.has(name) && t >= e1 + delay) { slot = name; break; }
  }
  return slot;
};

/** Le propriétaire a-t-il ouvert la page des candidats de cette demande (hors scripts) ? */
async function ownerOpened(postId) {
  const CandidatesView = require('../models/CandidatesView2610');
  const n = await CandidatesView.countDocuments({ postId: String(postId), origin: { $ne: 'script' } });
  return n > 0;
}

const runCandidatesReminders = async (opts = {}) => {
  const now = opts.now instanceof Date ? opts.now : new Date();
  const dryRun = opts.dryRun === true;
  const report = { enabled: enabled(), dryRun, examined: 0, sent: [], wouldSend: [], skipped: {} };
  if (!dryRun && !enabled() && opts.force !== true) return report;
  const Post = require('../models/Post');
  const Application = require('../models/Application');
  const Owner = require('../models/Owner');
  const Reminder = require('../models/CandidatesReminder2810');
  const r615 = require('./applicationReminder615');
  const email2610 = require('./applicationEmail2610');
  const skip = (why) => { report.skipped[why] = (report.skipped[why] || 0) + 1; };

  let posts = [];
  try {
    posts = await Post.find({
      postType: 'request', hidden: { $ne: true }, status: { $ne: 'closed' }, 'reservedBy.bookingId': null,
    }).sort({ createdAt: -1 }).limit(MAX_POSTS_PER_RUN).lean();
  } catch (e) {
    logger.warn(`[relance2810] lecture des demandes : ${e && e.message ? e.message : e}`);
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
      if (await ownerOpened(post._id)) { skip('owner_opened'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const sent = await Reminder.find({ postId: post._id }).select('slot createdAt').lean();
      const slot = dueSlot(apps[0].createdAt, now, sent);
      if (!slot) { skip(sent.length >= 3 ? 'max_3' : 'not_due'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const owner = await Owner.findById(post.ownerId).select('email status isStaff location country').lean();
      if (!owner) { skip('no_owner'); continue; }
      const oe = plainEmail(owner.email);
      if (TEST_EMAIL_RE.test(oe) || NOT_A_PERSON_RE.test(oe)) { skip('test'); continue; }
      if (owner.isStaff === true || staff.has(oe)) { skip('staff'); continue; }
      if (owner.status && owner.status !== 'active') { skip('inactive'); continue; }
      const tz = r615.ownerTimeZone(post, owner);
      if (r615.isNight(tz, now.getTime())) { skip('night'); continue; }
      const line = { postId: String(post._id), slot, candidates: apps.length, dateMode: post.dateMode || '' };
      if (dryRun) { report.wouldSend.push(line); continue; }
      let claim;
      try {
        // eslint-disable-next-line no-await-in-loop
        claim = await Reminder.create({ postId: post._id, slot, ownerId: post.ownerId, candidates: apps.length, createdAt: now });
      } catch (e) {
        if (e && e.code === 11000) { skip('already'); continue; }
        throw e;
      }
      // eslint-disable-next-line no-await-in-loop
      const r = await email2610.sendFor({ post, ownerId: post.ownerId, apps, send: opts.send });
      if (r && r.sent) {
        report.sent.push(line);
        logger.info(`[relance2810] ${slot} envoyé : demande ${post._id}, ${apps.length} candidat(s)`);
      } else {
        // eslint-disable-next-line no-await-in-loop
        await Reminder.updateOne({ _id: claim._id }, { $set: { status: 'failed', error: String((r && r.reason) || 'not_sent').slice(0, 300) } });
        skip(`not_sent:${(r && r.reason) || '?'}`);
      }
    } catch (e) {
      skip('error');
      logger.warn(`[relance2810] demande ${post && post._id} : ${e && e.message ? e.message : e}`);
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
    const r = await runCandidatesReminders();
    if (r.sent.length) logger.info(`[relance2810] passage : ${r.sent.length} e-mail(s), ${r.examined} demande(s) examinée(s)`);
  } catch (e) {
    logger.warn(`[relance2810] passage échoué : ${e && e.message ? e.message : e}`);
  } finally {
    running = false;
  }
};
/** Balayage toutes les 30 min, SEULEMENT si CANDIDATES_REMINDER_2810=on. */
const startCandidatesReminderScheduler = (opts = {}) => {
  if (timer) return;
  if (!enabled()) { logger.info('[relance2810] désactivé (CANDIDATES_REMINDER_2810 ≠ on)'); return; }
  const first = setTimeout(tick, opts.firstDelayMs != null ? opts.firstDelayMs : 5 * 60 * 1000);
  if (typeof first.unref === 'function') first.unref();
  timer = setInterval(tick, opts.intervalMs || TICK_MS);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info('📧 Relance « candidats non consultés » 2810 démarrée (toutes les 30 min)');
};
const stopCandidatesReminderScheduler = () => { if (timer) { clearInterval(timer); timer = null; } };

module.exports = {
  enabled, dueSlot, runCandidatesReminders, startCandidatesReminderScheduler, stopCandidatesReminderScheduler, FIRST_DELAY, FOLLOW_UPS,
};
