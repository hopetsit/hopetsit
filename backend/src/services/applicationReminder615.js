/**
 * 615 (ZOE, 07/10/2026) — RAPPEL AU PROPRIÉTAIRE QUI A DES CANDIDATS MAIS N'A PAS CHOISI.
 *
 * Accord de Daniel du 07/10 (« ok »). Cas réel : la balade de Nicola (Paris 11e,
 * 05/10) a reçu 2 candidatures ; personne n'a été choisi ; demande expirée, 0 €.
 *
 * RÈGLES (toutes testées dans tests/applicationReminder615.test.js) :
 *   · seulement une DEMANDE (postType 'request') ouverte, non masquée, non
 *     réservée, avec ≥ 1 candidature EN ATTENTE ;
 *   · arrêt dès que le propriétaire a DÉCIDÉ (une candidature acceptée ou
 *     refusée sur cette demande, ou la demande réservée / fermée) ;
 *   · 2 rappels au plus par demande, registre ApplicationReminder615
 *     (postId, slot) unique :
 *       r1 = 2 h après la 1re candidature,
 *       r2 = 2 h avant une balade / une visite, 24 h avant une garde ;
 *     r1 n'est pas envoyé si r2 tombe moins de 2 h plus tard (pas deux
 *     notifications rapprochées) ; jamais de r1 après un r2 ; rien à moins de
 *     30 min du service ni après ;
 *   · jamais entre 22 h et 8 h, heure locale du propriétaire (fuseau de la
 *     demande, sinon de son profil, sinon Paris) : le rappel attend le matin ;
 *   · jamais pour un compte +test, staff, sonde, suspendu ou banni ; les
 *     candidats de test, suspendus, supprimés ou bloqués ne comptent pas ;
 *   · canal : cloche + notification du téléphone, JAMAIS d'e-mail (règle de
 *     Daniel du 28/09 : « pas de spam ») ;
 *   · envoyé sous le type `application_new` avec l'id d'une candidature en
 *     attente : les apps déjà installées (≥ 602) ouvrent alors les candidats de
 *     CETTE demande (Choisir → Payer) — aucun build nécessaire. Le texte vient du
 *     gabarit `application_reminder_615` (9 langues).
 *
 * L'heure d'une demande est enregistrée « murale » (l'heure choisie, lue en UTC :
 * voir utils/requestAlertText612). On la convertit en instant réel avec le fuseau
 * du propriétaire avant de comparer à l'heure actuelle.
 */
const logger = require('../utils/logger');
const { decrypt } = require('../utils/encryption');
const { TEST_EMAIL_RE } = require('../utils/testAccount2809');
const { isWalkingService } = require('../utils/requestAlertText612');

const HOUR = 60 * 60 * 1000;
const R1_DELAY_MS = 2 * HOUR;
const R2_LEAD_SHORT_MS = 2 * HOUR; // balade, visite
const R2_LEAD_SITTING_MS = 24 * HOUR; // garde
const MIN_GAP_MS = 2 * HOUR;
const MIN_BEFORE_START_MS = 30 * 60 * 1000;
const NO_DATE_WINDOW_MS = 7 * 24 * HOUR;
const NIGHT_START = 22;
const NIGHT_END = 8;
const MAX_POSTS_PER_RUN = 300;
const DEFAULT_TZ = 'Europe/Paris';
const TICK_MS = 10 * 60 * 1000;
const HARD_STAFF_EMAILS = ['dadaciao84@gmail.com', 'hopetsit@gmail.com'];
const NOT_A_PERSON_RE = /@invalid\.example$/i;
const TEMPLATE = 'application_reminder_615';

const plainEmail = (stored) => {
  let e = stored;
  try { e = decrypt(stored); } catch (_) { /* illisible */ }
  return typeof e === 'string' ? e.trim().toLowerCase() : '';
};
const staffEmails = () => new Set([
  ...HARD_STAFF_EMAILS,
  ...String(process.env.STAFF_EMAILS || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean),
]);

// ── Fuseau horaire ──────────────────────────────────────────────────────────
const timeZoneForCoords = (lat, lng) => {
  try {
    return require('./plushService607').timeZoneFor(lat, lng);
  } catch (_) {
    return null;
  }
};
const COUNTRY_TZ = { US: 'America/Chicago', GB: 'Europe/London', IE: 'Europe/London', PT: 'Europe/Lisbon' };
const pickCoords = (loc) => {
  if (!loc || typeof loc !== 'object') return null;
  const c = Array.isArray(loc.coordinates) && loc.coordinates.length >= 2
    ? { lat: Number(loc.coordinates[1]), lng: Number(loc.coordinates[0]) }
    : { lat: Number(loc.lat), lng: Number(loc.lng) };
  if (!Number.isFinite(c.lat) || !Number.isFinite(c.lng) || (c.lat === 0 && c.lng === 0)) return null;
  return c;
};
/** Fuseau du propriétaire : lieu de la demande, sinon son profil, sinon son pays, sinon Paris. */
const ownerTimeZone = (post, owner) => {
  for (const c of [pickCoords(post && post.location), pickCoords(owner && owner.location)]) {
    if (c) {
      const tz = timeZoneForCoords(c.lat, c.lng);
      if (tz) return tz;
    }
  }
  const cc = String((owner && owner.country) || '').toUpperCase();
  return COUNTRY_TZ[cc] || DEFAULT_TZ;
};

/** Décalage (ms) du fuseau à un instant donné : heure locale − UTC. */
const tzOffsetMs = (tz, instantMs) => {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: tz, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit',
    }).formatToParts(new Date(instantMs));
    const g = (t) => Number((parts.find((p) => p.type === t) || {}).value);
    const asUtc = Date.UTC(g('year'), g('month') - 1, g('day'), g('hour') % 24, g('minute'), g('second'));
    return asUtc - Math.floor(instantMs / 1000) * 1000;
  } catch (_) {
    return 0;
  }
};
/** Heure « murale » (lue en UTC) → instant réel dans ce fuseau. */
const wallToInstant = (wall, tz) => {
  const w = wall instanceof Date ? wall.getTime() : new Date(wall).getTime();
  if (!Number.isFinite(w)) return null;
  let t = w - tzOffsetMs(tz, w);
  t = w - tzOffsetMs(tz, t); // 2e passe : changement d'heure
  return new Date(t);
};
/** Heure locale (0-23) et jour local AAAA-MM-JJ d'un instant dans ce fuseau. */
const localClock = (tz, instantMs) => {
  const local = new Date(instantMs + tzOffsetMs(tz, instantMs));
  return { hour: local.getUTCHours(), day: local.toISOString().slice(0, 10) };
};
const isNight = (tz, instantMs) => {
  const { hour } = localClock(tz, instantMs);
  return hour >= NIGHT_START || hour < NIGHT_END;
};

const serviceKindOf = (services) => {
  const list = (Array.isArray(services) ? services : [services]).map((s) => String(s || '').trim().toLowerCase()).filter(Boolean);
  if (list.some((s) => isWalkingService(s))) return 'walk';
  if (list.includes('home_visit')) return 'visit';
  return 'sitting';
};

/**
 * Décide, pour UNE demande, quel rappel est dû maintenant. Fonction pure.
 * @returns {{slot:'r1'|'r2'|null, why:string}}
 */
const decideSlot = ({ now, firstAppAt, start, kind, sent = [], tz }) => {
  const nowMs = now.getTime();
  const has = (s) => sent.some((r) => r.slot === s);
  if (sent.length >= 2 || has('r2')) return { slot: null, why: 'done' };
  const startMs = start ? start.getTime() : null;
  if (startMs != null && nowMs >= startMs - MIN_BEFORE_START_MS) return { slot: null, why: 'too_late' };
  const r1Due = firstAppAt.getTime() + R1_DELAY_MS;
  const lead = kind === 'sitting' ? R2_LEAD_SITTING_MS : R2_LEAD_SHORT_MS;
  const r2Due = startMs != null ? startMs - lead : null;
  let slot = null;
  if (r2Due != null && nowMs >= r2Due) {
    // r2 ne suit jamais r1 de moins de 2 h.
    const last = sent.find((r) => r.slot === 'r1');
    if (last && nowMs - new Date(last.createdAt).getTime() < MIN_GAP_MS) return { slot: null, why: 'gap' };
    slot = 'r2';
  } else if (!has('r1') && nowMs >= r1Due) {
    if (startMs == null && nowMs - firstAppAt.getTime() > NO_DATE_WINDOW_MS) return { slot: null, why: 'stale' };
    if (r2Due != null && r2Due - nowMs < MIN_GAP_MS) return { slot: null, why: 'r2_soon' };
    slot = 'r1';
  }
  if (!slot) return { slot: null, why: 'not_due' };
  if (isNight(tz, nowMs)) return { slot: null, why: 'night' };
  return { slot, why: 'due' };
};

const providerModel = (app) => (app.walkerId ? require('../models/Walker') : require('../models/Sitter'));
const providerIdOf = (app) => app.walkerId || app.sitterId;

/** Candidatures en attente qui comptent (candidat réel, actif, non bloqué). */
const validPendingApps = async (apps, owner, ownerIsTest) => {
  const { isOwnerSitterInteractionBlocked } = require('./blockService');
  const out = [];
  for (const a of apps) {
    const pid = providerIdOf(a);
    if (!pid) continue;
    // eslint-disable-next-line no-await-in-loop
    const p = await providerModel(a).findById(pid).select('email status').lean();
    if (!p) continue;
    if (p.status && p.status !== 'active') continue;
    const e = plainEmail(p.email);
    if (NOT_A_PERSON_RE.test(e)) continue;
    if (!ownerIsTest && TEST_EMAIL_RE.test(e)) continue;
    let blocked = false;
    try {
      // eslint-disable-next-line no-await-in-loop
      blocked = !!(await isOwnerSitterInteractionBlocked(owner._id, pid));
    } catch (_) { blocked = false; }
    if (blocked) continue;
    out.push(a);
  }
  return out;
};

/**
 * Un passage : examine les demandes qui ont des candidatures en attente et
 * envoie les rappels dus. Ne lève jamais.
 * @param {{now?:Date, send?:Function}} [opts]  `send` = sendNotification (remplaçable en test)
 * @returns {Promise<{examined:number, sent:Array, skipped:Object}>}
 */
const runApplicationReminders = async (opts = {}) => {
  const now = opts.now instanceof Date ? opts.now : new Date();
  const send = typeof opts.send === 'function' ? opts.send : require('./notificationSender').sendNotification;
  const Application = require('../models/Application');
  const Post = require('../models/Post');
  const Owner = require('../models/Owner');
  const Reminder = require('../models/ApplicationReminder615');
  const report = { examined: 0, sent: [], skipped: {} };
  const skip = (why) => { report.skipped[why] = (report.skipped[why] || 0) + 1; };

  let groups = [];
  try {
    groups = await Application.aggregate([
      { $match: { status: 'pending', postId: { $ne: null } } },
      { $group: { _id: '$postId' } },
      { $limit: MAX_POSTS_PER_RUN },
    ]);
  } catch (e) {
    logger.warn(`[rappel615] lecture des candidatures : ${e && e.message ? e.message : e}`);
    return report;
  }
  const staff = staffEmails();

  for (const g of groups) {
    report.examined += 1;
    try {
      const postId = g._id;
      // eslint-disable-next-line no-await-in-loop
      const post = await Post.findById(postId)
        .select('ownerId postType status hidden reservedBy startDate endDate serviceTypes location closedAt').lean();
      if (!post) { skip('no_post'); continue; }
      if (post.postType && post.postType !== 'request') { skip('not_request'); continue; }
      if (post.hidden || (post.status && post.status !== 'open') || post.closedAt) { skip('closed'); continue; }
      if (post.reservedBy && post.reservedBy.bookingId) { skip('reserved'); continue; }
      // Décision du propriétaire sur cette demande → plus aucun rappel.
      // eslint-disable-next-line no-await-in-loop
      if (await Application.exists({ postId, status: { $in: ['accepted', 'rejected'] } })) { skip('decided'); continue; }

      // eslint-disable-next-line no-await-in-loop
      const owner = await Owner.findById(post.ownerId).select('email status isStaff location country').lean();
      if (!owner) { skip('no_owner'); continue; }
      const oe = plainEmail(owner.email);
      const ownerIsTest = TEST_EMAIL_RE.test(oe);
      if (ownerIsTest) { skip('test'); continue; }
      if (NOT_A_PERSON_RE.test(oe)) { skip('test'); continue; }
      if (owner.isStaff === true || staff.has(oe)) { skip('staff'); continue; }
      if (owner.status && owner.status !== 'active') { skip('inactive'); continue; }

      // eslint-disable-next-line no-await-in-loop
      const pending = await Application.find({ postId, status: 'pending', ownerId: post.ownerId })
        .select('_id sitterId walkerId createdAt').sort({ createdAt: 1 }).lean();
      // eslint-disable-next-line no-await-in-loop
      const valid = await validPendingApps(pending, owner, ownerIsTest);
      if (!valid.length) { skip('no_candidate'); continue; }

      const tz = ownerTimeZone(post, owner);
      const kind = serviceKindOf(post.serviceTypes);
      const start = post.startDate ? wallToInstant(post.startDate, tz) : null;
      // eslint-disable-next-line no-await-in-loop
      const sent = await Reminder.find({ postId }).select('slot createdAt').lean();
      const { slot, why } = decideSlot({ now, firstAppAt: new Date(valid[0].createdAt), start, kind, sent, tz });
      if (!slot) { skip(why); continue; }

      const latest = valid[valid.length - 1];
      // Place réservée AVANT l'envoi : jamais deux fois, même si deux serveurs balaient.
      let claim;
      try {
        // eslint-disable-next-line no-await-in-loop
        claim = await Reminder.create({
          postId, slot, ownerId: post.ownerId, candidates: valid.length,
          applicationId: latest._id, serviceKind: kind, timeZone: tz,
        });
      } catch (e) {
        if (e && e.code === 11000) { skip('already'); continue; }
        throw e;
      }

      const wall = post.startDate ? new Date(post.startDate) : null;
      const hasTime = !!(wall && (wall.getUTCHours() !== 0 || wall.getUTCMinutes() !== 0));
      const sameDay = !!(start && localClock(tz, now.getTime()).day === (wall ? wall.toISOString().slice(0, 10) : ''));
      const data = {
        applicationId: String(latest._id),
        postId: String(postId),
        providerRole: latest.walkerId ? 'walker' : 'sitter',
        providerId: String(providerIdOf(latest)),
        reminder615: slot,
        candidates: String(valid.length),
        serviceKind: kind,
        startWall: wall ? wall.toISOString() : '',
        hasTime: hasTime ? '1' : '0',
        sameDay: sameDay ? '1' : '0',
      };
      try {
        // eslint-disable-next-line no-await-in-loop
        await send({
          userId: String(post.ownerId),
          role: 'owner',
          type: 'application_new',
          templateType: TEMPLATE,
          data,
          channels: { email: false },
        });
        report.sent.push({ postId: String(postId), slot, candidates: valid.length, tz });
        logger.info(`[rappel615] ${slot} envoyé : demande ${postId}, ${valid.length} candidat(s), ${tz}`);
      } catch (e) {
        // eslint-disable-next-line no-await-in-loop
        await Reminder.updateOne({ _id: claim._id }, { $set: { status: 'failed', error: String(e && e.message ? e.message : e).slice(0, 300) } });
        skip('send_failed');
        logger.warn(`[rappel615] envoi échoué ${postId}/${slot} : ${e && e.message ? e.message : e}`);
      }
    } catch (e) {
      skip('error');
      logger.warn(`[rappel615] demande ${g && g._id} : ${e && e.message ? e.message : e}`);
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
    const r = await runApplicationReminders();
    if (r.sent.length) logger.info(`[rappel615] passage : ${r.sent.length} rappel(s), ${r.examined} demande(s) examinée(s)`);
  } catch (e) {
    logger.warn(`[rappel615] passage échoué : ${e && e.message ? e.message : e}`);
  } finally {
    running = false;
  }
};
/** Démarre le balayage (toutes les 10 min). `APPLICATION_REMINDERS=off` le coupe sans rebuild. */
const startApplicationReminderScheduler = (opts = {}) => {
  if (timer) return;
  if (String(process.env.APPLICATION_REMINDERS || '').toLowerCase() === 'off') {
    logger.info('[rappel615] désactivé (APPLICATION_REMINDERS=off)');
    return;
  }
  const intervalMs = opts.intervalMs || TICK_MS;
  // Premier passage 2 min après le démarrage (le serveur finit de s'installer).
  const first = setTimeout(tick, opts.firstDelayMs != null ? opts.firstDelayMs : 2 * 60 * 1000);
  if (typeof first.unref === 'function') first.unref();
  timer = setInterval(tick, intervalMs);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info(`🔔 Rappel candidats 615 démarré (toutes les ${Math.round(intervalMs / 60000)} min)`);
};
const stopApplicationReminderScheduler = () => {
  if (timer) { clearInterval(timer); timer = null; }
};

module.exports = {
  runApplicationReminders,
  startApplicationReminderScheduler,
  stopApplicationReminderScheduler,
  decideSlot,
  wallToInstant,
  ownerTimeZone,
  isNight,
  serviceKindOf,
  TEMPLATE,
};
