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
      headers: isCampaign
        ? {}
        : {
            // RFC 2076 — marque l'email comme automatisé, Gmail / Outlook
            // cachent alors le bouton Reply directement.
            'Auto-Submitted': 'auto-generated',
            'X-Auto-Response-Suppress': 'All',
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

const sendVerificationEmail = async (email, code) => {
  const subject = `Verify your ${BRAND_NAME} account`;
  const text = `Hi there,

Thank you for joining ${BRAND_NAME}!

Your verification code is: ${code}

Enter this code within the next 10 minutes to activate your account.

If you didn't request this email, you can safely ignore it or contact our support at ${SUPPORT_EMAIL}.

Warm regards,
The ${BRAND_NAME} Team`;
  const html = `<div style="font-family:Arial,Helvetica,sans-serif;max-width:560px;margin:auto;padding:24px;background:#fff;border:1px solid #eee;border-radius:8px">
  <h2 style="color:#E8590C;margin:0 0 12px">Welcome to ${BRAND_NAME}!</h2>
  <p>Thank you for joining us. Your verification code is:</p>
  <div style="font-size:28px;font-weight:700;letter-spacing:6px;background:#f7f7f7;padding:16px;text-align:center;border-radius:6px;margin:16px 0">${code}</div>
  <p>Enter this code within the next <strong>10 minutes</strong> to activate your account.</p>
  <p style="color:#888;font-size:12px">If you didn't request this email, you can safely ignore it or contact our support at ${SUPPORT_EMAIL}.</p>
  <p style="margin-top:24px">— The ${BRAND_NAME} Team</p>
</div>`;
  await sendEmail(email, subject, text, html);
};

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
};

