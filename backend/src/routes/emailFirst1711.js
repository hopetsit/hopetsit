/**
 * 17/11/2026 (NEO, ordre de Daniel transmis par BOB) — INSCRIPTION « E-MAIL D'ABORD ».
 *
 * Mesure de BOB (45 j) : 313 inscrits e-mail + mot de passe → 97 vérifiés (~30 %) ; Google / Apple = 100 %.
 * Le compte était créé AVANT le code : ceux qui n'allaient pas chercher le code restaient en base « non vérifiés ».
 * Désormais (site, puis app au prochain build) : AUCUN compte tant que le code n'est pas bon.
 *
 *   POST /auth/email-first/send  { email, lang, allowExisting? }
 *        → { suggestion }  domaine mal tapé (gmail.con…) : rien n'est envoyé, le site propose la correction ;
 *        → { exists: true } un compte VÉRIFIÉ existe déjà : rien n'est envoyé, le site propose la connexion
 *                           (sauf `allowExisting: true` — page de demande : la personne prouve sa boîte et
 *                           publie sur son compte existant) ;
 *        → { ok: true, sent, retryAfter: 60 } code à 6 chiffres envoyé (haché en base, valable 60 min).
 *        Limites par adresse : 1 envoi / 60 s (429 RESEND_TOO_SOON), 5 / 24 h (429 TOO_MANY).
 *        Adresses de test (+test, staff…) : 403 TEST_ACCOUNT, aucun envoi.
 *   POST /auth/email-first/check { email, code }
 *        → { emailProof } jeton signé 60 min (utils/emailProof1711), à présenter à /auth/signup ou /ad-leads/site.
 *        Faux code : 400 CODE_INVALID { left } ; 5 faux → 429 TOO_MANY_TRIES pendant 1 h ; code consommé au succès.
 *
 * Rien n'est écrit dans Owner / Sitter / Walker / AdLead ici. Aucune adresse e-mail dans les journaux.
 * Limiteur par IP : celui de /auth (authLimiter, 12 / min).
 * Coupe-circuit : EMAIL_FIRST_1711=off → 404 sur les deux routes (site et app reprennent l'ancien parcours).
 */
const express = require('express');
const dayjs = require('dayjs');
const logger = require('../utils/logger');
const VerificationCode = require('../models/VerificationCode');
const { generateVerificationCode, hashCode, compareCode } = require('../utils/code');
const { signEmailProof, typoSuggestion, canonicalEmail, EMAIL_RE } = require('../utils/emailProof1711');

const router = express.Router();
const PURPOSE = 'email_first';
const CODE_RE = /^\d{6}$/;
const RESEND_MS = 60 * 1000;
const MAX_SENDS_24H = 5;
const MAX_TRIES = 5;
const DAY_MS = 24 * 3600 * 1000;
const HOUR_MS = 3600 * 1000;
const CODE_TTL_MIN = 60;
const LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'pl', 'ko', 'ja'];
const TEST_RE = /\+test|^hopetsit@|^dadaciao84@|^probe-|@invalid\.example$|staff@hopetsit/i;

// Compteurs en mémoire par boîte (même modèle que demandeCode0811 / ownerMagicLink0611).
const sends = new Map(); // boîte → [horodatages des envois]
const tries = new Map(); // boîte → [horodatages des essais ratés]
function countIn(map, key, windowMs, now) {
  const list = (map.get(key) || []).filter((t) => now - t < windowMs);
  map.set(key, list);
  if (map.size > 5000) for (const k of map.keys()) { if (map.size <= 4000) break; map.delete(k); }
  return list;
}

const T = {
  fr: { subject: (c) => `${c} — ton code HoPetSit`, hi: 'Bonjour,', intro: 'Voici ton code pour continuer sur hopetsit.com :', valid: 'Tape-le sur la page que tu viens de quitter. Il est valable 60 minutes.', foot: 'Si tu n\'as rien demandé, ignore cet e-mail : aucun compte n\'est créé.', team: 'L\'équipe HoPetSit' },
  en: { subject: (c) => `${c} — your HoPetSit code`, hi: 'Hi,', intro: 'Here is your code to continue on hopetsit.com:', valid: 'Type it on the page you just left. It is valid for 60 minutes.', foot: 'If you did not ask for this, ignore this email: no account is created.', team: 'The HoPetSit team' },
  es: { subject: (c) => `${c} — tu código HoPetSit`, hi: 'Hola:', intro: 'Aquí tienes tu código para continuar en hopetsit.com:', valid: 'Escríbelo en la página que acabas de dejar. Es válido durante 60 minutos.', foot: 'Si no has pedido nada, ignora este correo: no se crea ninguna cuenta.', team: 'El equipo de HoPetSit' },
  de: { subject: (c) => `${c} — dein HoPetSit-Code`, hi: 'Hallo,', intro: 'Hier ist dein Code, um auf hopetsit.com fortzufahren:', valid: 'Gib ihn auf der Seite ein, die du gerade verlassen hast. Er ist 60 Minuten gültig.', foot: 'Wenn du nichts angefordert hast, ignoriere diese E-Mail: Es wird kein Konto erstellt.', team: 'Dein HoPetSit-Team' },
  it: { subject: (c) => `${c} — il tuo codice HoPetSit`, hi: 'Ciao,', intro: 'Ecco il tuo codice per continuare su hopetsit.com:', valid: 'Inseriscilo nella pagina che hai appena lasciato. È valido per 60 minuti.', foot: 'Se non hai richiesto nulla, ignora questa e-mail: non viene creato alcun account.', team: 'Il team HoPetSit' },
  pt: { subject: (c) => `${c} — o teu código HoPetSit`, hi: 'Olá,', intro: 'Aqui está o teu código para continuar em hopetsit.com:', valid: 'Escreve-o na página que acabaste de deixar. É válido durante 60 minutos.', foot: 'Se não pediste nada, ignora este e-mail: nenhuma conta é criada.', team: 'A equipa HoPetSit' },
  pl: { subject: (c) => `${c} — Twój kod HoPetSit`, hi: 'Cześć,', intro: 'Oto Twój kod, aby kontynuować na hopetsit.com:', valid: 'Wpisz go na stronie, którą właśnie opuściłeś(-aś). Jest ważny przez 60 minut.', foot: 'Jeśli to nie Ty, zignoruj tę wiadomość: żadne konto nie zostanie utworzone.', team: 'Zespół HoPetSit' },
  ko: { subject: (c) => `${c} — HoPetSit 인증 코드`, hi: '안녕하세요,', intro: 'hopetsit.com에서 계속하려면 아래 코드를 입력하세요:', valid: '방금 보던 페이지에 입력해 주세요. 60분 동안 유효합니다.', foot: '요청하지 않으셨다면 이 메일을 무시하세요. 계정은 만들어지지 않습니다.', team: 'HoPetSit 팀' },
  ja: { subject: (c) => `${c} — HoPetSit 認証コード`, hi: 'こんにちは。', intro: 'hopetsit.com で続けるためのコードはこちらです：', valid: '先ほどのページに入力してください。60分間有効です。', foot: '心当たりがない場合はこのメールを無視してください。アカウントは作成されません。', team: 'HoPetSitチーム' },
};
// COUPE-CIRCUIT sans redéploiement du site ni rebuild de l'app : EMAIL_FIRST_1711=off (Render) → les deux routes
// répondent 404, et le site comme l'app retombent d'eux-mêmes sur le parcours d'avant (prévu pour le déploiement).
router.use((req, res, next) => (String(process.env.EMAIL_FIRST_1711 || '').toLowerCase() === 'off'
  ? res.status(404).json({ error: 'not_found', code: 'EMAIL_FIRST_OFF' }) : next()));

const esc = (x) => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/** E-mail « ton code » : le code seul, AUCUN lien de validation (il n'y a pas encore de compte). */
function buildMail(code, lang) {
  const t = T[lang] || T.en;
  const subject = t.subject(code);
  const text = `${t.hi}\n\n${t.intro}\n\n${code}\n\n${t.valid}\n\n${t.foot}\n\n— ${t.team}`;
  const html = `<div style="font-family:-apple-system,Arial,Helvetica,sans-serif;max-width:560px;margin:auto;padding:28px;background:#fff;border:1px solid #eee;border-radius:14px;color:#1D1D1F">
  <p style="font-size:20px;font-weight:700;margin:0 0 8px">🐾 HoPetSit</p>
  <p>${esc(t.hi)}</p>
  <p>${esc(t.intro)}</p>
  <div style="font-size:32px;font-weight:800;letter-spacing:8px;background:#F5F5F7;padding:16px;text-align:center;border-radius:12px;margin:18px 0;color:#C92A12">${esc(code)}</div>
  <p style="color:#6E6E73;font-size:14px">${esc(t.valid)}</p>
  <p style="color:#6E6E73;font-size:12px">${esc(t.foot)}</p>
  <p style="margin-top:24px">— ${esc(t.team)}</p>
</div>`;
  return { subject, text, html };
}

async function verifiedAccountExists(email) {
  const Owner = require('../models/Owner');
  const Sitter = require('../models/Sitter');
  const Walker = require('../models/Walker');
  const found = await Promise.all([Owner, Sitter, Walker].map((M) => M.exists({ email, verified: true })));
  return found.some(Boolean);
}

router.post('/send', async (req, res) => {
  try {
    const b = req.body || {};
    const email = String(b.email || '').trim().toLowerCase();
    if (!EMAIL_RE.test(email) || email.length > 120) return res.status(400).json({ error: 'EMAIL_INVALID', code: 'EMAIL_INVALID' });
    if (TEST_RE.test(email)) return res.status(403).json({ error: 'TEST_ACCOUNT', code: 'TEST_ACCOUNT' });
    const suggestion = typoSuggestion(email);
    if (suggestion) return res.status(200).json({ suggestion });
    const exists = await verifiedAccountExists(email);
    const allowExisting = b.allowExisting === true || b.allowExisting === 'true';
    if (exists && !allowExisting) return res.status(200).json({ exists: true });

    const key = canonicalEmail(email);
    const now = Date.now();
    const list = countIn(sends, key, DAY_MS, now);
    if (list.length >= MAX_SENDS_24H) return res.status(429).json({ error: 'TOO_MANY', code: 'TOO_MANY' });
    // Garantie du compte à rebours de 60 s aussi après un redémarrage du serveur (date du code en base).
    const rec = await VerificationCode.findOne({ email, purpose: PURPOSE }).select('updatedAt createdAt').lean();
    const recAt = rec ? new Date(rec.updatedAt || rec.createdAt).getTime() : 0;
    const last = Math.max(list.length ? list[list.length - 1] : 0, recAt);
    if (last && now - last < RESEND_MS) {
      return res.status(429).json({ error: 'RESEND_TOO_SOON', code: 'RESEND_TOO_SOON', retryAfter: Math.ceil((RESEND_MS - (now - last)) / 1000) });
    }
    list.push(now);
    sends.set(key, list);

    const code = generateVerificationCode();
    await VerificationCode.findOneAndUpdate(
      { email, purpose: PURPOSE },
      { email, code: hashCode(code), expiresAt: dayjs().add(CODE_TTL_MIN, 'minute').toDate(), purpose: PURPOSE, verified: false },
      { upsert: true, new: true, setDefaultsOnInsert: true },
    );
    const raw = String(b.lang || '').toLowerCase().slice(0, 2);
    const lang = LANGS.includes(raw) ? raw : 'en';
    let sent = false;
    try {
      const { sendEmail } = require('../services/emailService');
      const mail = buildMail(code, lang);
      await sendEmail(email, mail.subject, mail.text, mail.html);
      sent = true;
      try { await require('../models/VerificationEmailLog').touch(email, 'email_first'); } catch (_) { /* jamais bloquant */ }
    } catch (e) {
      logger.warn(`[emailFirst1711] e-mail « code » non envoyé : ${e && e.message}`);
    }
    if (!sent) return res.status(502).json({ error: 'EMAIL_NOT_SENT', code: 'EMAIL_NOT_SENT' });
    return res.json({ ok: true, sent: true, retryAfter: RESEND_MS / 1000, ...(exists ? { exists: true } : {}) });
  } catch (e) {
    logger.error('[emailFirst1711] send failed', e);
    return res.status(500).json({ error: 'Unable to send the code.' });
  }
});

router.post('/check', async (req, res) => {
  try {
    const b = req.body || {};
    const email = String(b.email || '').trim().toLowerCase();
    const code = String(b.code || '').replace(/\s+/g, '');
    if (!EMAIL_RE.test(email) || email.length > 120) return res.status(400).json({ error: 'EMAIL_INVALID', code: 'EMAIL_INVALID' });
    const key = canonicalEmail(email);
    const now = Date.now();
    const failed = countIn(tries, key, HOUR_MS, now);
    if (failed.length >= MAX_TRIES) return res.status(429).json({ error: 'TOO_MANY_TRIES', code: 'TOO_MANY_TRIES' });
    if (!CODE_RE.test(code)) {
      failed.push(now); tries.set(key, failed);
      return res.status(400).json({ error: 'CODE_INVALID', code: 'CODE_INVALID', left: Math.max(0, MAX_TRIES - failed.length) });
    }
    const rec = await VerificationCode.findOne({ email, purpose: PURPOSE });
    if (!rec) return res.status(410).json({ error: 'CODE_EXPIRED', code: 'CODE_EXPIRED' });
    if (dayjs(rec.expiresAt).isBefore(dayjs())) {
      await VerificationCode.deleteOne({ _id: rec._id });
      return res.status(410).json({ error: 'CODE_EXPIRED', code: 'CODE_EXPIRED' });
    }
    if (!compareCode(code, rec.code)) {
      failed.push(now); tries.set(key, failed);
      return res.status(400).json({ error: 'CODE_INVALID', code: 'CODE_INVALID', left: Math.max(0, MAX_TRIES - failed.length) });
    }
    await VerificationCode.deleteOne({ _id: rec._id });
    tries.delete(key);
    logger.info('[emailFirst1711] code OK');
    return res.json({ emailProof: signEmailProof(email), expiresIn: require('../utils/emailProof1711').TTL_SECONDS });
  } catch (e) {
    logger.error('[emailFirst1711] check failed', e);
    return res.status(500).json({ error: 'Unable to check the code.' });
  }
});

module.exports = router;
module.exports.buildMail = buildMail;
module.exports._resetForTest = () => { sends.clear(); tries.clear(); };
module.exports._backdateForTest = (email, ms) => { const k = canonicalEmail(email); sends.set(k, (sends.get(k) || []).map((t) => t - ms)); };
