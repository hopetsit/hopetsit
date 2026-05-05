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
  const primary = await Model.findById(userId).select('email language fcmTokens name').lean();
  if (primary) return primary;

  // v23.1 part 49 — cross-collection fallback. The destructive switchRole
  // flow deletes the old role's doc and creates a new one in the target
  // collection. Bookings created BEFORE the switch still reference the
  // OLD userId, which now lives in a different collection (e.g. an Owner
  // who switched to Walker — Owner.findById returns null but the same
  // _id exists in Walker). Without this fallback, payment notifs to the
  // owner of an old booking go silently dropped : the booking points
  // to "owner X1", X1 has been migrated to Walker collection, owner
  // collection lookup returns null → notif skipped.
  //
  // We search the other 2 collections by _id ; if found we return it
  // even though the role mismatch is logged at the call site so we know.
  // The recipient still gets the notification on their device (FCM
  // tokens move with the doc on switchRole for owner — see the
  // userController.switchRole owner branch).
  const fallbackModels = [Owner, Sitter, Walker].filter((m) => m !== Model);
  for (const Fb of fallbackModels) {
    try {
      const found = await Fb.findById(userId).select('email language fcmTokens name').lean();
      if (found) {
        logger.warn(
          `[notif.fallback] user ${userId} expected in ${role} collection but ` +
          `found in ${Fb.modelName} (likely a switchRole migration). ` +
          `Notification will still be delivered.`,
        );
        return found;
      }
    } catch (_) { /* try next */ }
  }
  return null;
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
  // v23.1 part 48 — entry log fires UNCONDITIONALLY before any early return.
  // Lets us prove from Render logs that sendNotification was actually
  // invoked (vs being skipped upstream). Previous logs only fired once
  // user/template resolved, so a "user not found" path was indistinguishable
  // from a "function never called" one.
  logger.info(`[notif.entry] type=${type} role=${role} userId=${userId}`);
  if (!userId || !role || !type) {
    logger.warn(
      `[notif.skip] missing required fields userId=${userId} role=${role} type=${type}`,
    );
    return;
  }
  const user = await resolveUser(role, userId);
  if (!user) {
    logger.warn(
      `[notif.skip] user not found in ${role} collection for userId=${userId} ` +
      `(this happens when the booking references a deleted/migrated user — ` +
      `check whether a switchRole purged the recipient's old doc)`,
    );
    return;
  }
  const locale = resolveLocale(user.language);
  const tmpl = pickTemplate(locale, type);
  if (!tmpl) {
    logger.warn(`[notif.skip] template missing type=${type} locale=${locale}`);
    return;
  }
  const title = render(tmpl.title, data);
  const body = render(tmpl.body, data);
  const emailSubject = render(tmpl.emailSubject, data);
  const emailBody = render(tmpl.emailBody, data);
  const email = decrypt(user.email || '');
  const tokenCount = Array.isArray(user.fcmTokens) ? user.fcmTokens.length : 0;
  logger.info(
    `[notif.send] type=${type} role=${role} userId=${userId} ` +
    `locale=${locale} fcmTokens=${tokenCount} ` +
    `emailReady=${email && email.length > 3 ? 'yes' : 'NO'} ` +
    `title="${(title || '').slice(0, 60)}"`,
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

  // v23.1 part 48 — log success/failure per channel so the Render log
  // explicitly tells us each channel's outcome instead of just complaining
  // when something failed. Helps diagnose "email arrived but push didn't"
  // or vice-versa.
  const channels = ['in-app', 'push', 'email'];
  results.forEach((r, idx) => {
    const channel = channels[idx];
    if (r.status === 'rejected') {
      logger.warn(
        `[notif.channel] ${channel} FAILED for ${type} → ${r.reason?.message || r.reason}`,
      );
    } else {
      const v = r.value || {};
      const skipped = v.skipped ? ` (skipped: ${v.reason || 'no_email'})` : '';
      logger.info(`[notif.channel] ${channel} ok for ${type}${skipped}`);
    }
  });
};

module.exports = { sendNotification };
