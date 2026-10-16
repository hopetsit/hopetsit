/**
 * 617 (ADA, 16/10/2026) — RAPPELS « DES DEUX CÔTÉS » (§B.1 du PROCHAIN_BUILD_617,
 * accord de Daniel du 16/10 : « fais tout le reste et publie »).
 *
 *   (a) 'p24' — au GARDIEN / PROMENEUR dont la candidature (`pending`) attend
 *       depuis ≥ 24 h sur une demande encore ouverte : « <Prénom> n'a pas encore
 *       répondu à ta candidature. Envoie-lui un message pour te présenter. »
 *       Une seule fois par candidature. Type `application_new` + postId : l'app
 *       ouvre la demande (DeepLinkService : prestataire → /post/<postId>) où le
 *       bouton de contact se trouve. Texte : gabarit `application_reminder_provider_617`.
 *   (b) 'x48' — au PROPRIÉTAIRE 48 h avant l'EXPIRATION de sa demande (fin de
 *       prestation = endDate, sinon startDate — règle d'`openRequestFilter`, ADA
 *       16/10) quand ≥ 1 candidat attend : « Ta demande expire dans 2 jours et N
 *       gardien(s) attendent ta réponse : choisis-en un maintenant. » Une fois par
 *       demande. Type `application_new` + applicationId d'un candidat en attente
 *       (comme 615 : l'app ouvre Choisir → Payer). Pas si un rappel 615 (r1/r2) est
 *       parti il y a moins de 2 h. Texte : gabarit `request_expiry_617`.
 *
 * RÈGLES COMMUNES (testées dans tests/applicationReminder617.test.js) :
 *   · jamais entre 22 h et 8 h, heure LOCALE du destinataire (ses coordonnées,
 *     sinon son pays, sinon Paris) — helpers de 615 réutilisés ;
 *   · jamais pour un compte +test (sauf si les deux côtés sont des comptes de
 *     test), sonde @invalid.example, staff, suspendu ; jamais entre personnes
 *     bloquées ;
 *   · rien dès que le propriétaire a décidé (candidature acceptée / refusée,
 *     demande réservée, fermée, masquée) ni quand la prestation est passée ;
 *   · push + cloche, JAMAIS d'e-mail (`channels: { email: false }`) ;
 *   · registre ApplicationReminder617 : la place est prise AVANT l'envoi.
 */
const logger = require('../utils/logger');
const { decrypt } = require('../utils/encryption');
const { TEST_EMAIL_RE } = require('../utils/testAccount2809');
const { deriveNameParts } = require('../utils/personName');
const r615 = require('./applicationReminder615');

const HOUR = 60 * 60 * 1000;
const P24_DELAY_MS = 24 * HOUR;
const X48_LEAD_MS = 48 * HOUR;
const MIN_BEFORE_EXPIRY_MS = 30 * 60 * 1000;
const GAP_615_MS = 2 * HOUR;
const MAX_PER_RUN = 300;
const TICK_MS = 10 * 60 * 1000;
const HARD_STAFF_EMAILS = ['dadaciao84@gmail.com', 'hopetsit@gmail.com'];
const NOT_A_PERSON_RE = /@invalid\.example$/i;
const TEMPLATE_PROVIDER = 'application_reminder_provider_617';
const TEMPLATE_EXPIRY = 'request_expiry_617';

const plainEmail = (stored) => {
  let e = stored;
  try { e = decrypt(stored); } catch (_) { /* illisible */ }
  return typeof e === 'string' ? e.trim().toLowerCase() : '';
};
const staffEmails = () => new Set([
  ...HARD_STAFF_EMAILS,
  ...String(process.env.STAFF_EMAILS || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean),
]);
const firstNameOf = (doc) => {
  const { firstName } = deriveNameParts(doc || {});
  return firstName || String((doc && doc.name) || '').trim().split(/\s+/)[0] || '';
};
const providerModel = (app) => (app.walkerId ? require('../models/Walker') : require('../models/Sitter'));
const providerIdOf = (app) => app.walkerId || app.sitterId;
const providerRoleOf = (app) => (app.walkerId ? 'walker' : 'sitter');

/** Qui ne reçoit jamais de rappel. @returns {string|null} raison, ou null si OK */
const personSkipReason = (doc, { otherIsTest = false } = {}) => {
  if (!doc) return 'no_person';
  const e = plainEmail(doc.email);
  if (NOT_A_PERSON_RE.test(e)) return 'test';
  if (TEST_EMAIL_RE.test(e) && !otherIsTest) return 'test';
  if (doc.isStaff === true || staffEmails().has(e)) return 'staff';
  if (doc.status && doc.status !== 'active') return 'inactive';
  return null;
};
const isTestDoc = (doc) => !!doc && TEST_EMAIL_RE.test(plainEmail(doc.email));

/** Instant d'expiration d'une demande : fin, sinon début (règle openRequestFilter), heure murale → instant. */
const expiryInstant = (post, tz) => {
  const wall = post.endDate || post.startDate;
  if (!wall) return null;
  return r615.wallToInstant(wall, tz);
};
/** La demande est-elle encore ouverte aux candidatures ? @returns {string|null} raison du refus */
const postClosedReason = (post, now, tz) => {
  if (!post) return 'no_post';
  if (post.postType && post.postType !== 'request') return 'not_request';
  if (post.hidden || (post.status && post.status !== 'open') || post.closedAt) return 'closed';
  if (post.reservedBy && post.reservedBy.bookingId) return 'reserved';
  const exp = expiryInstant(post, tz);
  if (exp && exp.getTime() <= now.getTime()) return 'past';
  return null;
};

/**
 * (a) Décision pure : le rappel 'p24' est-il dû pour cette candidature ?
 * @returns {{slot:'p24'|null, why:string}}
 */
const decideProvider = ({ now, appliedAt, sent = [], tz }) => {
  if (sent.some((r) => r.slot === 'p24')) return { slot: null, why: 'done' };
  const applied = appliedAt instanceof Date ? appliedAt.getTime() : new Date(appliedAt).getTime();
  if (!Number.isFinite(applied)) return { slot: null, why: 'no_date' };
  if (now.getTime() < applied + P24_DELAY_MS) return { slot: null, why: 'not_due' };
  if (r615.isNight(tz, now.getTime())) return { slot: null, why: 'night' };
  return { slot: 'p24', why: 'due' };
};

/**
 * (b) Décision pure : le rappel 'x48' est-il dû pour cette demande ?
 * @param {Date|null} expiresAt instant réel d'expiration
 * @param {Array<{createdAt:Date}>} sent615 rappels 615 déjà partis sur cette demande
 * @returns {{slot:'x48'|null, why:string}}
 */
const decideOwnerExpiry = ({ now, expiresAt, sent = [], sent615 = [], tz }) => {
  if (sent.some((r) => r.slot === 'x48')) return { slot: null, why: 'done' };
  if (!expiresAt) return { slot: null, why: 'no_date' };
  const nowMs = now.getTime();
  const expMs = expiresAt.getTime();
  if (expMs - nowMs <= MIN_BEFORE_EXPIRY_MS) return { slot: null, why: 'too_late' };
  if (nowMs < expMs - X48_LEAD_MS) return { slot: null, why: 'not_due' };
  const recent615 = sent615.some((r) => nowMs - new Date(r.createdAt).getTime() < GAP_615_MS);
  if (recent615) return { slot: null, why: 'gap' };
  if (r615.isNight(tz, nowMs)) return { slot: null, why: 'night' };
  return { slot: 'x48', why: 'due' };
};

const Models = () => ({
  Application: require('../models/Application'),
  Post: require('../models/Post'),
  Owner: require('../models/Owner'),
  Reminder: require('../models/ApplicationReminder617'),
  Reminder615: require('../models/ApplicationReminder615'),
});

/** Place prise avant l'envoi ; false si déjà prise. */
const claim = async (Reminder, doc) => {
  try {
    return await Reminder.create(doc);
  } catch (e) {
    if (e && e.code === 11000) return null;
    throw e;
  }
};
const markFailed = (Reminder, id, e) => Reminder.updateOne(
  { _id: id },
  { $set: { status: 'failed', error: String(e && e.message ? e.message : e).slice(0, 300) } },
);
const isBlocked = async (ownerId, providerId) => {
  try {
    const { isOwnerSitterInteractionBlocked } = require('./blockService');
    return !!(await isOwnerSitterInteractionBlocked(ownerId, providerId));
  } catch (_) { return false; }
};

/** (a) Un passage sur les candidatures en attente depuis ≥ 24 h. */
const runProviderReminders = async ({ now, send, report }) => {
  const { Application, Post, Owner, Reminder } = Models();
  const skip = (why) => { report.skipped[why] = (report.skipped[why] || 0) + 1; };
  let apps = [];
  try {
    apps = await Application.find({
      status: 'pending', postId: { $ne: null }, createdAt: { $lte: new Date(now.getTime() - P24_DELAY_MS) },
    }).select('_id postId ownerId sitterId walkerId createdAt').sort({ createdAt: 1 }).limit(MAX_PER_RUN).lean();
  } catch (e) {
    logger.warn(`[rappel617] lecture des candidatures : ${e && e.message ? e.message : e}`);
    return;
  }
  for (const app of apps) {
    report.examined += 1;
    try {
      const pid = providerIdOf(app);
      if (!pid) { skip('no_person'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const provider = await providerModel(app).findById(pid).select('email status isStaff location country name firstName').lean();
      // eslint-disable-next-line no-await-in-loop
      const owner = await Owner.findById(app.ownerId).select('email status isStaff name firstName').lean();
      if (!owner) { skip('no_owner'); continue; }
      const ownerIsTest = isTestDoc(owner);
      const why = personSkipReason(provider, { otherIsTest: ownerIsTest });
      if (why) { skip(why); continue; }
      if (ownerIsTest && !isTestDoc(provider)) { skip('test'); continue; }
      if (NOT_A_PERSON_RE.test(plainEmail(owner.email))) { skip('test'); continue; }
      if (owner.status && owner.status !== 'active') { skip('owner_inactive'); continue; }
      const tz = r615.ownerTimeZone(null, provider);
      // eslint-disable-next-line no-await-in-loop
      const post = await Post.findById(app.postId)
        .select('ownerId postType status hidden reservedBy startDate endDate closedAt').lean();
      const closed = postClosedReason(post, now, tz);
      if (closed) { skip(closed); continue; }
      // eslint-disable-next-line no-await-in-loop
      if (await isBlocked(app.ownerId, pid)) { skip('blocked'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const sent = await Reminder.find({ applicationId: app._id, slot: 'p24' }).select('slot').lean();
      const d = decideProvider({ now, appliedAt: app.createdAt, sent, tz });
      if (!d.slot) { skip(d.why); continue; }
      const key = `p24:${app._id}`;
      const role = providerRoleOf(app);
      // eslint-disable-next-line no-await-in-loop
      const c = await claim(Reminder, {
        key, slot: 'p24', postId: app.postId, applicationId: app._id, recipientRole: role, recipientId: pid, timeZone: tz,
      });
      if (!c) { skip('already'); continue; }
      const data = {
        applicationId: String(app._id),
        postId: String(app.postId),
        providerRole: role,
        providerId: String(pid),
        ownerName: firstNameOf(owner),
        reminder617: 'p24',
      };
      try {
        // eslint-disable-next-line no-await-in-loop
        await send({
          userId: String(pid), role, type: 'application_new', templateType: TEMPLATE_PROVIDER, data, channels: { email: false },
        });
        report.sent.push({ slot: 'p24', applicationId: String(app._id), postId: String(app.postId), role, tz });
        logger.info(`[rappel617] p24 envoyé : candidature ${app._id} (${role}), ${tz}`);
      } catch (e) {
        // eslint-disable-next-line no-await-in-loop
        await markFailed(Reminder, c._id, e);
        skip('send_failed');
        logger.warn(`[rappel617] envoi p24 échoué ${app._id} : ${e && e.message ? e.message : e}`);
      }
    } catch (e) {
      skip('error');
      logger.warn(`[rappel617] candidature ${app && app._id} : ${e && e.message ? e.message : e}`);
    }
  }
};

/** (b) Un passage sur les demandes qui expirent dans 48 h avec des candidats. */
const runOwnerExpiryReminders = async ({ now, send, report }) => {
  const { Application, Post, Owner, Reminder, Reminder615 } = Models();
  const skip = (why) => { report.skipped[why] = (report.skipped[why] || 0) + 1; };
  let groups = [];
  try {
    groups = await Application.aggregate([
      { $match: { status: 'pending', postId: { $ne: null } } },
      { $group: { _id: '$postId' } },
      { $limit: MAX_PER_RUN },
    ]);
  } catch (e) {
    logger.warn(`[rappel617] lecture des demandes : ${e && e.message ? e.message : e}`);
    return;
  }
  for (const g of groups) {
    report.examined += 1;
    const postId = g._id;
    try {
      // eslint-disable-next-line no-await-in-loop
      const post = await Post.findById(postId)
        .select('ownerId postType status hidden reservedBy startDate endDate serviceTypes location closedAt').lean();
      if (!post) { skip('no_post'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const owner = await Owner.findById(post.ownerId).select('email status isStaff location country name firstName').lean();
      const ownerIsTest = isTestDoc(owner);
      // Sonde, staff, suspendu : jamais. Un propriétaire de test n'est rappelé
      // que si ses candidats sont aussi de test (filtre plus bas).
      const why = personSkipReason(owner, { otherIsTest: true });
      if (why) { skip(why); continue; }
      const tz = r615.ownerTimeZone(post, owner);
      const closed = postClosedReason(post, now, tz);
      if (closed) { skip(closed); continue; }
      // eslint-disable-next-line no-await-in-loop
      if (await Application.exists({ postId, status: { $in: ['accepted', 'rejected'] } })) { skip('decided'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const pending = await Application.find({ postId, status: 'pending' })
        .select('_id sitterId walkerId createdAt').sort({ createdAt: 1 }).lean();
      const valid = [];
      for (const a of pending) {
        const pid = providerIdOf(a);
        if (!pid) continue;
        // eslint-disable-next-line no-await-in-loop
        const p = await providerModel(a).findById(pid).select('email status').lean();
        if (personSkipReason(p, { otherIsTest: true })) continue; // sonde, staff, suspendu
        if (isTestDoc(p) !== ownerIsTest) continue; // test et réel ne se mélangent jamais
        // eslint-disable-next-line no-await-in-loop
        if (await isBlocked(post.ownerId, pid)) continue;
        valid.push(a);
      }
      // Un propriétaire de test n'est rappelé que si ses candidats sont aussi de test.
      if (ownerIsTest && !valid.length) { skip('test'); continue; }
      if (!valid.length) { skip('no_candidate'); continue; }
      const [sent, sent615] = await Promise.all([ // eslint-disable-line no-await-in-loop
        Reminder.find({ postId, slot: 'x48' }).select('slot').lean(),
        Reminder615.find({ postId }).select('slot createdAt').lean(),
      ]);
      const d = decideOwnerExpiry({ now, expiresAt: expiryInstant(post, tz), sent, sent615, tz });
      if (!d.slot) { skip(d.why); continue; }
      const latest = valid[valid.length - 1];
      // eslint-disable-next-line no-await-in-loop
      const c = await claim(Reminder, {
        key: `x48:${postId}`, slot: 'x48', postId, applicationId: latest._id, recipientRole: 'owner',
        recipientId: post.ownerId, candidates: valid.length, timeZone: tz,
      });
      if (!c) { skip('already'); continue; }
      const data = {
        applicationId: String(latest._id),
        postId: String(postId),
        providerRole: providerRoleOf(latest),
        providerId: String(providerIdOf(latest)),
        candidates: String(valid.length),
        reminder617: 'x48',
      };
      try {
        // eslint-disable-next-line no-await-in-loop
        await send({
          userId: String(post.ownerId), role: 'owner', type: 'application_new', templateType: TEMPLATE_EXPIRY, data, channels: { email: false },
        });
        report.sent.push({ slot: 'x48', postId: String(postId), candidates: valid.length, tz });
        logger.info(`[rappel617] x48 envoyé : demande ${postId}, ${valid.length} candidat(s), ${tz}`);
      } catch (e) {
        // eslint-disable-next-line no-await-in-loop
        await markFailed(Reminder, c._id, e);
        skip('send_failed');
        logger.warn(`[rappel617] envoi x48 échoué ${postId} : ${e && e.message ? e.message : e}`);
      }
    } catch (e) {
      skip('error');
      logger.warn(`[rappel617] demande ${postId} : ${e && e.message ? e.message : e}`);
    }
  }
};

/**
 * Un passage complet (a) puis (b). Ne lève jamais.
 * @param {{now?:Date, send?:Function}} [opts]
 * @returns {Promise<{examined:number, sent:Array, skipped:Object}>}
 */
const runReminders617 = async (opts = {}) => {
  const now = opts.now instanceof Date ? opts.now : new Date();
  const send = typeof opts.send === 'function' ? opts.send : require('./notificationSender').sendNotification;
  const report = { examined: 0, sent: [], skipped: {} };
  try { await runProviderReminders({ now, send, report }); } catch (e) { logger.warn(`[rappel617] (a) : ${e && e.message ? e.message : e}`); }
  try { await runOwnerExpiryReminders({ now, send, report }); } catch (e) { logger.warn(`[rappel617] (b) : ${e && e.message ? e.message : e}`); }
  return report;
};

let timer = null;
let running = false;
const tick = async () => {
  if (running) return;
  running = true;
  try {
    const r = await runReminders617();
    if (r.sent.length) logger.info(`[rappel617] passage : ${r.sent.length} rappel(s), ${r.examined} élément(s) examiné(s)`);
  } catch (e) {
    logger.warn(`[rappel617] passage échoué : ${e && e.message ? e.message : e}`);
  } finally {
    running = false;
  }
};
/** Démarre le balayage (toutes les 10 min). `APPLICATION_REMINDERS_617=off` le coupe sans rebuild. */
const startReminder617Scheduler = (opts = {}) => {
  if (timer) return;
  if (String(process.env.APPLICATION_REMINDERS_617 || '').toLowerCase() === 'off') {
    logger.info('[rappel617] désactivé (APPLICATION_REMINDERS_617=off)');
    return;
  }
  const intervalMs = opts.intervalMs || TICK_MS;
  const first = setTimeout(tick, opts.firstDelayMs != null ? opts.firstDelayMs : 3 * 60 * 1000);
  if (typeof first.unref === 'function') first.unref();
  timer = setInterval(tick, intervalMs);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info(`🔔 Rappels des deux côtés 617 démarrés (toutes les ${Math.round(intervalMs / 60000)} min)`);
};
const stopReminder617Scheduler = () => {
  if (timer) { clearInterval(timer); timer = null; }
};

module.exports = {
  runReminders617,
  startReminder617Scheduler,
  stopReminder617Scheduler,
  decideProvider,
  decideOwnerExpiry,
  expiryInstant,
  postClosedReason,
  TEMPLATE_PROVIDER,
  TEMPLATE_EXPIRY,
};
