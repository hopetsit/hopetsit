const nodemailer = require('nodemailer');
const logger = require('../utils/logger');

const transporter = (() => {
  if (!process.env.SMTP_HOST) {
    return null;
  }
  return nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: process.env.SMTP_PORT ? Number(process.env.SMTP_PORT) : 587,
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
})();

const sendEmail = async (email, subject, text, html) => {
  if (transporter) {
    await transporter.sendMail({
      to: email,
      from: process.env.SMTP_FROM || process.env.SMTP_USER,
      subject,
      text,
      ...(html ? { html } : {}),
    });
  } else {
    logger.info(`[PetsInsta] ${subject} for ${email}: ${text}`);
  }
};

const sendVerificationEmail = async (email, code) => {
  const subject = 'Verify your PetsInsta account';
  const text = `Hi there,

Thank you for joining PetsInsta!

Your verification code is: ${code}

Enter this code within the next 10 minutes to activate your account.

If you didn't request this email, you can safely ignore it or contact our support team.

Warm regards,
The PetsInsta Team`;
  await sendEmail(email, subject, text);
};

const sendPasswordResetEmail = async (email, code) => {
  const subject = 'Reset your PetsInsta password';
  const text = `Use the following code to reset your PetsInsta password: ${code}. It expires in 10 minutes.`;
  await sendEmail(email, subject, text);
};

module.exports = {
  sendVerificationEmail,
  sendPasswordResetEmail,
  sendEmail,
};

