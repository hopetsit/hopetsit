import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scale;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();

    // Immersive status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _checkAuthentication();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuthentication() async {
    await Future.delayed(const Duration(milliseconds: 2000));

    final storage = GetStorage();
    final token = storage.read<String>(StorageKeys.authToken);
    final role = storage.read<String>(StorageKeys.userRole);

    debugPrint(
      '[HOPETSIT] ========== SPLASH SCREEN - CHECKING AUTH ==========',
    );
    debugPrint('[HOPETSIT] Token exists: ${token != null && token.isNotEmpty}');
    debugPrint('[HOPETSIT] Role: $role');

    if (token != null && token.isNotEmpty) {
      if (role == 'owner') {
        debugPrint('[HOPETSIT] Navigating to Owner Home');
        Get.offAll(() => const BottomNavWrapper());
      } else if (role == 'sitter') {
        debugPrint('[HOPETSIT] Navigating to Sitter Home');
        Get.offAll(() => const SitterNavWrapper());
      } else {
        debugPrint('[HOPETSIT] Role not found, navigating to Onboarding');
        Get.offAll(() => const OnboardingScreen());
      }
    } else {
      debugPrint('[HOPETSIT] No token found, navigating to Onboarding');
      Get.offAll(() => const OnboardingScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEF4324), // primaryColor
              Color(0xFFFF6B4A), // lighter accent
              Color(0xFFEF4324),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // Logo with scale animation
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 130.w,
                    height: 130.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(20.w),
                    child: Image.asset(
                      AppImages.bgRemovedLogo,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                SizedBox(height: 28.h),

                // App name with slide animation
                SlideTransition(
                  position: _slideUp,
                  child: Column(
                    children: [
                      PoppinsText(
                        text: 'HoPetSit',
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                      SizedBox(height: 6.h),
                      InterText(
                        text: 'Home Pets Sitting',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 0.5,
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // Modern loading indicator
                SizedBox(
                  width: 28.w,
                  height: 28.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),

                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
