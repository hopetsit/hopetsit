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
          // v482b — Daniel : « fais comme le design fournis » → dégradé
          // EXACTEMENT comme la maquette « App Opening » : tout ORANGE en
          // clair (#f0562b → #ed4f25 → #f87a52), pas de fondu vers le blanc ;
          // dégradé sombre brun en mode sombre (#3a201a → #161210).
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF3A201A),
                    Color(0xFF1C1714),
                    Color(0xFF161210),
                  ]
                : const [
                    Color(0xFFC92A12),
                    Color(0xFFED4F25),
                    Color(0xFFF87A52),
                  ],
            stops: const [0.0, 0.55, 1.0],
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
          // v481b — BULLETPROOF : Column simple dans la SafeArea (hauteur
          // bornée) + Spacer pour coller les CTA en bas. PLUS de
          // SingleChildScrollView/IntrinsicHeight/Expanded (qui faisaient
          // disparaître la grille + les boutons en release). Aucun overlay
          // au-dessus des boutons.
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 16.h),

                // v483b — logo SIMPLE (sans Stack ni halo RadialGradient, qui
                // pouvaient casser le rendu en release et masquer la suite).
                Container(
                  width: 120.w,
                  height: 120.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
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
                  // v484b — CAUSE RACINE du « aucun bouton » : stretch + cartes
                  // Expanded dans un scroll → calcul intrinsèque qui PLANTE le
                  // rendu en release et masque tout le reste. → start.
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                  // v484b — CAUSE RACINE du « aucun bouton » : stretch + cartes
                  // Expanded dans un scroll → calcul intrinsèque qui PLANTE le
                  // rendu en release et masque tout le reste. → start.
                  crossAxisAlignment: CrossAxisAlignment.start,
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

                // v483b — gap fixe (le scroll gère les petits écrans ; PLUS
                // d'Expanded, interdit dans un SingleChildScrollView).
                SizedBox(height: 36.h),

                // ── CTA Section ──
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
                      // v482b — maquette : S'inscrire = bouton BLANC (texte
                      // orange) en clair ; dégradé orange (texte blanc) en
                      // sombre. Câblage inchangé (→ SignUpAsScreen).
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Get.to(() => SignUpAsScreen()),
                          borderRadius: BorderRadius.circular(18.r),
                          child: Container(
                            height: 56.h,
                            decoration: BoxDecoration(
                              color: isDark ? null : Colors.white,
                              gradient: isDark
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFA8A3F),
                                        Color(0xFFC92A12),
                                      ],
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(18.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.16),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.pets,
                                    size: 18.sp,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.primaryColor),
                                SizedBox(width: 10.w),
                                PoppinsText(
                                  text: 'onboarding_signup'.tr,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.primaryColor,
                                ),
                                SizedBox(width: 8.w),
                                Icon(Icons.arrow_forward_ios_rounded,
                                    size: 14.sp,
                                    color: (isDark
                                            ? Colors.white
                                            : AppColors.primaryColor)
                                        .withValues(alpha: 0.7)),
                              ],
                            ),
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

                      SizedBox(height: 16.h),

                      // v482b — maquette : pas de séparateur « Ou continuer
                      // avec » sur l'accueil. Juste « Vous avez un compte ? ».
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InterText(
                            text: 'onboarding_have_account'.tr,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.92),
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
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                textDecoration: TextDecoration.underline,
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
          // v482b — maquette : sur le fond orange (clair) / sombre, le bouton
          // Google est un bouton « verre » translucide blanc + bord blanc ;
          // Apple reste noir.
          color: isOutlined
              ? (isDark
                  ? AppColors.cardDark
                  : Colors.white.withValues(alpha: 0.16))
              : AppColors.blackColor,
          border: isOutlined
              ? Border.all(
                  color: isDark
                      ? AppColors.dividerDark
                      : Colors.white.withValues(alpha: 0.40),
                  width: 1.5,
                )
              : null,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  height: 24.r,
                  width: 24.r,
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                        // v482b — texte/icône TOUJOURS blanc (fond orange en
                        // clair, sombre en dark, noir pour Apple).
                        color: Colors.white,
                      ),
                    SizedBox(width: 10.w),
                    InterText(
                      text: label,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
