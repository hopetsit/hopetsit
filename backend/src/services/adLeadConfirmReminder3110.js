'use strict';
/**
 * 3110 (ADA, ordre de Daniel 31/10 via BOB) — UN rappel « ta demande attend ta confirmation » aux contacts
 * (pub Meta et site) restés en BROUILLON 3 h (03/11, avant : 24 h) après l'e-mail « confirme », puis plus rien.
 *  - jamais la nuit : heure locale du contact (FR → Europe/Paris, US → America/New_York, sinon Paris) entre 9 h et 20 h ;
 *  - langue du contact (lead.lang) ;
 *  - comptes de test / internes exclus (TEST_LEAD_RE) ;
 *  - brouillons de plus de 10 jours ignorés (le contact est purgé à 60 j de toute façon).
 * AD_LEAD_CONFIRM_REMINDER=off coupe le planificateur ; `runAdLeadConfirmReminders({ now, dryRun })` est pur côté décision.
 */
const logger = require('../utils/logger');

const DAY = 86400000;
// 03/11 (BOB, Daniel « qu'il y ait de vraies annonces ») — rappel à +3 h au lieu de +24 h : la personne
// vient de remplir le formulaire et pense encore à sa garde ; le lendemain, elle a souvent oublié.
// Réglable sans republier : AD_LEAD_CONFIRM_REMINDER_DELAY_H (heures, 24 = ancien comportement).
const DELAY_MS = Math.max(1, Number(process.env.AD_LEAD_CONFIRM_REMINDER_DELAY_H) || 3) * 3600 * 1000;
const MAX_AGE_MS = 10 * DAY;
const TICK_MS = 30 * 60 * 1000;
const TZ_BY_COUNTRY = { FR: 'Europe/Paris', BE: 'Europe/Brussels', CH: 'Europe/Zurich', LU: 'Europe/Luxembourg', US: 'America/New_York', CA: 'America/Toronto', GB: 'Europe/London', ES: 'Europe/Madrid', DE: 'Europe/Berlin', IT: 'Europe/Rome', PT: 'Europe/Lisbon' };

const enabled = () => String(process.env.AD_LEAD_CONFIRM_REMINDER || 'on').toLowerCase() !== 'off';

/** Heure locale (0-23) du contact. Pur. */
function localHour(now, country) {
  const tz = TZ_BY_COUNTRY[String(country || '').toUpperCase()] || 'Europe/Paris';
  try {
    const h = new Intl.DateTimeFormat('en-US', { timeZone: tz, hour: '2-digit', hourCycle: 'h23' }).formatToParts(now).find((x) => x.type === 'hour');
    return Number(h && h.value) % 24;
  } catch (_) { return now.getUTCHours(); }
}
const isDaytime = (now, country) => { const h = localHour(now, country); return h >= 9 && h < 20; };

/** Le rappel est-il dû ? Pur. */
function reminderDue(lead, now) {
  if (!lead || !lead.pendingConfirm || lead.postId) return { due: false, why: 'not_pending' };
  if (lead.confirmReminderAt) return { due: false, why: 'already_reminded' };
  if (!lead.confirmEmailAt) return { due: false, why: 'no_confirm_email' };
  const sentAt = new Date(lead.confirmEmailAt).getTime();
  if (now.getTime() - sentAt < DELAY_MS) return { due: false, why: 'not_yet' };
  if (now.getTime() - sentAt > MAX_AGE_MS) return { due: false, why: 'too_old' };
  if (!isDaytime(now, lead.country)) return { due: false, why: 'night' };
  return { due: true, why: 'due' };
}

async function runAdLeadConfirmReminders(opts = {}) {
  const now = opts.now instanceof Date ? opts.now : new Date();
  const dryRun = opts.dryRun === true;
  const AdLead = require('../models/AdLead2210');
  const { sendConfirmEmail, TEST_LEAD_RE } = require('../routes/adLeads2210');
  const report = { dryRun, examined: 0, sent: 0, wouldSend: 0, skipped: {} };
  const skip = (why) => { report.skipped[why] = (report.skipped[why] || 0) + 1; };
  const leads = await AdLead.find({ pendingConfirm: true, postId: null, confirmReminderAt: null, confirmEmailAt: { $lte: new Date(now.getTime() - DELAY_MS) } }).limit(200);
  for (const lead of leads) {
    report.examined += 1;
    if (TEST_LEAD_RE.test(String(lead.email || ''))) { skip('test'); continue; }
    const d = reminderDue(lead, now);
    if (!d.due) { skip(d.why); continue; }
    if (dryRun) { report.wouldSend += 1; continue; }
    try {
      // eslint-disable-next-line no-await-in-loop
      const ok = await sendConfirmEmail(lead, 'reminder');
      if (ok) report.sent += 1; else skip('not_sent');
    } catch (e) {
      skip('error');
      logger.warn(`[adLeadReminder3110] rappel non envoyé (${String(lead._id).slice(0, 6)}) : ${e && e.message}`);
    }
  }
  if (report.sent || report.wouldSend) logger.info(`[adLeadReminder3110] ${JSON.stringify(report)}`);
  return report;
}

let timer = null;
function startAdLeadConfirmReminderScheduler(o = {}) {
  if (timer) return;
  if (!enabled()) { logger.info('[adLeadReminder3110] désactivé (AD_LEAD_CONFIRM_REMINDER=off)'); return; }
  const tick = () => runAdLeadConfirmReminders().catch((e) => logger.warn(`[adLeadReminder3110] ${e && e.message}`));
  setTimeout(tick, o.initialDelayMs || 90 * 1000).unref();
  timer = setInterval(tick, o.intervalMs || TICK_MS);
  if (timer.unref) timer.unref();
  logger.info('[adLeadReminder3110] planificateur démarré (toutes les 30 min, rappel unique à +24 h, jamais la nuit)');
}
function stopAdLeadConfirmReminderScheduler() { if (timer) { clearInterval(timer); timer = null; } }

module.exports = { runAdLeadConfirmReminders, startAdLeadConfirmReminderScheduler, stopAdLeadConfirmReminderScheduler, reminderDue, localHour, isDaytime, DELAY_MS };
