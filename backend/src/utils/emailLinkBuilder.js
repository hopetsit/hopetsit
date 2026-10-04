/**
 * Liens des notifications (e-mail + push) → écran précis de l'app.
 *
 * v23.1.155 : liens universels `https://hopetsit.com/...` (App Links Android +
 * Universal Links iOS : app ouverte si installée, site sinon).
 * v449 : tout avait été rabattu sur UN lien `/open` (« 1 lien, 2 issues »).
 * v561 — Daniel : « quand je reçois le mail ou le push, ça doit envoyer
 * DIRECT sur l'app au thème correspondant, pas d'abord sur le site ; et
 * "Voir mes amis" donnait un écran noir ». On revient à un vrai lien par
 * type, calculé UNE fois ici et utilisé :
 *   - par l'e-mail  : `{{emailLink}}` = BASE_URL + route ;
 *   - par le push   : champ `route` du payload FCM (même chemin) ;
 *   - par l'app     : DeepLinkService.openRoute(route) (mêmes chemins que les
 *     liens universels, déclarés dans apple-app-site-association + manifest).
 *
 * Chemins compris par l'app (deep_link_service.dart) :
 *   /bookings[/:id]  /pay?bookingId=  /chat[/:conversationId]  /walk/:id
 *   /post/:id  /wallet  /subscription  /paw-spot  /profile  /notifications
 *   /friends  /friends/requests  /friends/live  /alert/:reportId  /map
 */
// v565 — Daniel : « le bouton d'un e-mail ouvre encore le SITE ». Cause : Apple exige
// que le fichier apple-app-site-association soit servi SANS redirection ; or
// https://hopetsit.com/.well-known/… répond 308 → www. Les liens universels
// ne sont donc valides que sur www.hopetsit.com → on génère TOUS les liens sur www.
const BASE_URL = (process.env.WEBSITE_URL || 'https://www.hopetsit.com').replace(
  /\/+$/,
  '',
);

const isId = (v) => typeof v === 'string' && /^[a-fA-F0-9]{24}$/.test(v);
const pick = (data, ...keys) => {
  for (const k of keys) {
    const v = data && data[k] != null ? String(data[k]) : '';
    if (isId(v)) return v;
  }
  return '';
};

/**
 * Route « thème » pour un type de notification (insensible à la casse).
 * Retourne toujours un chemin (fallback `/notifications`).
 */
const buildAppRoute = (notifType, data = {}) => {
  const t = String(notifType || '').toLowerCase();
  const d = data || {};
  const bookingId = pick(d, 'bookingId', 'id');
  const bookingPath = bookingId ? `/bookings/${bookingId}` : '/bookings';
  const conversationId = pick(d, 'conversationId');
  const chatPath = conversationId ? `/chat/${conversationId}` : '/chat';
  const postId = pick(d, 'postId');
  const postPath = postId ? `/post/${postId}` : '/bookings';
  const reportId = pick(d, 'reportId');

  // Réservation à payer (le prestataire vient d'accepter, paiement échoué…)
  if (t === 'booking_accepted' || t === 'payment_failed' ||
      t === 'payment_required') {
    return bookingId ? `/pay?bookingId=${bookingId}` : bookingPath;
  }
  // Chat déverrouillé / message / option chat
  if (t === 'new_message' || t === 'message' || t === 'chat_auto_welcome' ||
      t === 'booking_paid_chat_unlocked') {
    return conversationId ? chatPath : (t === 'booking_paid_chat_unlocked' ? bookingPath : '/chat');
  }
  if (t === 'chat_addon_activated') return '/chat';
  // Balade suivie
  if (t === 'walk_started' || t === 'walk_finished') {
    return bookingId ? `/walk/${bookingId}` : bookingPath;
  }
  // Annonces
  if (t === 'new_request_nearby' || t === 'new_request_for_you' || t === 'post_new' ||
      t === 'post_application_eligible' ||
      t === 'application_rejected_other_accepted') {
    return postPath;
  }
  // Tout le déroulé d'une réservation / candidature / service / rapport
  if (t.startsWith('booking_') || t.startsWith('application_') ||
      t.startsWith('service_') || t.startsWith('handover_') ||
      t === 'visit_report' || t === 'payment_success') {
    return bookingPath;
  }
  // Argent
  if (t.startsWith('payout_') || t.startsWith('withdrawal_') ||
      t === 'wallet_credited') {
    return '/wallet';
  }
  // Profil / badges / identité
  if (t === 'new_review' || t === 'premium_achieved' ||
      t === 'top_sitter_achieved' || t.startsWith('kyc_')) {
    return '/profile';
  }
  // Boutique
  if (t === 'referral_credited' || t.startsWith('map_boost') ||
      t === 'profile_boost_activated') {
    return '/paw-spot';
  }
  if (t.startsWith('subscription_')) return '/subscription';
  // Amis / famille / suivi en direct
  if (t === 'friend_request_received' || t === 'family_invitation_received') {
    return '/friends/requests';
  }
  // v602 — Daniel : « je tape sur la notification de demande de suivi, ça
  // m'envoie sur les Amis ». La demande, son acceptation et son refus vivent
  // dans une carte du CHAT (boutons Accepter / Refuser, « Voir sur la
  // carte ») : on ouvre cette conversation. Sans conversation connue : la
  // liste des conversations (demande, refus) ou les personnes en direct
  // (acceptation) — jamais l'écran Amis, qui ne montre pas ces demandes.
  if (t === 'live_tracking_request_received' || t === 'live_tracking_refused') {
    return conversationId ? chatPath : '/chat';
  }
  if (t === 'live_tracking_accepted') return conversationId ? chatPath : '/friends/live';
  // v566 — audit : partage en direct « toujours actif » / « session terminée »
  // tombaient sur /notifications côté serveur alors que l'app les route vers
  // /friends/live (DeepLinkService.routeForNotification) → même chemin des deux côtés.
  if (t === 'live_still_active' || t === 'live_session_ended') return '/friends/live';
  if (t.startsWith('friend_') || t.startsWith('family_') ||
      t.startsWith('live_tracking')) {
    return '/friends';
  }
  // Carte : SOS / animal aperçu
  if (t === 'sos_pet_nearby' || t === 'lost_pet_sighting' || t === 'good_samaritan_premium') {
    return reportId ? `/alert/${reportId}` : '/map';
  }
  return '/notifications';
};

/**
 * Lien e-mail par « famille » (compatibilité avec les appels existants :
 * buildEmailLink('walk', {bookingId}), ('chat', {conversationId}),
 * ('friends'), ('notifications'), ('booking'|'wallet'|'pay'|'post'…)).
 */
const buildDeepLink = (type, params = {}) => {
  const p = params || {};
  const bookingId = pick(p, 'bookingId');
  switch (String(type || '').toLowerCase()) {
    case 'booking':
    case 'booking_paid':
    case 'booking_accepted':
    case 'booking_canceled':
    case 'visit_report':
    case 'application':
    case 'application_new':
      return bookingId ? `/bookings/${bookingId}` : '/bookings';
    case 'pay':
    case 'payment':
    case 'payment_success':
    case 'payment_failed':
      return bookingId ? `/pay?bookingId=${bookingId}` : '/bookings';
    case 'chat':
    case 'message':
    case 'new_message': {
      const c = pick(p, 'conversationId');
      return c ? `/chat/${c}` : '/chat';
    }
    case 'walk':
    case 'walk_live':
      return bookingId ? `/walk/${bookingId}` : '/bookings';
    case 'post':
    case 'post_new': {
      const id = pick(p, 'postId');
      return id ? `/post/${id}` : '/bookings';
    }
    case 'notifications':
      return '/notifications';
    case 'friends':
    case 'friend_request':
      return '/friends';
    case 'live_tracking':
      return '/friends/requests';
    case 'profile':
    case 'kyc':
      return '/profile';
    case 'subscription':
    case 'paw_pass':
    case 'paw_follow':
      return '/subscription';
    case 'paw_spot':
    case 'map_boost':
      return '/paw-spot';
    case 'payout':
    case 'payout_succeeded':
    case 'payout_failed':
    case 'wallet':
    case 'wallet_credited':
      return '/wallet';
    case 'home':
    case 'open':
      return '/open';
    default:
      return '/notifications';
  }
};

const buildEmailLink = (type, params = {}) => `${BASE_URL}${buildDeepLink(type, params)}`;

/** Lien e-mail complet pour un type de notification + son payload. */
const buildEmailLinkFromNotification = (notifType, data = {}) =>
  `${BASE_URL}${buildAppRoute(notifType, data)}`;

// ───────────────────────── v603 (ZOE) — liens des e-mails ─────────────────────────
// Daniel (29/09) : « pourquoi ça n'a pas été fait ? » — le 602 envoie la cloche et
// le push sur la tâche PRÉCISE (DeepLinkService.routeForNotification), mais le
// bouton des e-mails gardait les routes « thème » d'avant (liste des réservations,
// profil, écran Amis…). buildEmailRoute est le MIROIR EXACT du routeur de l'app
// 602 (test de parité : tests/emailLink603.test.js lit la table du test Dart).
//
// buildAppRoute (au-dessus) reste INCHANGÉ : c'est le champ `route` du push, lu tel
// quel par les apps 598-601.
//
// Compatibilité 598-602 : cinq cibles n'existent que depuis le 602 et ne sont PAS
// déclarées comme liens universels dans les apps déjà installées
//   /request/<id>  /application/<id>  /identity  /reviews  /member/<rôle>/<id>
// (Android : filtre d'intention figé dans l'APK ; une app 598-601 ne sait pas les
// ouvrir). On ne les met dans l'e-mail que si TOUS les appareils de la personne
// savent les ouvrir : iOS ≥ 602 (fichier apple-app-site-association du site, mis à
// jour le 29/09) et Android ≥ 603 (filtre ajouté au manifeste du 603). Sinon, la
// cible la plus précise que ces apps comprennent (fiche de la réservation, demande,
// profil, écran Amis). Personne sans appareil connu = lien web (mêmes replis).
const PRECISE_IOS_MIN_BUILD = 602;
const PRECISE_ANDROID_MIN_BUILD = 603;
const PRECISE_ONLY_RE = /^\/(request|application|identity|reviews|member)(\/|$|\?)/;

const buildPreciseRoute = (notifType, data = {}, role = '') => {
  const t = String(notifType || '').toLowerCase();
  const d = data || {};
  const r = String(role || d.recipientRole || '').toLowerCase();
  const isOwner = r === 'owner';
  const isProvider = r === 'sitter' || r === 'walker';
  const bookingId = pick(d, 'bookingId') || pick(d, 'id');
  const bookingPath = bookingId ? `/bookings/${bookingId}` : '/bookings';
  const conv = pick(d, 'conversationId');
  const chatPath = conv ? `/chat/${conv}` : '/chat';
  const postId = pick(d, 'postId');
  const postPath = postId ? `/post/${postId}` : '/bookings';
  const reportId = pick(d, 'reportId');
  const applicationId = pick(d, 'applicationId');

  // Suivi en direct : territoire de PAM, route serveur (602) inchangée.
  if (t.startsWith('live_')) return buildAppRoute(notifType, d);
  if (t === 'booking_accepted' || t === 'payment_failed' || t === 'payment_required') {
    return bookingId ? `/pay?bookingId=${bookingId}` : bookingPath;
  }
  if (t === 'booking_mutually_accepted') {
    return isOwner && bookingId ? `/pay?bookingId=${bookingId}` : bookingPath;
  }
  if (t === 'new_message' || t === 'message' || t === 'message_new' ||
      t === 'chat_auto_welcome' || t === 'booking_paid_chat_unlocked') {
    return conv ? chatPath : (t === 'booking_paid_chat_unlocked' ? bookingPath : '/chat');
  }
  if (t === 'chat_addon_activated') return '/chat';
  if (t === 'walk_started' || t === 'walk_finished') {
    return bookingId ? `/walk/${bookingId}` : bookingPath;
  }
  if (t === 'booking_new') {
    if (!bookingId) return '/bookings';
    return isOwner ? bookingPath : `/request/${bookingId}`;
  }
  if (t === 'application_new') {
    if (applicationId && !isProvider) return `/application/${applicationId}`;
    return postId ? postPath : '/bookings';
  }
  if (t === 'application_rejected') return postId ? postPath : '/bookings';
  if (t === 'new_request_nearby' || t === 'new_request_for_you' || t === 'post_new' ||
      t === 'post_application_eligible' || t === 'application_rejected_other_accepted' ||
      t.startsWith('post_')) {
    return postPath;
  }
  if (t.startsWith('booking_') || t.startsWith('application_') ||
      t.startsWith('service_') || t.startsWith('handover_') ||
      t === 'visit_report' || t === 'payment_success') {
    return bookingPath;
  }
  if (t.startsWith('payout_') || t.startsWith('withdrawal_') ||
      t === 'wallet_credited' || t.includes('wallet')) {
    return '/wallet';
  }
  if (t.startsWith('kyc_')) return '/identity';
  if (t === 'new_review') return '/reviews';
  if (t === 'premium_achieved' || t === 'top_sitter_achieved') return '/profile';
  if (t.startsWith('map_boost') || t === 'profile_boost_activated') return '/shop/0';
  if (t === 'referral_credited') return '/shop/1';
  if (t.startsWith('subscription_')) {
    const plan = String(d.plan || '').toLowerCase();
    return plan.startsWith('premium') ? '/shop/3' : '/shop/1';
  }
  if (t === 'pawspot_validated' || t === 'pawspot_popular') {
    const spotId = pick(d, 'spotId');
    return spotId ? `/spot/${spotId}` : '/shop/2';
  }
  if (t === 'friend_request_received' || t === 'family_invitation_received') {
    return '/friends/requests';
  }
  if (t === 'friend_request_accepted') {
    const who = pick(d, 'byUserId');
    const whoRole = String(d.byUserRole || '').toLowerCase();
    if (who && ['owner', 'sitter', 'walker'].includes(whoRole)) {
      return `/member/${whoRole}/${who}`;
    }
    return '/friends';
  }
  if (t.startsWith('family_')) return '/friends/family';
  if (t.startsWith('friend_')) return '/friends';
  if (t === 'sos_pet_nearby' || t === 'lost_pet_sighting' || t === 'good_samaritan_premium') {
    return reportId ? `/alert/${reportId}` : '/map';
  }
  return '/notifications';
};

/** Repli d'une cible 602 pour les apps qui ne la connaissent pas (598-601). */
const legacyFallbackFor = (route, data = {}) => {
  const segs = String(route || '').split('?')[0].split('/').filter(Boolean);
  switch (segs[0]) {
    case 'request':
      return segs[1] ? `/bookings/${segs[1]}` : '/bookings';
    case 'application': {
      const postId = pick(data || {}, 'postId');
      return postId ? `/post/${postId}` : '/bookings';
    }
    case 'identity':
    case 'reviews':
      return '/profile';
    case 'member':
      return '/friends';
    default:
      return route;
  }
};

/** Un appareil ouvre-t-il directement les cibles propres au 602 ? */
const deviceOpensPreciseLinks = (dev) => {
  if (!dev || !dev.token) return false;
  const platform = String(dev.platform || '').toLowerCase();
  const build = Number(dev.appBuild || 0);
  if (platform === 'ios') return build >= PRECISE_IOS_MIN_BUILD;
  if (platform === 'android') return build >= PRECISE_ANDROID_MIN_BUILD;
  return false;
};

const routeNeedsRecentApp = (route) => PRECISE_ONLY_RE.test(String(route || ''));

/**
 * Chemin du bouton d'un e-mail de notification.
 * @param {string} notifType
 * @param {object} data     payload de la notification
 * @param {object} opts     { role, devices } — devices = appareils ACTIFS de la
 *                          personne ({platform, appBuild, token}) ; absent = inconnu.
 */
const buildEmailRoute = (notifType, data = {}, opts = {}) => {
  const { role = '', devices = null } = opts || {};
  const precise = buildPreciseRoute(notifType, data, role);
  if (!routeNeedsRecentApp(precise)) return precise;
  const list = Array.isArray(devices) ? devices : [];
  if (list.length > 0 && list.every(deviceOpensPreciseLinks)) return precise;
  return legacyFallbackFor(precise, data);
};

module.exports = {
  buildAppRoute,
  buildPreciseRoute,
  buildEmailRoute,
  legacyFallbackFor,
  deviceOpensPreciseLinks,
  routeNeedsRecentApp,
  PRECISE_IOS_MIN_BUILD,
  PRECISE_ANDROID_MIN_BUILD,
  buildDeepLink,
  buildEmailLink,
  buildEmailLinkFromNotification,
  BASE_URL,
};
