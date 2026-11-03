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
 * 0311 (Daniel : « oui, ajoute-la », après la mesure : 44 demandes sur 47 ont des candidats, 0 choisi,
 * dates à ~48 jours en moyenne) — place `j10` : UN e-mail par demande quand la date de début
 * approche (entre 10 jours et 24 h avant), MÊME si le propriétaire a déjà ouvert ses candidats,
 * HORS du plafond de 3 ; candidature en attente depuis ≥ 24 h, aucun autre e-mail de relance dans
 * les 24 h, jamais la nuit ; demande à dates (jamais « dates à prévoir »).
 * ACTIVÉ PAR DÉFAUT depuis le 28/10 (accord de Daniel) : CANDIDATES_REMINDER_2810=off pour tout couper.
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
const MAX_TOTAL = 3; // 3110 — toutes relances e-mail confondues (2810 + « posez vos dates »)
const TICK_MS = 30 * 60 * 1000;
const HARD_STAFF_EMAILS = ['dadaciao84@gmail.com', 'hopetsit@gmail.com'];
const NOT_A_PERSON_RE = /@invalid\.example$/i;
const J10_WINDOW = 10 * DAY;

/**
 * 0311 — jours restants si la relance J-10 est due pour cette demande, sinon null.
 * @param {object} post  demande (startDate, dateMode)
 * @param {Date} firstAppAt  1re candidature en attente
 * @param {Date} now
 * @param {{slot:string, createdAt:Date}[]} all  relances déjà faites (toutes places)
 */
const j10Due = (post, firstAppAt, now, all) => {
  if (!post || !post.startDate || String(post.dateMode || '').toLowerCase() === 'tbd') return null;
  if ((all || []).some((s) => s.slot === 'j10')) return null;
  const t = now.getTime();
  const left = new Date(post.startDate).getTime() - t;
  if (!Number.isFinite(left) || left < DAY || left > J10_WINDOW) return null;
  if (!firstAppAt || t - new Date(firstAppAt).getTime() < DAY) return null;
  if ((all || []).some((s) => t - new Date(s.createdAt).getTime() < DAY)) return null;
  return Math.max(1, Math.ceil(left / DAY));
};

// ACTIVÉ le 28/10/2026 sur ordre écrit de Daniel (« oui, faut les relancer ») ; CANDIDATES_REMINDER_2810=off pour couper.
const enabled = () => String(process.env.CANDIDATES_REMINDER_2810 || 'on').toLowerCase() !== 'off';

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
      const allRows = await Reminder.find({ postId: post._id }).select('slot createdAt').lean();
      // 0311 — J-10 d'abord : elle passe même si les candidats ont été ouverts et hors plafond.
      const j10Days = j10Due(post, apps[0].createdAt, now, allRows);
      let slot = j10Days ? 'j10' : null;
      if (!slot) {
        // eslint-disable-next-line no-await-in-loop
        if (await ownerOpened(post._id)) { skip('owner_opened'); continue; }
        // 3110 (ADA) — registre COMMUN avec la relance « posez vos dates » : 3 e-mails AU TOTAL par demande
        // (règle de Daniel du 28/10), et jamais deux relances à moins de 24 h d'écart. La place j10 n'y compte pas.
        const all = allRows.filter((s) => s.slot !== 'j10');
        if (all.length >= MAX_TOTAL) { skip('max_3'); continue; }
        if (allRows.some((s) => (s.slot === 'dates' || s.slot === 'j10') && now.getTime() - new Date(s.createdAt).getTime() < DAY)) { skip('recent_other'); continue; }
        const sent = all.filter((s) => s.slot !== 'dates');
        slot = dueSlot(apps[0].createdAt, now, sent);
        if (!slot) { skip(sent.length >= 3 ? 'max_3' : 'not_due'); continue; }
      }
      // eslint-disable-next-line no-await-in-loop
      const owner = await Owner.findById(post.ownerId).select('email status isStaff location country').lean();
      if (!owner) { skip('no_owner'); continue; }
      const oe = plainEmail(owner.email);
      if (TEST_EMAIL_RE.test(oe) || NOT_A_PERSON_RE.test(oe)) { skip('test'); continue; }
      if (owner.isStaff === true || staff.has(oe)) { skip('staff'); continue; }
      if (owner.status && owner.status !== 'active') { skip('inactive'); continue; }
      const tz = r615.ownerTimeZone(post, owner);
      if (r615.isNight(tz, now.getTime())) { skip('night'); continue; }
      const line = { postId: String(post._id), slot, candidates: apps.length, dateMode: post.dateMode || '', ...(j10Days ? { daysLeft: j10Days } : {}) };
      if (dryRun) { report.wouldSend.push(line); continue; }
      let claim;
      try {
        // eslint-disable-next-line no-await-in-loop
        claim = await Reminder.create({ postId: post._id, slot, ownerId: post.ownerId, candidates: apps.length, createdAt: now });
      } catch (e) {
        if (e && e.code === 11000) { skip('already'); continue; }
        throw e;
      }
      // 3110 — course avec l'autre balayage : recompte APRÈS la réservation, on rend la place si > 3.
      // eslint-disable-next-line no-await-in-loop
      if (slot !== 'j10' && await Reminder.countDocuments({ postId: post._id, slot: { $ne: 'j10' } }) > MAX_TOTAL) {
        // eslint-disable-next-line no-await-in-loop
        await Reminder.deleteOne({ _id: claim._id });
        skip('max_3'); continue;
      }
      // eslint-disable-next-line no-await-in-loop
      const r = await email2610.sendFor({ post, ownerId: post.ownerId, apps, send: opts.send, j10Days });
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
/** Balayage toutes les 30 min, sauf si CANDIDATES_REMINDER_2810=off. */
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
  enabled, dueSlot, j10Due, runCandidatesReminders, startCandidatesReminderScheduler, stopCandidatesReminderScheduler, FIRST_DELAY, FOLLOW_UPS, MAX_TOTAL,
};
