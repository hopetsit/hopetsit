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
}
