class AppConstants {
  static const bool isDevelopment = true;
  static const bool useLocalhost = true; // Set to true to use localhost:5000

  /// Feature flag: hide PayPal payout option for new sitters.
  /// Existing accounts with a PayPal email already saved keep seeing it (read-only).
  static const bool showPayPalOption = false;
  // static const String googleMapKey = "AIzaSyD-BQGjOLl-ovWguecsCmqOEOBO5MZcvJk";

  static const double initialLat = 19.07283000;
  static const double initialLong = 72.88261000;

  /// v18.9.8 — taux de commission plateforme appliqué au-dessus du tarif
  /// provider côté owner. Gardé en mémoire pour les écrans d'estimation
  /// ET comme garde-fou si le backend ne renvoie pas la valeur.
  /// SOURCE DE VÉRITÉ : backend/src/utils/pricing.js PLATFORM_COMMISSION_RATE.
  /// Toujours préférer `booking.pricing.commission` quand dispo.
  static const double platformCommissionRate = 0.20;
}
