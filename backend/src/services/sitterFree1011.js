/**
 * 1011 (FLO, plan « conclure » B.4, validé par Daniel le 09/11 : « ça doit être tout automatisé ») —
 * MESSAGE AUTOMATIQUE « UN GARDIEN EST LIBRE ET VOUS ATTEND → PAYER ».
 *
 * A. « Toujours libre ? » — pour une demande ouverte, à dates À VENIR, sans réservation ni
 *    candidat choisi, dont la 1re candidature en attente a ≥ 24 h : on écrit aux candidats en
 *    attente les mieux placés (3 au plus ; boost actif, identité vérifiée, puis le plus proche ;
 *    jamais hors distance) : « Êtes-vous toujours libre pour garder Rex du … au … à … ? » avec
 *    deux liens signés (oui / non). UNE fois par candidature ; 2 questions par PERSONNE et par
 *    24 h au plus ; jamais la nuit (heure locale du prestataire).
 * B. « Oui » → noté ; le PREMIER « oui » d'une demande envoie au propriétaire UN message
 *    « <Prénom> est libre et vous attend · <prix> · [Payer et réserver] » (lien signé de paiement).
 *    Une seule fois par demande, HORS du plafond de 3 relances (registre séparé).
 * C. « Non » → candidature retirée par le chemin EXISTANT du retrait par le prestataire
 *    (applicationController.cancelSitterSentApplicationRequest).
 * D. Garde-fous : registre réservé AVANT l'envoi (models/SitterFree1011) ; jamais un compte de
 *    test hors zone fictive ; jamais une vraie personne sur une demande en zone fictive ; jamais
 *    une demande sans dates, passée, close, masquée, réservée ; 10 demandes servies par passage.
 *
 * COUPE-CIRCUIT : SITTER_FREE_1011. Livré ÉTEINT : rien ne part tant que la variable ne vaut pas
 * exactement « on ». Éteint (ou « off ») : aucune question, aucun message au propriétaire ; la
 * simulation (dryRun) répond toujours ; un « non » déjà reçu par e-mail reste honoré (la personne
 * retire sa candidature), un « oui » reste noté. SITTER_FREE_1011_PUSH=off coupe les seuls push.
 *
 * Ce service n'écrit rien dans les réservations ni dans les paiements : il envoie des messages.
 */
const crypto = require('crypto');
const logger = require('../utils/logger');
const { decrypt } = require('../utils/encryption');
const { TEST_EMAIL_RE } = require('../utils/testAccount2809');

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;
const ASK_DELAY = DAY; // 1re candidature en attente depuis ≥ 24 h
const MAX_ASKED_PER_POST = 3; // questions en cours par demande
const MAX_PER_PERSON_PER_DAY = 2; // questions par personne sur 24 h glissantes
const MAX_POSTS_PER_RUN = 10; // demandes servies par passage
const MAX_EXAMINED = 300;
const MAX_ATTEMPTS = 3; // rejeux d'un envoi en échec
// 10/11/2026 (BOB, « Oui, autorise » de Daniel) — la question part aussi vers un e-mail jamais
// validé (notificationSender, coupe-circuit SITTER_FREE_EMAIL_UNVERIFIED=off). Les lignes
// restées en échec pour CE motif après 3 essais sont débloquées UNE fois (`unblockedAt`).
const UNVERIFIED_REASON = 'email_blocked:unverified';
const unverifiedAllowed = () => process.env.SITTER_FREE_EMAIL_UNVERIFIED !== 'off';
const canUnblock = (row) => !!row && row.status === 'failed' && row.error === UNVERIFIED_REASON && !row.unblockedAt && unverifiedAllowed();
const LINK_TTL = 14 * DAY;
const YES_FRESH = DAY; // un « oui » vaut 24 h pour prévenir le propriétaire
const TICK_MS = 30 * 60 * 1000;
const TEMPLATE_EMAIL = 'application_new_2610';
const TEMPLATE_PUSH = 'application_reminder_615';
const TYPE_QUESTION = 'still_free_1011';
const HARD_STAFF_EMAILS = ['dadaciao84@gmail.com', 'hopetsit@gmail.com'];
const NOT_A_PERSON_RE = /(@invalid\.example$|^probe-)/i;

const enabled = () => String(process.env.SITTER_FREE_1011 || '').trim().toLowerCase() === 'on';
const pushEnabled = () => String(process.env.SITTER_FREE_1011_PUSH || '').trim().toLowerCase() !== 'off';

// ───────────────────────────── liens signés (oui / non) ─────────────────────────────
const secret = () => process.env.JWT_SECRET || '';
const b64u = (buf) => Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const unb64u = (s) => Buffer.from(String(s).replace(/-/g, '+').replace(/_/g, '/'), 'base64');
// Préfixe propre à ce service : un jeton d'un autre lien signé (même secret) n'est jamais accepté ici.
const hmac = (payload) => b64u(crypto.createHmac('sha256', secret()).update(`sf1011:${payload}`).digest());
const OID = /^[a-f0-9]{24}$/i;

/** Jeton « oui » ou « non » d'une candidature ('' si le secret manque). */
const signAnswerLink = ({ applicationId, providerId, answer, now = Date.now() }) => {
  if (!secret() || !OID.test(String(applicationId)) || !OID.test(String(providerId))) return '';
  const payload = b64u(JSON.stringify({ v: 1, a: String(applicationId), p: String(providerId), r: answer === 'no' ? 'n' : 'y', e: Number(now) + LINK_TTL }));
  return `${payload}.${hmac(payload)}`;
};

/** @returns {{ok:boolean, reason?:'format'|'signature'|'expired', applicationId?:string, providerId?:string, answer?:'yes'|'no'}} */
const verifyAnswerLink = (token, now = Date.now()) => {
  const t = String(token || '');
  if (!secret() || !t || t.length > 600) return { ok: false, reason: 'format' };
  const parts = t.split('.');
  if (parts.length !== 2 || !parts[0] || !parts[1]) return { ok: false, reason: 'format' };
  const given = Buffer.from(parts[1]);
  const wanted = Buffer.from(hmac(parts[0]));
  if (given.length !== wanted.length || !crypto.timingSafeEqual(given, wanted)) return { ok: false, reason: 'signature' };
  let d;
  try { d = JSON.parse(unb64u(parts[0]).toString('utf8')); } catch (_) { return { ok: false, reason: 'format' }; }
  if (!d || d.v !== 1 || !OID.test(String(d.a)) || !OID.test(String(d.p)) || (d.r !== 'y' && d.r !== 'n')) return { ok: false, reason: 'format' };
  if (!Number.isFinite(Number(d.e)) || Number(d.e) < Number(now)) return { ok: false, reason: 'expired' };
  return { ok: true, applicationId: String(d.a), providerId: String(d.p), answer: d.r === 'n' ? 'no' : 'yes' };
};

const publicApi = () => String(process.env.PUBLIC_API_URL || 'https://hopetsit-backend.onrender.com/api/v1').replace(/\/+$/, '');
const answerUrl = (token) => (token ? `${publicApi()}/sitter-free/${token}` : '');

// ───────────────────────────── aides ─────────────────────────────
const idOf = (v) => String(v && v._id ? v._id : v);
const plainEmail = (stored) => {
  let e = stored;
  try { e = decrypt(stored); } catch (_) { /* illisible */ }
  return typeof e === 'string' ? e.trim().toLowerCase() : '';
};
const isTestAccount = (doc) => TEST_EMAIL_RE.test(plainEmail(doc && doc.email));
const isNotAPerson = (doc) => NOT_A_PERSON_RE.test(plainEmail(doc && doc.email));
const isStaff = (doc) => !!doc && (doc.isStaff === true || HARD_STAFF_EMAILS.includes(plainEmail(doc.email)));
const providerOf = (app) => (app.walkerId ? { role: 'walker', id: idOf(app.walkerId) } : { role: 'sitter', id: idOf(app.sitterId) });
const PROVIDER_FIELDS = 'name firstName email status location country city boostExpiry kycStatus identityVerification language';

const loadProvider = async (role, id) => {
  const Model = role === 'walker' ? require('../models/Walker') : require('../models/Sitter');
  return Model.findById(id).select(PROVIDER_FIELDS).lean();
};

const firstName = (doc) => {
  try { return require('../utils/applicationNewText617').firstNameOf(doc) || ''; } catch (_) { return ''; }
};

/** Clé stable de la PERSONNE (ses profils propriétaire / gardien / promeneur confondus). */
const personKeyOf = async (role, id) => {
  try {
    const p = await require('../utils/person3110').personOf(role, String(id));
    const all = (p && Array.isArray(p.allIds) ? p.allIds : []).map(String).filter(Boolean).sort();
    return all[0] || String(id);
  } catch (_) {
    return String(id);
  }
};

/**
 * État d'une DEMANDE : peut-elle recevoir ce message ? Fonction pure.
 * @returns {string|null} raison d'exclusion, ou null si elle est éligible
 */
const postBlocker = (post, now, tz) => {
  if (!post || post.postType !== 'request') return 'not_a_request';
  if (post.hidden === true) return 'hidden';
  if (post.status === 'closed' || post.closedAt) return 'closed';
  if (post.reservedBy && post.reservedBy.bookingId) return 'reserved';
  if (!post.startDate || String(post.dateMode || '').toLowerCase() === 'tbd') return 'no_dates';
  // Les dates d'une demande sont une heure « murale » lue en UTC : on la ramène à l'instant réel.
  let start = null;
  try { start = require('./applicationReminder615').wallToInstant(post.startDate, tz); } catch (_) { start = null; }
  const t = start ? start.getTime() : new Date(post.startDate).getTime();
  if (!Number.isFinite(t)) return 'no_dates';
  if (t <= now.getTime()) return 'past';
  return null;
};

/** Règle des comptes de test : jamais hors zone fictive ; jamais une vraie personne en zone fictive. */
const testBlocker = (post, owner) => {
  const { inFictiveZone } = require('../utils/applicationLink3110');
  const fictive = inFictiveZone(post && post.location) === true;
  if (isNotAPerson(owner)) return { why: 'test', testMode: false };
  const ownerTest = isTestAccount(owner) || isStaff(owner);
  if (ownerTest && !fictive) return { why: isStaff(owner) && !isTestAccount(owner) ? 'staff' : 'test', testMode: true };
  if (!ownerTest && fictive) return { why: 'fictive_zone', testMode: false };
  return { why: null, testMode: ownerTest };
};

/** Tente de réserver une clé du registre. @returns {object|null} la ligne, ou null si déjà prise. */
const claim = async (fields, now) => {
  const Free = require('../models/SitterFree1011');
  const replay = await Free.findOneAndUpdate(
    { key: fields.key, status: 'failed', attempts: { $lt: MAX_ATTEMPTS } },
    { $set: { status: 'sent', error: '', createdAt: now }, $inc: { attempts: 1 } },
    { new: true },
  );
  if (replay) return replay;
  if (unverifiedAllowed()) {
    // Déblocage unique d'une ligne arrêtée à 3 essais par le garde-fou « e-mail non validé ».
    const freed = await Free.findOneAndUpdate(
      { key: fields.key, status: 'failed', error: UNVERIFIED_REASON, attempts: { $gte: MAX_ATTEMPTS }, unblockedAt: null },
      { $set: { status: 'sent', error: '', createdAt: now, attempts: 1, unblockedAt: now } },
      { new: true },
    );
    if (freed) return freed;
  }
  try {
    return await Free.create({ ...fields, status: 'sent', attempts: 1, createdAt: now });
  } catch (e) {
    if (e && e.code === 11000) return null;
    throw e;
  }
};
const markFailed = async (row, reason) => {
  const Free = require('../models/SitterFree1011');
  await Free.updateOne({ _id: row._id }, { $set: { status: 'failed', error: String(reason || 'not_sent').slice(0, 300) } });
};

const petNamesOf = async (post) => {
  try {
    const ids = Array.isArray(post && post.petIds) ? post.petIds.slice(0, 3) : [];
    if (!ids.length) return [];
    const pets = await require('../models/Pet').find({ _id: { $in: ids } }).select('petName').lean();
    return pets.map((p) => String(p.petName || '').trim()).filter(Boolean);
  } catch (_) {
    return [];
  }
};

/** 1111 — races des animaux de la demande (fiche animal) ; liste vide si inconnues. */
const petBreedsOf = async (post) => {
  try {
    const ids = Array.isArray(post && post.petIds) ? post.petIds.slice(0, 3) : [];
    if (!ids.length) return [];
    const pets = await require('../models/Pet').find({ _id: { $in: ids } }).select('breed').lean();
    return pets.map((p) => String(p.breed || '').trim()).filter(Boolean);
  } catch (_) {
    return [];
  }
};

const langOf = async (role, id) => {
  try { return (await require('./notificationSender').resolveRecipientLocale(role, String(id))) || 'fr'; } catch (_) { return 'fr'; }
};

// ───────────────────────────── B. message au propriétaire ─────────────────────────────
/**
 * Tout ce qu'il faut pour prévenir le propriétaire après un « oui », ou la raison de ne pas le faire.
 * Ne lit PAS le registre des relances (CandidatesReminder2810) : ce message est hors du plafond de 3.
 */
const ownerPlan = async (applicationId, now) => {
  const Application = require('../models/Application');
  const Post = require('../models/Post');
  const Owner = require('../models/Owner');
  const Free = require('../models/SitterFree1011');
  const r615 = require('./applicationReminder615');
  const app = await Application.findById(applicationId).lean();
  if (!app || app.status !== 'pending' || app.archivedAt || app.bookingId) return { ok: false, reason: 'application_gone' };
  const q = await Free.findOne({ key: `q:${app._id}` }).lean();
  if (!q || q.answer !== 'yes' || !q.answeredAt) return { ok: false, reason: 'no_yes', app };
  if (now.getTime() - new Date(q.answeredAt).getTime() > YES_FRESH) return { ok: false, reason: 'yes_stale', app };
  const post = app.postId ? await Post.findById(app.postId).lean() : null;
  if (!post) return { ok: false, reason: 'no_post', app };
  const owner = await Owner.findById(post.ownerId).select('name firstName email status isStaff location country').lean();
  if (!owner) return { ok: false, reason: 'no_owner', app, post };
  const tz = r615.ownerTimeZone(post, owner);
  const blocker = postBlocker(post, now, tz);
  if (blocker) return { ok: false, reason: blocker, app, post };
  if (await Application.exists({ postId: post._id, $or: [{ status: 'accepted' }, { bookingId: { $ne: null } }] })) return { ok: false, reason: 'already_chosen', app, post };
  if (owner.status && owner.status !== 'active') return { ok: false, reason: 'owner_inactive', app, post };
  const tb = testBlocker(post, owner);
  if (tb.why) return { ok: false, reason: tb.why, app, post };
  const { role, id } = providerOf(app);
  const provider = await loadProvider(role, id);
  if (!provider || (provider.status && provider.status !== 'active')) return { ok: false, reason: 'provider_inactive', app, post };
  if (isNotAPerson(provider) || isTestAccount(provider) !== tb.testMode) return { ok: false, reason: 'test_provider', app, post };
  let blocked = false;
  try { blocked = await require('./blockService').isOwnerSitterInteractionBlocked(String(post.ownerId), id); } catch (_) { blocked = false; }
  if (blocked) return { ok: false, reason: 'blocked', app, post };
  const already = await Free.findOne({ key: `o:${post._id}` }).lean();
  if (already && (already.status === 'sent' || already.attempts >= MAX_ATTEMPTS)) return { ok: false, reason: 'owner_already_told', app, post, already };
  return { ok: true, app, post, owner, provider, role, providerId: id, tz };
};

const ownerLine = (plan) => {
  const text = require('../utils/applicationEmailText2610');
  return {
    postId: String(plan.post._id),
    applicationId: String(plan.app._id),
    providerRole: plan.role,
    providerFirstName: firstName(plan.provider),
    ownerFirstName: firstName(plan.owner),
    price: text.priceLabel('fr', plan.app.pricing),
    startDate: plan.post.startDate || null,
    endDate: plan.post.endDate || null,
  };
};

/**
 * Prévient le propriétaire qu'un candidat a dit « oui ». Une seule fois par demande.
 * @returns {Promise<{sent:boolean, reason?:string, deferred?:boolean, line?:object}>}
 */
const notifyOwner = async ({ applicationId, now = new Date(), dryRun = false, send, push } = {}) => {
  const plan = await ownerPlan(applicationId, now);
  if (!plan.ok) return { sent: false, reason: plan.reason, postId: plan.post ? String(plan.post._id) : '', sameApplication: !!(plan.already && String(plan.already.applicationId) === String(applicationId)) };
  const line = ownerLine(plan);
  const r615 = require('./applicationReminder615');
  // Éteint : on ne promet rien (pas de « reporté à demain matin ») ; la simulation, elle, répond.
  if (!dryRun && !enabled()) return { sent: false, reason: 'disabled', line };
  if (r615.isNight(plan.tz, now.getTime())) return { sent: false, reason: 'night', deferred: true, line };
  if (dryRun) return { sent: false, reason: 'dry_run', line };

  const ns = require('./notificationSender');
  const email2610 = require('./applicationEmail2610');
  const text = require('../utils/sitterFreeText1011');
  const { BASE_URL } = require('../utils/emailLinkBuilder');
  const ownerId = String(plan.post.ownerId);
  const row = await claim({
    key: `o:${plan.post._id}`, kind: 'owner', postId: plan.post._id, applicationId: plan.app._id, ownerId: plan.post.ownerId, providerRole: plan.role, providerId: plan.providerId,
  }, now);
  if (!row) return { sent: false, reason: 'owner_already_told', line };
  try {
    const lang = await langOf('owner', ownerId);
    const cards = await email2610.cardsFor([plan.app], plan.post);
    const card = cards[0] || { name: firstName(plan.provider) || 'HoPetSit', role: plan.role, pricing: plan.app.pricing || null };
    const direct = `${BASE_URL}/application/${plan.app._id}?from=email&choose=1`;
    const payLink = await ns.leadOwnerEmailLink('owner', ownerId, direct, BASE_URL);
    const data = { applicationId: String(plan.app._id), postId: String(plan.post._id), ...text.ownerEmailData({ lang, post: plan.post, card, payLink, now: now.getTime() }) };
    const r = await (send || ns.sendEmailOnly)({ userId: ownerId, role: 'owner', type: 'application_new', templateType: TEMPLATE_EMAIL, data });
    if (!r || !r.sent) {
      await markFailed(row, r && r.reason);
      return { sent: false, reason: `not_sent:${(r && r.reason) || '?'}`, line };
    }
    logger.info(`[libre1011] propriétaire prévenu : demande ${plan.post._id}, candidature ${plan.app._id}`);
    if (pushEnabled()) {
      try {
        await (push || ns.sendNotification)({
          userId: ownerId, role: 'owner', type: 'application_new', templateType: TEMPLATE_PUSH, channels: { email: false },
          data: { applicationId: String(plan.app._id), postId: String(plan.post._id), ...text.ownerPushData({ lang, post: plan.post, card }) },
        });
      } catch (e) {
        logger.warn(`[libre1011] push propriétaire non parti : ${e && e.message ? e.message : e}`);
      }
    }
    return { sent: true, line };
  } catch (e) {
    await markFailed(row, e && e.message ? e.message : e);
    throw e;
  }
};

// ───────────────────────────── B / C. réponses du prestataire ─────────────────────────────
/** « Oui, je suis libre » : noté une fois, puis le propriétaire est prévenu (si c'est le 1er oui). */
const answerYes = async ({ applicationId, providerId, now = new Date(), send, push } = {}) => {
  const Application = require('../models/Application');
  const Free = require('../models/SitterFree1011');
  const app = await Application.findById(applicationId).lean();
  if (!app || app.status !== 'pending' || app.archivedAt) return { ok: false, reason: 'gone' };
  if (providerOf(app).id !== String(providerId)) return { ok: false, reason: 'invalid' };
  const q = await Free.findOne({ key: `q:${app._id}` }).lean();
  if (!q) return { ok: false, reason: 'gone' };
  const first = await Free.updateOne({ _id: q._id, answer: '' }, { $set: { answer: 'yes', answeredAt: now } });
  let owner = { sent: false, reason: 'error' };
  try {
    owner = await notifyOwner({ applicationId: String(app._id), now, send, push });
  } catch (e) {
    logger.warn(`[libre1011] message propriétaire après un oui : ${e && e.message ? e.message : e}`);
  }
  // « Nous prévenons le propriétaire » n'est affiché que si c'est vrai pour CE candidat.
  const ownerTold = owner.sent === true || owner.deferred === true || (owner.reason === 'owner_already_told' && owner.sameApplication === true);
  return { ok: true, answer: 'yes', first: !!(first && first.modifiedCount), ownerTold, owner: owner.sent ? 'sent' : owner.reason };
};

/** « Non, plus disponible » : retrait par le chemin EXISTANT (même contrôleur que l'app). */
const answerNo = async ({ applicationId, providerId, now = new Date() } = {}) => {
  const Application = require('../models/Application');
  const Free = require('../models/SitterFree1011');
  const key = `q:${applicationId}`;
  const app = await Application.findById(applicationId).lean();
  if (!app) {
    const q = await Free.findOne({ key }).lean();
    return q && q.answer === 'no' && String(q.providerId) === String(providerId) ? { ok: true, answer: 'no', already: true } : { ok: false, reason: 'gone' };
  }
  if (providerOf(app).id !== String(providerId)) return { ok: false, reason: 'invalid' };
  if (app.status !== 'pending') return { ok: false, reason: 'gone' };
  const { cancelSitterSentApplicationRequest } = require('../controllers/applicationController');
  const out = { status: 200, body: null };
  const res = { status(c) { out.status = c; return res; }, json(b) { out.body = b; return res; } };
  await cancelSitterSentApplicationRequest({ user: { id: String(providerId) }, params: { id: String(applicationId) }, body: {}, query: {}, headers: {} }, res);
  if (out.status !== 200) return { ok: false, reason: out.status === 409 || out.status === 404 ? 'gone' : 'error' };
  await Free.updateOne({ key }, { $set: { answer: 'no', answeredAt: now } });
  logger.info(`[libre1011] « non » : candidature ${applicationId} retirée par son auteur`);
  return { ok: true, answer: 'no' };
};

// ───────────────────────────── A. balayage ─────────────────────────────
const runSitterFree = async (opts = {}) => {
  const now = opts.now instanceof Date ? opts.now : new Date();
  const dryRun = opts.dryRun === true;
  const report = {
    enabled: enabled(), dryRun, examined: 0, asked: [], wouldAsk: [], ownerTold: [], wouldTellOwner: [], excluded: [], skipped: {},
  };
  if (!dryRun && !enabled()) return report;
  const Post = require('../models/Post');
  const Application = require('../models/Application');
  const Owner = require('../models/Owner');
  const Free = require('../models/SitterFree1011');
  const r615 = require('./applicationReminder615');
  const DIST = require('../utils/applicationDistance1610');
  const text = require('../utils/sitterFreeText1011');
  const text2610 = require('../utils/applicationEmailText2610');
  const ns = require('./notificationSender');
  const skip = (why, where = {}) => {
    report.skipped[why] = (report.skipped[why] || 0) + 1;
    if (where.postId) report.excluded.push({ postId: String(where.postId), ...(where.applicationId ? { applicationId: String(where.applicationId) } : {}), reason: why });
  };

  // 1) « oui » déjà reçus dont le propriétaire n'a pas encore été prévenu (nuit, envoi en échec).
  let waiting = [];
  try {
    waiting = await Free.find({ kind: 'question', answer: 'yes', answeredAt: { $gte: new Date(now.getTime() - YES_FRESH) } }).sort({ answeredAt: 1 }).limit(MAX_EXAMINED).lean();
  } catch (e) {
    logger.warn(`[libre1011] lecture des « oui » : ${e && e.message ? e.message : e}`);
  }
  const toldPosts = new Set();
  for (const q of waiting) {
    if (toldPosts.has(String(q.postId))) continue;
    try {
      // eslint-disable-next-line no-await-in-loop
      const r = await notifyOwner({ applicationId: String(q.applicationId), now, dryRun, send: opts.send, push: opts.push });
      if (r.sent) { report.ownerTold.push(r.line); toldPosts.add(String(q.postId)); } else if (r.reason === 'dry_run') { report.wouldTellOwner.push(r.line); toldPosts.add(String(q.postId)); } else if (r.reason === 'owner_already_told') { toldPosts.add(String(q.postId)); } else skip(`owner:${r.reason}`, { postId: q.postId, applicationId: q.applicationId });
    } catch (e) {
      skip('owner:error', { postId: q.postId, applicationId: q.applicationId });
      logger.warn(`[libre1011] message propriétaire, demande ${q.postId} : ${e && e.message ? e.message : e}`);
    }
  }

  // 2) questions « toujours libre ? »
  let posts = [];
  try {
    posts = await Post.find({ postType: 'request', hidden: { $ne: true }, status: { $ne: 'closed' }, closedAt: null, 'reservedBy.bookingId': null })
      .sort({ startDate: 1 }).limit(MAX_EXAMINED).lean();
  } catch (e) {
    logger.warn(`[libre1011] lecture des demandes : ${e && e.message ? e.message : e}`);
    return report;
  }
  const max = DIST.maxKm();
  const askedThisRun = new Map(); // personne → questions de ce passage (simulation seulement : rien n'est écrit au registre)
  let served = 0;

  for (const post of posts) {
    if (served >= MAX_POSTS_PER_RUN) { report.batchFull = true; break; }
    report.examined += 1;
    const here = { postId: post._id };
    try {
      // eslint-disable-next-line no-await-in-loop
      const apps = await Application.find({ postId: post._id, status: 'pending', archivedAt: null }).sort({ createdAt: 1 }).lean();
      if (!apps.length) { skip('no_candidate'); continue; }
      // eslint-disable-next-line no-await-in-loop
      const owner = await Owner.findById(post.ownerId).select('name firstName email status isStaff location country').lean();
      if (!owner) { skip('no_owner', here); continue; }
      const blocker = postBlocker(post, now, r615.ownerTimeZone(post, owner));
      if (blocker) { skip(blocker, here); continue; }
      // eslint-disable-next-line no-await-in-loop
      if (await Application.exists({ postId: post._id, $or: [{ status: 'accepted' }, { bookingId: { $ne: null } }] })) { skip('already_chosen', here); continue; }
      if (now.getTime() - new Date(apps[0].createdAt).getTime() < ASK_DELAY) { skip('too_recent', here); continue; }
      if (owner.status && owner.status !== 'active') { skip('owner_inactive', here); continue; }
      const tb = testBlocker(post, owner);
      if (tb.why) { skip(tb.why, here); continue; }

      // eslint-disable-next-line no-await-in-loop
      const rows = await Free.find({ postId: post._id }).lean();
      if (rows.some((r) => r.kind === 'owner' && r.status === 'sent')) { skip('owner_already_told', here); continue; }
      if (rows.some((r) => r.kind === 'question' && r.answer === 'yes')) { skip('has_yes', here); continue; }
      const byApp = new Map(rows.filter((r) => r.kind === 'question').map((r) => [String(r.applicationId), r]));
      const pendingIds = new Set(apps.map((a) => String(a._id)));
      const busy = [...byApp.values()].filter((r) => r.status === 'sent' && r.answer !== 'no' && pendingIds.has(String(r.applicationId))).length;
      const slots = MAX_ASKED_PER_POST - busy;
      if (slots <= 0) { skip('waiting_answers', here); continue; }

      const candidates = [];
      for (const a of apps) {
        const at = { postId: post._id, applicationId: a._id };
        const prev = byApp.get(String(a._id));
        if (prev && prev.status === 'sent') continue; // déjà interrogé : rien à redire
        if (prev && prev.attempts >= MAX_ATTEMPTS && !canUnblock(prev)) { skip('failed_max', at); continue; }
        if (a.bookingId) { skip('has_booking', at); continue; }
        const { role, id } = providerOf(a);
        // eslint-disable-next-line no-await-in-loop
        const p = await loadProvider(role, id);
        if (!p) { skip('no_provider', at); continue; }
        if (p.status && p.status !== 'active') { skip('provider_inactive', at); continue; }
        if (isNotAPerson(p)) { skip('not_a_person', at); continue; }
        if (isTestAccount(p) !== tb.testMode) { skip(tb.testMode ? 'real_provider_on_test' : 'test_provider', at); continue; }
        let blocked = false;
        // eslint-disable-next-line no-await-in-loop
        try { blocked = await require('./blockService').isOwnerSitterInteractionBlocked(String(post.ownerId), id); } catch (_) { blocked = false; }
        if (blocked) { skip('blocked', at); continue; }
        let km = null;
        try { km = DIST.distanceKm(post, p); } catch (_) { km = null; }
        km = Number.isFinite(Number(km)) && km != null ? Number(km) : null;
        if (max > 0 && km != null && km > max) { skip('too_far', at); continue; }
        let kyc = false;
        try { kyc = require('../utils/mapVisibility').isKycVerified(p) === true; } catch (_) { kyc = false; }
        const boosted = !!(p.boostExpiry && new Date(p.boostExpiry).getTime() > now.getTime());
        candidates.push({ app: a, role, id, p, km, kyc, boosted });
      }
      candidates.sort((x, y) => (Number(y.boosted) - Number(x.boosted)) || (Number(y.kyc) - Number(x.kyc))
        || ((x.km == null ? Infinity : x.km) - (y.km == null ? Infinity : y.km))
        || (new Date(x.app.createdAt) - new Date(y.app.createdAt)));
      if (!candidates.length) { skip('nobody_to_ask', here); continue; }

      let petNames = null;
      let breeds = null; // 1111
      let did = false;
      for (const c of candidates.slice(0, slots)) {
        const at = { postId: post._id, applicationId: c.app._id };
        if (r615.isNight(r615.ownerTimeZone(null, c.p), now.getTime())) { skip('night', at); continue; }
        // eslint-disable-next-line no-await-in-loop
        const personKey = await personKeyOf(c.role, c.id);
        // eslint-disable-next-line no-await-in-loop
        const recent = await Free.countDocuments({ kind: 'question', personKey, status: 'sent', createdAt: { $gt: new Date(now.getTime() - DAY) } });
        if (recent + (askedThisRun.get(personKey) || 0) >= MAX_PER_PERSON_PER_DAY) { skip('person_cap', at); continue; }
        const line = {
          postId: String(post._id), applicationId: String(c.app._id), providerRole: c.role, providerFirstName: firstName(c.p), ownerFirstName: firstName(owner),
          price: text2610.priceLabel('fr', c.app.pricing), km: c.km == null ? null : Math.round(c.km), startDate: post.startDate || null, endDate: post.endDate || null,
        };
        if (dryRun) { report.wouldAsk.push(line); askedThisRun.set(personKey, (askedThisRun.get(personKey) || 0) + 1); did = true; continue; }
        // eslint-disable-next-line no-await-in-loop
        const row = await claim({
          key: `q:${c.app._id}`, kind: 'question', postId: post._id, applicationId: c.app._id, ownerId: post.ownerId, providerRole: c.role, providerId: c.id, personKey,
        }, now);
        if (!row) { skip('already_asked', at); continue; }
        did = true;
        try {
          // eslint-disable-next-line no-await-in-loop
          if (petNames === null) petNames = await petNamesOf(post);
          if (breeds === null) breeds = await petBreedsOf(post);
          // eslint-disable-next-line no-await-in-loop
          const lang = await langOf(c.role, c.id);
          const yesLink = answerUrl(signAnswerLink({ applicationId: c.app._id, providerId: c.id, answer: 'yes', now: now.getTime() }));
          const noLink = answerUrl(signAnswerLink({ applicationId: c.app._id, providerId: c.id, answer: 'no', now: now.getTime() }));
          if (!yesLink || !noLink) {
            // eslint-disable-next-line no-await-in-loop
            await markFailed(row, 'no_link');
            skip('not_sent:no_link', at); continue;
          }
          const ids = { applicationId: String(c.app._id), postId: String(post._id) };
          const data = { ...ids, ...text.questionEmailData({ lang, post, serviceType: c.app.serviceType, petNames, breeds, yesLink, noLink }) };
          // eslint-disable-next-line no-await-in-loop
          const r = await (opts.send || ns.sendEmailOnly)({ userId: c.id, role: c.role, type: TYPE_QUESTION, templateType: TEMPLATE_EMAIL, data });
          if (!r || !r.sent) {
            // eslint-disable-next-line no-await-in-loop
            await markFailed(row, r && r.reason);
            skip(`not_sent:${(r && r.reason) || '?'}`, at); continue;
          }
          report.asked.push(line); // le plafond par personne lit le registre : pas de second décompte ici
          logger.info(`[libre1011] question envoyée : demande ${post._id}, candidature ${c.app._id}`);
          if (pushEnabled()) {
            try {
              // eslint-disable-next-line no-await-in-loop
              await (opts.push || ns.sendNotification)({
                userId: c.id, role: c.role, type: TYPE_QUESTION, templateType: TEMPLATE_PUSH, channels: { email: false }, data: { ...ids, ...text.questionPushData({ lang }) },
              });
            } catch (e) {
              logger.warn(`[libre1011] push de la question non parti : ${e && e.message ? e.message : e}`);
            }
          }
        } catch (e) {
          // eslint-disable-next-line no-await-in-loop
          await markFailed(row, e && e.message ? e.message : e);
          skip('error', at);
          logger.warn(`[libre1011] candidature ${c.app._id} : ${e && e.message ? e.message : e}`);
        }
      }
      if (did) served += 1;
    } catch (e) {
      skip('error', here);
      logger.warn(`[libre1011] demande ${post && post._id} : ${e && e.message ? e.message : e}`);
    }
  }
  return report;
};

// ───────────────────────────── planificateur ─────────────────────────────
let timer = null;
let running = false;
const tick = async () => {
  if (running) return;
  running = true;
  try {
    const r = await runSitterFree();
    if (r.asked.length || r.ownerTold.length) logger.info(`[libre1011] passage : ${r.asked.length} question(s), ${r.ownerTold.length} propriétaire(s) prévenu(s), ${r.examined} demande(s) examinée(s)`);
  } catch (e) {
    logger.warn(`[libre1011] passage échoué : ${e && e.message ? e.message : e}`);
  } finally {
    running = false;
  }
};
/** Balayage toutes les 30 min — SEULEMENT si SITTER_FREE_1011=on (livré éteint). */
const startSitterFreeScheduler = (opts = {}) => {
  if (timer) return false;
  if (!enabled()) { logger.info('[libre1011] éteint (SITTER_FREE_1011 ≠ on) : seule la simulation répond'); return false; }
  const first = setTimeout(tick, opts.firstDelayMs != null ? opts.firstDelayMs : 7 * 60 * 1000);
  if (typeof first.unref === 'function') first.unref();
  timer = setInterval(tick, opts.intervalMs || TICK_MS);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info('[libre1011] message « un gardien est libre » démarré (toutes les 30 min)');
  return true;
};
const stopSitterFreeScheduler = () => { if (timer) { clearInterval(timer); timer = null; } };

module.exports = {
  enabled, signAnswerLink, verifyAnswerLink, answerUrl, postBlocker, runSitterFree, notifyOwner, answerYes, answerNo,
  startSitterFreeScheduler, stopSitterFreeScheduler,
  ASK_DELAY, MAX_ASKED_PER_POST, MAX_PER_PERSON_PER_DAY, MAX_POSTS_PER_RUN, LINK_TTL, YES_FRESH,
};
