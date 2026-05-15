import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/onboarding/onboarding_screen.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/views/pet_walker/bottom_wrapper/walker_nav_wrapper.dart';
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

  /// v23.1 part 44 — fix Bug H "login as owner opens walker".
  ///
  /// Root cause : splash read `StorageKeys.userRole` directly. When storage
  /// was contaminated by a previous session (e.g. walker test → kill app
  /// without clean logout → storage still says walker), splash navigated
  /// based on that stale value even though the JWT could say something else.
  /// The walker case fell into the `else` branch (Onboarding) because only
  /// owner/sitter were handled.
  ///
  /// Fix : decode the JWT directly and use ITS role claim as the source of
  /// truth (the backend signs the JWT, so its role cannot drift). Storage
  /// is only consulted as a fallback if the JWT is missing/expired/malformed.
  /// The 3 roles (owner/sitter/walker) all have a proper navigation branch.
  String? _decodeRoleFromJwt(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final bytes = base64.decode(payload);
      final json = jsonDecode(utf8.decode(bytes));
      final role = (json is Map && json['role'] is String)
          ? (json['role'] as String).toLowerCase()
          : null;
      // Reject tokens that are already expired so we never auto-login a
      // user whose backend session is dead.
      if (json is Map && json['exp'] is num) {
        final expSec = (json['exp'] as num).toInt();
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (expSec <= nowSec) return null;
      }
      return (role != null && role.isNotEmpty) ? role : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkAuthentication() async {
    await Future.delayed(const Duration(milliseconds: 2000));

    final storage = GetStorage();
    final token = storage.read<String>(StorageKeys.authToken);
    final storedRole = storage.read<String>(StorageKeys.userRole);
    final jwtRole = _decodeRoleFromJwt(token);

    debugPrint(
      '[HOPETSIT] ========== SPLASH SCREEN - CHECKING AUTH ==========',
    );
    debugPrint('[HOPETSIT] Token exists: ${token != null && token.isNotEmpty}');
    debugPrint('[HOPETSIT] JWT role: $jwtRole');
    debugPrint('[HOPETSIT] Storage role: $storedRole');

    if (token == null || token.isEmpty) {
      debugPrint('[HOPETSIT] No token found, navigating to Onboarding');
      Get.offAll(() => const OnboardingScreen());
      return;
    }

    // JWT is the source of truth. If it cannot be decoded (malformed) OR
    // the token is expired, treat as logged out.
    if (jwtRole == null) {
      debugPrint(
        '[HOPETSIT] JWT invalid/expired, clearing auth + Onboarding',
      );
      storage.remove(StorageKeys.authToken);
      storage.remove(StorageKeys.userRole);
      Get.offAll(() => const OnboardingScreen());
      return;
    }

    // Storage drift recovery : if storage disagrees with JWT, re-write
    // storage so AuthController.onInit reads the correct value next time.
    if (storedRole != jwtRole) {
      debugPrint(
        '[HOPETSIT] ⚠️ Role drift (storage=$storedRole, jwt=$jwtRole). Forcing JWT role.',
      );
      storage.write(StorageKeys.userRole, jwtRole);
    }

    switch (jwtRole) {
      case 'owner':
        debugPrint('[HOPETSIT] Navigating to Owner Home');
        Get.offAll(() => const BottomNavWrapper());
        break;
      case 'sitter':
        debugPrint('[HOPETSIT] Navigating to Sitter Home');
        Get.offAll(() => const SitterNavWrapper());
        break;
      case 'walker':
        debugPrint('[HOPETSIT] Navigating to Walker Home');
        Get.offAll(() => const WalkerNavWrapper());
        break;
      default:
        debugPrint(
          '[HOPETSIT] Unknown JWT role "$jwtRole" → Onboarding',
        );
        Get.offAll(() => const OnboardingScreen());
    }

    // v23.1 part 146 — fix écran noir au boot via deep link.
    // Le DeepLinkService a pu recevoir un Intent VIEW AVANT que
    // GetMaterialApp soit monté (cas où l'app est lancée par un lien
    // hopetsit.com depuis un email/Chrome/etc.). Les URIs reçues trop
    // tôt sont bufferisées dans `_pendingUris`. Maintenant que la nav
    // GetX est prête (Get.offAll vient de monter le bon écran), on
    // rejoue les URIs en attente : `_openPayment` peut push par-dessus
    // BottomNavWrapper, `/chat` peut routerNamed, etc.
    // Wrappé en addPostFrameCallback pour laisser le frame se peindre
    // avant la nav (évite tout flicker visuel).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.instance.flushPending();
    });
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
                    padding: EdgeInsets.all(16.w),
                    // v18.5 — logo V4 (SVG) sur fond orange. L'ancien
                    // logo "œil" (bg-removed-logo.png) est remplacé par
                    // la patte V4.
                    child: SvgPicture.asset(
                      'assets/brand/apple/apple-icon-original.svg',
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
