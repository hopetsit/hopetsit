'use strict';
/**
 * 2411 (BOB, ordre de Daniel du 24/11/2026 « oui fais les 3 ») — « LE PROPRIÉTAIRE A REGARDÉ TA PROPOSITION : ÉCRIS-LUI ».
 *
 * Mesure du 24/11 : 24 demandes dont le propriétaire a regardé les candidats, 0 choix ; et sur 30 jours les fils ouverts
 * par un message concret reçoivent une réponse en quelques minutes. Exemple du jour : une propriétaire de Paris regarde
 * ses candidates, la seule bien placée (1,6 km) ne lui a jamais écrit et ne sait pas qu'on l'attend.
 * Le rappel existant (applicationReminder617) part 24 h après la candidature, sans e-mail, sans dire qu'on a regardé.
 *
 * Règle : 20 minutes après qu'un VRAI propriétaire (site ou app, jamais un script) a ouvert ses candidats, si la demande
 * est toujours ouverte et sans choix, chaque prestataire en attente qui ne lui a PAS encore écrit reçoit UNE notification
 * (push + cloche + e-mail, gabarit owner_viewed_2411, 9 langues) qui ouvre la demande, où se trouve le bouton de contact.
 *   · une seule fois par candidature (registre OwnerViewedNudge2411, réservé AVANT l'envoi) ;
 *   · 3 prestataires au plus par demande (les plus proches d'abord), jamais au-delà de la limite de distance ;
 *   · 2 notifications au plus par prestataire sur 24 h ; entre 8 h et 21 h 30 (heure de Paris) seulement ;
 *   · jamais un compte de test, jamais une demande masquée, close, réservée ou dont les dates sont passées ;
 *   · vues de moins de 24 h seulement (on ne réveille pas de vieilles demandes).
 * Interrupteur Render : OWNER_VIEWED_2411=off coupe tout. Simulation : runOnce({ dryRun: true }) n'envoie rien.
 */
const mongoose = require('mongoose');
const logger = require('../utils/logger');
const { TEST_EMAIL_RE } = require('../utils/testAccount2809');

const MIN = 60 * 1000;
const WAIT_MS = 20 * MIN;
const WINDOW_MS = 24 * 60 * MIN;
const TICK_MS = 10 * MIN;
const MAX_PER_POST = 3;
const MAX_PER_PROVIDER_DAY = 2;
const MAX_PER_RUN = 15;
const TEMPLATE = 'owner_viewed_2411';

let timer = null;
let running = false;

const enabled = () => !/^(off|0|false|no)$/i.test(String(process.env.OWNER_VIEWED_2411 || 'on').trim());
const dbReady = () => mongoose.connection && mongoose.connection.readyState === 1;
const idOf = (v) => (v ? String(v._id || v.id || v) : '');
const firstName = (doc) => String((doc && (doc.firstName || doc.name)) || '').trim().split(/\s+/)[0] || '';
const parisHour = (now) => Number(new Intl.DateTimeFormat('en-GB', { hour: '2-digit', hour12: false, timeZone: 'Europe/Paris' }).format(new Date(now)));
const parisMinutes = (now) => {
  const p = new Intl.DateTimeFormat('en-GB', { hour: '2-digit', minute: '2-digit', hour12: false, timeZone: 'Europe/Paris' }).format(new Date(now)).split(':');
  return Number(p[0]) * 60 + Number(p[1]);
};
const daytime = (now) => { const m = parisMinutes(now); return m >= 8 * 60 && m <= 21 * 60 + 30; };

const runOnce = async ({ now = Date.now(), dryRun = false, send } = {}) => {
  const out = { dryRun, examined: 0, sent: 0, wouldSend: 0, skipped: {} };
  const skip = (why) => { out.skipped[why] = (out.skipped[why] || 0) + 1; };
  if (!enabled()) return { ...out, reason: 'off' };
  if (!dbReady()) return { ...out, reason: 'db' };
  if (!daytime(now)) return { ...out, reason: 'night', parisHour: parisHour(now) };
  if (running) return { ...out, reason: 'busy' };
  running = true;
  try {
    const CandidatesView = require('../models/CandidatesView2610');
    const Post = require('../models/Post');
    const Application = require('../models/Application');
    const Owner = require('../models/Owner');
    const Sitter = require('../models/Sitter');
    const Walker = require('../models/Walker');
    const Conversation = require('../models/Conversation');
    const Message = require('../models/Message');
    const Nudge = require('../models/OwnerViewedNudge2411');
    const dist = require('../utils/applicationDistance1610');
    const notify = typeof send === 'function' ? send : require('./notificationSender').sendNotification;

    const views = await CandidatesView.find({
      at: { $gte: new Date(now - WINDOW_MS), $lte: new Date(now - WAIT_MS) }, origin: { $in: ['web', 'app'] },
    }).select('postId ownerId at').sort({ at: -1 }).limit(400).lean();
    const lastView = new Map();
    for (const v of views) if (!lastView.has(String(v.postId))) lastView.set(String(v.postId), v);
    let budget = MAX_PER_RUN;
    for (const [postId, view] of lastView) {
      if (budget <= 0) break;
      out.examined += 1;
      if (!mongoose.isValidObjectId(postId)) { skip('bad_post'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const post = await Post.findById(postId).lean();
      if (!post || post.postType !== 'request' || post.hidden === true || post.bannedAt) { skip('post_hidden'); continue; }
      if (post.status === 'closed' || post.closedAt || (post.reservedBy && post.reservedBy.bookingId)) { skip('post_closed'); continue; }
      const end = post.endDate || post.startDate;
      if (end && new Date(end).getTime() < now) { skip('dates_past'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const owner = await Owner.findById(post.ownerId).select('name firstName email isStaff').lean();
      if (!owner || TEST_EMAIL_RE.test(String(owner.email || '')) || owner.isStaff === true) { skip('owner_test'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const apps = await Application.find({ postId: post._id }).select('sitterId walkerId status createdAt').lean();
      if (apps.some((a) => a.status === 'accepted')) { skip('already_chosen'); continue; }
      const pending = apps.filter((a) => a.status === 'pending' && new Date(a.createdAt).getTime() <= new Date(view.at).getTime());
      if (!pending.length) { skip('no_pending'); continue; }
      const rows = [];
      for (const a of pending) {
        const role = a.walkerId ? 'walker' : 'sitter';
        const pid = idOf(a.walkerId || a.sitterId);
        // eslint-disable-next-line no-await-in-loop
        const p = await (role === 'walker' ? Walker : Sitter).findById(pid).lean();
        if (!p || TEST_EMAIL_RE.test(String(p.email || '')) || p.isStaff === true) { skip('provider_test'); continue; }
        let km = null;
        try { const k = dist.distanceKm(post, p); km = typeof k === 'number' && Number.isFinite(k) ? k : null; } catch (_) { km = null; }
        const max = dist.maxKm();
        if (max > 0 && typeof km === 'number' && km > max) { skip('too_far'); continue; }
        rows.push({ a, role, pid, km });
      }
      rows.sort((x, y) => (x.km == null ? 1e9 : x.km) - (y.km == null ? 1e9 : y.km));
      let perPost = 0;
      for (const r of rows) {
        if (budget <= 0 || perPost >= MAX_PER_POST) break;
        // Le prestataire a-t-il déjà écrit à ce propriétaire ? Alors rien à lui dire.
        // eslint-disable-next-line no-await-in-loop
        const conv = await Conversation.findOne({ ownerId: post.ownerId, [r.role === 'walker' ? 'walkerId' : 'sitterId']: r.pid }).select('_id').lean();
        // eslint-disable-next-line no-await-in-loop
        if (conv && await Message.exists({ conversationId: conv._id, senderRole: r.role })) { skip('already_wrote'); continue; }
        // eslint-disable-next-line no-await-in-loop
        if (await Nudge.exists({ applicationId: String(r.a._id) })) { skip('already_nudged'); continue; }
        // eslint-disable-next-line no-await-in-loop
        const recent = await Nudge.countDocuments({ providerId: r.pid, status: 'sent', createdAt: { $gte: new Date(now - WINDOW_MS) } });
        if (recent >= MAX_PER_PROVIDER_DAY) { skip('provider_cap'); continue; }
        perPost += 1;
        if (dryRun) { out.wouldSend += 1; budget -= 1; continue; }
        let row;
        try {
          // eslint-disable-next-line no-await-in-loop
          row = await Nudge.create({ applicationId: String(r.a._id), postId, providerId: r.pid, providerRole: r.role, viewedAt: view.at });
        } catch (e) { skip('claimed_elsewhere'); continue; }
        try {
          let whereWhen = '';
          try {
            const { datesLine, cityOfPost } = require('../utils/applicationEmailText2610');
            const ns = require('./notificationSender');
            // eslint-disable-next-line no-await-in-loop
            const lang = (typeof ns.resolveRecipientLocale === 'function' ? await ns.resolveRecipientLocale(r.role, r.pid) : 'fr') || 'fr';
            const bits = [cityOfPost(post), datesLine(lang, post)].filter(Boolean).join(', ');
            whereWhen = bits ? ` (${bits})` : '';
          } catch (_) { whereWhen = ''; }
          // eslint-disable-next-line no-await-in-loop
          await notify({
            userId: r.pid, role: r.role, type: 'application_new', templateType: TEMPLATE,
            data: { postId, applicationId: String(r.a._id), ownerName: firstName(owner) || 'HoPetSit', whereWhen },
          });
          // eslint-disable-next-line no-await-in-loop
          await Nudge.updateOne({ _id: row._id }, { $set: { status: 'sent' } });
          out.sent += 1; budget -= 1;
        } catch (e) {
          // eslint-disable-next-line no-await-in-loop
          await Nudge.updateOne({ _id: row._id }, { $set: { status: 'failed', reason: String((e && e.message) || e).slice(0, 120) } }).catch(() => {});
          skip('send_failed');
        }
      }
    }
    if (out.sent || out.wouldSend) logger.info(`[ownerViewed2411] ${dryRun ? 'simulation' : 'envoi'} : ${JSON.stringify(out)}`);
  } catch (e) {
    out.reason = 'error';
    logger.warn(`[ownerViewed2411] passage interrompu : ${e && e.message ? e.message : e}`);
  } finally { running = false; }
  return out;
};

const start = () => {
  if (timer || process.env.NODE_ENV === 'test') return false;
  timer = setInterval(() => { runOnce().catch(() => {}); }, TICK_MS);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info('[ownerViewed2411] « le propriétaire a regardé ta proposition » : passage toutes les 10 min');
  return true;
};
const stop = () => { if (timer) clearInterval(timer); timer = null; };

module.exports = { start, stop, runOnce, enabled, TEMPLATE, WAIT_MS };
