const nodemailer = require('nodemailer');
const logger = require('../utils/logger');

// v496 — Daniel : « on reçoit HopeTSIT au lieu de HoPetSit » comme nom
// d'expéditeur. CAUSE : la var d'env EMAIL_BRAND_NAME sur Render valait
// "HopeTSIT" (mauvaise casse) → elle écrasait le défaut. On FORCE désormais
// la casse de marque correcte « HoPetSit » en dur, indépendamment de l'env
// (qui restait mal configurée), pour que TOUS les emails affichent HoPetSit.
const BRAND_NAME = 'HoPetSit';
const SUPPORT_EMAIL = process.env.SMTP_FROM || process.env.SMTP_USER || 'hopetsit@gmail.com';

const transporter = (() => {
  if (!process.env.SMTP_HOST) {
    logger.warn(
      '[emailService] SMTP_HOST is not set — emails will be logged, not sent. '
      + 'Configure SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM on Render.'
    );
    return null;
  }
  const t = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: process.env.SMTP_PORT ? Number(process.env.SMTP_PORT) : 587,
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
    // v23.1.267 — Daniel : "les mails de notification arrivent en retard".
    // CAUSE : sans pool, CHAQUE email rouvrait une connexion SMTP complète
    // (TCP + TLS + AUTH) → plusieurs secondes par mail, aggravé par le
    // throttling Gmail. On active le POOL (connexions réutilisées) + des
    // timeouts courts pour ne pas rester bloqué sur un serveur lent.
    pool: true,
    maxConnections: 5,
    maxMessages: 100,
    connectionTimeout: 10000,
    greetingTimeout: 7000,
    socketTimeout: 20000,
  });
  // Verify transporter at boot so we see a clear error in logs if creds are wrong
  t.verify((err) => {
    if (err) {
      logger.error('[emailService] SMTP transporter verification FAILED', err.message || err);
    } else {
      logger.info(`[emailService] SMTP transporter ready (host=${process.env.SMTP_HOST}).`);
    }
  });
  return t;
})();

const fromAddress = () => {
  const raw = process.env.SMTP_FROM || process.env.SMTP_USER;
  if (!raw) return `${BRAND_NAME} <noreply@hopetsit.app>`;
  // v23.1.328 — Daniel : "mets HoPetSit dans le mail". On FORCE le nom
  // d'expediteur "HoPetSit" quel que soit le format de SMTP_FROM. Si la var
  // contenait "hopetsit <...>" (minuscule du compte Gmail), le destinataire
  // voyait "hopetsit". On extrait juste l'adresse et on remet "HoPetSit".
  const m = raw.match(/<([^>]+)>/);
  const email = (m ? m[1] : raw).trim();
  return `${BRAND_NAME} <${email}>`;
};

// v18.9 — adresse Reply-To no-reply pour toutes les notifs sortantes.
// Avant v18.9, l'utilisateur qui répondait à un email "nouveau message"
// envoyait DIRECTEMENT à l'adresse SMTP_FROM (ex hopetsit@gmail.com).
// Pire, certaines implémentations auto-branchaient l'email de l'expéditeur
// réel comme reply-to → fuite de l'adresse privée de l'owner/provider.
// On force désormais un alias no-reply@ neutre.
const noReplyAddress = () => {
  const explicit = process.env.SMTP_NO_REPLY;
  if (explicit && explicit.trim().length > 0) return explicit.trim();
  return `${BRAND_NAME} no-reply <no-reply@hopetsit.app>`;
};

// v402 — opts.replyTo : permet aux campagnes promo (admin) de fixer une adresse
// de réponse choisie (ex. l'adresse perso de Daniel) tout en ENVOYANT depuis
// l'adresse de marque vérifiée (SPF/DKIM OK, pas de spam). Quand replyTo est
// fourni on n'ajoute PAS les en-têtes Auto-Submitted (sinon Gmail masque le
// bouton « Répondre », alors qu'ici on VEUT que les clients puissent répondre).
const sendEmail = async (email, subject, text, html, opts = {}) => {
  if (!email) {
    logger.warn(`[emailService] sendEmail called with empty recipient (subject="${subject}")`);
    return { skipped: true, reason: 'no-recipient' };
  }
  if (!transporter) {
    logger.info(`[${BRAND_NAME} dev-log] To=${email} | Subject=${subject} | Body=${text}`);
    return { skipped: true, reason: 'no-smtp-transporter' };
  }
  const replyTo = opts && opts.replyTo ? String(opts.replyTo).trim() : noReplyAddress();
  const isCampaign = !!(opts && opts.replyTo);
  try {
    const info = await transporter.sendMail({
      to: email,
      from: fromAddress(),
      // v18.9 — Reply-To no-reply par défaut (privacy). v402 — override possible
      // pour les campagnes promo.
      replyTo,
      subject,
      text,
      ...(html ? { html } : {}),
      headers: {
        ...(isCampaign
          ? {}
          : {
              // RFC 2076 — marque l'email comme automatisé, Gmail / Outlook
              // cachent alors le bouton Reply directement.
              'Auto-Submitted': 'auto-generated',
              'X-Auto-Response-Suppress': 'All',
            }),
        // v566 — en-têtes supplémentaires (ex. List-Unsubscribe du cycle de vie).
        ...(opts && opts.headers && typeof opts.headers === 'object' ? opts.headers : {}),
      },
    });
    logger.info(`[emailService] sent to=${email} subject="${subject}" messageId=${info.messageId}`);
    return info;
  } catch (err) {
    logger.error(`[emailService] FAILED to send to=${email} subject="${subject}"`, err.message || err);
    throw err;
  }
};

// v402 — email de campagne promo (admin). Enveloppe le corps (texte simple ou
// HTML léger) dans un gabarit de marque + ajoute, si fourni, un encadré code
// promo. Envoi depuis l'adresse de marque, Reply-To = adresse choisie.
const sendCampaignEmail = async (email, subject, bodyText, { replyTo, promoCode, ctaUrl, ctaLabel } = {}) => {
  const safeBodyHtml = String(bodyText || '')
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/\n/g, '<br/>');
  const codeBlock = promoCode
    ? `<div style="font-size:24px;font-weight:800;letter-spacing:4px;background:#FFF4EE;color:#EF4324;padding:16px;text-align:center;border-radius:10px;border:2px dashed #EF4324;margin:18px 0">${String(promoCode).toUpperCase()}</div>`
    : '';
  const ctaBlock = ctaUrl
    ? `<p style="text-align:center;margin:18px 0"><a href="${ctaUrl}" style="background:#EF4324;color:#fff;text-decoration:none;font-weight:700;padding:12px 22px;border-radius:999px;display:inline-block">${ctaLabel || 'En profiter'}</a></p>`
    : '';
  const html = `<div style="font-family:Arial,Helvetica,sans-serif;max-width:560px;margin:auto;padding:24px;background:#fff;border:1px solid #eee;border-radius:12px">
  <h2 style="color:#EF4324;margin:0 0 12px">${BRAND_NAME}</h2>
  <div style="color:#222;font-size:15px;line-height:1.5">${safeBodyHtml}</div>
  ${codeBlock}
  ${ctaBlock}
  <p style="color:#999;font-size:12px;margin-top:24px">— ${BRAND_NAME}</p>
</div>`;
  return sendEmail(email, subject, bodyText, html, { replyTo: replyTo || undefined });
};

/**
 * Send a simple test email — used by admin to verify SMTP is working.
 */
const sendTestEmail = async (email) => {
  const subject = `${BRAND_NAME} SMTP test — it works!`;
  const text = `Hi,

This is a test email from the ${BRAND_NAME} backend.
If you received this, your SMTP configuration is working correctly.

— ${BRAND_NAME} Team`;
  const html = `<p>Hi,</p>
<p>This is a test email from the <strong>${BRAND_NAME}</strong> backend.</p>
<p>If you received this, your SMTP configuration is working correctly. ✅</p>
<p>— ${BRAND_NAME} Team</p>`;
  return sendEmail(email, subject, text, html);
};

// v562 — Daniel (14/09) : « 17 comptes sur 34 n'ont jamais validé leur e-mail ».
// Causes : e-mail en anglais seulement, code valable 10 minutes, rien à cliquer.
// → texte dans la langue du compte, code valable 24 h, bouton « Activer mon compte »
// (GET /auth/verify-link) qui valide sans rien taper. Aucun changement dans l'app.
const API_BASE = process.env.PUBLIC_API_URL || 'https://hopetsit-backend.onrender.com/api/v1';
const VERIFY_I18N = {
  fr: { subject: 'Ton code HoPetSit : {code}', hi: 'Bonjour{name},', thanks: 'Bienvenue sur HoPetSit ! Voici ton code de vérification :', button: 'Activer mon compte', or: 'ou saisis ce code dans l\'app :', valid: 'Valable 24 heures.', ignore: 'Si tu n\'es pas à l\'origine de cette demande, ignore simplement cet e-mail.', team: 'L\'équipe HoPetSit' },
  en: { subject: 'Your HoPetSit code: {code}', hi: 'Hi{name},', thanks: 'Welcome to HoPetSit! Here is your verification code:', button: 'Activate my account', or: 'or enter this code in the app:', valid: 'Valid for 24 hours.', ignore: 'If you didn\'t request this, you can safely ignore this email.', team: 'The HoPetSit team' },
  es: { subject: 'Tu código HoPetSit: {code}', hi: 'Hola{name},', thanks: '¡Bienvenido a HoPetSit! Este es tu código de verificación:', button: 'Activar mi cuenta', or: 'o introduce este código en la app:', valid: 'Válido durante 24 horas.', ignore: 'Si no has solicitado esto, ignora este correo.', team: 'El equipo de HoPetSit' },
  de: { subject: 'Dein HoPetSit-Code: {code}', hi: 'Hallo{name},', thanks: 'Willkommen bei HoPetSit! Hier ist dein Bestätigungscode:', button: 'Konto aktivieren', or: 'oder gib diesen Code in der App ein:', valid: '24 Stunden gültig.', ignore: 'Falls du das nicht angefordert hast, ignoriere diese E-Mail einfach.', team: 'Das HoPetSit-Team' },
  it: { subject: 'Il tuo codice HoPetSit: {code}', hi: 'Ciao{name},', thanks: 'Benvenuto su HoPetSit! Ecco il tuo codice di verifica:', button: 'Attiva il mio account', or: 'oppure inserisci questo codice nell\'app:', valid: 'Valido per 24 ore.', ignore: 'Se non hai richiesto questa e-mail, ignorala.', team: 'Il team HoPetSit' },
  pt: { subject: 'O teu código HoPetSit: {code}', hi: 'Olá{name},', thanks: 'Bem-vindo à HoPetSit! Aqui está o teu código de verificação:', button: 'Ativar a minha conta', or: 'ou introduz este código na app:', valid: 'Válido durante 24 horas.', ignore: 'Se não pediste isto, ignora este e-mail.', team: 'A equipa HoPetSit' },
  pl: { subject: 'Twój kod HoPetSit: {code}', hi: 'Cześć{name},', thanks: 'Witaj w HoPetSit! Oto Twój kod weryfikacyjny:', button: 'Aktywuj moje konto', or: 'lub wpisz ten kod w aplikacji:', valid: 'Ważny przez 24 godziny.', ignore: 'Jeśli to nie Ty, zignoruj tę wiadomość.', team: 'Zespół HoPetSit' },
  ko: { subject: 'HoPetSit 인증 코드: {code}', hi: '안녕하세요{name},', thanks: 'HoPetSit에 오신 것을 환영합니다! 인증 코드입니다:', button: '계정 활성화', or: '또는 앱에 이 코드를 입력하세요:', valid: '24시간 동안 유효합니다.', ignore: '요청하지 않으셨다면 이 메일을 무시하세요.', team: 'HoPetSit 팀' },
  ja: { subject: 'HoPetSit 認証コード: {code}', hi: 'こんにちは{name}', thanks: 'HoPetSitへようこそ！認証コードはこちらです：', button: 'アカウントを有効にする', or: 'またはアプリでこのコードを入力：', valid: '24時間有効です。', ignore: '心当たりがない場合はこのメールを無視してください。', team: 'HoPetSitチーム' },
};
const sendVerificationEmail = async (email, code, lang = 'en', name = '') => {
  const t = VERIFY_I18N[lang] || VERIFY_I18N.en;
  const first = String(name || '').trim().split(/\s+/)[0];
  const who = first ? ' ' + first : '';
  const link = `${API_BASE}/auth/verify-link?email=${encodeURIComponent(String(email).toLowerCase())}&code=${encodeURIComponent(code)}`;
  const subject = t.subject.replace('{code}', code);
  const text = `${t.hi.replace('{name}', who)}

${t.thanks} ${code}
${t.valid}

${t.button} : ${link}

${t.ignore}

— ${t.team}`;
  const html = `<div style="font-family:-apple-system,Arial,Helvetica,sans-serif;max-width:560px;margin:auto;padding:28px;background:#fff;border:1px solid #eee;border-radius:14px;color:#1D1D1F">
  <p style="font-size:20px;font-weight:700;margin:0 0 8px">🐾 HoPetSit</p>
  <p>${t.hi.replace('{name}', who)}</p>
  <p>${t.thanks}</p>
  <p style="text-align:center;margin:22px 0"><a href="${link}" style="display:inline-block;background:#D83C28;color:#fff;text-decoration:none;font-weight:700;font-size:17px;padding:14px 28px;border-radius:999px">${t.button}</a></p>
  <p style="color:#6E6E73;text-align:center;margin:0 0 6px">${t.or}</p>
  <div style="font-size:30px;font-weight:800;letter-spacing:8px;background:#F5F5F7;padding:16px;text-align:center;border-radius:12px;margin:0 0 16px">${code}</div>
  <p style="color:#6E6E73;font-size:13px">${t.valid}</p>
  <p style="color:#6E6E73;font-size:12px">${t.ignore}</p>
  <p style="margin-top:24px">— ${t.team}</p>
</div>`;
  await sendEmail(email, subject, text, html);
};

// ─── v566 — AUDIT NOTIFICATIONS : gabarit commun des e-mails de notification ───
// Avant : le `emailBody` du catalogue (quelques <p>) partait TEL QUEL : pas de
// viewport (texte minuscule sur mobile), bouton collé à gauche, 35 types sans lien
// de secours, aucun pied de page. Désormais chaque e-mail de notification est
// enveloppé ici : en-tête de marque, largeur 560 px fluide, bouton centré, lien de
// secours ajouté s'il manque, pied de page traduit (pourquoi je reçois ce message +
// où régler mes notifications). Aucun envoi ici : fonction pure, testable.
const NOTIF_EMAIL_I18N = {
  fr: { fallback: 'Si le bouton ne fonctionne pas, copie ce lien dans ton navigateur :', footer: 'Tu reçois cet e-mail parce que tu as un compte HoPetSit. Tu peux choisir tes notifications dans l\'app : Profil › Préférences › Notifications.', noreply: 'Message automatique, merci de ne pas y répondre.' },
  en: { fallback: 'If the button doesn\'t work, copy this link into your browser:', footer: 'You are receiving this email because you have a HoPetSit account. You can choose your notifications in the app: Profile › Preferences › Notifications.', noreply: 'Automated message, please do not reply.' },
  es: { fallback: 'Si el botón no funciona, copia este enlace en tu navegador:', footer: 'Recibes este correo porque tienes una cuenta HoPetSit. Puedes elegir tus notificaciones en la app: Perfil › Preferencias › Notificaciones.', noreply: 'Mensaje automático, por favor no respondas.' },
  de: { fallback: 'Falls der Button nicht funktioniert, kopiere diesen Link in deinen Browser:', footer: 'Du erhältst diese E-Mail, weil du ein HoPetSit-Konto hast. Deine Benachrichtigungen wählst du in der App: Profil › Einstellungen › Benachrichtigungen.', noreply: 'Automatische Nachricht, bitte nicht antworten.' },
  it: { fallback: 'Se il pulsante non funziona, copia questo link nel browser:', footer: 'Ricevi questa e-mail perché hai un account HoPetSit. Puoi scegliere le notifiche nell\'app: Profilo › Preferenze › Notifiche.', noreply: 'Messaggio automatico, non rispondere.' },
  pt: { fallback: 'Se o botão não funcionar, copia este link para o teu navegador:', footer: 'Recebes este e-mail porque tens uma conta HoPetSit. Podes escolher as tuas notificações na app: Perfil › Preferências › Notificações.', noreply: 'Mensagem automática, por favor não respondas.' },
  pl: { fallback: 'Jeśli przycisk nie działa, skopiuj ten link do przeglądarki:', footer: 'Otrzymujesz tę wiadomość, ponieważ masz konto HoPetSit. Powiadomienia wybierzesz w aplikacji: Profil › Preferencje › Powiadomienia.', noreply: 'Wiadomość automatyczna, prosimy nie odpowiadać.' },
  ko: { fallback: '버튼이 작동하지 않으면 이 링크를 브라우저에 복사하세요:', footer: 'HoPetSit 계정이 있어 이 메일을 받으셨습니다. 알림은 앱의 프로필 › 환경설정 › 알림에서 선택할 수 있어요.', noreply: '자동 발송 메일입니다. 회신하지 마세요.' },
  ja: { fallback: 'ボタンが動作しない場合は、このリンクをブラウザにコピーしてください：', footer: 'HoPetSitのアカウントをお持ちのため、このメールをお送りしています。通知はアプリの「プロフィール › 設定 › 通知」で選べます。', noreply: '自動送信メールです。返信しないでください。' },
};
const escapeHtml = (v) => String(v == null ? '' : v)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/**
 * @param {string} innerHtml  emailBody rendu (catalogue locales/<lang>/notifications.json)
 * @param {Object} [o]
 * @param {string} [o.locale]    fr|en|es|de|it|pt|ko|ja|pl
 * @param {string} [o.link]      lien universel du bouton (ajoute le lien de secours s'il manque)
 * @param {string} [o.preheader] texte d'aperçu (corps du push)
 */
const buildNotificationEmailHtml = (innerHtml, { locale = 'fr', link = '', preheader = '' } = {}) => {
  const t = NOTIF_EMAIL_I18N[locale] || NOTIF_EMAIL_I18N.en;
  let inner = String(innerHtml || '');
  // Bouton centré : le paragraphe qui contient le bouton (lien « display:inline-block »).
  inner = inner.replace(/<p>(\s*<a\s[^>]*display:inline-block)/g, '<p style="text-align:center;margin:24px 0">$1');
  const safeLink = escapeHtml(link);
  const occurrences = link ? inner.split(link).length - 1 : 0;
  const fallback = link && occurrences < 2
    ? `<p style="color:#6E6E73;font-size:12px;line-height:1.5;word-break:break-all">${t.fallback} <a href="${safeLink}" style="color:#6E6E73">${safeLink}</a></p>`
    : '';
  return `<!doctype html><html lang="${locale}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><title>${BRAND_NAME}</title></head>
<body style="margin:0;padding:0;background:#F5F5F7">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">${escapeHtml(preheader)}</div>
<div style="padding:16px 12px;background:#F5F5F7">
<div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,Helvetica,sans-serif;max-width:560px;margin:0 auto;padding:24px 22px;background:#FFFFFF;border-radius:16px;color:#1D1D1F;font-size:16px;line-height:1.55">
<p style="font-size:20px;font-weight:700;margin:0 0 14px;color:#D83C28">🐾 ${BRAND_NAME}</p>
${inner}
${fallback}
<hr style="border:none;border-top:1px solid #EEEEF0;margin:22px 0 14px">
<p style="color:#8E8E93;font-size:12px;line-height:1.5;margin:0">${t.footer}<br>${t.noreply}</p>
</div></div></body></html>`;
};

// (L'e-mail de réinitialisation traduit vit dans authController.sendPasswordResetEmailI18n ;
// cette version anglaise n'est que son repli.)
const sendPasswordResetEmail = async (email, code) => {
  const subject = `Reset your ${BRAND_NAME} password`;
  const text = `Use the following code to reset your ${BRAND_NAME} password: ${code}. It expires in 10 minutes.

If you didn't request this, please contact ${SUPPORT_EMAIL}.

— The ${BRAND_NAME} Team`;
  const html = `<div style="font-family:Arial,Helvetica,sans-serif;max-width:560px;margin:auto;padding:24px;background:#fff;border:1px solid #eee;border-radius:8px">
  <h2 style="color:#E8590C;margin:0 0 12px">Reset your password</h2>
  <p>Use the following code to reset your ${BRAND_NAME} password:</p>
  <div style="font-size:28px;font-weight:700;letter-spacing:6px;background:#f7f7f7;padding:16px;text-align:center;border-radius:6px;margin:16px 0">${code}</div>
  <p>It expires in <strong>10 minutes</strong>.</p>
  <p style="color:#888;font-size:12px">If you didn't request this, please contact ${SUPPORT_EMAIL}.</p>
  <p style="margin-top:24px">— The ${BRAND_NAME} Team</p>
</div>`;
  await sendEmail(email, subject, text, html);
};

module.exports = {
  sendVerificationEmail,
  sendPasswordResetEmail,
  sendEmail,
  sendTestEmail,
  sendCampaignEmail,
  buildNotificationEmailHtml, // v566
};

