class AppConstants {
  static const bool isDevelopment = true;
  static const bool useLocalhost = true; // Set to true to use localhost:5000

  /// Feature flag: hide PayPal payout option for new sitters.
  /// Existing accounts with a PayPal email already saved keep seeing it (read-only).
  static const bool showPayPalOption = false;
  // static const String googleMapKey = "AIzaSyD-BQGjOLl-ovWguecsCmqOEOBO5MZcvJk";

  static const double initialLat = 19.07283000;
  static const double initialLong = 72.88261000;
}
