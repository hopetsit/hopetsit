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
const { emitToUser, isUserOnline } = require('../sockets/emitter');

// v448 — AUDIT MESSAGERIE : types pour lesquels l'email n'est envoyé QUE si le
// destinataire est HORS LIGNE (règle produit « email uniquement si hors ligne »).
// On cible les MESSAGES (haut volume + cause des emails 10-20 min de retard et
// du « email reçu alors que je suis dans le chat »). Les emails TRANSACTIONNELS
// (paiement, KYC, retrait, payout, avis...) ne sont PAS gatés → toujours envoyés
// (ce sont des reçus importants). Comparaison en minuscules.
const PRESENCE_GATED_EMAIL_TYPES = new Set(['new_message']);
const logger = require('../utils/logger');

const SUPPORTED_LOCALES = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']; // v546 — polonais
// v18.5 — fallback changé de 'en' vers 'fr'. HoPetSit est lancé sur le
// marché francophone (Daniel) ; la majorité des users n'ont pas encore
// `language` renseigné côté DB et tombaient sur l'anglais par défaut
// (notif "A provider sent you a request."). FR reste un fallback plus
// utile ; les users réellement anglophones ont leur `language='en'`
// chargé via updateProfile.
const FALLBACK_LOCALE = 'fr';

// ─── v565 §2 — préférences de notification (son + catégories) ───────────────
// Contrat docs/v565_contracts.md §2 : stockage `notificationPrefs` sur les 3
// docs de la personne ; catégorie désactivée → PAS de push ni d'e-mail (la
// notification in-app reste créée) ; son → APNs `aps.sound`, canal Android
// `hopetsit_<son>` + `data.sound` pour l'affichage au premier plan.
const NOTIFICATION_SOUNDS = ['default', 'frog', 'bark', 'meow', 'tweet', 'vibrate', 'silent']; // v565 — frog = défaut, tweet = hibou
const NOTIFICATION_CATEGORIES = [
  'messages', 'bookings', 'payments', 'friends', 'pawmap', 'live', 'reviews', 'subscriptions',
];
const defaultNotificationPrefs = () => ({
  sound: 'frog', // v565 — Daniel : son grenouille par défaut
  categories: Object.fromEntries(NOTIFICATION_CATEGORIES.map((c) => [c, true])),
});
/** Objet complet (défauts + valeurs fournies), tolérant aux entrées partielles. */
const normalizeNotificationPrefs = (raw) => {
  const out = defaultNotificationPrefs();
  if (!raw || typeof raw !== 'object') return out;
  const sound = String(raw.sound || '').toLowerCase().trim();
  if (NOTIFICATION_SOUNDS.includes(sound)) out.sound = sound;
  const cats = raw.categories && typeof raw.categories === 'object' ? raw.categories : {};
  for (const c of NOTIFICATION_CATEGORIES) {
    if (cats[c] === false || cats[c] === 'false' || cats[c] === 0) out.categories[c] = false;
    else if (cats[c] === true || cats[c] === 'true' || cats[c] === 1) out.categories[c] = true;
  }
  return out;
};
/** Vrai si le doc porte des préférences explicites (pas seulement des défauts Mongoose absents). */
const hasExplicitPrefs = (doc) =>
  !!(doc && doc.notificationPrefs && typeof doc.notificationPrefs === 'object' &&
    (doc.notificationPrefs.sound || doc.notificationPrefs.categories));

/**
 * Catégorie d'un type de notification — mappage FIGÉ par le contrat §2 :
 *   messages = NEW_MESSAGE, CHAT_AUTO_WELCOME, chat_addon_activated, BOOKING_PAID_CHAT_UNLOCKED
 *   bookings = booking_*, application_*, service_*, VISIT_REPORT, BOOKING_*, walk_*, new_request_nearby, handover_*
 *   payments = PAYMENT_*, payout_*, withdrawal_*, wallet_credited, kyc_payment_succeeded, REFERRAL_CREDITED
 *   friends = friend_*, family_* ; pawmap = lost_pet_sighting, sos_pet_nearby, map_boost_activated, profile_boost_activated
 *   live = live_tracking_*, live_still_active, live_session_ended ; reviews = NEW_REVIEW, PREMIUM_ACHIEVED, TOP_SITTER_ACHIEVED
 *   subscriptions = subscription_activated, kyc_verified, kyc_rejected ; inconnu = bookings.
 */
const EXACT_CATEGORY = {
  NEW_MESSAGE: 'messages', CHAT_AUTO_WELCOME: 'messages', chat_addon_activated: 'messages',
  BOOKING_PAID_CHAT_UNLOCKED: 'messages',
  VISIT_REPORT: 'bookings', new_request_nearby: 'bookings',
  wallet_credited: 'payments', kyc_payment_succeeded: 'payments', REFERRAL_CREDITED: 'payments',
  lost_pet_sighting: 'pawmap', sos_pet_nearby: 'pawmap', map_boost_activated: 'pawmap',
  profile_boost_activated: 'pawmap',
  live_still_active: 'live', live_session_ended: 'live',
  NEW_REVIEW: 'reviews', PREMIUM_ACHIEVED: 'reviews', TOP_SITTER_ACHIEVED: 'reviews',
  subscription_activated: 'subscriptions', kyc_verified: 'subscriptions', kyc_rejected: 'subscriptions',
};
const PREFIX_CATEGORY = [
  ['booking_', 'bookings'], ['application_', 'bookings'], ['service_', 'bookings'],
  ['BOOKING_', 'bookings'], ['walk_', 'bookings'], ['handover_', 'bookings'],
  ['PAYMENT_', 'payments'], ['payout_', 'payments'], ['withdrawal_', 'payments'],
  ['friend_', 'friends'], ['family_', 'friends'],
  ['live_tracking_', 'live'],
];
const categoryForType = (type) => {
  const t = String(type || '');
  if (EXACT_CATEGORY[t]) return EXACT_CATEGORY[t];
  for (const [prefix, cat] of PREFIX_CATEGORY) {
    if (t.startsWith(prefix)) return cat;
  }
  // Repli insensible à la casse (n'altère aucun mappage listé ci-dessus).
  const lower = t.toLowerCase();
  for (const [k, cat] of Object.entries(EXACT_CATEGORY)) {
    if (k.toLowerCase() === lower) return cat;
  }
  for (const [prefix, cat] of PREFIX_CATEGORY) {
    if (lower.startsWith(prefix.toLowerCase())) return cat;
  }
  return 'bookings';
};

/**
 * Préférences de la personne : sur le doc résolu, sinon sur ses frères
 * (même email / oldId / _id) — même famille que gatherFcmTokens (v407).
 */
const resolveNotificationPrefsAcrossRoles = async (primary, userId) => {
  if (hasExplicitPrefs(primary)) return normalizeNotificationPrefs(primary.notificationPrefs);
  try {
    const or = [{ _id: userId }];
    if (primary?.email) or.push({ email: primary.email });
    if (primary?.oldId != null) or.push({ oldId: primary.oldId });
    const [owners, sitters, walkers] = await Promise.all([
      Owner.find({ $or: or }).select('notificationPrefs').lean(),
      Sitter.find({ $or: or }).select('notificationPrefs').lean(),
      Walker.find({ $or: or }).select('notificationPrefs').lean(),
    ]);
    const withPrefs = [...owners, ...sitters, ...walkers].find(hasExplicitPrefs);
    return normalizeNotificationPrefs(withPrefs ? withPrefs.notificationPrefs : null);
  } catch (e) {
    logger.warn(`[notif.prefs] cross-role prefs lookup failed : ${e?.message || e}`);
    return defaultNotificationPrefs();
  }
};

/** Champs FCM dérivés du son choisi (contrat §2 / §1 pour les canaux). */
const pushSoundConfig = (sound) => {
  const s = NOTIFICATION_SOUNDS.includes(sound) ? sound : 'default';
  if (s === 'default') {
    return {
      android: { channelId: 'hopetsit_default_channel', sound: 'default' },
      apnsSound: 'default',
      dataSound: 'default',
    };
  }
  if (s === 'vibrate' || s === 'silent') {
    // Canaux dédiés (vibration seule / silencieux) ; aucun champ `sound`.
    return { android: { channelId: `hopetsit_${s}` }, apnsSound: null, dataSound: s };
  }
  return {
    android: { channelId: `hopetsit_${s}`, sound: s },
    apnsSound: `${s}.caf`,
    dataSound: s,
  };
};

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

// v23.1.293 — Daniel : "les notifs ne sont pas traduites". CAUSE : user.language
// est souvent stocké en MOT COMPLET ("English", "German", "Português"…). Le
// simple slice(0,2) donnait "ge"/"po"/"sp" → codes invalides → fallback FR pour
// tout le monde. On mappe d'abord les noms complets (FR/EN/natifs) vers le code,
// puis on retombe sur le préfixe 2 lettres (gère "fr-FR", "es_ES", "en").
const LANGUAGE_NAME_TO_LOCALE = {
  french: 'fr', francais: 'fr', 'français': 'fr', fr: 'fr',
  english: 'en', anglais: 'en', en: 'en',
  spanish: 'es', espanol: 'es', 'español': 'es', espagnol: 'es', es: 'es',
  german: 'de', deutsch: 'de', allemand: 'de', de: 'de',
  italian: 'it', italiano: 'it', italien: 'it', it: 'it',
  portuguese: 'pt', portugues: 'pt', 'português': 'pt', portugais: 'pt', pt: 'pt',
  // v532 — le champ libre `language` peut contenir le nom natif (il est
  // proposé tel quel dans la liste des langues parlées du profil).
  korean: 'ko', coreen: 'ko', 'coréen': 'ko', '한국어': 'ko', ko: 'ko',
  japanese: 'ja', japonais: 'ja', '日本語': 'ja', ja: 'ja',
  polish: 'pl', polonais: 'pl', polski: 'pl', pl: 'pl', // v546
};
const resolveLocale = (userLanguage) => {
  const raw = String(userLanguage || '').toLowerCase().trim();
  if (!raw) return FALLBACK_LOCALE;
  if (LANGUAGE_NAME_TO_LOCALE[raw]) return LANGUAGE_NAME_TO_LOCALE[raw];
  const short = raw.slice(0, 2);
  return SUPPORTED_LOCALES.includes(short) ? short : FALLBACK_LOCALE;
};

const pickTemplate = (locale, type) => {
  const primary = loadCatalog(locale)[type];
  if (primary) return primary;
  return loadCatalog(FALLBACK_LOCALE)[type] || null;
};

// v530 — Daniel : « notifs mal traduites ». L'appLocale (langue UI synchronisée
// par l'app) n'était lue QUE sur le doc du rôle notifié/lecteur. Or l'app ne la
// synchronise que sur le rôle COURANT (PATCH /users/me/app-locale) → les 2
// autres profils de la même personne gardaient appLocale vide et retombaient
// sur le champ libre `language` (langues PARLÉES du profil, ex. « English »
// chez un utilisateur français) → notifs/push/emails en anglais. On cherche
// l'appLocale sur les 3 docs du groupe d'identité (même _id/email/oldId) —
// même famille de correctifs que gatherFcmTokens (v407) et identityGroup (v526).
const resolveAppLocaleAcrossRoles = async (primary, userId) => {
  if (primary?.appLocale) return primary.appLocale;
  try {
    const or = [{ _id: userId }];
    if (primary?.email) or.push({ email: primary.email });
    if (primary?.oldId != null) or.push({ oldId: primary.oldId });
    const [owners, sitters, walkers] = await Promise.all([
      Owner.find({ $or: or }).select('appLocale').lean(),
      Sitter.find({ $or: or }).select('appLocale').lean(),
      Walker.find({ $or: or }).select('appLocale').lean(),
    ]);
    const withLocale = [...owners, ...sitters, ...walkers].find((d) => d.appLocale);
    return withLocale ? withLocale.appLocale : null;
  } catch (e) {
    logger.warn(`[notif.locale] cross-role appLocale lookup failed : ${e?.message || e}`);
    return null;
  }
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
  const primary = await Model.findById(userId).select('email language appLocale fcmTokens name oldId notificationPrefs').lean();
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
      const found = await Fb.findById(userId).select('email language appLocale fcmTokens name oldId notificationPrefs').lean();
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

/**
 * v407 — Daniel : "push tel pas reçu alors que l'email oui" (demande de suivi).
 * CAUSE RACINE : registerFcmToken écrit le token UNIQUEMENT sur le doc du rôle
 * COURANT. Avec 1 compte = 3 profils (Owner/Sitter/Walker séparés), notifier le
 * rôle X lit X.fcmTokens — vides si le token a été enregistré sous un autre
 * rôle → sendPush saute ("no_tokens"). L'email partait quand même (résolu
 * cross-collection). FIX : on UNIT les fcmTokens des 3 docs de la MÊME personne
 * (même email / oldId / _id) avant d'envoyer le push → le push atteint le
 * device quel que soit le rôle sous lequel le token a été enregistré.
 * Bénéficie à TOUTES les notifs push, pas seulement au suivi.
 */
const gatherFcmTokens = async (primary, userId) => {
  const tokens = new Set((primary?.fcmTokens || []).filter(Boolean));
  try {
    const or = [{ _id: userId }];
    if (primary?.email) or.push({ email: primary.email });
    if (primary?.oldId) or.push({ oldId: primary.oldId });
    const [owners, sitters, walkers] = await Promise.all([
      Owner.find({ $or: or }).select('fcmTokens').lean(),
      Sitter.find({ $or: or }).select('fcmTokens').lean(),
      Walker.find({ $or: or }).select('fcmTokens').lean(),
    ]);
    [...owners, ...sitters, ...walkers].forEach((d) => {
      (d.fcmTokens || []).forEach((t) => {
        if (t) tokens.add(t);
      });
    });
  } catch (e) {
    logger.warn(`[notif.push] gatherFcmTokens failed : ${e?.message || e}`);
  }
  return Array.from(tokens);
};

const sendPush = async (tokens, title, body, data, { userId, role, sound } = {}) => {
  const list = (tokens || []).filter(Boolean);
  if (!list.length) {
    logger.warn('[notif.push] skipped : user has no fcmTokens registered');
    return { skipped: true, reason: 'no_tokens' };
  }
  // v565 §2 — son choisi par l'utilisateur (défaut = comportement v558).
  const snd = pushSoundConfig(sound);
  const message = {
    tokens: list,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries({ ...(data || {}), sound: snd.dataSound }).map(([k, v]) => [k, String(v ?? '')])
    ),
    // v558 (serveur seul) — Daniel : « je reçois les notifications en retard ».
    // Diagnostic Render : le serveur émet en ~1 s (entrée → push → e-mail
    // accepté par Gmail). Le retard vient (1) d'iOS : Firebase n'avait qu'une
    // clé APNs de DÉVELOPPEMENT → les builds App Store (aps-environment =
    // production) répondent `messaging/third-party-auth-error`, donc AUCUN
    // push iPhone, la notif n'apparaît qu'à l'ouverture de l'app ; (2) côté
    // Android, de l'économie d'énergie (Doze / « applications en veille »).
    // Ici on force explicitement la priorité HAUTE des deux côtés (FCM la met
    // par défaut pour les messages `notification`, mais on ne dépend plus de
    // ce défaut) + canal Android + son + type APNs « alert ».
    android: {
      priority: 'high',
      notification: { ...snd.android },
    },
    apns: {
      headers: { 'apns-priority': '10', 'apns-push-type': 'alert' },
      payload: { aps: snd.apnsSound ? { sound: snd.apnsSound } : {} },
    },
  };
  const result = await firebaseAdmin.messaging().sendEachForMulticast(message);
  if (result && (result.failureCount || 0) > 0) {
    logger.warn(
      `[notif.push] partial failure : success=${result.successCount} ` +
      `fail=${result.failureCount} (tokens checked=${list.length})`,
    );
    // v23.1 part 50 — auto-purge of dead FCM tokens. Daniel's walker doc
    // had accumulated 10 tokens (one per install/login over months) and
    // 9 of them were `messaging/registration-token-not-registered` —
    // these are tokens whose app instance has been uninstalled or whose
    // FCM SDK rotated the token. Each push attempt fanout-charges all
    // 10 tokens, even though only the most recent install can actually
    // receive ; over time this hurts delivery latency and Firebase
    // accidentally rate-limits us. We collect the dead tokens here and
    // pull them from the user's doc in a single $pullAll, leaving only
    // the valid ones. Idempotent — running this twice is a no-op.
    const deadTokens = [];
    (result.responses || []).forEach((r, i) => {
      if (r && !r.success && r.error) {
        const code = r.error.code || r.error.errorInfo?.code || 'unknown';
        logger.warn(`[notif.push] token #${i} rejected : ${code}`);
        // These error codes mean the token will NEVER work again ; safe to drop.
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/invalid-argument'
        ) {
          if (list[i]) deadTokens.push(list[i]);
        }
      }
    });
    if (deadTokens.length > 0 && userId && role) {
      try {
        const Model = _roleModelForPurge(role);
        if (Model) {
          await Model.findByIdAndUpdate(userId, {
            $pullAll: { fcmTokens: deadTokens },
          });
          logger.info(
            `[notif.push] purged ${deadTokens.length} dead token(s) from ${role}:${userId}`,
          );
        }
      } catch (e) {
        logger.warn(`[notif.push] dead-token purge failed : ${e?.message || e}`);
      }
    }
  }
  return result;
};

const _roleModelForPurge = (role) =>
  role === 'sitter' ? Sitter :
  role === 'owner' ? Owner :
  role === 'walker' ? Walker :
  null;

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
  // v23.1.348 — Daniel : la langue suit le système. appLocale (code UI synchronisé
  // par l'app : choix manuel OU langue du téléphone) est PRIORITAIRE sur le champ
  // libre language (langues parlées affichées sur les profils prestataires).
  // v530 — appLocale cherchée sur les 3 docs de rôle de la personne.
  const appLocale = await resolveAppLocaleAcrossRoles(user, userId);
  const locale = resolveLocale(appLocale || user.language);
  const tmpl = pickTemplate(locale, type);
  if (!tmpl) {
    logger.warn(`[notif.skip] template missing type=${type} locale=${locale}`);
    return;
  }
  // v23.1.155 — Daniel : "connecte les boutons quon recois par mail a
  // lapp ou le web". On injecte un `emailLink` universel
  // (https://hopetsit.com/...) calcule depuis le type de notif + le payload
  // data. Universal Links iOS / App Links Android → ouvrent l'app si
  // installee, sinon le site web. Les templates JSON utilisent
  // {{emailLink}} a la place des anciens `hopetsit://...` hardcoded.
  // v561 — Daniel : « du mail ou du push, direct sur l'app au thème
  // correspondant ». La route « thème » est calculée UNE fois par type
  // (buildAppRoute) et sert au bouton du mail (lien universel) ET au push
  // (champ `route`). Un `data.emailLink` fourni par l'appelant n'est gardé
  // que si le type n'a pas de route dédiée.
  const { buildAppRoute, BASE_URL: SITE_BASE } = require('../utils/emailLinkBuilder');
  const appRoute = buildAppRoute(type, data);
  const renderData = {
    ...data,
    emailLink:
      appRoute !== '/notifications' || !data.emailLink
        ? `${SITE_BASE}${appRoute}`
        : data.emailLink,
  };
  const title = render(tmpl.title, renderData);
  const body = render(tmpl.body, renderData);
  const emailSubject = render(tmpl.emailSubject, renderData);
  const emailBody = render(tmpl.emailBody, renderData);
  const email = decrypt(user.email || '');
  // v407 — union des fcmTokens sur les 3 docs de rôle (fix push multi-profils).
  const allTokens = await gatherFcmTokens(user, userId);
  const tokenCount = allTokens.length;
  // v565 §2 — préférences : catégorie coupée → ni push ni e-mail (in-app gardée).
  const prefs = await resolveNotificationPrefsAcrossRoles(user, userId);
  const category = categoryForType(type);
  const categoryEnabled = prefs.categories[category] !== false;
  if (!categoryEnabled) {
    logger.info(
      `[notif.prefs.skip] category=${category} disabled → push+email suppressed ` +
      `type=${type} role=${role} userId=${userId} (in-app kept)`,
    );
  }
  logger.info(
    `[notif.send] type=${type} role=${role} userId=${userId} ` +
    `locale=${locale} fcmTokens=${tokenCount} ` +
    `emailReady=${email && email.length > 3 ? 'yes' : 'NO'} ` +
    `category=${category} sound=${prefs.sound} ` +
    `title="${(title || '').slice(0, 60)}"`,
  );

  // v23.1.182 — Daniel : "il faut jme deco et reco pour voir la nouvelle
  // notif au lieu que se soit instentanee". Cause racine : avant on emit
  // 'notification.new' AVANT createNotificationSafe → le payload socket
  // n'avait PAS d'_id. Le frontend listener avait le bug : il ne pouvait
  // pas insérer la notif dans la liste live, juste bump le badge. Daniel
  // voyait donc le badge +1 mais aucune nouvelle ligne dans la bell list
  // tant qu'il n'avait pas reloadInitial (= deco/reco ou refresh écran).
  // Fix : on crée la notif EN PREMIER, on récupère l'id + createdAt, puis
  // on emit le payload COMPLET au socket. Frontend peut alors préfixer
  // direct dans la liste sans refetch.
  const inAppCreated = await createNotificationSafe({
    recipientRole: role,
    recipientId: userId,
    actorRole: actor?.role || null,
    actorId: actor?.id || null,
    type,
    title,
    body,
    data,
  });

  // Real-time socket push avec payload complet (id + recipientRole +
  // createdAt) pour insertion live dans la bell list — best-effort.
  try {
    const socketPayload = {
      type,
      title,
      body,
      data,
      recipientRole: role,
      recipientId: String(userId),
      actorRole: actor?.role || null,
      actorId: actor?.id ? String(actor.id) : null,
    };
    if (inAppCreated) {
      socketPayload.id = String(inAppCreated._id);
      socketPayload._id = String(inAppCreated._id);
      socketPayload.notificationId = String(inAppCreated._id);
      socketPayload.createdAt = inAppCreated.createdAt
        ? new Date(inAppCreated.createdAt).toISOString()
        : new Date().toISOString();
      socketPayload.readAt = null;
    }
    emitToUser(role, userId, 'notification.new', socketPayload);
  } catch (_) { /* noop */ }

  // v448 — gating email hors-ligne pour les types à fort volume (messages).
  // Si le destinataire a un socket connecté (app ouverte), il voit déjà la
  // notif en direct → on n'envoie PAS l'email (évite le spam + le retard
  // Gmail). Best-effort : en cas de doute, l'email part.
  let sendEmailNow = Boolean(email) && categoryEnabled;
  if (sendEmailNow &&
      PRESENCE_GATED_EMAIL_TYPES.has(String(type).toLowerCase())) {
    try {
      const online = await isUserOnline(userId);
      if (online) {
        sendEmailNow = false;
        logger.info(
          `[notif.email.skip] recipient ONLINE → email suppressed type=${type} role=${role} userId=${userId}`,
        );
      }
    } catch (_) {
      /* doute → on laisse partir l'email */
    }
  }

  const results = await Promise.allSettled([
    Promise.resolve(inAppCreated),
    // v23.1.317 — Daniel : "notifs pas en doublon". CAUSE : le payload FCM ne
    // contenait PAS l'id de la notif → la dédup côté app (_markSeenOrDupe, qui
    // lit data.notificationId) ne pouvait jamais rapprocher le push et l'event
    // socket → badge compté 2×. On injecte notificationId dans le data push.
    categoryEnabled
      ? sendPush(
        allTokens,
        title,
        body,
        {
          type,
          ...data,
          // v561 — même chemin que le bouton du mail : l'app l'ouvre au tap.
          route: appRoute,
          ...(inAppCreated && inAppCreated._id
            ? { notificationId: String(inAppCreated._id) }
            : {}),
        },
        { userId, role, sound: prefs.sound },
      )
      : Promise.resolve({ skipped: true, reason: `prefs_category_off:${category}` }),
    sendEmailNow
      ? sendEmail(email, emailSubject, body, emailBody)
      : Promise.resolve({ skipped: true, reason: categoryEnabled ? 'no_email' : `prefs_category_off:${category}` }),
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

// v497 — Daniel : « je suis en espagnol mais les notifs du site sortent en FR ».
// Les notifs sont rendues à l'ENVOI (locale d'alors) puis STOCKÉES → un
// changement de langue ne les retraduisait pas. Ce helper RE-REND le titre/corps
// d'une notif depuis son `type` + `data` dans la langue COURANTE du lecteur
// (utilisé par GET /notifications/my) → la langue des notifs suit l'UI, app+web.
// Retourne null si aucun template (on garde alors le texte stocké).
const renderNotificationContent = (type, data = {}, userLanguage) => {
  try {
    const locale = resolveLocale(userLanguage);
    const tmpl = pickTemplate(locale, type);
    if (!tmpl) return null;
    const safeData = data && typeof data === 'object' ? data : {};
    return {
      title: render(tmpl.title, safeData),
      body: render(tmpl.body, safeData),
    };
  } catch (_) {
    return null;
  }
};

module.exports = {
  sendNotification,
  renderNotificationContent,
  resolveAppLocaleAcrossRoles,
  // v565 §2
  NOTIFICATION_SOUNDS,
  NOTIFICATION_CATEGORIES,
  defaultNotificationPrefs,
  normalizeNotificationPrefs,
  categoryForType,
  resolveNotificationPrefsAcrossRoles,
  pushSoundConfig,
};
