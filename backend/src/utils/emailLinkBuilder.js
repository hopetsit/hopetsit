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
const BASE_URL = (process.env.WEBSITE_URL || 'https://hopetsit.com').replace(
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
  if (t === 'new_request_nearby' || t === 'post_new' ||
      t === 'post_application_eligible' ||
      t === 'application_rejected_other_accepted') {
    return postPath;
  }
  // Tout le déroulé d'une réservation / candidature / service / rapport
  if (t.startsWith('booking_') || t.startsWith('application_') ||
      t.startsWith('service_') || t === 'visit_report' ||
      t === 'payment_success') {
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
  if (t === 'live_tracking_request_received') {
    return conversationId ? chatPath : '/friends/requests';
  }
  if (t === 'live_tracking_accepted') return '/friends/live';
  if (t.startsWith('friend_') || t.startsWith('family_') ||
      t.startsWith('live_tracking')) {
    return '/friends';
  }
  // Carte : SOS / animal aperçu
  if (t === 'sos_pet_nearby' || t === 'lost_pet_sighting') {
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

module.exports = {
  buildAppRoute,
  buildDeepLink,
  buildEmailLink,
  buildEmailLinkFromNotification,
  BASE_URL,
};
