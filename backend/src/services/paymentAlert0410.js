'use strict';

/**
 * 04/10/2026 (FLO) — Daniel : « c'est possible qu'à chaque paiement réussi je
 * reçoive un mail sur contact@hopetsit.com ? ».
 *
 * UN SEUL service pour tous les encaissements : il formate l'e-mail interne,
 * garantit qu'il ne part qu'UNE fois par paiement (registre PaymentAlert0410,
 * clé unique) et l'envoie EN ARRIÈRE-PLAN : il ne peut jamais retarder ni
 * faire échouer un paiement (aucune exception ne remonte à l'appelant).
 *
 * Points du serveur qui CONFIRMENT un encaissement et appellent ce service :
 *  - réservation payée (carte Airwallex, PayPal, rattrapage admin) : crochet
 *    `post('save')` du modèle Booking, sur le passage de paymentStatus à
 *    'paid' → un seul endroit pour tous les chemins (webhook, /confirm,
 *    capture PayPal, réconciliation admin) ;
 *  - boutique par carte / PayPal (Airwallex) : webhook
 *    payment_intent.succeeded + utils/assertPaidIntent.js (les /confirm) ;
 *  - boutique payée avec le portefeuille : purchaseActivationController
 *    (paiements `wallet_…`), /boost/purchase/wallet, KYC par portefeuille ;
 *  - achats intégrés Apple validés côté serveur : appleIapService ;
 *  - vérification d'identité (KYC) : kycController.onKycPaymentSucceeded ;
 *  - remboursements : refundBookingPayment (réservations), remboursement
 *    admin, notification Apple REFUND.
 * Pas de Stripe (retiré en v21.1.1) ni de Google Play Billing (Android paie
 * par carte Airwallex ou portefeuille) : rien à brancher de ce côté.
 *
 * Interrupteurs : PAYMENT_ALERT_EMAIL (destinataire, défaut
 * contact@hopetsit.com) ; PAYMENT_ALERTS=off coupe tout. En test jest le
 * service est muet sauf PAYMENT_ALERTS_IN_TEST=1 (évite des envois parasites
 * dans les autres suites qui créent des réservations payées).
 */

const logger = require('../utils/logger');

const DEFAULT_TO = 'contact@hopetsit.com';
const TEAM_EMAIL_RE = /hopetsit@gmail\.com|contact@hopetsit\.com|dadaciao84@|jandoe@email\.com/i;

const recipient = () => String(process.env.PAYMENT_ALERT_EMAIL || DEFAULT_TO).trim() || DEFAULT_TO;

function alertsEnabled() {
  if (/^(off|0|false|no)$/i.test(String(process.env.PAYMENT_ALERTS || '').trim())) return false;
  if (process.env.NODE_ENV === 'test' && process.env.PAYMENT_ALERTS_IN_TEST !== '1') return false;
  return true;
}

function adminUrl() {
  if (process.env.PAYMENT_ALERT_ADMIN_URL) return String(process.env.PAYMENT_ALERT_ADMIN_URL).trim();
  const api = String(process.env.PUBLIC_API_URL || '').trim();
  if (api) return `${api.replace(/\/+$/, '').replace(/\/api\/v\d+$/, '')}/admin`;
  return 'https://hopetsit-backend.onrender.com/admin';
}

// ─── File d'attente en arrière-plan ────────────────────────────────────────
const _pending = new Set();

function _queue(task) {
  if (!alertsEnabled()) return null;
  const p = new Promise((resolve) => setImmediate(resolve))
    .then(task)
    .catch((e) => {
      logger.error(`[paymentAlert] échec non bloquant : ${e && e.message ? e.message : e}`);
      return { error: String(e && e.message ? e.message : e) };
    })
    .finally(() => _pending.delete(p));
  _pending.add(p);
  return p;
}

/** Pour les tests : attend que toutes les alertes en file soient traitées. */
async function flushPaymentAlerts() {
  while (_pending.size) {
    await Promise.allSettled([..._pending]);
  }
}

// ─── Mise en forme ─────────────────────────────────────────────────────────
const num = (v) => {
  if (v === undefined || v === null || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

function money(amount, currency) {
  const n = num(amount);
  if (n === null) return 'montant non transmis';
  const cur = String(currency || 'EUR').toUpperCase();
  try {
    return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: cur })
      .format(n)
      .replace(/[  ]/g, ' ');
  } catch (_) {
    return `${n.toFixed(2).replace('.', ',')} ${cur}`;
  }
}

const esc = (v) => String(v == null ? '' : v)
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;');

const ROLE_FR = { owner: 'propriétaire', sitter: 'gardien', walker: 'promeneur' };

function _plainEmail(stored) {
  if (!stored) return '';
  try {
    const { decrypt } = require('../utils/encryption');
    const d = decrypt(stored);
    if (typeof d === 'string' && d) return d;
  } catch (_) { /* e-mail en clair */ }
  return String(stored);
}

/** « Camille D. » — jamais l'e-mail ni le nom complet. */
function shortName(doc) {
  if (!doc) return 'compte inconnu';
  const full = String(doc.name || '').trim();
  const first = String(doc.firstName || '').trim() || full.split(/\s+/)[0] || '';
  const last = String(doc.lastName || '').trim()
    || (full.split(/\s+/).length > 1 ? full.split(/\s+/).slice(-1)[0] : '');
  const initial = last ? ` ${last.charAt(0).toUpperCase()}.` : '';
  return `${first || 'Sans nom'}${initial}`;
}

function cityOf(doc) {
  if (!doc) return '';
  return String(doc.city || (doc.location && doc.location.city) || '').trim();
}

/** 'test' (+test), 'team' (staff / adresses de l'équipe) ou ''. */
function accountFlag(doc) {
  if (!doc) return '';
  const email = _plainEmail(doc.email);
  if (/\+test/i.test(email)) return 'test';
  if (doc.isStaff === true || TEAM_EMAIL_RE.test(email)) return 'team';
  return '';
}

function personLine(doc, role) {
  if (!doc) return `compte introuvable (${ROLE_FR[role] || role || '?'})`;
  const parts = [ROLE_FR[role] || role];
  const city = cityOf(doc);
  if (city) parts.push(city);
  const flag = accountFlag(doc);
  const tag = flag === 'test' ? ' — COMPTE DE TEST' : flag === 'team' ? ' — ÉQUIPE' : '';
  return `${shortName(doc)} (${parts.join(', ')})${tag}`;
}

function modelForRole(role) {
  const r = String(role || '').toLowerCase();
  if (r === 'owner') return require('../models/Owner');
  if (r === 'walker') return require('../models/Walker');
  if (r === 'sitter') return require('../models/Sitter');
  return null;
}

async function loadUser(userId, role) {
  const Model = modelForRole(role);
  if (!Model || !userId) return null;
  try {
    return await Model.findById(userId)
      .select('name firstName lastName email city location.city isStaff')
      .lean();
  } catch (_) {
    return null;
  }
}

const SERVICE_FR = {
  dog_walking: 'promenade',
  walking: 'promenade',
  home_visit: 'visite à domicile',
  overnight_stay: 'garde de nuit',
  long_stay: 'garde longue durée',
  pet_sitting: 'garde',
  house_sitting: 'garde à domicile',
  day_care: 'garderie',
  daycare: 'garderie',
};

function serviceLabel(booking) {
  const raw = booking && booking.serviceType;
  const key = typeof raw === 'string' ? raw.toLowerCase() : '';
  if (SERVICE_FR[key]) return SERVICE_FR[key];
  return booking && booking.walkerId ? 'promenade' : 'garde';
}

function planLabel(plan) {
  const p = String(plan || '').toLowerCase();
  let name = 'PawFollow';
  if (/^premium/.test(p)) name = 'PawPremium';
  else if (/^(family|famille)/.test(p)) name = 'PawFamily (Famille)';
  else if (/^pawspot/.test(p)) name = 'PawSpot';
  const period = /yearly|annual|annuel/.test(p) ? 'annuel' : 'mensuel';
  return `${name} ${period}`;
}

/** Libellé produit à partir du type d'intention Airwallex (ou du `purpose`). */
function productLabel(type, meta = {}) {
  const t = String(type || '').toLowerCase();
  if (t === 'subscription_purchase' || t === 'premium_purchase' || t === 'subscription') {
    return `abonnement ${planLabel(meta.plan)}`;
  }
  if (t === 'boost_purchase' || t === 'boost') return `PawBoost profil${meta.tier ? ` (${meta.tier})` : ''}`;
  if (t === 'map_boost_purchase' || t === 'map_boost') return `boost PawMap${meta.tier ? ` (${meta.tier})` : ''}`;
  if (t === 'pawspot_purchase' || t === 'pawspot') return 'abonnement PawSpot';
  if (t === 'chat_addon_purchase' || t === 'chat_addon') return 'option Chat';
  if (t === 'kyc') return "vérification d'identité";
  if (t === 'donation') return 'don';
  return t ? `achat boutique (${t})` : 'achat boutique';
}

const PROVIDER_FR = {
  airwallex: 'carte bancaire (Airwallex)',
  paypal: 'PayPal',
  wallet: 'portefeuille HoPetSit',
  apple: 'achat intégré Apple (App Store)',
};

function formatDate(d) {
  if (!d) return '';
  const date = d instanceof Date ? d : new Date(d);
  if (Number.isNaN(date.getTime())) return String(d);
  try {
    return new Intl.DateTimeFormat('fr-FR', {
      dateStyle: 'medium', timeStyle: 'short', timeZone: 'Europe/Paris',
    }).format(date);
  } catch (_) {
    return date.toISOString();
  }
}

/**
 * Construit { subject, text, html } à partir d'une description neutre.
 * Aucune donnée bancaire n'entre jamais ici (pas de numéro de carte, d'IBAN
 * ni d'e-mail d'utilisateur) : seulement montants, rôles, villes, références.
 */
function renderAlert({
  kind = 'payment', amount, currency, label, city, flag, rows = [], essai = false,
}) {
  const head = kind === 'refund' ? '↩️ Remboursement' : '💰 Paiement reçu';
  const where = city ? ` (${city})` : '';
  const prefix = (essai ? '🧪 ESSAI — ' : '')
    + (flag === 'test' ? '🧪 TEST — ' : flag === 'team' ? '👥 ÉQUIPE — ' : '');
  const subject = `${prefix}${head} : ${money(amount, currency)} — ${label}${where}`;

  const banners = [];
  if (essai) {
    banners.push("ESSAI : e-mail de démonstration envoyé depuis l'admin. Aucun paiement n'a eu lieu.");
  }
  if (flag === 'test') {
    banners.push("COMPTE DE TEST : ce paiement implique un compte +test. Ce n'est PAS une vraie vente.");
  } else if (flag === 'team') {
    banners.push("ÉQUIPE : ce paiement implique un compte de l'équipe HoPetSit. Ce n'est PAS une vente à un client.");
  }

  const link = adminUrl();
  const textLines = [
    ...banners.map((b) => `⚠️ ${b}`),
    ...(banners.length ? [''] : []),
    ...rows.filter(([, v]) => v !== undefined && v !== null && v !== '').map(([k, v]) => `${k} : ${v}`),
    '',
    `Admin : ${link}`,
    '',
    "E-mail interne automatique HoPetSit (aucune donnée bancaire n'y figure).",
  ];
  const text = textLines.join('\n');

  const bannerHtml = banners
    .map((b) => `<div style="background:#FDECEA;border:2px solid #C92A12;color:#7A1A0B;border-radius:12px;padding:12px 14px;margin:0 0 12px;font-weight:800;font-size:15px;line-height:1.4">⚠️ ${esc(b)}</div>`)
    .join('');
  const rowsHtml = rows
    .filter(([, v]) => v !== undefined && v !== null && v !== '')
    .map(([k, v]) => `<tr><td style="padding:7px 0;color:#6E6E73;font-size:13px;vertical-align:top;width:42%">${esc(k)}</td><td style="padding:7px 0;color:#17141f;font-size:14px;font-weight:600">${esc(v)}</td></tr>`)
    .join('');
  const accent = kind === 'refund' ? '#2563EB' : '#16A34A';
  const html = `<!doctype html><html><body style="margin:0;background:#F5F5F7;font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif">
<div style="max-width:520px;margin:0 auto;padding:16px">
${bannerHtml}
<div style="background:#fff;border-radius:16px;padding:18px 16px">
<div style="font-size:13px;color:${accent};font-weight:800;text-transform:uppercase;letter-spacing:.04em">${esc(head)}</div>
<div style="font-size:28px;font-weight:800;color:#17141f;margin:4px 0 2px">${esc(money(amount, currency))}</div>
<div style="font-size:15px;color:#17141f;margin-bottom:12px">${esc(label)}${esc(where)}</div>
<table role="presentation" style="width:100%;border-collapse:collapse">${rowsHtml}</table>
<a href="${esc(link)}" style="display:inline-block;margin-top:14px;background:#C92A12;color:#fff;text-decoration:none;font-weight:700;padding:11px 18px;border-radius:999px">Ouvrir l'admin</a>
</div>
<p style="font-size:11px;color:#8E8E93;text-align:center;margin:12px 0 0">E-mail interne automatique HoPetSit — aucune donnée bancaire n'y figure.</p>
</div></body></html>`;
  return { subject, text, html };
}

// ─── Envoi idempotent ──────────────────────────────────────────────────────
/**
 * @param {object} p
 * @param {string} p.key   clé unique du paiement (idempotence)
 * @param {'payment'|'refund'} p.kind
 * @param {() => Promise<object|null>} p.build  renvoie les champs de renderAlert,
 *        ou null pour ne rien envoyer (ex. montant 0 = offert)
 */
async function _deliver({ key, kind, build }) {
  const PaymentAlert = require('../models/PaymentAlert0410');
  const to = recipient();
  let registered = true;
  try {
    await PaymentAlert.create({ key, kind, to });
  } catch (e) {
    if (e && e.code === 11000) {
      logger.info(`[paymentAlert] ${key} déjà signalé → pas de 2e e-mail`);
      return { duplicate: true };
    }
    // Registre indisponible : on préfère prévenir Daniel (rare) plutôt que
    // de taire un encaissement.
    registered = false;
    logger.warn(`[paymentAlert] registre indisponible pour ${key} (${e && e.message}) — envoi quand même`);
  }

  const mark = async (fields) => {
    if (!registered) return;
    try { await PaymentAlert.updateOne({ key }, { $set: fields }); } catch (_) { /* best-effort */ }
  };

  let content;
  try {
    content = await build();
  } catch (e) {
    await mark({ status: 'failed', error: `build: ${String(e && e.message).slice(0, 300)}` });
    throw e;
  }
  if (!content) {
    await mark({ status: 'skipped', reason: 'rien à signaler (montant nul ou offert)' });
    return { skipped: true };
  }
  const { subject, text, html } = renderAlert({ kind, ...content });
  try {
    const { sendEmail } = require('./emailService');
    await sendEmail(to, subject, text, html);
    await mark({ status: 'sent', subject, sentAt: new Date() });
    logger.info(`[paymentAlert] ${key} → e-mail « ${subject} » envoyé à ${to}`);
    return { sent: true, subject, to };
  } catch (e) {
    await mark({ status: 'failed', subject, error: String(e && e.message ? e.message : e).slice(0, 300) });
    logger.error(`[paymentAlert] ${key} : envoi échoué (${e && e.message}) — paiement non affecté`);
    return { failed: true, error: String(e && e.message ? e.message : e) };
  }
}

// ─── Réservations ──────────────────────────────────────────────────────────
async function _bookingParties(booking) {
  const Owner = require('../models/Owner');
  const owner = booking.ownerId
    ? await Owner.findById(booking.ownerId._id || booking.ownerId)
      .select('name firstName lastName email city location.city isStaff').lean().catch(() => null)
    : null;
  const providerRole = booking.walkerId ? 'walker' : 'sitter';
  const providerRef = booking.walkerId || booking.sitterId;
  const provider = providerRef ? await loadUser(providerRef._id || providerRef, providerRole) : null;
  return { owner, provider, providerRole };
}

function _bookingDates(booking) {
  const start = booking.startDate || booking.date || '';
  const end = booking.endDate && booking.endDate !== start ? ` → ${booking.endDate}` : '';
  const slot = booking.timeSlot ? `, ${booking.timeSlot}` : '';
  return start ? `${start}${end}${slot}` : '';
}

function _combinedFlag(...flags) {
  if (flags.includes('test')) return 'test';
  if (flags.includes('team')) return 'team';
  return '';
}

/**
 * Réservation passée à « payée ». Appelé par le crochet post('save') du
 * modèle Booking. `extra` = montant réellement débité s'il est connu
 * (webhook / /confirm le posent dans booking.$locals.paymentAlertAmount).
 */
function alertBookingPaid(booking, extra = {}) {
  if (!booking || !booking._id) return null;
  const bookingId = String(booking._id);
  const snapshot = typeof booking.toObject === 'function' ? booking.toObject() : { ...booking };
  return _queue(() => _deliver({
    key: `booking-paid:${bookingId}`,
    kind: 'payment',
    build: async () => {
      const { owner, provider, providerRole } = await _bookingParties(snapshot);
      const pricing = snapshot.pricing || {};
      const currency = String(extra.currency || pricing.currency || 'EUR').toUpperCase();
      const charged = num(extra.amount);
      const amount = charged !== null ? charged : num(pricing.totalPrice);
      const service = serviceLabel(snapshot);
      const city = cityOf(owner) || cityOf(provider);
      const flag = _combinedFlag(accountFlag(owner), accountFlag(provider));
      const rows = [
        ['Type', `réservation entre utilisateurs — ${service}`],
        ['Montant payé', money(amount, currency)],
        ['Devise', currency],
        ['Commission HoPetSit', money(pricing.commission, currency)],
        ['Pour le prestataire', money(pricing.netPayout, currency)],
      ];
      if (charged !== null && num(pricing.totalPrice) !== null && Math.abs(charged - pricing.totalPrice) > 0.009) {
        rows.push(['Prix de la réservation', `${money(pricing.totalPrice, currency)} (remise appliquée)`]);
      }
      rows.push(
        ['Qui paie', personLine(owner, 'owner')],
        ['Qui reçoit', personLine(provider, providerRole)],
        ['Date de la prestation', _bookingDates(snapshot)],
        ['Moyen de paiement', PROVIDER_FR[snapshot.paymentProvider] || snapshot.paymentProvider || ''],
        ['Payé le', formatDate(snapshot.paidAt || new Date())],
        ['Réservation (id interne)', bookingId],
        ['Réf. paiement', snapshot.airwallexPaymentIntentId || snapshot.paypalOrderId || ''],
      );
      return { amount, currency, label: `réservation ${service}`, city, flag, rows };
    },
  }));
}

/** Remboursement RÉUSSI d'une réservation (appelé après le succès du PSP). */
function alertBookingRefund(booking, { amount, currency, refundId, by } = {}) {
  if (!booking || !booking._id) return null;
  const bookingId = String(booking._id);
  const snapshot = typeof booking.toObject === 'function' ? booking.toObject() : { ...booking };
  return _queue(() => _deliver({
    key: `booking-refund:${bookingId}`,
    kind: 'refund',
    build: async () => {
      const { owner, provider, providerRole } = await _bookingParties(snapshot);
      const pricing = snapshot.pricing || {};
      const cur = String(currency || pricing.currency || 'EUR').toUpperCase();
      const refunded = num(amount) !== null ? num(amount) : num(pricing.totalPrice);
      const service = serviceLabel(snapshot);
      const city = cityOf(owner) || cityOf(provider);
      const flag = _combinedFlag(accountFlag(owner), accountFlag(provider));
      return {
        amount: refunded,
        currency: cur,
        label: `réservation ${service}`,
        city,
        flag,
        rows: [
          ['Type', `remboursement d'une réservation — ${service}`],
          ['Montant remboursé', money(refunded, cur)],
          ['Devise', cur],
          ['Commission HoPetSit perdue', money(pricing.commission, cur)],
          ['Remboursé à', personLine(owner, 'owner')],
          ['Prestataire', personLine(provider, providerRole)],
          ['Date de la prestation', _bookingDates(snapshot)],
          ['Moyen de paiement', PROVIDER_FR[snapshot.paymentProvider] || snapshot.paymentProvider || ''],
          ['Origine', by || ''],
          ['Réservation (id interne)', bookingId],
          ['Réf. remboursement', refundId || ''],
        ],
      };
    },
  }));
}

// ─── Boutique / abonnements / KYC / dons ──────────────────────────────────
const SKIP_ID_RE = /^(staff_free_|gift_|promo_|admin_gift)/i;

/**
 * Achat hors réservation réellement encaissé.
 * @param {object} p
 * @param {string} p.key       clé unique (ex. `pi:<id>`, `wallet:<id>`, `apple:<tx>`)
 * @param {string} p.type      type d'intention (subscription_purchase, boost_purchase…)
 * @param {object} [p.metadata]
 * @param {number} [p.amount]  montant réellement débité (unités majeures)
 * @param {string} [p.currency]
 * @param {'airwallex'|'paypal'|'wallet'|'apple'} p.provider
 * @param {string} [p.environment]  Apple : 'Sandbox' = test
 * @param {string} [p.reference]    référence du paiement (id d'intention…)
 */
function alertShopPayment({
  key, type, metadata = {}, amount, currency, provider, environment, reference, kind = 'payment',
}) {
  const rawKey = String(key || '');
  if (!rawKey) return null;
  const ref = String(reference || '');
  if (SKIP_ID_RE.test(ref)) return null; // offert (staff, cadeau, promo)
  const meta = { ...(metadata || {}) };
  return _queue(() => _deliver({
    key: rawKey,
    kind,
    build: async () => {
      const amt = num(amount) !== null
        ? num(amount)
        : (num(meta.providerAmount) !== null ? num(meta.providerAmount)
          : (num(meta.paidAmount) !== null ? num(meta.paidAmount) : num(meta.amount)));
      if (kind === 'payment' && amt === 0) return null; // 0 € = rien d'encaissé
      const cur = String(currency || meta.providerCurrency || meta.currency || 'EUR').toUpperCase();
      const role = String(meta.role || meta.userRole || '').toLowerCase();
      const user = await loadUser(meta.userId, role);
      const label = productLabel(type, meta);
      const sandbox = String(environment || meta.environment || '') === 'Sandbox';
      const flag = sandbox ? 'test' : accountFlag(user);
      const rows = [
        ['Type', kind === 'refund' ? `remboursement — ${label}` : label],
        [kind === 'refund' ? 'Montant remboursé' : 'Montant payé', money(amt, cur)],
        ['Devise', cur],
      ];
      if (kind === 'payment') {
        if (provider === 'apple') {
          rows.push(['Pour HoPetSit', 'le montant moins la commission Apple (15 %)']);
        } else if (provider === 'wallet') {
          rows.push(['Pour HoPetSit', "100 % — payé avec le portefeuille (argent déjà gagné sur l'app, pas un nouvel encaissement par carte)"]);
        } else {
          rows.push(['Pour HoPetSit', '100 % (achat boutique, pas de prestataire)']);
        }
      }
      rows.push(
        ['Qui paie', personLine(user, role || '?')],
        ['Moyen de paiement', PROVIDER_FR[provider] || provider || ''],
      );
      if (sandbox) rows.push(['Environnement Apple', 'Sandbox (test Apple, pas un vrai achat)']);
      if (meta.platform) rows.push(['Plateforme', String(meta.platform)]);
      rows.push(
        ['Date', formatDate(new Date())],
        ['Réf. paiement', ref || rawKey],
      );
      return {
        amount: amt, currency: cur, label, city: cityOf(user), flag, rows,
      };
    },
  }));
}

/** Intention Airwallex SUCCEEDED (webhook ou /confirm) d'un achat boutique. */
function alertIntentPaid({ piId, metadata = {}, amount, currency, purpose }) {
  if (!piId) return null;
  const meta = metadata || {};
  const type = String(meta.type || purpose || '').toLowerCase();
  if (!type || type === 'card_verification' || meta.verifyCardAutoRefund === 'true') return null;
  const prov = String(meta.provider || '').toLowerCase() === 'paypal' ? 'paypal' : 'airwallex';
  return alertShopPayment({
    key: `pi:${piId}`,
    type,
    metadata: meta,
    amount,
    currency,
    provider: prov,
    reference: piId,
  });
}

/** Achat boutique payé avec le portefeuille HoPetSit. */
function alertWalletPurchase({ reference, type, metadata = {} }) {
  if (!reference) return null;
  return alertShopPayment({
    key: `wallet:${reference}`,
    type,
    metadata,
    provider: 'wallet',
    reference,
  });
}

// ─── E-mail d'essai (route admin) ──────────────────────────────────────────
/**
 * Envoie UN e-mail d'essai clairement marqué « ESSAI », sans aucun paiement
 * ni écriture dans le registre. Synchrone (attendu par la route admin).
 */
async function sendTestPaymentAlert() {
  const to = recipient();
  const { subject, text, html } = renderAlert({
    kind: 'payment',
    essai: true,
    amount: 24,
    currency: 'EUR',
    label: 'réservation promenade',
    city: 'Paris',
    flag: '',
    rows: [
      ['Type', 'réservation entre utilisateurs — promenade (EXEMPLE)'],
      ['Montant payé', money(24, 'EUR')],
      ['Devise', 'EUR'],
      ['Commission HoPetSit', money(4, 'EUR')],
      ['Pour le prestataire', money(20, 'EUR')],
      ['Qui paie', 'Camille D. (propriétaire, Paris) — EXEMPLE'],
      ['Qui reçoit', 'Lucas M. (promeneur, Paris) — EXEMPLE'],
      ['Date de la prestation', 'exemple'],
      ['Réservation (id interne)', 'ESSAI — aucun'],
    ],
  });
  const { sendEmail } = require('./emailService');
  await sendEmail(to, subject, text, html);
  return { to, subject };
}

module.exports = {
  alertBookingPaid,
  alertBookingRefund,
  alertShopPayment,
  alertIntentPaid,
  alertWalletPurchase,
  sendTestPaymentAlert,
  flushPaymentAlerts,
  // exportés pour les tests
  renderAlert,
  money,
  shortName,
  accountFlag,
  alertsEnabled,
};
