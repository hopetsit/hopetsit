'use strict';

/**
 * 607 (ZOE, 02/10/2026) — GAINS D'ACTIVITÉ PawPoints (nouveau catalogue).
 *
 *   walkCompleted        +15  Balade terminée (≥ 10 min ET ≥ 300 m), 1 / jour
 *   firstReviewReceived  +50  premier avis reçu, 1 fois
 *   profileComplete      +100 profil complété à 100 % (mêmes règles que l'app,
 *                             utils/profile_completion.dart), 1 fois
 *   pioneer              +200 Pionnier (utils/pioneer607, NEO), 1 fois
 *   streak7              +50  7 jours d'activité de suite (chaque série)
 *   plushCaught          +20  peluche attrapée (appelé par le code de PAM), 1 / jour
 *
 * Tout passe par awardActivity : journal PawPointsEvent à clé unique AVANT de
 * créditer (deux requêtes simultanées = un seul gain), puis
 * pawPointsService.awardPointsDetailed (×2 Premium, bonus de niveau, 3 profils).
 * Ne lève jamais : un gain raté ne casse aucune action de l'utilisateur.
 */

const crypto = require('crypto');
const logger = require('../utils/logger');
const catalog = require('./pawPointsCatalog607');

const ROLE_MODEL = {
  owner: () => require('../models/Owner'),
  sitter: () => require('../models/Sitter'),
  walker: () => require('../models/Walker'),
};
const normRole = (r) => {
  const x = String(r || '').toLowerCase();
  return ROLE_MODEL[x] ? x : 'owner';
};

const WALK_MIN_MS = 10 * 60 * 1000;
const WALK_MIN_M = 300;
const STREAK_DAYS = 7;
const BIO_MIN = 20; // = kProfileBioMinLength (app)

const dayKey = (d = new Date()) => new Date(d).toISOString().slice(0, 10);
const prevDayKey = (k) => dayKey(new Date(new Date(`${k}T00:00:00Z`).getTime() - 86400000));

function personKeyFromEmail(email) {
  const e = String(email || '').toLowerCase().trim();
  return e ? crypto.createHash('sha256').update(e).digest('hex').slice(0, 32) : '';
}

async function personKeyOf(userId, role) {
  try {
    const doc = await ROLE_MODEL[normRole(role)]().findById(userId).select('email').lean();
    return personKeyFromEmail(doc && doc.email) || `id:${userId}`;
  } catch (_) {
    return `id:${userId}`;
  }
}

/** Clé de déduplication selon la règle du gain. */
function dedupeKeyFor(rule, personKey, { refId = '', now = new Date() } = {}) {
  switch (rule.limit) {
    case 'once': return `${personKey}:${rule.key}`;
    case 'daily': return `${personKey}:${rule.key}:${dayKey(now)}`;
    case 'streak': return `${personKey}:${rule.key}:${refId || dayKey(now)}`;
    default: return `${personKey}:${rule.key}:${refId || crypto.randomBytes(8).toString('hex')}`;
  }
}

/**
 * Crédite un gain du catalogue. Rend { key, points, credited } ou null
 * (déjà obtenu aujourd'hui / une fois, règle inconnue, erreur).
 */
async function awardActivity({ userId, role, key, refId = '', now = new Date() }) {
  try {
    const rule = catalog.earnRuleByKey(key);
    if (!rule || !userId) return null;
    const r = normRole(role);
    const PawPointsEvent = require('../models/PawPointsEvent');
    const personKey = await personKeyOf(userId, r);
    const dedupeKey = dedupeKeyFor(rule, personKey, { refId, now });
    let ev;
    try {
      ev = await PawPointsEvent.create({
        personKey, userId: String(userId), role: r, key, points: rule.points,
        refId: String(refId || ''), dedupeKey, at: now,
      });
    } catch (e) {
      if (e && e.code === 11000) return null; // déjà obtenu
      throw e;
    }
    const pawPoints = require('./pawPointsService');
    const got = await pawPoints.awardPointsDetailed({
      userId, role: r, points: rule.points, reason: `607 ${key}`,
    });
    if (!got) {
      // Crédit impossible (profil introuvable…) : on libère la clé.
      await PawPointsEvent.deleteOne({ _id: ev._id }).catch(() => {});
      return null;
    }
    await PawPointsEvent.updateOne({ _id: ev._id }, { $set: { credited: got.credited } }).catch(() => {});
    return { key, points: rule.points, credited: got.credited };
  } catch (e) {
    logger.warn(`[pawPoints607] ${key} : ${e?.message || e}`);
    return null;
  }
}

function _meters(aLat, aLng, bLat, bLng) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(bLat - aLat);
  const dLng = toRad(bLng - aLng);
  const x = Math.sin(dLat / 2) ** 2
    + Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(x)));
}

/** Distance parcourue d'un tracé [[lat, lng, t], …] (mètres). Pure. */
function trailMeters(trail) {
  let m = 0;
  const t = Array.isArray(trail) ? trail : [];
  for (let i = 1; i < t.length; i += 1) {
    const a = t[i - 1]; const b = t[i];
    if (a && b) m += _meters(Number(a[0]), Number(a[1]), Number(b[0]), Number(b[1]));
  }
  return m;
}

/** Une Balade compte-t-elle ? (≥ 10 min et ≥ 300 m). Pure. */
function baladeQualifies(session, now = Date.now()) {
  if (!session || !session.startedAt) return false;
  const dur = Number(now) - Number(session.startedAt);
  return dur >= WALK_MIN_MS && trailMeters(session.trail) >= WALK_MIN_M;
}

/** Appelé à l'arrêt de la Balade par l'utilisateur (utils/liveDevices589). */
async function onBaladeEnded({ userId, role, session, now = new Date() }) {
  if (!baladeQualifies(session, now.getTime())) return null;
  return awardActivity({ userId, role: role || session.role, key: 'walkCompleted', now });
}

/** Appelé après la création d'un avis (controllers/reviewController). */
async function onReviewCreated({ revieweeId, revieweeRole, now = new Date() }) {
  return awardActivity({ userId: revieweeId, role: revieweeRole, key: 'firstReviewReceived', now });
}

/** Mêmes éléments que l'app (profile_completion.dart). Pure. */
function isProfileComplete(doc, role, petsCount = 0) {
  if (!doc) return false;
  const s = (v) => String(v || '').trim();
  const parts = s(doc.name).replace(/\s+/g, ' ').split(' ').filter(Boolean);
  const first = s(doc.firstName) || (parts[0] || '');
  const last = s(doc.lastName) || (s(doc.firstName) ? '' : parts.slice(1).join(' '));
  const city = s(doc.city) || s(doc.location && doc.location.city);
  const base = first && last && s(doc.avatar && doc.avatar.url) && s(doc.mobile)
    && s(doc.address) && city && s(doc.bio).length >= BIO_MIN;
  if (!base) return false;
  if (normRole(role) === 'owner') return Number(petsCount) > 0;
  const services = Array.isArray(doc.service) ? doc.service.filter(Boolean) : [];
  const animals = Array.isArray(doc.acceptedPetTypes) ? doc.acceptedPetTypes.filter(Boolean) : [];
  return services.length > 0 && animals.length > 0;
}

async function _checkProfile(userId, role, now) {
  const r = normRole(role);
  const doc = await ROLE_MODEL[r]().findById(userId)
    .select('name firstName lastName avatar mobile address city location.city bio service acceptedPetTypes')
    .lean();
  let pets = 0;
  if (doc && r === 'owner') {
    try { pets = await require('../models/Pet').countDocuments({ ownerId: userId }); } catch (_) { pets = 0; }
  }
  if (!isProfileComplete(doc, r, pets)) return null;
  return awardActivity({ userId, role: r, key: 'profileComplete', now });
}

async function _checkPioneer(userId, role, now) {
  const r = normRole(role);
  if (r === 'owner') return null;
  let computeIsPioneer;
  try {
    ({ computeIsPioneer } = require('../utils/pioneer607'));
  } catch (_) {
    return null; // module de NEO pas encore en ligne
  }
  const doc = await ROLE_MODEL[r]().findById(userId).lean();
  if (!doc) return null;
  const v = await computeIsPioneer(doc);
  if (v !== true) return null;
  return awardActivity({ userId, role: r, key: 'pioneer', now });
}

/** Série : rend le nouvel état + true si la 7e journée vient d'être atteinte. */
function nextStreak(state, today) {
  const last = state && state.lastDay;
  if (last === today) return { lastDay: today, count: state.count, reached: false, same: true };
  const count = last && last === prevDayKey(today) ? (Number(state.count) || 0) + 1 : 1;
  if (count >= STREAK_DAYS) return { lastDay: today, count: 0, reached: true, same: false };
  return { lastDay: today, count, reached: false, same: false };
}

async function _checkStreak(userId, role, now) {
  const { PawPointsStreak } = require('../models/PawPointsEvent');
  const personKey = await personKeyOf(userId, role);
  const today = dayKey(now);
  const cur = await PawPointsStreak.findOne({ personKey }).lean();
  const nx = nextStreak(cur, today);
  if (nx.same) return null;
  // Écriture conditionnelle : deux sessions le même jour n'avancent pas deux fois.
  const filter = cur ? { personKey, lastDay: cur.lastDay } : { personKey };
  const best = Math.max(Number(cur && cur.best) || 0, nx.reached ? STREAK_DAYS : nx.count);
  try {
    const res = await PawPointsStreak.updateOne(
      filter,
      { $set: { lastDay: nx.lastDay, count: nx.count, best } },
      { upsert: !cur },
    );
    if (cur && !(res.modifiedCount || res.matchedCount)) return null;
  } catch (e) {
    if (e && e.code === 11000) return null;
    throw e;
  }
  if (!nx.reached) return null;
  return awardActivity({ userId, role, key: 'streak7', refId: today, now });
}

/**
 * « Je suis actif aujourd'hui » : série de jours + profil complet + Pionnier.
 * Appelé au début de chaque session (utils/activity590, toutes les apps et le
 * site) et par POST /pawpoints/checkin. Rend la liste des gains obtenus.
 */
async function checkIn({ userId, role, now = new Date() }) {
  const out = [];
  for (const fn of [_checkStreak, _checkProfile, _checkPioneer]) {
    try {
      const g = await fn(userId, role, now);
      if (g) out.push(g);
    } catch (e) {
      logger.warn(`[pawPoints607] checkIn ${fn.name} : ${e?.message || e}`);
    }
  }
  return out;
}

module.exports = {
  WALK_MIN_MS,
  WALK_MIN_M,
  STREAK_DAYS,
  dayKey,
  prevDayKey,
  personKeyFromEmail,
  dedupeKeyFor,
  awardActivity,
  trailMeters,
  baladeQualifies,
  onBaladeEnded,
  onReviewCreated,
  isProfileComplete,
  nextStreak,
  checkIn,
};
