/**
 * 612 (ADA, 04/10/2026) — Daniel : « je peux qu'appuyer sur le bouton Staff /
 * Premium, je ne peux pas séparer ; si je la mets Premium, elle apparaîtra ? ».
 *
 * « 👑 Offrir Premium » (admin, colonne Staff / Premium) : donne Paw Premium à la
 * PERSONNE (ses 3 profils, même e-mail / oldId) SANS le badge staff. Elle reste un
 * vrai compte : classement public, statistiques « vrais comptes ».
 *
 *   · même mécanique que les autres cadeaux admin (POST /admin/pawpremium/grant,
 *     geste du bon Samaritain) : historique `admin_gift`, AUCUN paiement, aucun
 *     Stripe / Airwallex, rien dans `payments` ;
 *   · durée : 1 mois (30 j), 3 mois (90 j, défaut) ou 1 an (365 j) ;
 *   · abonnement payant en cours : on prolonge à la suite, son forfait est gardé ;
 *   · retirer = on enlève seulement la part du cadeau qui reste à courir ; le
 *     temps payé (avant OU après le cadeau) n'est jamais rogné.
 */
const UserSubscription = require('../models/UserSubscription');
const { identityGroup } = require('../utils/identityGroup');
const logger = require('../utils/logger');

const DAY_MS = 86_400_000;
const GIFT_DAYS = { 1: 30, 3: 90, 12: 365 };
const DEFAULT_MONTHS = 3;
const SOURCE = 'admin_console';
const TIMERS = [
  ['premium', 'premiumExpiry'],
  ['pawspot', 'pawspotExpiry'],
  ['period', 'currentPeriodEnd'],
];

function monthsToDays(months) {
  const m = months == null || months === '' ? DEFAULT_MONTHS : Number(months);
  return GIFT_DAYS[m] || null;
}

function roleModel(role) {
  const r = String(role || '').toLowerCase();
  if (r === 'owner') return { name: 'Owner', Model: require('../models/Owner') };
  if (r === 'sitter') return { name: 'Sitter', Model: require('../models/Sitter') };
  if (r === 'walker') return { name: 'Walker', Model: require('../models/Walker') };
  return null;
}

async function personDocs(role, id) {
  const rm = roleModel(role);
  if (!rm) { const e = new Error('Invalid role.'); e.status = 400; throw e; }
  if (!/^[a-f0-9]{24}$/i.test(String(id))) { const e = new Error('User not found.'); e.status = 404; throw e; }
  const me = await rm.Model.findById(id).select('_id').lean();
  if (!me) { const e = new Error('User not found.'); e.status = 404; throw e; }
  let g = null;
  try { g = await identityGroup(id); } catch (_) { g = null; }
  const docs = g && g.docs && g.docs.length ? g.docs : [{ id: String(id), model: rm.name }];
  return docs;
}

const later = (d, now) => (d && new Date(d) > now ? new Date(d) : now);

/** Offre `months` mois de Premium aux 3 profils de la personne. */
async function grantPremiumGift(role, id, months, now = new Date()) {
  const days = monthsToDays(months);
  if (!days) { const e = new Error('Durée invalide (1, 3 ou 12 mois).'); e.status = 400; throw e; }
  const docs = await personDocs(role, id);
  const { migrateLegacyFamily } = require('../models/UserSubscription');
  const stamp = now.getTime();
  const out = [];
  for (const d of docs) {
    let sub = await UserSubscription.findOne({ userId: d.id, userModel: d.model });
    if (!sub) sub = new UserSubscription({ userId: d.id, userModel: d.model });
    migrateLegacyFamily(sub, now);
    const periodActive = !!(sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > now);
    const prevPlan = sub.plan || 'none';
    const prevStatus = sub.status || 'pending';
    const giftBase = {};
    for (const [key, field] of TIMERS) {
      const base = later(sub[field], now);
      giftBase[key] = base;
      sub[field] = new Date(base.getTime() + days * DAY_MS);
    }
    // Un abonnement en cours (payé) garde son forfait : on ajoute seulement du temps.
    if (!periodActive) sub.plan = days >= 365 ? 'premium_yearly' : 'premium_monthly';
    sub.status = 'active';
    sub.currentPeriodStart = sub.currentPeriodStart || now;
    sub.history = sub.history || [];
    sub.history.push({
      plan: days >= 365 ? 'premium_yearly' : 'premium_monthly',
      paymentProvider: 'admin_gift',
      paymentId: `adminpremium_${stamp}_${d.model}_${d.id}`,
      activatedAt: now,
      expiresAt: sub.premiumExpiry,
      intervalDays: days,
      currency: 'EUR',
      giftBase,
      giftSource: SOURCE,
      prevPlan: periodActive ? undefined : prevPlan,
      prevStatus: periodActive ? undefined : prevStatus,
    });
    await sub.save();
    out.push({ role: d.model.toLowerCase(), premiumExpiry: sub.premiumExpiry, giftUntil: sub.premiumExpiry });
  }
  logger.info(`[admin/premium-gift] ${role} ${id} +${days} j → ${out.length} profil(s), sans isStaff ni paiement`);
  return { days, months: Number(months == null || months === '' ? DEFAULT_MONTHS : months), profiles: out };
}

/** Temps du cadeau encore à courir sur un compteur (ms, entre 0 et la durée). */
function remainingMs(entry, key, now) {
  const dur = (Number(entry.intervalDays) || 0) * DAY_MS;
  if (!dur) {
    // Très ancien cadeau sans durée notée : ce qui reste jusqu'à sa fin.
    return entry.expiresAt ? Math.max(0, new Date(entry.expiresAt).getTime() - now.getTime()) : 0;
  }
  let base = entry.giftBase && entry.giftBase[key] ? new Date(entry.giftBase[key]) : null;
  // Anciens cadeaux (sans point de départ) : déduit de la fin du cadeau.
  if (!base && entry.expiresAt) base = new Date(new Date(entry.expiresAt).getTime() - dur);
  if (!base) return 0;
  const end = base.getTime() + dur;
  const from = Math.max(now.getTime(), base.getTime());
  return Math.max(0, Math.min(dur, end - from));
}

/** Retire les Premium OFFERTS en cours (jamais le temps payé). */
async function revokePremiumGift(role, id, now = new Date()) {
  const docs = await personDocs(role, id);
  const out = [];
  let removedAny = false;
  for (const d of docs) {
    const sub = await UserSubscription.findOne({ userId: d.id, userModel: d.model });
    if (!sub) continue;
    const gifts = (sub.history || []).filter((h) => h.paymentProvider === 'admin_gift' && !h.revokedAt
      && remainingMs(h, 'premium', now) > 0);
    if (!gifts.length) continue;
    for (const [key, field] of TIMERS) {
      if (!sub[field]) continue;
      const remove = gifts.reduce((n, h) => n + remainingMs(h, key, now), 0);
      if (!remove) continue;
      const v = new Date(sub[field]).getTime() - remove;
      sub[field] = new Date(Math.max(v, now.getTime()));
    }
    for (const h of gifts) h.revokedAt = now;
    const periodLeft = sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > now;
    if (!periodLeft) {
      // Le cadeau avait posé le forfait : on remet celui d'avant.
      const first = gifts.find((h) => h.prevPlan != null);
      if (first) {
        sub.plan = first.prevPlan || 'none';
        sub.status = first.prevStatus === 'active' ? 'expired' : (first.prevStatus || 'expired');
      } else {
        sub.status = 'expired';
      }
    }
    await sub.save();
    removedAny = true;
    out.push({ role: d.model.toLowerCase(), premiumExpiry: sub.premiumExpiry, revoked: gifts.length });
  }
  logger.info(`[admin/premium-gift] ${role} ${id} cadeau retiré sur ${out.length} profil(s)`);
  return { removed: removedAny, profiles: out };
}

/** Cadeaux admin encore en cours (pastille de l'admin). */
async function activeGifts(now = new Date()) {
  const subs = await UserSubscription.find({
    'history.paymentProvider': 'admin_gift',
    premiumExpiry: { $gt: now },
  }).select('userId userModel premiumExpiry history').lean();
  const rows = [];
  for (const s of subs) {
    const live = (s.history || []).filter((h) => h.paymentProvider === 'admin_gift' && !h.revokedAt
      && remainingMs(h, 'premium', now) > 0);
    if (!live.length) continue;
    const giftUntil = live.reduce((m, h) => {
      const dur = (Number(h.intervalDays) || 0) * DAY_MS;
      if (!dur || !(h.giftBase && h.giftBase.premium)) return Math.max(m, h.expiresAt ? new Date(h.expiresAt).getTime() : 0);
      return Math.max(m, new Date(h.giftBase.premium).getTime() + dur);
    }, 0);
    rows.push({
      userId: String(s.userId),
      role: String(s.userModel || '').toLowerCase(),
      premiumExpiry: s.premiumExpiry,
      giftUntil: giftUntil ? new Date(giftUntil) : s.premiumExpiry,
    });
  }
  return rows;
}

module.exports = {
  grantPremiumGift,
  revokePremiumGift,
  activeGifts,
  monthsToDays,
  GIFT_DAYS,
  DEFAULT_MONTHS,
};
