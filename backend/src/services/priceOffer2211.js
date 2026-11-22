/**
 * 2211 — « PROPOSER MON PRIX » (mesure du 22/11/2026 : 55 propriétaires voient leurs candidats en
 * 30 jours, 2 cliquent « Choisir et payer », 0 paie ; deux étaient d'accord avec le gardien sur un
 * prix plus bas dans la discussion, mais rien ne permettait de changer le prix de la candidature).
 *
 * A. Le PROPRIÉTAIRE propose un total (commission comprise, devise de la candidature) sur une
 *    candidature en attente d'une demande datée : POST /applications/:id/price-offer { amount }.
 *    Strictement inférieur au total actuel, au moins 40 % de ce total ; une seule proposition en
 *    attente, 2 au plus par candidature ; valable 48 h ou jusqu'au début du service.
 * B. Le GARDIEN / PROMENEUR reçoit un message du propriétaire dans leur conversation, un push et un
 *    e-mail avec un LIEN SIGNÉ (routes/priceOffer2211) : page servie par ce serveur, Accepter / Refuser.
 * C. ACCEPTÉ → `pricing.totalPrice` = montant proposé, `commissionRate` INCHANGÉ, base / commission /
 *    net recalculés par la formule inverse de utils/pricing.calculateTotalWithAddOns, marqueur
 *    `pricing.negotiated2211`, ancien bloc gardé (`priceOffer2211.previousPricing`). Le propriétaire
 *    est prévenu avec le lien signé de sa page candidats. REFUSÉ → rien ne change, il est prévenu.
 * D. Les garde-fous de prix (filet 2610, « prix à confirmer » 3110, recalculs 620) respectent un prix
 *    négocié TANT QUE la demande n'a pas changé (`negotiatedState`) : même service, mêmes dates, même
 *    quantité, et total stocké = montant accepté. Si la demande change, le prix négocié est annulé et
 *    le moteur reprend la main ; si seul le tarif du profil change, il reste.
 *
 * COUPE-CIRCUIT : PRICE_OFFER_2211=off (allumé par défaut) → la route répond 404 OFFER_DISABLED et
 * le site ne montre plus le lien ; une proposition déjà envoyée reste honorée (le gardien peut répondre).
 * Ce service n'écrit rien dans les réservations ni dans les paiements.
 */
const crypto = require('crypto');
const logger = require('../utils/logger');
const engine = require('../utils/pricingEngine620');
const { PLATFORM_COMMISSION_RATE } = require('../utils/pricing');

const HOUR = 60 * 60 * 1000;
const OFFER_TTL = 48 * HOUR;
const LINK_TTL = 14 * 24 * HOUR;
const MIN_RATIO = 0.4;
const MAX_OFFERS = 2;
const TYPE_OFFER = 'price_offer_2211';
const TEMPLATE_EMAIL = 'application_new_2610';
const TEMPLATE_PUSH = 'application_reminder_615';

const enabled = () => String(process.env.PRICE_OFFER_2211 || '').trim().toLowerCase() !== 'off';
const round2 = (n) => Math.round((Number(n) + Number.EPSILON) * 100) / 100;
const cents = (n) => Math.round(Number(n) * 100);
const near = (a, b) => Math.abs((Number(a) || 0) - (Number(b) || 0)) <= 0.011;
const idOf = (v) => String(v && v._id ? v._id : v || '');
const plain = (v) => (v && typeof v.toObject === 'function' ? v.toObject() : { ...(v || {}) });
const offersOf = (app) => {
  const list = app && app.priceOffer2211 && app.priceOffer2211.offers;
  return Array.isArray(list) ? list : (list && typeof list.length === 'number' ? Array.from(list) : []);
};
const providerOf = (app) => (app.walkerId ? { role: 'walker', id: idOf(app.walkerId) } : { role: 'sitter', id: idOf(app.sitterId) });

// ───────────────────────────── lien signé (page de réponse) ─────────────────────────────
const secret = () => process.env.JWT_SECRET || '';
const b64u = (buf) => Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const unb64u = (s) => Buffer.from(String(s).replace(/-/g, '+').replace(/_/g, '/'), 'base64');
// Préfixe propre à ce service : un jeton d'un autre lien signé (même secret) n'est jamais accepté ici.
const hmac = (payload) => b64u(crypto.createHmac('sha256', secret()).update(`po2211:${payload}`).digest());
const OID = /^[a-f0-9]{24}$/i;

/** Jeton « accepter » ou « refuser » d'UNE proposition ('' si le secret manque). */
const signOfferLink = ({ applicationId, providerId, index, answer, now = Date.now() }) => {
  if (!secret() || !OID.test(String(applicationId)) || !OID.test(String(providerId)) || !Number.isInteger(index) || index < 0) return '';
  const payload = b64u(JSON.stringify({ v: 1, a: String(applicationId), p: String(providerId), i: index, r: answer === 'decline' ? 'd' : 'a', e: Number(now) + LINK_TTL }));
  return `${payload}.${hmac(payload)}`;
};

/** @returns {{ok:boolean, reason?:'format'|'signature'|'expired', applicationId?:string, providerId?:string, index?:number, answer?:'accept'|'decline'}} */
const verifyOfferLink = (token, now = Date.now()) => {
  const t = String(token || '');
  if (!secret() || !t || t.length > 600) return { ok: false, reason: 'format' };
  const parts = t.split('.');
  if (parts.length !== 2 || !parts[0] || !parts[1]) return { ok: false, reason: 'format' };
  const given = Buffer.from(parts[1]);
  const wanted = Buffer.from(hmac(parts[0]));
  if (given.length !== wanted.length || !crypto.timingSafeEqual(given, wanted)) return { ok: false, reason: 'signature' };
  let d;
  try { d = JSON.parse(unb64u(parts[0]).toString('utf8')); } catch (_) { return { ok: false, reason: 'format' }; }
  if (!d || d.v !== 1 || !OID.test(String(d.a)) || !OID.test(String(d.p)) || !Number.isInteger(d.i) || d.i < 0 || d.i >= MAX_OFFERS || (d.r !== 'a' && d.r !== 'd')) return { ok: false, reason: 'format' };
  if (!Number.isFinite(Number(d.e)) || Number(d.e) < Number(now)) return { ok: false, reason: 'expired' };
  return { ok: true, applicationId: String(d.a), providerId: String(d.p), index: d.i, answer: d.r === 'd' ? 'decline' : 'accept' };
};

const publicApi = () => String(process.env.PUBLIC_API_URL || 'https://hopetsit-backend.onrender.com/api/v1').replace(/\/+$/, '');
const offerUrl = (token) => (token ? `${publicApi()}/price-offer/${token}` : '');

// ───────────────────────────── prix négocié ─────────────────────────────
/**
 * Empreinte de la DEMANDE : service, visites par jour, lieu, mode de dates, dates, quantité facturée,
 * durée de balade. Si elle change après une proposition, celle-ci (et le prix négocié) tombe.
 */
const requestKey = (post) => {
  const p = post || {};
  const iso = (d) => { const t = d ? new Date(d).getTime() : NaN; return Number.isFinite(t) ? new Date(t).toISOString() : ''; };
  let q = { quantity: '', unit: '' };
  try { q = engine.quantityFor(p, engine.mainService(p)) || q; } catch (_) { /* demande incomplète */ }
  return [
    require('./applicationRepricing620').serviceFingerprint(p), engine.effectiveDateMode(p), iso(p.startDate), iso(p.endDate),
    q.quantity == null ? '' : q.quantity, q.unit || '', Number(p.walkDurationMinutes) || '',
  ].join('|');
};

const commissionRateOf = (pricing) => {
  const r = pricing && pricing.commissionRate;
  return typeof r === 'number' && r >= 0 && r <= 1 ? r : PLATFORM_COMMISSION_RATE;
};

/**
 * Bloc `pricing` pour un total NÉGOCIÉ. Formule inverse de calculateTotalWithAddOns
 * (total = brut prestataire × (1 + taux), commission = brut × taux, net = brut) :
 *   brut = arrondi(total ÷ (1 + taux)) ; commission = total − brut ; net = brut.
 * Le TAUX de commission n'est jamais modifié ; total = net + commission au centime près.
 * Le tarif unitaire affiché est réduit dans la même proportion (sinon « total < tarif » = incohérent).
 */
function negotiatedPricing(pricing, amount) {
  const p = plain(pricing);
  const rate = commissionRateOf(p);
  const total = round2(amount);
  const gross = round2(total / (1 + rate));
  const commission = round2(total - gross);
  const oldTotal = Number(p.totalPrice);
  const ratio = oldTotal > 0 ? total / oldTotal : 1;
  const scaled = (v) => (typeof v === 'number' && v > 0 ? round2(v * ratio) : v);
  return {
    ...p,
    basePrice: gross,
    appliedRate: scaled(p.appliedRate),
    weeklyRate: scaled(p.weeklyRate),
    totalPrice: total,
    commission,
    netPayout: gross,
    commissionRate: rate,
    indicative: false,
    stale: false,
    negotiated2211: true,
  };
}

/** Ce que voit le prestataire : montant proposé, ce qu'il toucherait, son prix actuel et son net actuel. */
const offerView = (pricing, offer) => {
  const p = plain(pricing);
  const n = negotiatedPricing(p, offer.amount);
  const currentTotal = offer.status === 'pending' ? Number(p.totalPrice) || 0 : Number(offer.originalTotal) || 0;
  return {
    amount: n.totalPrice, currency: String(offer.currency || p.currency || 'EUR').toUpperCase(), newNet: n.netPayout, commission: n.commission,
    currentTotal, currentNet: round2(currentTotal / (1 + n.commissionRate)),
  };
};

/**
 * Le prix de cette candidature est-il un prix négocié ENCORE VALABLE pour cette demande ?
 * Valable = marqueur posé + une proposition acceptée dont le montant est le total stocké + la demande
 * n'a pas changé depuis. Tout autre cas (marqueur seul, total modifié, demande changée) = non valable :
 * les garde-fous de prix s'appliquent alors comme pour n'importe quelle candidature.
 * @returns {{negotiated:boolean, valid:boolean, reason?:string}}
 */
function negotiatedState(app, post) {
  const p = (app && app.pricing) || {};
  if (p.negotiated2211 !== true) return { negotiated: false, valid: false };
  const accepted = offersOf(app).filter((o) => o && o.status === 'accepted').pop();
  if (!accepted) return { negotiated: true, valid: false, reason: 'no_offer' };
  if (!(Number(p.totalPrice) > 0) || !near(p.totalPrice, accepted.amount)) return { negotiated: true, valid: false, reason: 'amount' };
  if (!post || engine.effectiveDateMode(post) === 'tbd') return { negotiated: true, valid: false, reason: 'no_dates' };
  if (String(accepted.requestKey || '') !== requestKey(post)) return { negotiated: true, valid: false, reason: 'request_changed' };
  return { negotiated: true, valid: true };
}
const isNegotiatedValid = (app, post) => { try { return negotiatedState(app, post).valid === true; } catch (_) { return false; } };

/**
 * Annule le prix négocié d'un DOCUMENT candidature (sans l'enregistrer) : le bloc d'avant revient,
 * le marqueur tombe, les propositions en attente ou acceptées passent à « cancelled ».
 * L'appelant recalcule ensuite par le moteur s'il le peut, puis enregistre.
 * @returns {boolean} vrai si quelque chose a changé
 */
function dropNegotiated(appDoc, reason = 'request_changed', now = new Date()) {
  let changed = false;
  const list = appDoc && appDoc.priceOffer2211 && appDoc.priceOffer2211.offers;
  if (list && list.length) {
    for (const o of list) {
      if (o.status === 'pending' || o.status === 'accepted') { o.status = 'cancelled'; o.reason = String(reason).slice(0, 60); o.respondedAt = o.respondedAt || now; changed = true; }
    }
  }
  if (appDoc && appDoc.pricing && appDoc.pricing.negotiated2211 === true) {
    const prev = appDoc.priceOffer2211 && appDoc.priceOffer2211.previousPricing;
    appDoc.pricing = { ...(prev && typeof prev === 'object' ? plain(prev) : plain(appDoc.pricing)), negotiated2211: false };
    changed = true;
  }
  if (changed && appDoc.priceOffer2211) {
    appDoc.priceOffer2211.previousPricing = undefined;
    if (typeof appDoc.markModified === 'function') appDoc.markModified('priceOffer2211');
  }
  return changed;
}

/**
 * Garde-fou commun aux recalculs (applicationRepricing620, filet de respondToApplication) :
 *   · prix négocié valable → 'keep' : ne pas recalculer ;
 *   · marqueur posé mais plus valable (demande changée) → annulé sur le document, 'dropped' :
 *     l'appelant poursuit son recalcul habituel ;
 *   · pas de prix négocié → 'none'.
 */
function guardNegotiated(appDoc, post) {
  const st = negotiatedState(appDoc, post);
  if (!st.negotiated) return 'none';
  if (st.valid) return 'keep';
  dropNegotiated(appDoc, st.reason || 'request_changed');
  logger.info(`[prix2211] prix négocié annulé (${st.reason}) : candidature ${appDoc && appDoc._id}`);
  return 'dropped';
}

// ───────────────────────────── expiration ─────────────────────────────
const effectiveStatus = (offer, now = Date.now()) => {
  if (!offer) return null;
  if (offer.status === 'pending' && offer.expiresAt && new Date(offer.expiresAt).getTime() <= Number(now)) return 'expired';
  return offer.status;
};
/** Passe à « expired » les propositions en attente échues (document, sans enregistrer). */
const expireDue = (appDoc, now = new Date()) => {
  let changed = false;
  for (const o of offersOf(appDoc)) {
    if (o.status === 'pending' && effectiveStatus(o, now.getTime()) === 'expired') { o.status = 'expired'; o.respondedAt = now; changed = true; }
  }
  if (changed && typeof appDoc.markModified === 'function') appDoc.markModified('priceOffer2211');
  return changed;
};

const minAmountFor = (total) => Math.ceil(Number(total) * MIN_RATIO * 100 - 1e-6) / 100;

/**
 * Ce que le SITE doit savoir pour une candidature (côté propriétaire) : peut-il proposer, et où en est
 * sa dernière proposition. Lecture pure d'un objet déjà chargé (aucune requête).
 */
function ownerView(app, now = Date.now()) {
  const p = (app && app.pricing) || {};
  const list = offersOf(app);
  const last = list[list.length - 1] || null;
  const status = last ? effectiveStatus(last, now) : null;
  const total = Number(p.totalPrice);
  const priced = p.indicative !== true && p.stale !== true && p.priceToConfirm !== true && total > 0;
  const canOffer = enabled() && !!app && app.status === 'pending' && !app.archivedAt && priced && list.length < MAX_OFFERS && status !== 'pending' && p.negotiated2211 !== true;
  return {
    enabled: enabled(),
    canOffer,
    count: list.length,
    max: MAX_OFFERS,
    status,
    amount: last ? last.amount : null,
    currency: String((last && last.currency) || p.currency || 'EUR').toUpperCase(),
    expiresAt: last && last.expiresAt ? new Date(last.expiresAt).toISOString() : null,
    currentTotal: priced ? total : null,
    minAmount: priced ? minAmountFor(total) : null,
    negotiated: p.negotiated2211 === true,
  };
}

// ───────────────────────────── aides d'envoi ─────────────────────────────
const firstName = (doc) => {
  try { return require('../utils/applicationNewText617').firstNameOf(doc) || ''; } catch (_) { return ''; }
};
const langOf = async (role, id) => {
  try { return (await require('./notificationSender').resolveRecipientLocale(role, String(id))) || 'fr'; } catch (_) { return 'fr'; }
};
const loadProvider = (role, id) => (role === 'walker' ? require('../models/Walker') : require('../models/Sitter'))
  .findById(id).select('name firstName status hourlyRate dailyRate weeklyRate monthlyRate visitRate visitDurationMinutes walkRates currency isTopSitter isTopWalker').lean();

/** Message du propriétaire dans la conversation existante (même chemin que la question de la page candidats). */
const sendChatDefault = async ({ ownerId, providerRole, providerId, body }) => {
  const { startConversation } = require('../controllers/conversationController');
  const out = { status: 200, body: null };
  const res = { status(c) { out.status = c; return res; }, json(b) { out.body = b; return res; } };
  await startConversation({
    user: { id: String(ownerId), role: 'owner' }, params: {}, headers: {},
    query: providerRole === 'walker' ? {} : { sitterId: String(providerId) },
    body: providerRole === 'walker' ? { walkerId: String(providerId) } : {},
  }, res);
  const conv = out.body && out.body.conversation;
  const conversationId = conv ? String(conv.id || conv._id || '') : '';
  if (!conversationId) return { sent: false, reason: `conversation_${out.status}` };
  await require('./conversationService').sendMessage({ conversationId, senderRole: 'owner', senderId: String(ownerId), body });
  return { sent: true, conversationId };
};

/** Effets d'une proposition : message dans la conversation, e-mail avec lien signé, push. Jamais d'exception. */
async function notifyProvider({ app, post, index, now, deps = {} }) {
  const text = require('../utils/priceOfferText2211');
  const out = { chat: 'skipped', email: 'skipped', push: 'skipped' };
  const offer = offersOf(app)[index];
  const { role, id } = providerOf(app);
  const ownerId = idOf(app.ownerId);
  const view = offerView(app.pricing, offer);
  try {
    const ownerLang = await langOf('owner', ownerId);
    const r = await (deps.sendChat || sendChatDefault)({ ownerId, providerRole: role, providerId: id, body: text.chatMessage({ lang: ownerLang, amount: view.amount, currency: view.currency }) });
    out.chat = r && r.sent ? 'sent' : `not_sent:${(r && r.reason) || '?'}`;
  } catch (e) {
    out.chat = 'error';
    logger.warn(`[prix2211] message de la proposition non parti (candidature ${app._id}) : ${e && e.message ? e.message : e}`);
  }
  const ns = require('./notificationSender');
  const lang = await langOf(role, id);
  const ids = { applicationId: String(app._id), postId: post ? String(post._id) : '' };
  try {
    const link = offerUrl(signOfferLink({ applicationId: app._id, providerId: id, index, answer: 'accept', now: now.getTime() }));
    if (!link) out.email = 'not_sent:no_link';
    else {
      const data = { ...ids, ...text.providerEmailData({ lang, post, serviceType: app.serviceType, view, link }) };
      const r = await (deps.send || ns.sendEmailOnly)({ userId: id, role, type: TYPE_OFFER, templateType: TEMPLATE_EMAIL, data });
      out.email = r && r.sent ? 'sent' : `not_sent:${(r && r.reason) || '?'}`;
    }
  } catch (e) {
    out.email = 'error';
    logger.warn(`[prix2211] e-mail de la proposition non parti (candidature ${app._id}) : ${e && e.message ? e.message : e}`);
  }
  try {
    await (deps.push || ns.sendNotification)({ userId: id, role, type: TYPE_OFFER, templateType: TEMPLATE_PUSH, channels: { email: false }, data: { ...ids, ...text.providerPushData({ lang, view }) } });
    out.push = 'sent';
  } catch (e) {
    out.push = 'error';
    logger.warn(`[prix2211] push de la proposition non parti (candidature ${app._id}) : ${e && e.message ? e.message : e}`);
  }
  logger.info(`[prix2211] proposition envoyée : candidature ${app._id}, message ${out.chat}, e-mail ${out.email}`);
  return out;
}

/** Prévient le propriétaire de la réponse (e-mail dont le bouton ouvre sa page candidats par lien signé, + push). */
async function notifyOwner({ app, accepted, amount, currentTotal, currency, deps = {} }) {
  const text = require('../utils/priceOfferText2211');
  const ns = require('./notificationSender');
  const out = { email: 'skipped', push: 'skipped' };
  const ownerId = idOf(app.ownerId);
  const { role, id } = providerOf(app);
  let providerName = '';
  try { providerName = firstName(await loadProvider(role, id)); } catch (_) { providerName = ''; }
  const lang = await langOf('owner', ownerId);
  const ids = { applicationId: String(app._id), postId: app.postId ? idOf(app.postId) : '' };
  try {
    // type « application_new » : le bouton du gabarit vise /application/<id>, signé pour le propriétaire
    // (notificationSender.leadOwnerEmailLink → utils/applicationLink3110.withSignedApplicationLink).
    const data = { ...ids, ...text.ownerEmailData({ lang, accepted, providerName, amount, currentTotal, currency }) };
    const r = await (deps.send || ns.sendEmailOnly)({ userId: ownerId, role: 'owner', type: 'application_new', templateType: TEMPLATE_EMAIL, data });
    out.email = r && r.sent ? 'sent' : `not_sent:${(r && r.reason) || '?'}`;
  } catch (e) {
    out.email = 'error';
    logger.warn(`[prix2211] e-mail au propriétaire non parti (candidature ${app._id}) : ${e && e.message ? e.message : e}`);
  }
  try {
    await (deps.push || ns.sendNotification)({
      userId: ownerId, role: 'owner', type: 'application_new', templateType: TEMPLATE_PUSH, channels: { email: false },
      data: { ...ids, ...text.ownerPushData({ lang, accepted, providerName, amount, currency }) },
    });
    out.push = 'sent';
  } catch (e) {
    out.push = 'error';
    logger.warn(`[prix2211] push au propriétaire non parti (candidature ${app._id}) : ${e && e.message ? e.message : e}`);
  }
  return out;
}

// Dernière série d'envois lancée en arrière-plan (les tests l'attendent ; la production ne la lit pas).
let lastEffects = Promise.resolve(null);
const background = (promise, opts) => {
  lastEffects = promise.catch((e) => { logger.warn(`[prix2211] envois : ${e && e.message ? e.message : e}`); return null; });
  return opts && opts.awaitEffects === true ? lastEffects : null;
};

// ───────────────────────────── A. proposition du propriétaire ─────────────────────────────
const fail = (status, code, error, extra = {}) => ({ status, body: { error, code, ...extra } });

/**
 * @param {{applicationId:string, ownerId:string, amount:any, now?:Date, deps?:object, awaitEffects?:boolean}} p
 * @returns {Promise<{status:number, body:object}>}
 */
async function createOffer({ applicationId, ownerId, amount, now = new Date(), deps = {}, awaitEffects = false } = {}) {
  if (!enabled()) return fail(404, 'OFFER_DISABLED', 'Price offers are not available.');
  if (!ownerId) return fail(403, 'OWNER_REQUIRED', 'Owner context missing.');
  if (!OID.test(String(applicationId || ''))) return fail(400, 'INVALID_ID', 'Invalid application id.');
  const Application = require('../models/Application');
  const app = await Application.findById(applicationId);
  if (!app) return fail(404, 'NOT_FOUND', 'Application not found.');
  // Mêmes contrôles d'appartenance et d'état que respondToApplication.
  if (idOf(app.ownerId) !== String(ownerId)) return fail(403, 'FORBIDDEN', 'You do not have permission to update this application.');
  if (app.status !== 'pending') return fail(409, 'OFFER_NOT_PENDING', `Application already ${app.status}.`);
  if (app.archivedAt) return fail(409, 'OFFER_NOT_PENDING', 'Application is archived.');
  const post = app.postId ? await require('../models/Post').findById(app.postId).lean() : null;
  if (!post) return fail(409, 'OFFER_REQUEST_CLOSED', 'The request is no longer open.');
  if (engine.effectiveDateMode(post) === 'tbd') return fail(409, 'DATES_REQUIRED', 'Set the dates of the request first.', { postId: String(post._id) });
  const owner = await require('../models/Owner').findById(ownerId).select('location country').lean();
  let blocker = null;
  let startAt = null;
  try {
    const r615 = require('./applicationReminder615');
    const tz = r615.ownerTimeZone(post, owner);
    blocker = require('./sitterFree1011').postBlocker(post, now, tz);
    startAt = r615.wallToInstant(post.startDate, tz);
  } catch (_) { blocker = null; }
  if (blocker) return fail(409, blocker === 'no_dates' ? 'DATES_REQUIRED' : 'OFFER_REQUEST_CLOSED', 'The request is no longer open.', { reason: blocker });
  const p = app.pricing || {};
  const total = Number(p.totalPrice);
  if (p.indicative === true || p.stale === true || !(total > 0)) return fail(409, 'OFFER_NO_PRICE', 'This application has no total price yet.');
  const value = typeof amount === 'string' ? Number(amount.replace(',', '.')) : Number(amount);
  if (typeof amount === 'boolean' || amount == null || amount === '' || !Number.isFinite(value) || !(value > 0)) return fail(400, 'OFFER_INVALID', 'Invalid amount.');
  const offered = round2(value);
  const currency = String(p.currency || 'EUR').toUpperCase();
  const minAmount = minAmountFor(total);
  if (cents(offered) >= cents(total)) return fail(400, 'OFFER_NOT_LOWER', 'The offer must be lower than the current total.', { currentTotal: total, minAmount, currency });
  if (cents(offered) < cents(minAmount)) return fail(400, 'OFFER_TOO_LOW', 'The offer is too low.', { currentTotal: total, minAmount, currency });
  const { role, id: providerId } = providerOf(app);
  try {
    if (await require('./blockService').isOwnerSitterInteractionBlocked(String(ownerId), providerId)) return fail(403, 'BLOCKED', 'Messaging is disabled because one user has been blocked.');
  } catch (_) { /* non bloquant */ }
  // Contrôle ZOE (22/11) — on ne négocie que sur un prix JUSTE : le total stocké doit être celui du moteur
  // au tarif actuel du prestataire (même comparaison que le filet 2610 de respondToApplication), ou un prix
  // négocié encore valable. Sinon un ancien prix faux (2,70 € pour 15 jours à 18 €) devenait, une fois
  // « négocié », payable tel quel : il échappait au filet 2610 et au garde-fou 3110.
  if (!isNegotiatedValid(app, post)) {
    let engineTotal = null;
    try {
      const provider = await loadProvider(role, providerId);
      const priced = provider ? require('./applicationRepricing620').priceApplication({ application: app, post, provider, providerRole: role }) : null;
      engineTotal = priced ? Number(priced.totalPrice) : null;
    } catch (_) { engineTotal = null; }
    if (engineTotal > 0 && !near(engineTotal, total)) {
      logger.info(`[prix2211] proposition refusée : prix stocké ${total} ≠ prix du moteur ${engineTotal} (candidature ${app._id})`);
      return fail(409, 'OFFER_NO_PRICE', 'The price of this application must be confirmed first.', { reason: 'price_outdated' });
    }
  }

  if (expireDue(app, now)) await app.save();
  const list = offersOf(app);
  if (list.some((o) => o.status === 'pending')) return fail(409, 'OFFER_LIMIT', 'An offer is already waiting for an answer.', { reason: 'pending' });
  if (list.length >= MAX_OFFERS) return fail(409, 'OFFER_LIMIT', 'No more offers for this application.', { reason: 'max', max: MAX_OFFERS });
  // 2211 (BOB, relevé de ZOE) — un prix déjà négocié ne se renégocie pas : sinon le plancher de 40 % se
  // cumulerait (40 % de 40 % = 16 % du prix d'origine). Une seule négociation aboutie par candidature.
  if (p.negotiated2211 === true) return fail(409, 'OFFER_LIMIT', 'A price has already been agreed for this application.', { reason: 'negotiated', max: MAX_OFFERS });

  const startMs = startAt && Number.isFinite(startAt.getTime()) ? startAt.getTime() : new Date(post.startDate).getTime();
  const expiresAt = new Date(Math.min(now.getTime() + OFFER_TTL, Number.isFinite(startMs) ? startMs : Infinity));
  const offer = { amount: offered, currency, status: 'pending', originalTotal: total, requestKey: requestKey(post), createdAt: now, expiresAt, respondedAt: null, reason: '' };
  const index = list.length;
  // Écriture atomique : deux envois simultanés ne créent jamais deux propositions en attente.
  const w = await Application.updateOne(
    { _id: app._id, status: 'pending', [`priceOffer2211.offers.${index}`]: { $exists: false }, 'priceOffer2211.offers': { $not: { $elemMatch: { status: 'pending' } } } },
    { $push: { 'priceOffer2211.offers': offer } },
  );
  if (!w || !w.modifiedCount) return fail(409, 'OFFER_LIMIT', 'An offer is already waiting for an answer.', { reason: 'pending' });
  const fresh = await Application.findById(app._id).lean();
  logger.info(`[prix2211] proposition : candidature ${app._id}, ${offered} ${currency} pour un total de ${total} (${role})`);
  const waited = await background(notifyProvider({ app: fresh, post, index, now, deps }), { awaitEffects });
  return { status: 201, body: { offer: { index, amount: offered, currency, status: 'pending', expiresAt: expiresAt.toISOString(), originalTotal: total }, priceOffer2211View: ownerView(fresh, now.getTime()), ...(waited ? { delivery: waited } : {}) } };
}

// ───────────────────────────── C. réponse du prestataire ─────────────────────────────
/** Lecture seule pour la page : candidature, demande, proposition visée, état réel. */
async function loadForAnswer({ applicationId, providerId, index, now = new Date() }) {
  const Application = require('../models/Application');
  const app = await Application.findById(applicationId).lean();
  if (!app) return { ok: false, reason: 'gone' };
  if (providerOf(app).id !== String(providerId)) return { ok: false, reason: 'invalid' };
  const offer = offersOf(app)[index];
  if (!offer) return { ok: false, reason: 'invalid' };
  const post = app.postId ? await require('../models/Post').findById(app.postId).lean() : null;
  return { ok: true, app, post, offer, status: effectiveStatus(offer, now.getTime()), view: offerView(app.pricing, offer) };
}

/**
 * Accepter ou refuser UNE proposition. Idempotent : répondre deux fois la même chose renvoie le même
 * résultat sans rien réécrire ni renvoyer.
 * @returns {Promise<{ok:boolean, reason?:string, answer?:string, already?:boolean, view?:object}>}
 */
async function respond({ applicationId, providerId, index, answer, now = new Date(), deps = {}, awaitEffects = false } = {}) {
  const Application = require('../models/Application');
  const app = await Application.findById(applicationId);
  if (!app) return { ok: false, reason: 'gone' };
  const { role, id } = providerOf(app);
  if (id !== String(providerId)) return { ok: false, reason: 'invalid' };
  const offer = offersOf(app)[index];
  if (!offer) return { ok: false, reason: 'invalid' };
  const wanted = answer === 'decline' ? 'declined' : 'accepted';
  const view = offerView(app.pricing, offer);
  if (offer.status === wanted) return { ok: true, answer: wanted, already: true, view };
  if (expireDue(app, now)) await app.save();
  if (offer.status === 'expired') return { ok: false, reason: 'expired' };
  if (offer.status !== 'pending') return { ok: false, reason: 'answered' };
  if (app.status !== 'pending' || app.archivedAt) return { ok: false, reason: 'gone' };
  const key = `priceOffer2211.offers.${index}`;
  const guard = { _id: app._id, status: 'pending', [`${key}.status`]: 'pending' };

  if (wanted === 'declined') {
    const w = await Application.updateOne(guard, { $set: { [`${key}.status`]: 'declined', [`${key}.respondedAt`]: now } });
    if (!w || !w.modifiedCount) return { ok: false, reason: 'answered' };
    logger.info(`[prix2211] refusée : candidature ${app._id} (${role})`);
    await background(notifyOwner({ app: app.toObject(), accepted: false, amount: offer.amount, currentTotal: app.pricing && app.pricing.totalPrice, currency: view.currency, deps }), { awaitEffects });
    return { ok: true, answer: 'declined', view };
  }

  // Accepter : la demande et le prix doivent être ceux pour lesquels la proposition a été faite.
  const post = app.postId ? await require('../models/Post').findById(app.postId).lean() : null;
  const p = app.pricing || {};
  let cancel = '';
  if (!post || post.status === 'closed' || post.closedAt || post.hidden === true || (post.reservedBy && post.reservedBy.bookingId)) cancel = 'request_closed';
  else if (engine.effectiveDateMode(post) === 'tbd' || String(offer.requestKey || '') !== requestKey(post)) cancel = 'request_changed';
  else if (p.indicative === true || p.stale === true || !near(p.totalPrice, offer.originalTotal)) cancel = 'price_changed';
  if (cancel) {
    await Application.updateOne(guard, { $set: { [`${key}.status`]: 'cancelled', [`${key}.reason`]: cancel, [`${key}.respondedAt`]: now } });
    logger.info(`[prix2211] proposition annulée à la réponse (${cancel}) : candidature ${app._id}`);
    return { ok: false, reason: 'gone' };
  }
  const next = negotiatedPricing(p, offer.amount);
  const set = { pricing: next, [`${key}.status`]: 'accepted', [`${key}.respondedAt`]: now };
  // L'ancien bloc gardé est celui d'AVANT la 1re négociation (le prix du moteur), jamais un prix déjà négocié.
  const hasPrevious = !!(app.priceOffer2211 && app.priceOffer2211.previousPricing) && p.negotiated2211 === true;
  if (!hasPrevious) set['priceOffer2211.previousPricing'] = plain(p);
  const w = await Application.updateOne(guard, { $set: set });
  if (!w || !w.modifiedCount) return { ok: false, reason: 'answered' };
  logger.info(`[prix2211] acceptée : candidature ${app._id}, total ${p.totalPrice} → ${next.totalPrice} ${view.currency} (commission ${next.commission}, net ${next.netPayout}, taux ${next.commissionRate} inchangé)`);
  await background(notifyOwner({ app: app.toObject(), accepted: true, amount: next.totalPrice, currentTotal: p.totalPrice, currency: view.currency, deps }), { awaitEffects });
  return { ok: true, answer: 'accepted', view };
}

// ───────────────────────────── D. la demande change ─────────────────────────────
/**
 * Appelé après l'enregistrement d'une demande modifiée (postController.updatePost) : toute proposition
 * en attente ou acceptée faite pour une AUTRE version de la demande (dates, service, visites) est
 * annulée ; un prix négocié redevient celui du moteur. Jamais bloquant.
 * @returns {Promise<{cancelled:string[], repriced:string[]}>}
 */
async function onRequestChanged(post) {
  const out = { cancelled: [], repriced: [] };
  try {
    if (!post || !post._id) return out;
    const Application = require('../models/Application');
    const apps = await Application.find({ postId: post._id, status: 'pending', 'priceOffer2211.offers.0': { $exists: true } });
    if (!apps.length) return out;
    const key = requestKey(post);
    const tbd = engine.effectiveDateMode(post) === 'tbd';
    for (const app of apps) {
      const live = offersOf(app).filter((o) => o.status === 'pending' || o.status === 'accepted');
      if (!live.length || live.every((o) => String(o.requestKey || '') === key)) continue;
      const wasNegotiated = !!(app.pricing && app.pricing.negotiated2211 === true);
      if (!dropNegotiated(app, 'request_changed')) continue;
      out.cancelled.push(String(app._id));
      if (wasNegotiated && !tbd) {
        try {
          const { role, id } = providerOf(app);
          // eslint-disable-next-line no-await-in-loop
          const provider = await loadProvider(role, id);
          const priced = provider ? require('./applicationRepricing620').priceApplication({ application: app, post, provider, providerRole: role }) : null;
          if (priced) { app.pricing = { ...priced, stale: false, negotiated2211: false }; out.repriced.push(String(app._id)); }
        } catch (e) {
          logger.warn(`[prix2211] recalcul après changement de la demande (candidature ${app._id}) : ${e && e.message ? e.message : e}`);
        }
      }
      // eslint-disable-next-line no-await-in-loop
      await app.save();
      logger.info(`[prix2211] demande ${post._id} modifiée : proposition / prix négocié annulés pour la candidature ${app._id}`);
    }
  } catch (e) {
    logger.warn(`[prix2211] changement de la demande ${post && post._id} : ${e && e.message ? e.message : e}`);
  }
  return out;
}

// ───────────────────────────── admin (lecture seule) ─────────────────────────────
/** Compteurs par statut + 50 dernières propositions. Ni e-mail, ni téléphone, ni nom. */
async function adminSummary({ now = new Date(), limit = 50 } = {}) {
  const Application = require('../models/Application');
  const apps = await Application.find({ 'priceOffer2211.offers.0': { $exists: true } })
    .select('postId sitterId walkerId status pricing.totalPrice pricing.negotiated2211 pricing.commissionRate priceOffer2211.offers bookingId').lean();
  const counts = { pending: 0, accepted: 0, declined: 0, expired: 0, cancelled: 0 };
  const rows = [];
  for (const a of apps) {
    offersOf(a).forEach((o, index) => {
      const status = effectiveStatus(o, now.getTime());
      counts[status] = (counts[status] || 0) + 1;
      rows.push({
        applicationId: String(a._id), postId: a.postId ? String(a.postId) : null, providerRole: a.walkerId ? 'walker' : 'sitter', index,
        amount: o.amount, currency: o.currency, originalTotal: o.originalTotal, status, reason: o.reason || '',
        createdAt: o.createdAt || null, expiresAt: o.expiresAt || null, respondedAt: o.respondedAt || null,
        applicationStatus: a.status, negotiated: !!(a.pricing && a.pricing.negotiated2211 === true), currentTotal: a.pricing ? a.pricing.totalPrice : null, hasBooking: !!a.bookingId,
      });
    });
  }
  rows.sort((x, y) => new Date(y.createdAt || 0) - new Date(x.createdAt || 0));
  return {
    enabled: enabled(), total: rows.length, applications: apps.length, counts,
    settings: { minRatio: MIN_RATIO, maxOffers: MAX_OFFERS, ttlHours: OFFER_TTL / HOUR },
    rows: rows.slice(0, limit),
  };
}

module.exports = {
  enabled, signOfferLink, verifyOfferLink, offerUrl, requestKey, negotiatedPricing, negotiatedState, isNegotiatedValid, dropNegotiated, guardNegotiated,
  effectiveStatus, ownerView, offerView, minAmountFor, createOffer, loadForAnswer, respond, onRequestChanged, adminSummary,
  effects: () => lastEffects,
  TYPE_OFFER, MIN_RATIO, MAX_OFFERS, OFFER_TTL, LINK_TTL,
};
