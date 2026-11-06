/**
 * 0611 (LEO, ordre de Daniel « fais tout ce qui est possible ») — LIEN PAR E-MAIL, SANS MOT DE PASSE.
 *
 * Mesure de FLO (06/11) : 5 propriétaires sur 16 sont arrivés sur « mes candidats → payer »
 * (/application/<id>?choose=1) SANS le jeton `k=` de l'e-mail (adresse tapée, favori, retour en
 * direct) → le site leur demandait un MOT DE PASSE qu'ils n'ont pas (compte créé par la pub).
 *
 *   POST /auth/owner-link { email, next, lang }
 *     → 200 { ok: true } DANS TOUS LES CAS (compte connu, inconnu, adresse de test) : on ne révèle
 *       jamais qu'un compte existe. Si un compte PROPRIÉTAIRE actif porte cet e-mail (minuscules),
 *       un e-mail « Ton lien pour voir tes candidats » part, avec UN bouton = le même lien signé que
 *       nos e-mails candidats (`leadOwnerEmailLink` → `k=` sur /application/<id>, ou /posts/confirmer
 *       pour un contact de la pub).
 *     → 400 EMAIL_INVALID (forme), 403 SCRIPT (pas un vrai navigateur ni l'app), 429 TOO_MANY
 *       (3 envois / 15 min par e-mail ET par IP).
 *
 * `next` : accepté seulement s'il commence par /application/, /posts, /chat, /bookings ou /dashboard,
 * sinon /posts. Un `k=` ou `l=` périmé dans l'adresse est retiré (sinon le lien ne serait pas re-signé).
 * Si la cible n'est pas une candidature de ce propriétaire (ou vise /posts), on vise sa candidature
 * en attente la plus récente : c'est elle qui ouvre la session sans mot de passe.
 * Rien n'est stocké en base. Aucune adresse e-mail dans les journaux.
 */
const express = require('express');
const logger = require('../utils/logger');

const router = express.Router();

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const OID = /^[a-f0-9]{24}$/i;
const NEXT_PREFIXES = ['/application/', '/posts', '/chat', '/bookings', '/dashboard'];
const DEFAULT_NEXT = '/posts';

// 3 envois / 15 min, par e-mail et par IP (règle du 06/11).
const MAX_PER_WINDOW = 3;
const WINDOW_MS = 15 * 60 * 1000;
const hits = new Map(); // clé → [horodatages]
function allowed(key, now = Date.now()) {
  const list = (hits.get(key) || []).filter((t) => now - t < WINDOW_MS);
  if (list.length >= MAX_PER_WINDOW) { hits.set(key, list); return false; }
  list.push(now);
  hits.set(key, list);
  if (hits.size > 5000) for (const k of hits.keys()) { if (hits.size <= 4000) break; hits.delete(k); }
  return true;
}
function resetLimiter() { hits.clear(); }

// Adresses de test : jamais d'e-mail (même liste que la pub). Repli local si le module ne charge pas.
function testEmailRe() {
  try { return require('./adLeads2210').TEST_LEAD_RE; } catch (_) { return /\+test|^hopetsit@|^dadaciao84@|^probe-|@invalid\.example$|staff@hopetsit/i; }
}

/** Chemin interne propre : préfixe autorisé, sans jeton périmé, sans ancre, longueur bornée. */
function cleanNext(raw) {
  const s = String(raw || '').trim();
  if (!s || s.length > 400 || !s.startsWith('/') || s.startsWith('//') || /[\s<>"'\\]/.test(s)) return DEFAULT_NEXT;
  if (!NEXT_PREFIXES.some((p) => s === p.replace(/\/$/, '') || s.startsWith(p))) return DEFAULT_NEXT;
  try {
    const u = new URL(s, 'http://x');
    u.searchParams.delete('k');
    u.searchParams.delete('l');
    u.searchParams.delete('e');
    const q = u.searchParams.toString();
    return `${u.pathname}${q ? `?${q}` : ''}`;
  } catch (_) { return DEFAULT_NEXT; }
}

/** Cible finale pour CE propriétaire : sa candidature si elle est à lui, sinon la plus récente en attente. */
async function targetFor(ownerId, next) {
  const Application = require('../models/Application');
  const m = next.match(/^\/application\/([a-f0-9]{24})(\?.*)?$/i);
  if (m) {
    const own = await Application.findOne({ _id: m[1], ownerId }).select('_id').lean();
    if (own) return next;
  }
  if (m || next.startsWith('/posts')) {
    const latest = await Application.findOne({ ownerId, status: 'pending', archivedAt: null }).sort({ createdAt: -1 }).select('_id').lean();
    if (latest) return `/application/${latest._id}${m && m[2] ? m[2] : ''}`;
    return m ? DEFAULT_NEXT : next;
  }
  return next;
}

const esc = (x) => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const firstNameOf = (name) => String(name || '').trim().split(/\s+/)[0] || '';

const T = {
  fr: {
    subject: 'Ton lien pour voir tes candidats',
    subjectOther: 'Ton lien HoPetSit',
    hi: (n) => (n ? `Bonjour ${n},` : 'Bonjour,'),
    body: 'Un seul geste : appuie sur le bouton, tu arrives directement sur tes candidats. Pas de mot de passe, rien à payer pour regarder.',
    bodyOther: 'Un seul geste : appuie sur le bouton, tu arrives directement dans ton espace HoPetSit. Pas de mot de passe à retenir.',
    cta: 'Voir mes candidats',
    ctaOther: 'Ouvrir HoPetSit',
    foot: 'Ce lien est pour toi seul(e) : ne le transfère pas. Si tu n\'as rien demandé, ignore cet e-mail.',
  },
  en: {
    subject: 'Your link to see your candidates',
    subjectOther: 'Your HoPetSit link',
    hi: (n) => (n ? `Hi ${n},` : 'Hi,'),
    body: 'One tap: press the button and you land right on your candidates. No password, nothing to pay to have a look.',
    bodyOther: 'One tap: press the button and you land right in your HoPetSit space. No password to remember.',
    cta: 'See my candidates',
    ctaOther: 'Open HoPetSit',
    foot: 'This link is for you only: please do not forward it. If you did not ask for it, just ignore this e-mail.',
  },
};
const langOf = (owner, hint) => {
  const a = String((owner && owner.appLocale) || '').toLowerCase();
  if (a) return a.startsWith('fr') ? 'fr' : 'en';
  return String(hint || '').toLowerCase().startsWith('fr') ? 'fr' : 'en';
};

function buildMail({ lang, name, link, toCandidates }) {
  const t = T[lang] || T.en;
  const subject = toCandidates ? t.subject : t.subjectOther;
  const body = toCandidates ? t.body : t.bodyOther;
  const cta = toCandidates ? t.cta : t.ctaOther;
  const text = `${t.hi(name)}\n\n${body}\n\n${cta} : ${link}\n\n${t.foot}`;
  const inner = `<p style="margin:0 0 14px">${esc(t.hi(name))}</p>`
    + `<p style="margin:0 0 14px">${esc(body)}</p>`
    + `<p><a href="${esc(link)}" style="display:inline-block;background:#C92A12;color:#fff;text-decoration:none;font-weight:800;font-size:17px;padding:16px 30px;border-radius:999px">${esc(cta)}</a></p>`
    + `<p style="margin:0 0 14px;color:#6E4F48;font-size:14px">${esc(t.foot)}</p>`;
  let html = '';
  try {
    const { buildNotificationEmailHtml } = require('../services/emailService');
    html = buildNotificationEmailHtml(inner, { locale: lang, link, preheader: body });
  } catch (_) { html = `<!doctype html><html lang="${lang}"><body>${inner}</body></html>`; }
  return { subject, text, html };
}

/** Travail après la réponse : compte connu → e-mail. Jamais d'exception vers l'appelant. */
async function sendLink({ email, next, lang }) {
  const Owner = require('../models/Owner');
  const owner = await Owner.findOne({ email }).select('_id name appLocale status').lean();
  if (!owner) { logger.info('[owner-link] adresse sans compte propriétaire : réponse neutre, aucun e-mail'); return { sent: false, reason: 'unknown' }; }
  if (owner.status && owner.status !== 'active') { logger.info({ ownerId: String(owner._id) }, '[owner-link] compte non actif : aucun e-mail'); return { sent: false, reason: 'inactive' }; }
  const ownerId = String(owner._id);
  const target = await targetFor(ownerId, next);
  const { leadOwnerEmailLink } = require('../services/notificationSender');
  const { BASE_URL } = require('../utils/emailLinkBuilder');
  const link = await leadOwnerEmailLink('owner', ownerId, `${BASE_URL}${target}`, BASE_URL);
  const mail = buildMail({ lang: langOf(owner, lang), name: firstNameOf(owner.name), link, toCandidates: /^\/application\//.test(target) });
  const { sendEmail } = require('../services/emailService');
  await sendEmail(email, mail.subject, mail.text, mail.html);
  const signed = /[?&]k=/.test(link) ? 'k' : (link.indexOf('/posts/confirmer') >= 0 ? 'lead' : 'nu');
  logger.info({ ownerId, target: target.split('?')[0], signed }, '[owner-link] e-mail envoyé');
  return { sent: true, ownerId, link, target };
}

router.post('/', express.json({ limit: '10kb' }), async (req, res) => {
  try {
    const b = req.body || {};
    const email = String(b.email || '').trim().toLowerCase();
    if (!EMAIL_RE.test(email) || email.length > 120) return res.status(400).json({ error: 'EMAIL_INVALID', code: 'EMAIL_INVALID' });
    const { classifyOrigin, isRealOrigin } = require('../utils/ownerReturn2610');
    if (!isRealOrigin(classifyOrigin(req))) return res.status(403).json({ error: 'SCRIPT', code: 'SCRIPT' });
    const now = Date.now();
    const ipOk = allowed(`ip:${req.ip || 'unknown'}`, now);
    const mailOk = allowed(`em:${email}`, now);
    if (!ipOk || !mailOk) return res.status(429).json({ error: 'TOO_MANY', code: 'TOO_MANY' });
    const next = cleanNext(b.next);
    // Même réponse pour tout le monde, tout de suite ; le travail se fait ensuite.
    res.json({ ok: true });
    if (testEmailRe().test(email)) { logger.info('[owner-link] adresse de test : aucun e-mail'); return; }
    const p = sendLink({ email, next, lang: b.lang }).catch((e) => logger.warn(`[owner-link] envoi impossible : ${e && e.message ? e.message : e}`));
    if (router.deps && router.deps.pending) router.deps.pending.push(p);
  } catch (e) {
    logger.error({ err: e }, '[owner-link] échec');
    if (!res.headersSent) res.status(500).json({ error: 'Failed. Please try again.' });
  }
});

router.deps = { pending: null }; // tests : { pending: [] } pour attendre le travail d'après-réponse
module.exports = router;
module.exports.cleanNext = cleanNext;
module.exports.targetFor = targetFor;
module.exports.buildMail = buildMail;
module.exports.resetLimiter = resetLimiter;
