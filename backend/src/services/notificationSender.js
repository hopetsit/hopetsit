const path = require('path');
const fs = require('fs');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const { createNotificationSafe } = require('./notificationService');
const { sendEmail } = require('./emailService');
const { render } = require('../utils/i18nTemplate');
const firebaseAdmin = require('../config/firebaseAdmin');
const { decrypt } = require('../utils/encryption');
const { emitToUser } = require('../sockets/emitter');
const logger = require('../utils/logger');

const SUPPORTED_LOCALES = ['fr', 'en', 'es', 'de', 'it', 'pt'];
// v18.5 — fallback changé de 'en' vers 'fr'. HoPetSit est lancé sur le
// marché francophone (Daniel) ; la majorité des users n'ont pas encore
// `language` renseigné côté DB et tombaient sur l'anglais par défaut
// (notif "A provider sent you a request."). FR reste un fallback plus
// utile ; les users réellement anglophones ont leur `language='en'`
// chargé via updateProfile.
const FALLBACK_LOCALE = 'fr';

const catalogCache = {};

const loadCatalog = (locale) => {
  if (catalogCache[locale]) return catalogCache[locale];
  try {
    const file = path.join(__dirname, '..', 'locales', locale, 'notifications.json');
    const raw = fs.readFileSync(file, 'utf8');
    const json = JSON.parse(raw || '{}');
    catalogCache[locale] = json;
    return json;
  } catch (e) {
    catalogCache[locale] = {};
    return catalogCache[locale];
  }
};

const resolveLocale = (userLanguage) => {
  const lang = String(userLanguage || '').toLowerCase().slice(0, 2);
  return SUPPORTED_LOCALES.includes(lang) ? lang : FALLBACK_LOCALE;
};

const pickTemplate = (locale, type) => {
  const primary = loadCatalog(locale)[type];
  if (primary) return primary;
  return loadCatalog(FALLBACK_LOCALE)[type] || null;
};

const resolveUser = async (role, userId) => {
  // Session v17 — walker added as first-class recipient alongside
  // owner/sitter. Notifications were silently dropped for walker before:
  // the template catalog had entries, but resolveUser returned null and
  // sendNotification bailed out with a "user not found" warning.
  const Model =
    role === 'sitter' ? Sitter :
    role === 'owner' ? Owner :
    role === 'walker' ? Walker :
    null;
  if (!Model) return null;
  return Model.findById(userId).select('email language fcmTokens name').lean();
};

const sendPush = async (tokens, title, body, data) => {
  const list = (tokens || []).filter(Boolean);
  if (!list.length) {
    // v23.1 part 44 — surface "no FCM token registered" as a distinct
    // log line. Previously sendPush silently returned skipped:true and
    // we had no way to tell from the logs whether the user had an
    // empty fcmTokens array (most likely cause of "no phone push") or
    // whether Firebase rejected every token.
    logger.warn('[notif.push] skipped : user has no fcmTokens registered');
    return { skipped: true, reason: 'no_tokens' };
  }
  const message = {
    tokens: list,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data || {}).map(([k, v]) => [k, String(v ?? '')])
    ),
  };
  const result = await firebaseAdmin.messaging().sendEachForMulticast(message);
  // Log per-token outcomes so a stale/invalid token gets visible.
  if (result && (result.failureCount || 0) > 0) {
    logger.warn(
      `[notif.push] partial failure : success=${result.successCount} ` +
      `fail=${result.failureCount} (tokens checked=${list.length})`,
    );
    (result.responses || []).forEach((r, i) => {
      if (r && !r.success && r.error) {
        const code = r.error.code || r.error.errorInfo?.code || 'unknown';
        logger.warn(`[notif.push] token #${i} rejected : ${code}`);
      }
    });
  }
  return result;
};

/**
 * Send a notification to a user across three channels: in-app, push (FCM), email.
 * Silent on failures — each channel is wrapped in allSettled and errors are logged.
 *
 * @param {Object} params
 * @param {string} params.userId
 * @param {'owner'|'sitter'} params.role
 * @param {string} params.type     - template key (e.g. 'NEW_MESSAGE')
 * @param {Object} [params.data]   - template variables + notification payload
 * @param {Object} [params.actor]  - { role, id } who triggered the event
 */
const sendNotification = async ({ userId, role, type, data = {}, actor = null }) => {
  if (!userId || !role || !type) {
    logger.warn('sendNotification: missing required fields', { userId, role, type });
    return;
  }
  const user = await resolveUser(role, userId);
  if (!user) {
    logger.warn('sendNotification: user not found', { role, userId });
    return;
  }
  const locale = resolveLocale(user.language);
  const tmpl = pickTemplate(locale, type);
  if (!tmpl) {
    logger.warn('sendNotification: template missing', { type, locale });
    return;
  }
  const title = render(tmpl.title, data);
  const body = render(tmpl.body, data);
  const emailSubject = render(tmpl.emailSubject, data);
  const emailBody = render(tmpl.emailBody, data);
  const email = decrypt(user.email || '');
  // v23.1 part 44 — diagnostic line so Daniel can see at a glance which
  // channels are even *attempted*. Previously the logs only said "channel
  // failed" after the fact ; if a channel was skipped (no email after
  // decrypt, no fcmTokens), the silence looked the same as a success.
  const tokenCount = Array.isArray(user.fcmTokens) ? user.fcmTokens.length : 0;
  logger.info(
    `[notif.send] type=${type} role=${role} userId=${userId} ` +
    `locale=${locale} fcmTokens=${tokenCount} ` +
    `emailReady=${email && email.length > 3 ? 'yes' : 'NO'}`,
  );

  // Real-time socket push for in-app badges — best-effort, no await.
  try {
    emitToUser(role, userId, 'notification.new', { type, title, body, data });
  } catch (_) { /* noop */ }

  const results = await Promise.allSettled([
    createNotificationSafe({
      recipientRole: role,
      recipientId: userId,
      actorRole: actor?.role || null,
      actorId: actor?.id || null,
      type,
      title,
      body,
      data,
    }),
    sendPush(user.fcmTokens, title, body, { type, ...data }),
    email ? sendEmail(email, emailSubject, body, emailBody) : Promise.resolve({ skipped: true }),
  ]);

  results.forEach((r, idx) => {
    if (r.status === 'rejected') {
      const channel = ['in-app', 'push', 'email'][idx];
      logger.warn(`notification ${channel} channel failed for ${type}`, r.reason?.message || r.reason);
    }
  });
};

module.exports = { sendNotification };
