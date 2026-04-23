const nodemailer = require('nodemailer');
const logger = require('../utils/logger');

const BRAND_NAME = process.env.EMAIL_BRAND_NAME || 'HopeTSIT';
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
  const addr = process.env.SMTP_FROM || process.env.SMTP_USER;
  if (!addr) return `${BRAND_NAME} <noreply@hopetsit.app>`;
  // If already formatted "Name <addr>", keep as-is; otherwise prefix brand name.
  return addr.includes('<') ? addr : `${BRAND_NAME} <${addr}>`;
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

const sendEmail = async (email, subject, text, html) => {
  if (!email) {
    logger.warn(`[emailService] sendEmail called with empty recipient (subject="${subject}")`);
    return { skipped: true, reason: 'no-recipient' };
  }
  if (!transporter) {
    logger.info(`[${BRAND_NAME} dev-log] To=${email} | Subject=${subject} | Body=${text}`);
    return { skipped: true, reason: 'no-smtp-transporter' };
  }
  try {
    const info = await transporter.sendMail({
      to: email,
      from: fromAddress(),
      // v18.9 — Reply-To no-reply : les users ne peuvent plus répondre par
      // mail (privacy). Ils doivent ouvrir l'app pour répondre au chat.
      replyTo: noReplyAddress(),
      subject,
      text,
      ...(html ? { html } : {}),
      headers: {
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
};

