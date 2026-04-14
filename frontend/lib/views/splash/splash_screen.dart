import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/onboarding/onboarding_screen.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/widgets/app_text.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    // Wait a bit for the app to initialize
    await Future.delayed(const Duration(milliseconds: 1500));

    final storage = GetStorage();
    final token = storage.read<String>(StorageKeys.authToken);
    final role = storage.read<String>(StorageKeys.userRole);
    final userProfile = storage.read<Map<String, dynamic>>(
      StorageKeys.userProfile,
    );

    // Debug: Print all saved data
    debugPrint(
      '[HOPETSIT] ========== SPLASH SCREEN - CHECKING AUTH ==========',
    );
    debugPrint('[HOPETSIT] Token exists: ${token != null && token.isNotEmpty}');
    if (token != null && token.isNotEmpty) {
      final tokenPreview = token.length > 20
          ? '${token.substring(0, 20)}...'
          : token;
      debugPrint('[HOPETSIT] Token: $tokenPreview');
    }
    debugPrint('[HOPETSIT] Role: $role');
    if (userProfile != null) {
      debugPrint('[HOPETSIT] User Profile:');
      debugPrint('[HOPETSIT]   - Name: ${userProfile['name'] ?? 'N/A'}');
      debugPrint('[HOPETSIT]   - Email: ${userProfile['email'] ?? 'N/A'}');
      debugPrint('[HOPETSIT]   - Mobile: ${userProfile['mobile'] ?? 'N/A'}');
      debugPrint('[HOPETSIT]   - Address: ${userProfile['address'] ?? 'N/A'}');
      debugPrint(
        '[HOPETSIT]   - Verified: ${userProfile['verified'] ?? 'N/A'}',
      );
      debugPrint('[HOPETSIT]   - Role: ${userProfile['role'] ?? 'N/A'}');
      debugPrint('[HOPETSIT]   - ID: ${userProfile['id'] ?? 'N/A'}');
    } else {
      debugPrint('[HOPETSIT] User Profile: Not found');
    }
    debugPrint(
      '[HOPETSIT] ====================================================',
    );

    if (token != null && token.isNotEmpty) {
      // User is logged in, navigate based on role
      if (role == 'owner') {
        debugPrint('[HOPETSIT] ✅ Navigating to Owner Home');
        Get.offAll(() => const BottomNavWrapper());
      } else if (role == 'sitter') {
        debugPrint('[HOPETSIT] ✅ Navigating to Sitter Home');
        Get.offAll(() => const SitterNavWrapper());
      } else {
        // Role not found, go to onboarding
        debugPrint('[HOPETSIT] ⚠️ Role not found, navigating to Onboarding');
        Get.offAll(() => const OnboardingScreen());
      }
    } else {
      // No token, go to onboarding
      debugPrint('[HOPETSIT] ⚠️ No token found, navigating to Onboarding');
      Get.offAll(() => const OnboardingScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: SafeArea(
        bottom: false,
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            children: [
              // Background decoration
              Container(
                decoration: BoxDecoration(color: AppColors.primaryColor),
              ),
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 20.h),
                    // App Logo
                    Image.asset(
                      AppImages.bgRemovedLogo,
                      color: AppColors.whiteColor,
                      height: 100.h,
                      width: 100.w,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: 20.h),
                    // App Name
                    PoppinsText(
                      text: 'Home Pets Sitting',
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.whiteColor,
                    ),
                    SizedBox(height: 40.h),
                    // Loading indicator
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.whiteColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
