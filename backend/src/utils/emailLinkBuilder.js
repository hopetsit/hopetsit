/**
 * v23.1.155 — Email CTA link builder.
 *
 * Daniel : "connecte les boutons quon recois par mail a lapp ou le web".
 *
 * Avant cette session, tous les templates de mail pointaient vers des liens
 * custom-scheme `hopetsit://...`. Resultat : sur desktop, click = navigateur
 * affiche une erreur "app non trouvee" et l'utilisateur perd le lien. Sur
 * mobile sans l'app installee : meme erreur.
 *
 * Solution : universal links / app links. Le format `https://hopetsit.com/...`
 * est intercepte par iOS Universal Links (via apple-app-site-association)
 * ET par Android App Links (via assetlinks.json + autoVerify=true) =>
 * ouverture automatique dans l'app. Si l'app n'est pas installee, le
 * navigateur charge naturellement le site web. UN seul lien, deux comportements.
 *
 * Configuration requise cote app (deja en place) :
 *   - iOS : Runner.entitlements declare `webcredentials:hopetsit.com`,
 *     `applinks:hopetsit.com`, `applinks:www.hopetsit.com`,
 *     `applinks:app.hopetsit.com`. Voir v23.1 part 146.
 *   - Android : AndroidManifest.xml a un intent-filter avec
 *     `android:autoVerify="true"` pour `https://hopetsit.com/*`.
 *   - Le site web a un fichier `.well-known/apple-app-site-association`
 *     et `.well-known/assetlinks.json` servis en HTTPS.
 *
 * Le frontend (deep_link_service.dart lines 155-224) handle deja les
 * routes /bookings/:id, /pay, /chat[/:id], /notifications, /auth?ott=
 * Pour les nouvelles routes (/application/:id, /post/:id), voir v23.1.155
 * patch deep_link_service.
 *
 * Le site web (Next.js) a deja les pages :
 *   - /bookings (liste)
 *   - /pay et /pay/done
 *   - /chat
 *   - /walk/[bookingId]
 *   - /book/[id]
 * Pour les routes manquantes (/bookings/:id detail, /application/:id),
 * le routing Next.js peut faire un fallback vers /bookings avec une
 * query `?focus=:id`.
 *
 * @param {string} type - 'booking' | 'application' | 'pay' | 'chat' |
 *                        'walk' | 'post' | 'notifications' | 'profile' |
 *                        'subscription' | 'paw_spot' | 'paw_pass' | null
 * @param {Object} [params] - resource ids (bookingId, conversationId, ...)
 * @returns {string} - https://hopetsit.com/... URL
 */
const BASE_URL = (process.env.WEBSITE_URL || 'https://hopetsit.com').replace(
  /\/+$/,
  '',
);

// v449 — Daniel : « tous les boutons des emails : ouvrir l'app si installée,
// sinon rediriger vers /download. Jamais une page vide ou ancienne. Logique
// simple et fiable. Ne route PAS vers une conversation précise. »
//
// On centralise sur UN lien canonique `${BASE_URL}/open` :
//   - App installée → l'OS intercepte l'App Link / Universal Link et ouvre
//     l'app (qui affiche l'accueil, ou le login puis l'accueil si déconnecté).
//   - App NON installée → le navigateur charge la page web `/open` qui
//     redirige immédiatement vers `/download`.
// Ce comportement « 1 lien, 2 issues » est plus fiable que d'envoyer des
// routes web profondes (qui pouvaient tomber sur une page vide/ancienne).
const APP_OPEN_LINK = `${BASE_URL}/open`;

const buildEmailLink = (/* type, params */) => APP_OPEN_LINK;

// Ancienne logique de routage profond, conservée pour référence / réusage
// éventuel hors-email. NON utilisée par les emails depuis v449.
// eslint-disable-next-line no-unused-vars
const buildDeepLink = (type, params = {}) => {
  const p = params || {};
  switch ((type || '').toLowerCase()) {
    case 'booking':
    case 'booking_paid':
    case 'booking_accepted':
    case 'booking_canceled':
    case 'visit_report':
      // /bookings/:id ouvre la fiche detail dans l'app (deep link existant)
      // ou affiche la liste filtree sur le site web (fallback).
      return p.bookingId
        ? `${BASE_URL}/bookings/${p.bookingId}`
        : `${BASE_URL}/bookings`;

    case 'application':
    case 'application_new':
      // /bookings/:id (l'app montre les applications dans le detail booking).
      // Note : pas de page web dediee `/applications/:id` — fallback liste.
      return p.bookingId
        ? `${BASE_URL}/bookings/${p.bookingId}`
        : `${BASE_URL}/bookings`;

    case 'pay':
    case 'payment':
    case 'payment_success':
    case 'payment_failed':
      // /pay ouvre l'ecran de paiement. Si on a bookingId, on l'utilise
      // comme intent pour reprendre le booking et relancer le PI cote
      // owner.
      if (p.bookingId) {
        return `${BASE_URL}/pay?bookingId=${p.bookingId}`;
      }
      return `${BASE_URL}/pay`;

    case 'chat':
    case 'message':
    case 'new_message':
      // /chat[/:conversationId] - le service web a une page /chat liste
      // + l'app deep-link supporte ?conversation=:id.
      if (p.conversationId) {
        return `${BASE_URL}/chat/${p.conversationId}`;
      }
      return `${BASE_URL}/chat`;

    case 'walk':
    case 'walk_live':
      // /walk/:bookingId - page Next.js existante pour le suivi live.
      return p.bookingId
        ? `${BASE_URL}/walk/${p.bookingId}`
        : `${BASE_URL}/bookings`;

    case 'post':
    case 'post_new':
      // /book/:id - page Next.js existante pour les annonces owner.
      return p.postId
        ? `${BASE_URL}/book/${p.postId}`
        : `${BASE_URL}/`;

    case 'notifications':
      return `${BASE_URL}/notifications`;

    case 'friends':
    case 'friend_request':
    case 'live_tracking':
      // v496 — Daniel : « depuis l'email, le bouton "Voir la demande" donne un
      // GRAND ÉCRAN NOIR au lieu de rediriger vers /download ». L'ancien lien
      // `/friends/live` ouvrait l'app sur un écran authentifié (écran noir si
      // pas connecté) côté mobile, et redirigeait vers `/map` côté web (pas de
      // fallback /download). On bascule sur le lien CANONIQUE `/open` (v449) :
      //   - app installée + connecté → l'app s'ouvre (la demande est déjà dans
      //     le bandeau d'accueil + la cloche) ;
      //   - app installée + PAS connecté → onboarding (login), plus d'écran noir
      //     (deep_link_service no-op gracieux v496) ;
      //   - app absente / navigateur → /open redirige vers /download.
      return APP_OPEN_LINK;

    case 'profile':
    case 'kyc':
      // /profile - lien generique vers le profil (app ouvre l'onglet
      // profil du role courant). KYC verifie/refuse → l'user va sur son
      // profil voir le badge / relancer la verification.
      return `${BASE_URL}/profile`;

    case 'subscription':
    case 'paw_pass':
    case 'paw_follow':
      return `${BASE_URL}/subscription`;

    case 'paw_spot':
    case 'map_boost':
      return `${BASE_URL}/paw-spot`;

    case 'payout':
    case 'payout_succeeded':
    case 'payout_failed':
    case 'wallet':
    case 'wallet_credited':
      // /wallet (page provider) - permet de voir le solde et l'historique.
      return `${BASE_URL}/wallet`;

    default:
      // Fallback : la page d'accueil. Mieux que rien si le type est
      // inconnu (template typo, nouveau type pas encore mappe).
      return `${BASE_URL}/`;
  }
};

/**
 * Helper de plus haut niveau : derive type + params depuis le payload
 * notification (sendNotification's `data` arg). Centralise la logique
 * de mapping pour ne pas la dupliquer dans chaque caller.
 */
const buildEmailLinkFromNotification = (notifType, data = {}) => {
  const t = (notifType || '').toLowerCase();
  // Map les types de notification specifiques vers le type de lien
  // approprie. Cette table de routage encapsule les bonnes URL.
  if (t.startsWith('booking_paid') || t === 'booking_accepted' ||
      t === 'booking_canceled' || t === 'booking_new' ||
      t === 'booking_cancelled_by_owner' || t === 'booking_cancelled_by_provider') {
    return buildEmailLink('booking', { bookingId: data.bookingId || data.id });
  }
  if (t === 'application_new' || t === 'application_accepted' ||
      t === 'application_rejected') {
    return buildEmailLink('application', {
      bookingId: data.bookingId || data.applicationId,
    });
  }
  if (t === 'payment_success' || t === 'payment_failed' ||
      t === 'payment_required') {
    return buildEmailLink('pay', { bookingId: data.bookingId });
  }
  if (t === 'new_message' || t === 'message') {
    return buildEmailLink('chat', { conversationId: data.conversationId });
  }
  if (t === 'visit_report') {
    return buildEmailLink('booking', { bookingId: data.bookingId });
  }
  if (t === 'walk_started' || t === 'walk_finished') {
    return buildEmailLink('walk', { bookingId: data.bookingId });
  }
  if (t === 'post_new' || t === 'post_application_eligible') {
    return buildEmailLink('post', { postId: data.postId });
  }
  if (t === 'payout_succeeded' || t === 'payout_failed' ||
      t === 'withdrawal_completed' || t === 'withdrawal_failed' ||
      t === 'wallet_credited') {
    return buildEmailLink('wallet');
  }
  if (t === 'subscription_renewed' || t === 'subscription_canceled') {
    return buildEmailLink('subscription');
  }
  if (t === 'map_boost_active' || t === 'map_boost_expired' ||
      t === 'map_boost_activated' || t === 'profile_boost_activated') {
    // Boost carte / profil active → page PawSpot (mise en avant).
    return buildEmailLink('paw_spot');
  }
  if (t === 'subscription_activated') {
    return buildEmailLink('subscription');
  }
  if (t === 'chat_addon_activated') {
    return buildEmailLink('chat');
  }
  if (t === 'kyc_verified' || t === 'kyc_rejected' ||
      t === 'kyc_payment_succeeded') {
    // Verification d'identite → profil (voir le badge ou relancer).
    return buildEmailLink('profile');
  }
  if (t === 'application_rejected_other_accepted') {
    // L'annonce a ete pourvue par un autre prestataire → renvoie vers
    // l'annonce (l'app/web peut afficher d'autres annonces similaires).
    return buildEmailLink('post', { postId: data.postId });
  }
  if (t === 'friend_request_received' || t === 'friend_request_accepted' ||
      t === 'family_member_added' || t === 'family_invitation_received' ||
      t === 'family_invitation_accepted' || t === 'family_invitation_refused' ||
      t === 'live_tracking_request_received' || t === 'live_tracking_accepted' ||
      t === 'live_tracking_refused') {
    // Amis / famille / suivi live → page /friends (liste + live).
    return buildEmailLink('friends');
  }
  // Default : home
  return buildEmailLink('home');
};

module.exports = {
  buildEmailLink,
  buildEmailLinkFromNotification,
  BASE_URL,
};
