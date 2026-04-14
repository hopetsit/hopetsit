/// Sprint 8 step 1 — centralised named routes.
///
/// Use [Get.toNamed(AppRoutes.xxx)] across the app instead of Get.to(() => Screen()).
/// Legacy Get.to calls still work; migrate progressively.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';

  // Auth
  static const String login = '/login';
  static const String signup = '/signup';
  static const String signupAs = '/signup-as';
  static const String emailVerification = '/email-verification';
  static const String otpVerification = '/otp-verification';
  static const String forgotPassword = '/forgot-password';
  static const String chooseService = '/choose-service';

  // Owner home + chat + bookings
  static const String homeOwner = '/home-owner';
  static const String chat = '/chat';
  static const String individualChat = '/chat/individual';
  static const String bookingsHistory = '/bookings';
  static const String ownerBookingDetail = '/booking/owner-detail';
  static const String bookingAgreement = '/booking/agreement';
  static const String publishRequest = '/publish-request';
  static const String application = '/application';
  static const String ownerVisitReport = '/visit-report/view';
  static const String liveWalk = '/walk/live';

  // Sitter home + chat + bookings
  static const String homeSitter = '/home-sitter';
  static const String sitterChat = '/sitter-chat';
  static const String sitterIndividualChat = '/sitter-chat/individual';
  static const String sitterBookings = '/sitter-bookings';
  static const String sitterBookingDetail = '/booking/sitter-detail';
  static const String sitterOnboarding = '/sitter-onboarding';
  static const String stripeConnectOnboarding = '/stripe-connect-onboarding';
  static const String stripeConnectWebview = '/stripe-connect-webview';
  static const String sitterApplication = '/sitter-application';
  static const String availability = '/sitter/availability';
  static const String identityVerification = '/sitter/identity-verification';
  static const String walkTracking = '/walk/tracking';
  static const String submitVisitReport = '/visit-report/submit';

  // Profile (shared)
  static const String profileOwner = '/profile-owner';
  static const String profileSitter = '/profile-sitter';
  static const String editOwnerProfile = '/profile/edit-owner';
  static const String editSitterProfile = '/profile/edit-sitter';
  static const String myPets = '/pets';
  static const String createPet = '/pets/new';
  static const String editPet = '/pets/edit';
  static const String addCard = '/card/add';
  static const String addTask = '/task/add';
  static const String blockedUsers = '/blocked-users';
  static const String changePassword = '/change-password';
  static const String terms = '/terms';
  static const String privacy = '/privacy';
  static const String referrals = '/referrals';
  static const String reviews = '/reviews';

  // Payment
  static const String stripePayment = '/payment/stripe';
  static const String stripeWebviewPayment = '/payment/stripe-webview';
  static const String paypalPayment = '/payment/paypal';
  static const String paypalWebviewPayment = '/payment/paypal-webview';
  static const String paymentResult = '/payment/result';

  // Notifications
  static const String notifications = '/notifications';

  // Map / discovery
  static const String petsMap = '/map';
  static const String serviceProviderDetail = '/service-provider';
  static const String sendRequest = '/send-request';

  // IBAN
  static const String ibanSetup = '/iban/setup';
  static const String sitterIban = '/iban';
  static const String payoutStatus = '/payout-status';
}
