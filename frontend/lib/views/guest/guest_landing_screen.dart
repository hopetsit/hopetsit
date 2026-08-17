import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/services/firebase_analytics_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/signup_wizard_screen.dart';
import 'package:hopetsit/views/guest/guest_discovery_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v539 — L'ATTERRISSAGE INVITÉ (maquette Daniel du 17/08).
///
/// Remplace l'arrivée directe sur la liste : une vraie page d'accueil —
/// promesse, bandeau de confiance, « Je veux… » (3 cartes de rôle qui mènent
/// au BON wizard), découverte des gardiens, et création de compte
/// Apple/Google/e-mail. Tous les boutons réutilisent les flux EXISTANTS
/// (AuthController.loginWithGoogle/Apple, SignupWizardScreen,
/// GuestDiscoveryScreen) — rien de nouveau côté auth.
class GuestLandingScreen extends StatelessWidget {
  const GuestLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    FirebaseAnalyticsService.instance.logFunnel('guest_landing');
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              16.w, 8.h, 16.w, 24.h + MediaQuery.viewPaddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête : logo + connexion ───────────────────────────
              Row(
                children: [
                  Image.asset('assets/brand/png/logo-mark.png',
                      width: 40.w, height: 40.w),
                  SizedBox(width: 8.w),
                  PoppinsText(
                    text: 'HoPetSit',
                    fontSize: 21.sp,
                    fontWeight: FontWeight.w800,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Get.to(() => const LoginScreen()),
                    child: InterText(
                      text: 'guest_login'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              // ── Badge confiance ──────────────────────────────────────
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 14.sp, color: const Color(0xFF16A34A)),
                    SizedBox(width: 6.w),
                    InterText(
                      text: 'guest_badge_trust'.tr,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF15803D),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              // ── Héros ────────────────────────────────────────────────
              PoppinsText(
                text: 'guest_hero_title'.tr,
                fontSize: 28.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
                maxLines: 3,
              ),
              SizedBox(height: 8.h),
              InterText(
                text: 'guest_hero_sub'.tr,
                fontSize: 14.sp,
                color: AppColors.textSecondary(context),
                maxLines: 3,
              ),
              SizedBox(height: 14.h),
              // v539 — photo héros chien+chat (maquette Daniel).
              ClipRRect(
                borderRadius: BorderRadius.circular(20.r),
                child: Image.asset(
                  'assets/images/guest_hero_pets.jpg',
                  width: double.infinity,
                  height: 150.h,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: 16.h),
              // ── Bandeau des 4 forces ─────────────────────────────────
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    Row(children: [
                      _feat(context, Icons.verified_outlined,
                          'guest_feat_verified'.tr, 'guest_feat_verified_sub'.tr),
                      _feat(context, Icons.my_location_outlined,
                          'guest_feat_gps'.tr, 'guest_feat_gps_sub'.tr),
                    ]),
                    SizedBox(height: 10.h),
                    Row(children: [
                      _feat(context, Icons.lock_outline,
                          'guest_feat_pay'.tr, 'guest_feat_pay_sub'.tr),
                      _feat(context, Icons.chat_bubble_outline,
                          'guest_feat_chat'.tr, 'guest_feat_chat_sub'.tr),
                    ]),
                  ],
                ),
              ),
              SizedBox(height: 22.h),
              // ── « Je veux… » ─────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    PoppinsText(
                      text: 'guest_iwant'.tr,
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      width: 44.w,
                      height: 3.h,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.h),
              _roleCard(
                context,
                image: AppImages.petOwner,
                color: AppColors.primaryColor,
                icon: Icons.person_outline,
                title: 'role_pet_owner'.tr,
                subtitle: 'guest_role_owner_sub'.tr,
                userType: 'pet_owner',
              ),
              SizedBox(height: 12.h),
              _roleCard(
                context,
                image: AppImages.petSitter,
                color: const Color(0xFF2563EB),
                icon: Icons.night_shelter_outlined,
                title: 'role_pet_sitter'.tr,
                subtitle: 'guest_role_sitter_sub'.tr,
                userType: 'pet_sitter',
              ),
              SizedBox(height: 12.h),
              _roleCard(
                context,
                image: AppImages.petWalker,
                color: const Color(0xFF16A34A),
                icon: Icons.directions_walk,
                title: 'role_pet_walker'.tr,
                subtitle: 'guest_role_walker_sub'.tr,
                userType: 'pet_walker',
              ),
              SizedBox(height: 18.h),
              // ── Découvrir sans compte ────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Get.to(() => const GuestDiscoveryScreen()),
                  icon: Icon(Icons.pets,
                      size: 16.sp, color: AppColors.primaryColor),
                  label: InterText(
                    text: 'guest_discover_btn'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryColor,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.primaryColor, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 22.h),
              // ── Créer mon compte ─────────────────────────────────────
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    PoppinsText(
                      text: 'guest_create_account'.tr,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(height: 4.h),
                    InterText(
                      text: 'guest_create_sub'.tr,
                      fontSize: 12.sp,
                      color: AppColors.textSecondary(context),
                    ),
                    SizedBox(height: 14.h),
                    if (Platform.isIOS) ...[
                      _authBtn(
                        label: 'guest_continue_apple'.tr,
                        icon: Icons.apple,
                        bg: Colors.black,
                        fg: Colors.white,
                        onTap: () =>
                            Get.find<AuthController>().loginWithApple(),
                      ),
                      SizedBox(height: 10.h),
                    ],
                    _authBtn(
                      label: 'guest_continue_google'.tr,
                      icon: Icons.g_mobiledata,
                      bg: Colors.white,
                      fg: Colors.black87,
                      border: true,
                      onTap: () =>
                          Get.find<AuthController>().loginWithGoogle(),
                    ),
                    SizedBox(height: 10.h),
                    _authBtn(
                      label: 'guest_signup_email'.tr,
                      icon: Icons.mail_outline,
                      bg: AppColors.primaryColor,
                      fg: Colors.white,
                      onTap: () => Get.to(() =>
                          SignupWizardScreen(userType: 'pet_owner')),
                    ),
                    SizedBox(height: 12.h),
                    InterText(
                      text: 'guest_terms_note'.tr,
                      fontSize: 10.5.sp,
                      color: AppColors.textSecondary(context),
                      textAlign: TextAlign.center,
                      maxLines: 2,
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

  Widget _feat(BuildContext context, IconData icon, String t, String s) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child:
                Icon(icon, size: 18.sp, color: AppColors.primaryColor),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: t,
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                ),
                InterText(
                  text: s,
                  fontSize: 9.5.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required String image,
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required String userType,
  }) {
    return GestureDetector(
      onTap: () {
        FirebaseAnalyticsService.instance
            .logFunnel('signup_start', params: {'trigger': 'landing_$userType'});
        Get.to(() => SignupWizardScreen(userType: userType));
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.all(10.w),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14.r),
                    child: Image.asset(
                      image,
                      width: 86.w,
                      height: 86.w,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4.w,
                    left: 4.w,
                    child: Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 13.sp, color: color),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: title,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    SizedBox(height: 3.h),
                    InterText(
                      text: subtitle,
                      fontSize: 12.sp,
                      color: Colors.white.withValues(alpha: 0.92),
                      // v539 — Daniel : « Promeneur c'est un peu coupé ».
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 14.w),
              child: Container(
                width: 34.w,
                height: 34.w,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_right, color: color, size: 22.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _authBtn({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
    bool border = false,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20.sp, color: fg),
        label: InterText(
          text: label,
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          elevation: 0,
          side: border
              ? BorderSide(color: Colors.grey.withValues(alpha: 0.35))
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      ),
    );
  }
}
