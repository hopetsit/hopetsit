/// Keys used for persisting values in GetStorage.
class StorageKeys {
  StorageKeys._();

  static const String authToken = 'auth_token';
  static const String userProfile = 'user_profile';
  static const String userRole = 'user_role';
  static const String languageCode = 'language_code';
  // v20.2.1 — chemin local de la photo de profil sélectionnée pendant
  // l'inscription. Utilisé par OtpVerificationController pour uploader la
  // photo via /users/me/profile-picture une fois l'auth token disponible.
  // Effacé immédiatement après upload (ou si l'upload échoue 3 fois).
  static const String pendingSignupPhotoPath = 'pending_signup_photo_path';
  // v23.1 — bug : owner-pay banner dismiss must survive app restart so a
  // dismissed booking does not reappear on next app open. Cleared at logout
  // to avoid leaking dismiss state across accounts.
  static const String dismissedBannerBookings = 'dismissed_banner_bookings';
  // Dernier code promo "% de réduction" appliqué (validé + consommé côté
  // serveur). Persisté localement pour pré-remplir la boutique. JSON :
  // { code, discountPercent, plan }. Effacé au logout (compte-spécifique).
  static const String redeemedPromoDiscount = 'redeemed_promo_discount';
  // v565 — pop-up promo discret (docs/v565_contracts.md §9) : affiché UNE fois,
  // jamais à la 1re ouverture. `appOpenCount` est incrémenté à chaque montage
  // du wrapper de navigation ; `promoPopupShown` mémorise l'affichage.
  static const String appOpenCount = 'app_open_count';
  static const String promoPopupShown = 'promo_popup_shown_v565';
  // v565 — cache local des préférences de notification (§2) pour un affichage
  // immédiat avant la réponse de GET /users/me/notification-prefs.
  static const String notificationPrefsCache = 'notification_prefs_cache_v565';
}
