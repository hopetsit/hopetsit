/**
 * 08/11/2026 (NEO, ordre de Daniel 16 h 45 transmis par BOB) — PAGE DE DEMANDE « publier ET vérifier
 * son e-mail d'un coup » (site /demande · /request), sans aller cliquer dans sa boîte mail plus tard.
 *
 * Mesure (BILAN_2026-11-08) : 35 contacts pub en 7 j → 5 demandes publiées, 30 n'ont jamais cliqué dans
 * l'e-mail « confirme ». Règle de Daniel du 31/10 MAINTENUE : rien n'est publié sans e-mail vérifié.
 * Ici la preuve de la boîte est un CODE à 6 chiffres reçu par e-mail et tapé sur la page même.
 *
 *   POST /ad-leads/site { …, codeFlow: true }  (adLeadsSite3110) → compte propriétaire créé ou retrouvé,
 *        brouillon `pendingConfirm`, UN e-mail « ton code » (code + le même bouton « Confirmer et publier »
 *        que l'e-mail actuel, en filet si la personne ferme la page) ; rien publié, aucun gardien prévenu.
 *   POST /ad-leads/code/send  { id }        → renvoie un code (1 / 60 s et 5 / 24 h par contact).
 *   POST /ad-leads/code/check { id, code }  → code juste : e-mail marqué vérifié (3 profils, preuve
 *        `lead_code`), demande PUBLIÉE par le même chemin que le clic de l'e-mail (publishLead →
 *        createPost → gardiens prévenus), session ouverte (jeton) + lien « voir mes candidats » signé
 *        (leadOwnerEmailLink, le même que dans nos e-mails). 6 essais / h par contact, puis 429.
 *
 * Le code est celui de l'app (VerificationCode, purpose email_verification, haché SHA-256, 24 h) : le même
 * code tapé dans l'app (POST /auth/verify) marche aussi. Limiteur par IP : sensitiveLimiter (monté sur
 * /ad-leads). Jamais aux adresses de test (TEST_LEAD_RE). Aucune adresse e-mail dans les journaux.
 */
const express = require('express');
const dayjs = require('dayjs');
const logger = require('../utils/logger');
const AdLead = require('../models/AdLead2210');
const VerificationCode = require('../models/VerificationCode');
const { generateVerificationCode, hashCode, compareCode } = require('../utils/code');

const router = express.Router();
const ID_RE = /^[a-f0-9]{32}$/;
const CODE_RE = /^\d{4,8}$/;
const RESEND_MS = 60 * 1000;
const MAX_SENDS_24H = 5;
const MAX_TRIES_1H = 6;
const DAY_MS = 24 * 3600 * 1000;
const HOUR_MS = 3600 * 1000;

// Compteurs en mémoire par contact (même modèle que les limiteurs voisins : ownerMagicLink0611, adLeadsSite3110).
const sends = new Map(); // id → [horodatages des envois]
const tries = new Map(); // id → [horodatages des essais ratés]
function countIn(map, key, windowMs, now) {
  const list = (map.get(key) || []).filter((t) => now - t < windowMs);
  map.set(key, list);
  if (map.size > 5000) for (const k of map.keys()) { if (map.size <= 4000) break; map.delete(k); }
  return list;
}
function resetForTest() { sends.clear(); tries.clear(); }

function testRe() {
  try { return require('./adLeads2210').TEST_LEAD_RE; } catch (_) { return /\+test|^hopetsit@|^dadaciao84@|^probe-|@invalid\.example$|staff@hopetsit/i; }
}
const esc = (x) => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const T = {
  fr: {
    subject: (p, code) => `${code} — ton code HoPetSit${p ? `, ${p}` : ''}`,
    hi: (p) => (p ? `Bonjour ${p},` : 'Bonjour,'),
    intro: 'Ta demande de garde est prête. Pour la publier, reviens sur la page hopetsit.com que tu viens de quitter et tape ce code :',
    valid: 'Le code est valable 24 h.',
    or: 'Tu as fermé la page ? Un seul clic suffit aussi :',
    cta: 'Confirmer et publier',
    then: 'Ensuite, les gardiens près de chez toi sont prévenus, ils te proposent leur prix, et tu choisis. Rien à payer pour publier.',
    foot: 'Si tu n\'as rien demandé, ignore cet e-mail : rien ne sera publié.',
  },
  en: {
    subject: (p, code) => `${code} — your HoPetSit code${p ? `, ${p}` : ''}`,
    hi: (p) => (p ? `Hi ${p},` : 'Hi,'),
    intro: 'Your pet-sitting request is ready. To publish it, go back to the hopetsit.com page you just left and type this code:',
    valid: 'The code is valid for 24 hours.',
    or: 'Closed the page? One click works too:',
    cta: 'Confirm and publish',
    then: 'Then sitters near you are notified, they send you their price, and you choose. Nothing to pay to publish.',
    foot: 'If you did not ask for this, ignore this email: nothing will be published.',
  },
};

function buildCodeMail(lead, code, link) {
  const t = lead.lang === 'en' ? T.en : T.fr;
  const p = String(lead.firstName || '').trim().split(/\s+/)[0] || '';
  const subject = t.subject(p, code);
  const text = `${t.hi(p)}\n\n${t.intro}\n\n${code}\n\n${t.valid}\n\n${t.or}\n${t.cta} : ${link}\n\n${t.then}\n\n${t.foot}`;
  const inner = `<p style="margin:0 0 14px">${esc(t.hi(p))}</p>`
    + `<p style="margin:0 0 14px">${esc(t.intro)}</p>`
    + `<p style="margin:18px 0;text-align:center;font-size:40px;font-weight:800;letter-spacing:10px;color:#C92A12">${esc(code)}</p>`
    + `<p style="margin:0 0 18px;color:#6E4F48;font-size:14px;text-align:center">${esc(t.valid)}</p>`
    + `<p style="margin:0 0 8px">${esc(t.or)}</p>`
    + `<p style="text-align:center;margin:10px 0 22px"><a href="${esc(link)}" style="display:inline-block;background:#C92A12;color:#fff;text-decoration:none;font-weight:800;font-size:17px;padding:16px 30px;border-radius:999px">${esc(t.cta)}</a></p>`
    + `<p style="margin:0 0 14px">${esc(t.then)}</p>`
    + `<p style="margin:0;color:#6E4F48;font-size:14px">${esc(t.foot)}</p>`;
  let html = '';
  try {
    const { buildNotificationEmailHtml } = require('../services/emailService');
    html = typeof buildNotificationEmailHtml === 'function' ? buildNotificationEmailHtml(inner, { locale: lead.lang === 'en' ? 'en' : 'fr', link, preheader: t.intro }) : '';
  } catch (_) { html = ''; }
  if (!html) html = `<!doctype html><html lang="${lead.lang === 'en' ? 'en' : 'fr'}"><body style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:560px;margin:0 auto;color:#231715;font-size:16px;line-height:1.55">${inner}</body></html>`;
  return { subject, text, html };
}

/** Lien « Confirmer et publier » de l'e-mail actuel (même page /posts/confirmer, même suivi utm). */
function confirmLink(lead) {
  const { BASE_URL } = require('../utils/emailLinkBuilder');
  const campaign = lead.campaign || (lead.country === 'US' ? 'nyc_owners' : 'paris_owners');
  return `${BASE_URL}/posts/confirmer?l=${lead._id}&utm_source=site&utm_medium=email&utm_campaign=${encodeURIComponent(campaign)}&utm_content=code`;
}

/**
 * Génère un code, l'enregistre (haché, 24 h, même enregistrement que l'app) et l'envoie. Pose
 * `confirmEmailAt` (dédoublonnage de /site et rappel +3 h = le filet existant) et `pendingConfirm` tant que
 * rien n'est publié. Retourne true si l'e-mail est parti ; false pour une adresse de test.
 */
async function sendCodeEmail(lead) {
  if (testRe().test(String(lead.email || ''))) return false;
  const email = String(lead.email).toLowerCase();
  const code = generateVerificationCode();
  await VerificationCode.findOneAndUpdate(
    { email, purpose: 'email_verification' },
    { email, code: hashCode(code), expiresAt: dayjs().add(24, 'hour').toDate(), purpose: 'email_verification', verified: false },
    { upsert: true, new: true, setDefaultsOnInsert: true },
  );
  const { sendEmail } = require('../services/emailService');
  const mail = buildCodeMail(lead, code, confirmLink(lead));
  await sendEmail(email, mail.subject, mail.text, mail.html);
  if (!lead.confirmEmailAt) lead.confirmEmailAt = new Date();
  if (!lead.postId) lead.pendingConfirm = true;
  await lead.save();
  return true;
}

/** Depuis POST /ad-leads/site { codeFlow: true } : compte (créé NON vérifié ou retrouvé), brouillon, e-mail « ton code ». */
async function startCodeFlow(lead) {
  const { ensureLeadOwner } = require('./adLeads2210');
  const owner = await ensureLeadOwner(lead);
  lead.ownerId = owner._id;
  if (!lead.postId) lead.pendingConfirm = true;
  await lead.save();
  sends.set(String(lead._id), [Date.now()]);
  let emailSent = false;
  try { emailSent = await sendCodeEmail(lead); } catch (e) { logger.warn(`[demandeCode0811] e-mail « code » non envoyé : ${e && e.message}`); }
  return { ownerId: String(owner._id), emailSent };
}

router.post('/send', async (req, res) => {
  try {
    const id = String((req.body && req.body.id) || '');
    if (!ID_RE.test(id)) return res.status(404).json({ error: 'not_found', code: 'NOT_FOUND' });
    const lead = await AdLead.findById(id);
    if (!lead) return res.status(404).json({ error: 'not_found', code: 'NOT_FOUND' });
    if (testRe().test(String(lead.email || ''))) return res.status(403).json({ error: 'TEST_ACCOUNT', code: 'TEST_ACCOUNT' });
    const now = Date.now();
    const list = countIn(sends, id, DAY_MS, now);
    if (list.length >= MAX_SENDS_24H) return res.status(429).json({ error: 'TOO_MANY', code: 'TOO_MANY' });
    const last = list.length ? list[list.length - 1] : 0;
    // Garantie serveur du compte à rebours de 60 s (même règle que /auth/resend-code), aussi après un redémarrage.
    const rec = await VerificationCode.findOne({ email: String(lead.email).toLowerCase(), purpose: 'email_verification' }).select('updatedAt createdAt').lean();
    const recAt = rec ? new Date(rec.updatedAt || rec.createdAt).getTime() : 0;
    const since = now - Math.max(last, recAt);
    if (Math.max(last, recAt) && since < RESEND_MS) {
      return res.status(429).json({ error: 'RESEND_TOO_SOON', code: 'RESEND_TOO_SOON', retryAfter: Math.ceil((RESEND_MS - since) / 1000) });
    }
    if (!lead.ownerId) {
      const { ensureLeadOwner } = require('./adLeads2210');
      const owner = await ensureLeadOwner(lead);
      lead.ownerId = owner._id;
    }
    list.push(now);
    sends.set(id, list);
    const sent = await sendCodeEmail(lead);
    return res.json({ ok: true, sent, retryAfter: RESEND_MS / 1000 });
  } catch (e) {
    logger.error('[demandeCode0811] send failed', e);
    return res.status(500).json({ error: 'Unable to send the code.' });
  }
});

router.post('/check', async (req, res) => {
  try {
    const b = req.body || {};
    const id = String(b.id || '');
    const code = String(b.code || '').replace(/\s+/g, '');
    if (!ID_RE.test(id)) return res.status(404).json({ error: 'not_found', code: 'NOT_FOUND' });
    if (!CODE_RE.test(code)) return res.status(400).json({ error: 'CODE_INVALID', code: 'CODE_INVALID' });
    const lead = await AdLead.findById(id);
    if (!lead) return res.status(404).json({ error: 'not_found', code: 'NOT_FOUND' });
    const now = Date.now();
    const failed = countIn(tries, id, HOUR_MS, now);
    if (failed.length >= MAX_TRIES_1H) return res.status(429).json({ error: 'TOO_MANY_TRIES', code: 'TOO_MANY_TRIES' });
    const email = String(lead.email).toLowerCase();
    const rec = await VerificationCode.findOne({ email, purpose: 'email_verification' });
    if (!rec) return res.status(410).json({ error: 'CODE_EXPIRED', code: 'CODE_EXPIRED' });
    if (dayjs(rec.expiresAt).isBefore(dayjs())) {
      await VerificationCode.deleteOne({ _id: rec._id });
      return res.status(410).json({ error: 'CODE_EXPIRED', code: 'CODE_EXPIRED' });
    }
    if (!compareCode(code, rec.code)) {
      failed.push(now);
      tries.set(id, failed);
      return res.status(400).json({ error: 'CODE_INVALID', code: 'CODE_INVALID', left: Math.max(0, MAX_TRIES_1H - failed.length) });
    }
    await VerificationCode.deleteOne({ _id: rec._id });
    tries.delete(id);

    // Le code tapé PROUVE la boîte (comme le clic du lien) : e-mail vérifié sur les 3 profils, puis publication par le
    // même chemin que le clic de l'e-mail (publishLead → createPost → gardiens prévenus ; idempotent).
    const { publishLead } = require('./adLeads2210');
    const hadPost = !!lead.postId;
    const lieu = b.lieu === 'at_sitter' ? 'at_sitter' : 'at_owner';
    const r = await publishLead(lead, lieu);
    if (r.status !== 200) return res.status(r.status).json(r.body);
    const { markVerifiedAcrossRoles, signAuthToken } = require('../controllers/authController');
    await markVerifiedAcrossRoles(email, 'lead_code');
    if (!lead.clickedAt) await AdLead.updateOne({ _id: lead._id, clickedAt: null }, { $set: { clickedAt: new Date() } });
    if (!hadPost && r.postId) { try { void require('../services/metaCapi0611').leadPublished(lead, req); } catch (_) { /* jamais bloquant */ } }

    // Lien « voir mes candidats » : le même que dans nos e-mails (signé par leadOwnerEmailLink ; pour un contact de
    // la pub : /posts/confirmer?l=…&next=/posts, qui ouvre la session sans mot de passe).
    let link = '';
    try {
      const { leadOwnerEmailLink } = require('../services/notificationSender');
      const { BASE_URL } = require('../utils/emailLinkBuilder');
      link = await leadOwnerEmailLink('owner', String(r.owner._id), `${BASE_URL}/posts`, BASE_URL);
    } catch (_) { link = ''; }
    logger.info({ leadId: String(lead._id), published: !hadPost && !!r.postId }, '[demandeCode0811] code OK');
    return res.json({
      token: signAuthToken({ id: r.owner._id.toString(), role: 'owner' }),
      user: { id: r.owner._id.toString(), name: r.owner.name, email: r.owner.email, role: 'owner' },
      postId: r.postId,
      published: !hadPost && !!r.postId,
      ...(r.notified === undefined || r.notified === null ? {} : { notified: r.notified }),
      ...(link ? { link } : {}),
    });
  } catch (e) {
    logger.error('[demandeCode0811] check failed', e);
    return res.status(500).json({ error: 'Unable to check the code.' });
  }
});

module.exports = router;
module.exports.startCodeFlow = startCodeFlow;
module.exports.sendCodeEmail = sendCodeEmail;
module.exports.buildCodeMail = buildCodeMail;
module.exports._resetForTest = resetForTest;
module.exports._backdateForTest = (id, ms) => { sends.set(String(id), (sends.get(String(id)) || []).map((t) => t - ms)); }; // tests : « le délai de 60 s est passé »
