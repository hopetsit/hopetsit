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
          // v480 — FIX layout : la grille 2×2 + les boutons ne s'affichaient
          // plus (poussés hors écran). Pattern « remplir la hauteur + footer
          // collé en bas + scroll seulement si trop grand » :
          // LayoutBuilder + ConstrainedBox(minHeight) + IntrinsicHeight +
          // Column avec un Expanded comme spacer (flex:1) avant les CTA.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
              children: [
                SizedBox(height: 16.h),

                // v478 — maquette « App Opening » : logo héros en squircle
                // blanc 124px + halo lumineux derrière + bord blanc + ombre.
                SizedBox(
                  height: 158.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Halo lumineux (blanc en clair, orange en sombre).
                      Container(
                        width: 200.w,
                        height: 200.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              isDark
                                  ? AppColors.primaryColor
                                      .withValues(alpha: 0.40)
                                  : Colors.white.withValues(alpha: 0.50),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.7],
                          ),
                        ),
                      ),
                      // Squircle blanc avec le logo.
                      Container(
                        width: 124.w,
                        height: 124.w,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(34.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 30,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(8.w),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26.r),
                          child: Image.asset(
                            'assets/brand/png/apple-icon-original.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
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
                  text: 'onboarding_services_subtitle'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.92),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 26.h),

                // v478 — maquette « App Opening » : grille 2×2 des 4 services
                // (icône carrée teintée + titre + 1 ligne). Tout en i18n.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.pets,
                        title: 'onboarding_svc_petsitting'.tr,
                        description: 'onboarding_svc_petsitting_d'.tr,
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(width: 11.w),
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.map_outlined,
                        title: 'PawMap',
                        description: 'onboarding_svc_pawmap_d'.tr,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 11.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.my_location_rounded,
                        title: 'PawFollow',
                        description: 'onboarding_svc_pawfollow_d'.tr,
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(width: 11.w),
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.bookmark_rounded,
                        title: 'PawSpot',
                        description: 'onboarding_svc_pawspot_d'.tr,
                        isDark: isDark,
                        gold: true,
                      ),
                    ),
                  ],
                ),

                // v480 — spacer flex : pousse les CTA en bas, grille + boutons
                // toujours visibles ; scroll seulement si l'écran est petit.
                Expanded(child: SizedBox(height: 24.h)),

                // ── CTA Section (en bas, flux normal) ──
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
          ),
        ),
      ),
    );
  }
}

/// v478 — maquette « App Opening » : carte service horizontale (icône carrée
/// arrondie teintée + titre + 1 ligne de description). Fond blanc en clair,
/// carte sombre #241D1A + bord #352A25 en sombre. Variante `gold` (PawSpot).
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isDark;
  final bool gold;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    this.isDark = false,
    this.gold = false,
  });

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFE5B24A);
    final accent = gold ? goldColor : AppColors.primaryColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 13.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF241D1A) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: isDark
            ? Border.all(color: const Color(0xFF352A25))
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Row(
        children: [
          // Icône carrée arrondie teintée (orange / doré pour PawSpot).
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.14),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(icon, size: 22.sp, color: accent),
          ),
          SizedBox(width: 11.w),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsText(
                  text: title,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.blackColor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: description,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFF9B918B)
                      : AppColors.grey700Color,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
