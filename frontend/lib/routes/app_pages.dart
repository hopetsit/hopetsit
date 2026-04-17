import 'package:get/get.dart';

import 'package:hopetsit/routes/app_routes.dart';
import 'package:hopetsit/views/splash/splash_screen.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/sign_up_screen.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/views/profile/terms_and_conditions_screen.dart';
import 'package:hopetsit/views/profile/privacy_policy_screen.dart';
import 'package:hopetsit/views/profile/my_referrals_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/availability_calendar_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/identity_verification_screen.dart';
import 'package:hopetsit/views/map/pets_map_screen.dart';

/// Sprint 8 step 1 — named-route registry.
///
/// Registered pages here can be navigated via `Get.toNamed(AppRoutes.xxx)`.
/// Screens that need constructor args (bookingId, conversationId, etc.) can be
/// registered later when a non-breaking migration from `Get.to(() => Screen(...))`
/// is done. For now we cover the screens that have no required constructor args.
class AppPages {
  AppPages._();

  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
    GetPage(
      name: AppRoutes.signup,
      page: () => SignUpScreen(
        userType: (Get.arguments is Map && (Get.arguments as Map)['userType'] is String)
            ? (Get.arguments as Map)['userType'] as String
            : 'pet_owner',
      ),
    ),
    GetPage(name: AppRoutes.homeOwner, page: () => const BottomNavWrapper()),
    GetPage(name: AppRoutes.homeSitter, page: () => const SitterNavWrapper()),
    GetPage(
      name: AppRoutes.terms,
      page: () => const TermsAndConditionsScreen(),
    ),
    GetPage(
      name: AppRoutes.privacy,
      page: () => const PrivacyPolicyScreen(),
    ),
    GetPage(
      name: AppRoutes.referrals,
      page: () => const MyReferralsScreen(),
    ),
    GetPage(
      name: AppRoutes.availability,
      page: () => const AvailabilityCalendarScreen(),
    ),
    GetPage(
      name: AppRoutes.identityVerification,
      page: () => const IdentityVerificationScreen(),
    ),
    // Classic pets map (legacy view kept accessible alongside new PawMap).
    // The PawMap is now wired to the bottom-nav center button; this route
    // lets any screen still jump back to PetsMapScreen via Get.toNamed.
    GetPage(
      name: AppRoutes.petsMap,
      page: () => const PetsMapScreen(),
    ),
  ];
}
