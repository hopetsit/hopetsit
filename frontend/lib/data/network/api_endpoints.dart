/// Holds the API endpoint paths used across the app.
class ApiEndpoints {
  ApiEndpoints._();

  static const String users = '/users';
  static const String authLogin = '/auth/login';
  static const String authSignup = '/auth/signup';
  static const String authVerify = '/auth/verify';
  static const String authResendVerification = '/auth/resend-code';
  static const String authChooseService = '/auth/choose-service';
  static const String authChangePassword = '/auth/change-password';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authVerifyForgotPassword = '/auth/verify';
  static const String authVerifyOtp = '/auth/verify-password-reset-otp';
  static const String authResetPassword = '/auth/reset-password';
  static const String authGoogleSignIn = '/auth/google';
  static const String authAppleSignIn = '/auth/apple';
  static const String petsCreateProfile = '/pets/create-pet-profile';
  static const String petsCreateProfileImages =
      '/pets/create-pet-profile/images';
  static const String myPets = '/pets/me';

  /// Get or update a specific pet
  /// Usage: '${ApiEndpoints.pets}/$petId'
  static const String pets = '/pets';

  /// Upload pet media
  /// Usage: '${ApiEndpoints.pets}/$petId/media'
  static const String petMedia = '/pets';

  static const String posts = '/posts';
  static const String postsWithMedia = '/posts/with-media';
  static const String sitters = '/sitters';

  /// Find nearby sitters by owner's location (GET with query lat, lng, optional radiusInMeters).
  static const String sittersNearby = '/sitters/nearby';

  // Walker endpoints (third role — dog walkers).
  static const String walkers = '/walkers';
  static const String walkersNearby = '/walkers/nearby';
  static const String walkersMe = '/walkers/me';
  static const String walkersMyRates = '/walkers/me/rates';
  static const String bookings = '/bookings';
  static const String myBookings = '/bookings/my';
  static const String myApplications = '/applications/my';
  // Session v18.2 — owner "Mes paiements" endpoints.
  static const String ownerPaymentMethods = '/owner/payments/methods';
  static const String ownerPaymentsSetupIntent = '/owner/payments/setup-intent';
  static const String ownerPaymentsHistory = '/owner/payments/history';
  static const String applications = '/applications';
  static const String tasks = '/tasks';
  static const String blocks = '/blocks';
  static const String userCard = '/users/me/card';
  static const String deleteAccount = '/users/me';
  static const String myProfile = '/users/me/profile';
  static const String profilePicture = '/users/me/profile-picture';
  static const String switchRole = '/users/switch-role';
  static const String conversationsList = '/conversations/list';

  /// Start a new conversation
  /// Usage: '${ApiEndpoints.conversationsStart}?sitterId={sitterId}'
  static const String conversationsStart = '/conversations/start';

  /// Start a new conversation by sitter with owner
  /// Usage: '${ApiEndpoints.conversationsStartBySitter}?ownerId={ownerId}'
  static const String conversationsStartBySitter =
      '/conversations/start-by-sitter';

  /// Get messages for a conversation
  /// Usage: '${ApiEndpoints.conversationMessages}/$conversationId/messages'
  static const String conversationMessages = '/conversations';

  /// Send a message in a conversation
  /// Usage: '${ApiEndpoints.conversationMessages}/$conversationId/messages'
  static const String sendMessage = '/conversations';

  /// Send a message with attachments in a conversation
  /// Usage: '${ApiEndpoints.conversationMessages}/$conversationId/messages/attachments'
  static const String sendMessageWithAttachments = '/conversations';

  // Payment and Stripe endpoints
  /// Create payment intent for a booking
  /// Usage: '${ApiEndpoints.bookings}/$bookingId/create-payment-intent'
  static const String createPaymentIntent = '/create-payment-intent';

  /// Get booking agreement/price
  /// Usage: '${ApiEndpoints.bookings}/$bookingId/agreement'
  static const String bookingAgreement = '/agreement';

  /// Cancel a pending booking/application request
  /// Usage: '${ApiEndpoints.bookings}/$bookingId/cancel-request'
  static const String requestCancellation = '/cancel-request';

  /// Get payment status for a booking
  /// Usage: '${ApiEndpoints.bookings}/$bookingId/payment-status'
  static const String paymentStatus = '/payment-status';

  /// Confirm payment for a booking
  /// Usage: '${ApiEndpoints.bookings}/$bookingId/confirm-payment/$paymentIntentId'
  static const String confirmPayment = '/confirm-payment';

  /// PayPal endpoints (Owner booking payments)
  /// Usage (create): '${ApiEndpoints.bookings}/$bookingId${ApiEndpoints.paypalCreateOrder}'
  static const String paypalCreateOrder = '/paypal/create-order';

  /// Usage (capture): '${ApiEndpoints.bookings}/$bookingId${ApiEndpoints.paypalCapture}/$orderId'
  static const String paypalCapture = '/paypal/capture';

  /// Stripe Connect endpoints
  static const String stripeConnect = '/stripe-connect';
  static const String stripeConnectCreateAccount =
      '/stripe-connect/create-account';
  static const String stripeConnectAccountStatus =
      '/stripe-connect/account-status';

  /// Sitter PayPal payout email (Sitter only)
  /// Usage: PUT '${ApiEndpoints.sittersPayPalEmail}'
  static const String sittersPayPalEmail = '/sitters/paypal-email';

  static const String reviews = '/reviews';

  /// v18.5 — unified IBAN payout endpoint (sitter + walker).
  /// Backend mounts ibanRoutes at /sitter AND /walker; the handler reads
  /// req.user.role to pick Sitter or Walker collection. Either URL works
  /// for either role. We keep the const name `sitterMeIban` so existing
  /// imports still compile.
  /// GET/PUT '${ApiEndpoints.sitterMeIban}'
  static const String sitterMeIban = '/sitter/iban';
  static const String walkerMeIban = '/walker/iban';

  /// Notifications (Owner + Sitter; role from JWT)
  /// GET `${notificationsMy}?limit=50` — optional `&cursor=`
  /// GET `${notificationsMy}/unread-count`
  /// PATCH `${notificationsMy}/<id>/read`
  /// PATCH `${notificationsMy}/read-all`
  static const String notificationsMy = '/notifications/my';

  /// Sprint 4 — FCM device token registration
  /// POST / DELETE with `{ token: string, platform?: 'android'|'ios'|'web' }`
  static const String fcmToken = '/users/fcm-token';

  /// Sprint 6 step 2 — live walk tracking
  static const String walksStart = '/walks/start';
  static const String walksEnd = '/walks'; // + /$id/end
  static const String walksPosition = '/walks'; // + /$id/position
  static const String walksActive = '/walks/active';

  /// Sprint 6 step 3 — visit report (base: /bookings/{id}/visit-report)
  static const String bookingsBase = '/bookings';

  /// Sprint 7 step 1 — owner loyalty stats
  static const String myLoyalty = '/users/me/loyalty';
}
