const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const logger = require('../utils/logger');
const { sendEmail } = require('./emailService');
const { decrypt } = require('../utils/encryption');
const { render } = require('../utils/i18nTemplate');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const Booking = require('../models/Booking');
const Post = require('../models/Post');
const LifecycleEmail = require('../models/LifecycleEmail');

/**
 * v560 — MOTEUR DE CROISSANCE AUTONOME : e-mails de cycle de vie.
 *
 * Mission Daniel (10/09/2026) : « crée du trafic et des clients, des choses
 * que tu feras seul ». Un compte inscrit qui ne fait rien ne rapporte rien :
 * ce planificateur relance chaque compte au bon moment, dans sa langue,
 * une seule fois par étape, avec un lien de désabonnement.
 *
 * Étapes (cf. locales/<lang>/lifecycle.json) :
 *   welcome_d1            — 20 h après l'inscription : les 3 gestes qui comptent.
 *   profile_incomplete_d3 — prestataire à J+3 sans photo, présentation ou tarif.
 *   first_client_d7       — prestataire à J+7 sans réservation : amener son 1er client.
 *   owner_first_request_d5 — propriétaire à J+5 sans annonce ni réservation.
 *   inactive_d21          — compte de 3 semaines sans activité depuis 14 jours.
 *   review_after_booking  — 2 à 6 jours après une réservation terminée : avis + parrainage.
 *
 * Garde-fous : comptes test (+test / hopetsit@ / dadaciao84@) et staff exclus ;
 * opt-out via GET /lifecycle/unsubscribe (jeton HMAC) ; envoi uniquement
 * entre 9 h et 19 h (Paris) ; 1 e-mail max par compte et par passage ;
 * plafond global par passage (LIFECYCLE_MAX_PER_RUN, 15) ; désactivable par
 * LIFECYCLE_EMAILS=off. Tout est tracé dans la collection LifecycleEmail.
 */

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;
const SITE = 'https://www.hopetsit.com';
const API_BASE = process.env.PUBLIC_API_URL || 'https://hopetsit-backend.onrender.com/api/v1';
const DRY_RUN = String(process.env.LIFECYCLE_DRY_RUN || '') === '1';
const SUPPORTED = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const NAME_TO_LOCALE = {
  french: 'fr', francais: 'fr', 'français': 'fr', english: 'en', anglais: 'en',
  spanish: 'es', espanol: 'es', 'español': 'es', espagnol: 'es', german: 'de', deutsch: 'de',
  allemand: 'de', italian: 'it', italiano: 'it', italien: 'it', portuguese: 'pt',
  portugues: 'pt', 'português': 'pt', portugais: 'pt', korean: 'ko', coreen: 'ko',
  'coréen': 'ko', '한국어': 'ko', japanese: 'ja', japonais: 'ja', '日本語': 'ja',
  polish: 'pl', polonais: 'pl', polski: 'pl',
};
const EXCLUDED_EMAIL_RE = /\+test|hopetsit@gmail\.com|dadaciao84@|jandoe@email\.com/i;

let timer = null;
const catalogs = {};

const loadCatalog = (locale) => {
  if (catalogs[locale]) return catalogs[locale];
  try {
    const file = path.join(__dirname, '..', 'locales', locale, 'lifecycle.json');
    catalogs[locale] = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (e) {
    catalogs[locale] = null;
  }
  return catalogs[locale];
};

const resolveLocale = (user) => {
  const raw = String(user.appLocale || user.language || '').toLowerCase().trim();
  if (!raw) return 'fr';
  if (NAME_TO_LOCALE[raw]) return NAME_TO_LOCALE[raw];
  const short = raw.slice(0, 2);
  return SUPPORTED.includes(short) ? short : 'fr';
};

const modelFor = (role) => (role === 'owner' ? Owner : role === 'sitter' ? Sitter : Walker);

/** Jeton de désabonnement : HMAC(role:id) — pas de secret dans l'URL. */
const unsubscribeToken = (role, id) =>
  crypto.createHmac('sha256', process.env.JWT_SECRET || 'hopetsit')
    .update(`${role}:${id}`).digest('hex').slice(0, 32);

const unsubscribeUrl = (role, id) =>
  `${API_BASE}/lifecycle/unsubscribe?r=${role}&u=${id}&t=${unsubscribeToken(role, id)}`;

const firstName = (name) => {
  const w = String(name || '').trim().split(/\s+/)[0] || '';
  if (!w || w.includes('@')) return '';
  return w.charAt(0).toUpperCase() + w.slice(1).toLowerCase();
};

const wrapHtml = ({ title, paragraphs, cta, ctaUrl, footer, unsubscribe, unsubscribeUrl: uUrl }) => `
<div style="font-family:Arial,Helvetica,sans-serif;max-width:560px;margin:auto;padding:24px;background:#fff;border:1px solid #eee;border-radius:12px;color:#222">
  <h2 style="color:#C92A12;margin:0 0 14px;font-size:20px">${title}</h2>
  ${paragraphs.map((p) => `<p style="font-size:15px;line-height:1.5;margin:0 0 12px">${p}</p>`).join('')}
  ${cta ? `<p style="margin:20px 0"><a href="${ctaUrl}" style="display:inline-block;padding:12px 22px;background:#C92A12;color:#fff;text-decoration:none;border-radius:999px;font-weight:700">${cta}</a></p>` : ''}
  <p style="color:#999;font-size:12px;margin-top:24px">${footer} <a href="${uUrl}" style="color:#999">${unsubscribe}</a></p>
</div>`;

const providerProfileComplete = (u) =>
  Boolean(u.avatar && u.avatar.url) && String(u.bio || '').trim().length >= 20 &&
  ((u.hourlyRate || 0) > 0 || (u.dailyRate || 0) > 0 || (Array.isArray(u.walkRates) && u.walkRates.length > 0));

const bookingCountFor = (role, id) =>
  Booking.countDocuments(role === 'owner' ? { ownerId: id } : role === 'sitter' ? { sitterId: id } : { walkerId: id });

/** Envoie (ou marque) une étape pour un utilisateur. Retourne true si un e-mail est parti. */
const deliver = async ({ user, role, step, refId = '', vars = {} }) => {
  const id = user._id;
  let email = '';
  try { email = decrypt(user.email || '') || ''; } catch (_) { email = ''; }
  const locale = resolveLocale(user);
  const cat = loadCatalog(locale) || loadCatalog('en');
  const tpl = cat && cat[step];
  const eligible = email && email.includes('@') && !EXCLUDED_EMAIL_RE.test(email) && !user.isStaff && !user.marketingOptOut && tpl;
  if (DRY_RUN) {
    // Mode à blanc : on journalise sans rien écrire (ni e-mail ni étape consommée).
    logger.info(`[lifecycle][dry-run] ${eligible ? 'WOULD SEND' : 'skip'} step=${step} role=${role} user=${id} locale=${locale}${eligible ? ` subject="${render(tpl.subject, { name: firstName(user.name) || cat.friend })}"` : ''}`);
    return Boolean(eligible);
  }
  try {
    await LifecycleEmail.create({ userId: id, role, step, refId, locale: '', skipped: true });
  } catch (e) {
    return false; // déjà envoyé (index unique) → on ne renvoie jamais
  }
  if (!eligible) return false;
  const data = { name: firstName(user.name) || (cat.friend || ''), ...vars };
  const html = wrapHtml({
    title: render(tpl.title, data),
    paragraphs: (tpl.paragraphs || []).map((p) => render(p, data)),
    cta: tpl.cta ? render(tpl.cta, data) : '',
    ctaUrl: tpl.ctaUrl ? render(tpl.ctaUrl, data) : SITE,
    footer: cat.footer || '',
    unsubscribe: cat.unsubscribe || 'unsubscribe',
    unsubscribeUrl: unsubscribeUrl(role, id),
  });
  const text = [render(tpl.title, data), ...(tpl.paragraphs || []).map((p) => render(p, data).replace(/<[^>]+>/g, ''))].join('\n\n');
  await sendEmail(email, render(tpl.subject, data), text, html);
  await LifecycleEmail.updateOne({ userId: id, role, step, refId }, { $set: { skipped: false, locale, sentAt: new Date() } });
  logger.info(`[lifecycle] sent step=${step} role=${role} user=${id} locale=${locale}`);
  return true;
};

const baseFilter = {
  isStaff: { $ne: true },
  marketingOptOut: { $ne: true },
};

/** Un passage : parcourt les règles, envoie au plus `max` e-mails. */
async function runLifecycleOnce({ max = Number(process.env.LIFECYCLE_MAX_PER_RUN || 15) } = {}) {
  if (String(process.env.LIFECYCLE_EMAILS || 'on').toLowerCase() === 'off') return { sent: 0, reason: 'disabled' };
  if (mongoose.connection.readyState !== 1) return { sent: 0, reason: 'db' };
  const now = Date.now();
  let sent = 0;
  const budgetLeft = () => sent < max;
  const touched = new Set(); // 1 e-mail max par compte et par passage

  const consider = async (user, role, step, cond, refId = '', vars = {}) => {
    const key = `${role}:${user._id}`;
    if (!budgetLeft() || touched.has(key)) return;
    if (await LifecycleEmail.exists({ userId: user._id, role, step, refId })) return;
    if (!(await cond())) return;
    touched.add(key);
    if (await deliver({ user, role, step, refId, vars })) sent += 1;
  };

  for (const role of ['sitter', 'walker', 'owner']) {
    const Model = modelFor(role);
    const users = await Model.find({ ...baseFilter, createdAt: { $lte: new Date(now - 20 * HOUR_MS) } })
      .select('name email appLocale language isStaff marketingOptOut avatar bio hourlyRate dailyRate walkRates createdAt updatedAt referralCode')
      .sort({ createdAt: -1 }).limit(2000).lean();
    for (const u of users) {
      if (!budgetLeft()) break;
      const age = now - new Date(u.createdAt).getTime();
      const isProvider = role !== 'owner';
      // welcome_d1 — 20 h à 7 jours après l'inscription (au-delà : trop tard, on n'écrit plus « bienvenue »).
      if (age >= 20 * HOUR_MS && age < 7 * DAY_MS) {
        await consider(u, role, isProvider ? 'welcome_provider_d1' : 'welcome_owner_d1', async () => true);
      }
      if (isProvider && age >= 3 * DAY_MS && age < 30 * DAY_MS) {
        await consider(u, role, 'profile_incomplete_d3', async () => !providerProfileComplete(u));
      }
      if (isProvider && age >= 7 * DAY_MS && age < 60 * DAY_MS) {
        await consider(u, role, 'first_client_d7', async () => (await bookingCountFor(role, u._id)) === 0);
      }
      if (!isProvider && age >= 5 * DAY_MS && age < 60 * DAY_MS) {
        await consider(u, role, 'owner_first_request_d5', async () =>
          (await Post.countDocuments({ ownerId: u._id })) === 0 && (await bookingCountFor(role, u._id)) === 0);
      }
      if (age >= 21 * DAY_MS && now - new Date(u.updatedAt || u.createdAt).getTime() >= 14 * DAY_MS) {
        await consider(u, role, 'inactive_d21', async () => true);
      }
    }
  }

  // review_after_booking — 2 à 6 jours après une réservation terminée, côté propriétaire ET prestataire.
  if (budgetLeft()) {
    const done = await Booking.find({
      status: 'completed',
      updatedAt: { $lte: new Date(now - 2 * DAY_MS), $gte: new Date(now - 6 * DAY_MS) },
    }).select('ownerId sitterId walkerId').limit(200).lean();
    for (const b of done) {
      if (!budgetLeft()) break;
      const pairs = [['owner', b.ownerId], ['sitter', b.sitterId], ['walker', b.walkerId]].filter(([, id]) => id);
      for (const [role, id] of pairs) {
        const u = await modelFor(role).findById(id).select('name email appLocale language isStaff marketingOptOut referralCode').lean();
        if (!u) continue;
        await consider(u, role, 'review_after_booking', async () => true, String(b._id));
      }
    }
  }
  return { sent };
}

function withinSendingHours() {
  // 9 h → 19 h Paris (UTC+2 en été, +1 en hiver) ≈ 7 h → 17 h UTC.
  const h = new Date().getUTCHours();
  return h >= 7 && h < 17;
}

function startLifecycleEmailScheduler({ intervalMs = HOUR_MS, runImmediately = false } = {}) {
  if (timer) return;
  const tick = async () => {
    if (!withinSendingHours()) return;
    try {
      const r = await runLifecycleOnce();
      if (r.sent) logger.info(`[lifecycle] run done : ${r.sent} e-mail(s)`);
    } catch (e) {
      logger.error('[lifecycle] run failed', e);
    }
  };
  if (runImmediately) tick();
  timer = setInterval(tick, intervalMs);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info('[lifecycle] scheduler started (hourly, 9h-19h Paris)');
}

function stopLifecycleEmailScheduler() {
  if (timer) { clearInterval(timer); timer = null; }
}

module.exports = {
  startLifecycleEmailScheduler,
  stopLifecycleEmailScheduler,
  runLifecycleOnce,
  unsubscribeToken,
};
