import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/services/firebase_analytics_service.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/signup_wizard_screen.dart';
import 'package:hopetsit/views/guest/guest_discovery_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/micro_anims.dart';

/// v540 — ATTERRISSAGE INVITÉ, version haute-fidélité du handoff design
/// « Page de connexion LAP » (écran 4a). Reproduit au pixel : fond dégradé
/// crème, héros 2 colonnes avec photo, tuiles de rôle en dégradé + tuile
/// Invité rose, bloc « Créer mon compte » Apple/Google côte à côte.
/// La logique reste 100 % celle des flux existants.
class GuestLandingScreen extends StatelessWidget {
  const GuestLandingScreen({super.key});

  // Tokens du handoff.
  static const _bgTop = Color(0xFFFFF9F4);
  static const _bgBottom = Color(0xFFFFF3EA);
  static const _ink = Color(0xFF1B222E);
  static const _muted = Color(0xFF6B6259);
  static const _brand = Color(0xFFC92A12);
  static const _brandLight = Color(0xFFE25822);
  static const _pink = Color(0xFFDB2777);
  static const _pinkBorder = Color(0xFFF472B6);

  @override
  Widget build(BuildContext context) {
    FirebaseAnalyticsService.instance.logFunnel('guest_landing');
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w,
                24.h + MediaQuery.viewPaddingOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Logo ─────────────────────────────────────────────
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.r),
                      child: Image.asset('assets/brand/png/logo-mark.png',
                          width: 38.w, height: 38.w),
                    ),
                    SizedBox(width: 8.w),
                    Row(
                      children: [
                        FredokaText(
                            text: 'Ho',
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: _ink),
                        FredokaText(
                            text: 'Pet',
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: _brand),
                        FredokaText(
                            text: 'Sit',
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: _ink),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // ── Badge confiance ──────────────────────────────────
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF0E3),
                    borderRadius: BorderRadius.circular(99.r),
                    border: Border.all(color: const Color(0xFFF0DFC9)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 13.sp, color: const Color(0xFF5C7A4E)),
                      SizedBox(width: 6.w),
                      InterText(
                        text: 'guest_badge_trust'.tr,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF5C7A4E),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                // ── Héros : titre à gauche, photo à droite ───────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 11,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FredokaText(
                            text: 'guest_hero_title_1'.tr,
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                            height: 1.16,
                            maxLines: 3,
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: FredokaText(
                                  text: 'guest_hero_title_2'.tr,
                                  fontSize: 26.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _brand,
                                  height: 1.16,
                                  maxLines: 1,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              HeartBeat(
                                  child: InterText(
                                      text: '❤', fontSize: 22.sp, color: _brand)),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          InterText(
                            text: 'guest_hero_sub'.tr,
                            fontSize: 13.sp,
                            color: _muted,
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      flex: 9,
                      child: Image.asset(
                        'assets/images/guest/hero3.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
                ),
                SizedBox(height: 18.h),
                // ── « Je veux… » ─────────────────────────────────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 180),
                  child: Center(
                  child: Column(
                    children: [
                      FredokaText(
                        text: 'guest_iwant'.tr,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        width: 40.w,
                        height: 3.h,
                        decoration: BoxDecoration(
                          color: _brand,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ],
                  ),
                ),
                ),
                SizedBox(height: 14.h),
                // ── Grille 2×2 des tuiles ────────────────────────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 260),
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _roleTile(
                        photo: 'assets/images/guest/prop-new.png',
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_brandLight, _brand],
                        ),
                        title: 'role_pet_owner'.tr,
                        subtitle: 'guest_role_owner_sub'.tr,
                        onTap: () => _toWizard('pet_owner'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _roleTile(
                        photo: 'assets/images/guest/sit-new.png',
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3A78EE), Color(0xFF2455C4)],
                        ),
                        title: 'role_pet_sitter'.tr,
                        subtitle: 'guest_role_sitter_sub'.tr,
                        onTap: () => _toWizard('pet_sitter'),
                      ),
                    ),
                  ],
                ),
                ),
                SizedBox(height: 12.h),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 340),
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _roleTile(
                        photo: 'assets/images/guest/walk-new.png',
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF27AE60), Color(0xFF178C4A)],
                        ),
                        title: 'role_pet_walker'.tr,
                        subtitle: 'guest_role_walker_sub'.tr,
                        onTap: () => _toWizard('pet_walker'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _roleTile(
                        photo: 'assets/images/guest/souris2.png',
                        gradient: null, // tuile invitée : blanche, bordure rose
                        title: 'guest_role_guest'.tr,
                        subtitle: 'guest_role_guest_sub'.tr,
                        titleColor: _pink,
                        subtitleColor: const Color(0xFF9D6B85),
                        border: Border.all(color: _pinkBorder, width: 2),
                        chevronColor: _pinkBorder,
                        onTap: () {
                          FirebaseAnalyticsService.instance
                              .logFunnel('guest_browse_from_tile');
                          Get.to(() => const GuestDiscoveryScreen());
                        },
                      ),
                    ),
                  ],
                ),
                ),
                SizedBox(height: 16.h),
                // ── Découvrir les gardiens ───────────────────────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 420),
                  child: SizedBox(
                  width: double.infinity,
                  height: 46.h,
                  child: OutlinedButton(
                    onPressed: () =>
                        Get.to(() => const GuestDiscoveryScreen()),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _brand, width: 1.3),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: InterText(
                      text: '🐾 ${'guest_discover_btn'.tr}',
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                      color: _brand,
                    ),
                  ),
                ),
                ),
                SizedBox(height: 16.h),
                // ── Créer mon compte ─────────────────────────────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 500),
                  child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      FredokaText(
                        text: 'guest_create_account'.tr,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                      SizedBox(height: 3.h),
                      InterText(
                        text: '${'guest_create_sub'.tr} 🔒',
                        fontSize: 11.5.sp,
                        color: _muted,
                      ),
                      SizedBox(height: 13.h),
                      Row(
                        children: [
                          if (Platform.isIOS) ...[
                            Expanded(
                              child: _smallAuthBtn(
                                label: 'Apple',
                                icon: Icons.apple,
                                bg: const Color(0xFF101319),
                                fg: Colors.white,
                                onTap: () => Get.find<AuthController>()
                                    .loginWithApple(),
                              ),
                            ),
                            SizedBox(width: 10.w),
                          ],
                          Expanded(
                            child: _smallAuthBtn(
                              label: 'Google',
                              icon: Icons.g_mobiledata,
                              bg: Colors.white,
                              fg: _ink,
                              border: true,
                              onTap: () => Get.find<AuthController>()
                                  .loginWithGoogle(),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      SizedBox(
                        width: double.infinity,
                        height: 46.h,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_brandLight, _brand],
                            ),
                            borderRadius: BorderRadius.circular(14.r),
                            boxShadow: [
                              BoxShadow(
                                color: _brand.withValues(alpha: 0.28),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => _toWizard('pet_owner'),
                            icon: Icon(Icons.mail_outline,
                                size: 17.sp, color: Colors.white),
                            label: InterText(
                              text: 'guest_signup_email'.tr,
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 11.h),
                      GestureDetector(
                        onTap: () => launchUrl(
                            Uri.parse('https://www.hopetsit.com/terms'),
                            mode: LaunchMode.externalApplication),
                        child: InterText(
                          text: 'guest_terms_note'.tr,
                          fontSize: 10.sp,
                          color: const Color(0xFF8A8177),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InterText(
                            text: 'guest_already'.tr,
                            fontSize: 12.5.sp,
                            color: _muted,
                          ),
                          SizedBox(width: 6.w),
                          GestureDetector(
                            onTap: () =>
                                Get.to(() => const LoginScreen()),
                            behavior: HitTestBehavior.opaque,
                            child: InterText(
                              text: 'guest_login'.tr,
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w800,
                              color: _brand,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toWizard(String userType) {
    FirebaseAnalyticsService.instance
        .logFunnel('signup_start', params: {'trigger': 'landing_$userType'});
    Get.to(() => SignupWizardScreen(userType: userType));
  }

  Widget _roleTile({
    required String photo,
    required LinearGradient? gradient,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color titleColor = Colors.white,
    Color? subtitleColor,
    Border? border,
    Color? chevronColor,
  }) {
    final onColor = gradient != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          color: onColor ? null : const Color(0xFFFDF2F8),
          borderRadius: BorderRadius.circular(20.r),
          border: border,
          boxShadow: [
            BoxShadow(
              color: (gradient?.colors.last ?? _pinkBorder)
                  .withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: EdgeInsets.all(8.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14.r),
              child: Image.asset(
                photo,
                width: double.infinity,
                height: 82.h,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(
                children: [
                  Expanded(
                    child: FredokaText(
                      text: title,
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                      maxLines: 1,
                    ),
                  ),
                  ArrowNudge(
                    child: Container(
                      width: 22.w,
                      height: 22.w,
                      decoration: BoxDecoration(
                        color: onColor
                            ? Colors.white.withValues(alpha: 0.25)
                            : (chevronColor ?? _pinkBorder)
                                .withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.chevron_right,
                          size: 15.sp,
                          color: onColor
                              ? Colors.white
                              : (chevronColor ?? _pinkBorder)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3.h),
            Padding(
              padding: EdgeInsets.only(left: 4.w, right: 4.w, bottom: 4.h),
              child: InterText(
                text: subtitle,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w600,
                color: subtitleColor ??
                    Colors.white.withValues(alpha: 0.92),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallAuthBtn({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
    bool border = false,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 44.h,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18.sp, color: fg),
        label: InterText(
          text: label,
          fontSize: 13.sp,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          elevation: 0,
          side: border
              ? const BorderSide(color: Color(0xFFECE5DE))
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      ),
    );
  }
}
