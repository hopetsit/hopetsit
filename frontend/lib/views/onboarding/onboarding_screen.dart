import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/sign_up_as.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          // v23.1.166 — Daniel a fourni un nouveau mockup : orange dominant
          // sur ~80% de l'ecran, 3 cartes blanches verticales avec icone
          // circulaire + titre + description, CTA orange en bas avec icone
          // patte + fleche. Gradient dégradé du orange chaud au orange plus
          // clair en bas pour adoucir la transition vers les CTA.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    AppColors.primaryColor,
                    AppColors.primaryColor.withValues(alpha: 0.92),
                    AppColors.backgroundDark.withValues(alpha: 0.7),
                    AppColors.backgroundDark,
                  ]
                : [
                    AppColors.primaryColor,
                    const Color(0xFFFF6B45),
                    const Color(0xFFFF9B7A),
                    Colors.white,
                  ],
            stops: const [0.0, 0.55, 0.78, 1.0],
          ),
        ),
        child: SafeArea(
          // v23.1.167 — Daniel : "la bande doit etre en arriere plan car
          // elle cache les 3 icones". Cause : v166 wrappait le contenu
          // dans Flexible(SingleChildScrollView) + Spacer + CTAs. Le
          // Flexible/Spacer 50/50 limitait la SingleChildScrollView a la
          // moitie de l'ecran → les cartes (hautes a cause des 4 lignes
          // de description) etaient CLIPPED au bas du scroll viewport.
          // Daniel voyait juste leur top blanc, le reste etait cache
          // par la zone "Spacer".
          // Fix : un seul SingleChildScrollView qui couvre TOUT l'ecran
          // (logo + cartes + CTAs en bas). Plus de Spacer ni de
          // Flexible. Les cartes sont entierement visibles et le scroll
          // marche si l'ecran est petit.
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                SizedBox(height: 20.h),

                // v23.1.166 — Logo plus grand (88w -> 130w) avec
                // bordure blanche + shadow plus prononcee.
                Container(
                  width: 130.w,
                  height: 130.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(10.w),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.r),
                    child: Image.asset(
                      'assets/brand/png/apple-icon-original.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                PoppinsText(
                  text: 'HoPetSit',
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),

                SizedBox(height: 8.h),

                InterText(
                  text: 'onboarding_tagline'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 26.h),

                // v23.1.166 — 3 cartes verticales avec icone circulaire
                // orange + titre + description.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.pets,
                          title: 'onboarding_feature_trusted'.tr,
                          description:
                              'onboarding_feature_trusted_desc'.tr,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.map_outlined,
                          title: 'onboarding_feature_chat'.tr,
                          description:
                              'onboarding_feature_chat_desc'.tr,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.family_restroom,
                          title: 'onboarding_feature_nearby'.tr,
                          description:
                              'onboarding_feature_nearby_desc'.tr,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 32.h),

                // ── CTA Section (dans le scroll, sous les cartes) ──
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 4.h,
                  ),
                  child: Column(
                    children: [
                      // v23.1.167 — Daniel : "le petit cercle avec la patte
                      // ds sinscrire un peu trop a gauche". Avant : Row
                      // spaceBetween sans padding interne → la patte
                      // collait au bord gauche du bouton. Maintenant :
                      // Padding horizontal sur la Row pour ramener la
                      // patte et la fleche vers l'interieur (16px de
                      // marge interne de chaque cote).
                      CustomButton(
                        onTap: () => Get.to(() => SignUpAsScreen()),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 36.w,
                                height: 36.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.pets,
                                  size: 18.sp,
                                  color: Colors.white,
                                ),
                              ),
                              PoppinsText(
                                text: 'onboarding_signup'.tr,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16.sp,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 10.h),

                      // v23.1.397 — flags SÉPARÉS par bouton (parité avec
                      // login_screen) : taper Google ne fait plus tourner
                      // le bouton Apple, et inversement.
                      Obx(
                        () => _SocialButton(
                          onTap: authController.isGoogleLoginLoading.value
                              ? null
                              : () => authController.loginWithGoogle(),
                          icon: Icons.g_mobiledata,
                          label: 'onboarding_continue_with_google'.tr,
                          isOutlined: true,
                          imagePath: AppImages.googleIcon,
                          isLoading:
                              authController.isGoogleLoginLoading.value,
                          isDark: isDark,
                        ),
                      ),

                      if (Platform.isIOS) ...[
                        SizedBox(height: 8.h),
                        Obx(
                          () => _SocialButton(
                            onTap: authController.isAppleLoginLoading.value
                                ? null
                                : () => authController.loginWithApple(),
                            icon: Icons.apple,
                            label: 'onboarding_continue_with_apple'.tr,
                            isOutlined: false,
                            isLoading:
                                authController.isAppleLoginLoading.value,
                            isDark: isDark,
                          ),
                        ),
                      ],

                      SizedBox(height: 14.h),

                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? AppColors.dividerDark
                                  : AppColors.grey300Color,
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: InterText(
                              text: 'onboarding_or'.tr,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? AppColors.dividerDark
                                  : AppColors.grey300Color,
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 12.h),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InterText(
                            text: 'onboarding_have_account'.tr,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary(context),
                          ),
                          GestureDetector(
                            onTap: () => Get.to(() => const LoginScreen()),
                            child: Container(
                              color: Colors.transparent,
                              padding: EdgeInsets.fromLTRB(
                                6.w, 8.h, 10.w, 8.h,
                              ),
                              child: InterText(
                                text: 'title_login'.tr,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small feature highlight chip for the onboarding hero area.
/// v23.1.166 — Daniel a fourni un mockup avec 3 cartes verticales (au lieu
/// de chips horizontales). Chaque carte = fond blanc + icone circulaire
/// orange + titre + description courte. Layout : Column dans une Card,
/// Row IntrinsicHeight au parent pour egaliser les hauteurs.
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icone circulaire orange-tinted (light orange bg, orange icon).
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28.sp, color: AppColors.primaryColor),
          ),
          SizedBox(height: 12.h),
          PoppinsText(
            text: title,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.blackColor,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8.h),
          InterText(
            text: description,
            fontSize: 11.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.grey700Color,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String? imagePath;
  final String label;
  final bool isOutlined;
  final bool isLoading;
  final bool isDark;

  const _SocialButton({
    this.onTap,
    required this.icon,
    required this.label,
    required this.isOutlined,
    this.imagePath,
    this.isLoading = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 52.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isOutlined
              ? (isDark ? AppColors.cardDark : AppColors.whiteColor)
              : AppColors.blackColor,
          border: isOutlined
              ? Border.all(
                  color: isDark
                      ? AppColors.dividerDark
                      : AppColors.grey300Color,
                )
              : null,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  height: 24.r,
                  width: 24.r,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOutlined ? AppColors.blackColor : AppColors.whiteColor,
                    ),
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (imagePath != null)
                      Image.asset(
                        imagePath!,
                        height: 22.sp,
                        width: 22.sp,
                        fit: BoxFit.cover,
                      )
                    else
                      Icon(
                        icon,
                        size: 22.sp,
                        color: isOutlined
                            ? AppColors.textPrimary(context)
                            : AppColors.whiteColor,
                      ),
                    SizedBox(width: 10.w),
                    InterText(
                      text: label,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: isOutlined
                          ? AppColors.textPrimary(context)
                          : AppColors.whiteColor,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
