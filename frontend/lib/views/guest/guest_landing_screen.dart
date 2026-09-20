import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/services/firebase_analytics_service.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/signup_wizard_screen.dart';
import 'package:hopetsit/views/guest/guest_discovery_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/micro_anims.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// v540 — ATTERRISSAGE INVITÉ (écran 4a du handoff « Page de connexion LAP ») :
/// héros 2 colonnes avec photo, tuiles de rôle en dégradé + tuile Invité rose,
/// bloc « Créer mon compte » Apple/Google côte à côte.
///
/// v573 — MISE AU DESIGN DE L'APP (builds 567-571), **rendu seulement** :
/// aucune logique, aucune navigation, aucun appel n'a bougé.
///   · la palette privée figée (`_bgTop`, `_ink`, `_brand`…) a disparu : tout
///     passe par les helpers contextuels d'`AppColors`, donc l'écran est enfin
///     correct en mode SOMBRE (c'était le dernier écran « clair uniquement »
///     de l'app, et c'est le premier que voit un nouvel utilisateur) ;
///   · le dégradé chaud et la patte de la marque sont conservés — ils sont
///     dérivés de `AppColors.scaffold/card`, pas écrits en dur ;
///   · `OutlinedButton` / `ElevatedButton` stylés à la main → [CustomButton],
///     le bouton unique de l'app depuis la v569 ;
///   · cartes : coins 18-22 sur `AppColors.card` + bord `AppColors.divider`
///     + `AppColors.cardShadow`.
class GuestLandingScreen extends StatelessWidget {
  const GuestLandingScreen({super.key});

  /// Rose de la tuile « Invité » — seule couleur de marque propre à cet écran.
  /// Elle n'est JAMAIS utilisée telle quelle : `AppColors.accentOn` l'éclaircit
  /// sur fond sombre pour rester lisible.
  static const Color _guestPink = Color(0xFFDB2777);

  /// Dégradé de fond « crème » (clair) / « nuit » (sombre), construit à partir
  /// des helpers : `scaffold()` vaut #FFF1EC en clair (orange pâle du rôle
  /// propriétaire, le rôle par défaut avant toute connexion) et #121212 en
  /// sombre ; on l'éclaircit vers la surface des cartes pour le haut de page.
  static List<Color> _pageGradient(BuildContext context) {
    final Color base = AppColors.scaffold(context);
    return <Color>[
      Color.lerp(base, AppColors.card(context), 0.55)!,
      base,
    ];
  }

  @override
  Widget build(BuildContext context) {
    FirebaseAnalyticsService.instance.logFunnel('guest_landing');
    final Color ink = AppColors.textPrimary(context);
    final Color muted = AppColors.textSecondary(context);
    final Color brand = AppColors.accentOn(context, AppColors.primaryColor);

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _pageGradient(context),
          ),
        ),
        // v573 — la patte de la marque en filigrane, comme sur les 3 accueils
        // et les écrans de messages (v571). Elle garde l'identité chaleureuse
        // de l'écran maintenant que les aplats crème en dur ont sauté.
        child: PawPatternBackground(
          color: AppColors.primaryColor,
          child: SafeArea(
            child: SingleChildScrollView(
              // v569 — dégagement bas unique de l'app (Samsung edge-to-edge :
              // `viewPadding.bottom` vaut 0 alors que la barre à 3 boutons
              // recouvre 48 px). Le SafeArea entoure déjà le contenu.
              padding: EdgeInsets.fromLTRB(
                18.w,
                10.h,
                18.w,
                24.h + appBottomInsetInsideSafeArea(context),
              ),
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
                      // Le logotype reste en Fredoka : c'est la signature de
                      // la marque, pas un titre d'écran.
                      Row(
                        children: [
                          FredokaText(
                              text: 'Ho',
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              color: ink),
                          FredokaText(
                              text: 'Pet',
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              color: brand),
                          FredokaText(
                              text: 'Sit',
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              color: ink),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  // ── Badge confiance ──────────────────────────────────
                  _TrustBadge(text: 'guest_badge_trust'.tr),
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
                              PoppinsText(
                                text: 'guest_hero_title_1'.tr,
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w800,
                                color: ink,
                                height: 1.18,
                                maxLines: 3,
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: PoppinsText(
                                      text: 'guest_hero_title_2'.tr,
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.w800,
                                      color: brand,
                                      height: 1.18,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  HeartBeat(
                                    child: InterText(
                                      text: '❤',
                                      fontSize: 22.sp,
                                      color: brand,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.h),
                              InterText(
                                text: 'guest_hero_sub'.tr,
                                fontSize: 13.sp,
                                color: muted,
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
                          PoppinsText(
                            text: 'guest_iwant'.tr,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: ink,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 6.h),
                          Container(
                            width: 40.w,
                            height: 3.h,
                            decoration: BoxDecoration(
                              color: brand,
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
                          child: GuestRoleTile(
                            photo: 'assets/images/guest/prop-new.png',
                            gradient: const <Color>[
                              Color(0xFFE25822),
                              Color(0xFFC92A12),
                            ],
                            title: 'role_pet_owner'.tr,
                            subtitle: 'guest_role_owner_sub'.tr,
                            onTap: () => _toWizard('pet_owner'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: GuestRoleTile(
                            photo: 'assets/images/guest/sit-new.png',
                            gradient: const <Color>[
                              Color(0xFF2F6FD6),
                              Color(0xFF1E4FB0),
                            ],
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
                          child: GuestRoleTile(
                            photo: 'assets/images/guest/walk-new.png',
                            gradient: const <Color>[
                              Color(0xFF2FAE4E),
                              Color(0xFF15803D),
                            ],
                            title: 'role_pet_walker'.tr,
                            subtitle: 'guest_role_walker_sub'.tr,
                            onTap: () => _toWizard('pet_walker'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: GuestRoleTile(
                            photo: 'assets/images/guest/souris2.png',
                            // Pas de dégradé : tuile posée sur la carte du
                            // thème, avec l'accent rose « Invité ».
                            accent: _guestPink,
                            title: 'guest_role_guest'.tr,
                            subtitle: 'guest_role_guest_sub'.tr,
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
                    child: CustomButton(
                      // `bgColor` transparent + `borderColor` = variante
                      // « contour » de CustomButton (cf. rounded_text_button).
                      bgColor: Colors.transparent,
                      borderColor: brand,
                      textColor: brand,
                      title: '🐾 ${'guest_discover_btn'.tr}',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      radius: 16.r,
                      height: 48.h,
                      onTap: () => Get.to(() => const GuestDiscoveryScreen()),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // ── Créer mon compte ─────────────────────────────────
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 500),
                    child: Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(22.r),
                        border: Border.all(
                          color: AppColors.divider(context)
                              .withValues(alpha: 0.8),
                          width: 1,
                        ),
                        boxShadow: AppColors.cardShadow(context),
                      ),
                      child: Column(
                        children: [
                          PoppinsText(
                            text: 'guest_create_account'.tr,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: ink,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                          SizedBox(height: 4.h),
                          InterText(
                            text: '${'guest_create_sub'.tr} 🔒',
                            fontSize: 11.5.sp,
                            color: muted,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                          SizedBox(height: 13.h),
                          Row(
                            children: [
                              if (Platform.isIOS) ...[
                                Expanded(
                                  child: _SmallAuthButton(
                                    label: 'auth569_apple_continue'.tr,
                                    icon: Icons.apple,
                                    // Noir Apple imposé par les règles de
                                    // marque : il ne suit pas le thème.
                                    bg: const Color(0xFF101319),
                                    fg: Colors.white,
                                    onTap: () => Get.find<AuthController>()
                                        .loginWithApple(),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                              ],
                              Expanded(
                                child: _SmallAuthButton(
                                  label: 'auth569_google_continue'.tr,
                                  imagePath: AppImages.googleIcon,
                                  icon: Icons.g_mobiledata,
                                  bg: AppColors.card(context),
                                  fg: ink,
                                  border: true,
                                  onTap: () => Get.find<AuthController>()
                                      .loginWithGoogle(),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          CustomButton(
                            isGradient: true,
                            radius: 16.r,
                            height: 48.h,
                            onTap: () => _toWizard('pet_owner'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mail_outline_rounded,
                                    size: 17.sp, color: Colors.white),
                                SizedBox(width: 8.w),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: InterText(
                                      text: 'guest_signup_email'.tr,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 11.h),
                          GestureDetector(
                            onTap: () => launchUrl(
                                Uri.parse('https://www.hopetsit.com/terms'),
                                mode: LaunchMode.externalApplication),
                            behavior: HitTestBehavior.opaque,
                            child: InterText(
                              text: 'guest_terms_note'.tr,
                              fontSize: 10.sp,
                              color: AppColors.textTertiary(context),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: InterText(
                                  text: 'guest_already'.tr,
                                  fontSize: 12.5.sp,
                                  color: muted,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              GestureDetector(
                                onTap: () => Get.to(() => const LoginScreen()),
                                behavior: HitTestBehavior.opaque,
                                child: InterText(
                                  text: 'guest_login'.tr,
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w800,
                                  color: brand,
                                  maxLines: 1,
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
      ),
    );
  }

  void _toWizard(String userType) {
    FirebaseAnalyticsService.instance
        .logFunnel('signup_start', params: {'trigger': 'landing_$userType'});
    Get.to(() => SignupWizardScreen(userType: userType));
  }
}

/// Pilule « paiement sécurisé · identité vérifiée » du haut de page.
class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Vert « confiance » de la marque, éclairci sur fond sombre.
    final Color green = AppColors.accentOn(context, const Color(0xFF3F6B2E));
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: green.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 13.sp, color: green),
          SizedBox(width: 6.w),
          Flexible(
            child: InterText(
              text: text,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w800,
              color: green,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile de rôle de l'atterrissage invité.
///
/// Deux variantes :
///   · [gradient] non nul → tuile pleine à la couleur du rôle (le texte blanc
///     est posé sur un aplat saturé : il est lisible dans les deux thèmes) ;
///   · [accent] non nul → tuile « Invité », posée sur `AppColors.card` avec un
///     liseré et un texte à l'accent (éclairci en sombre par `accentOn`).
///
/// Publique pour être montée seule dans `test/lot1_573_test.dart`.
class GuestRoleTile extends StatelessWidget {
  const GuestRoleTile({
    super.key,
    required this.photo,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.gradient,
    this.accent,
  });

  final String photo;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Dégradé du rôle (2 couleurs). Null = variante « Invité ».
  final List<Color>? gradient;

  /// Accent de la variante « Invité ». Ignoré si [gradient] est fourni.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final List<Color>? g = gradient;
    final bool filled = g != null;
    final Color tint = AppColors.accentOn(
      context,
      accent ?? AppColors.primaryColor,
    );
    final Color titleColor = filled ? Colors.white : tint;
    final Color subtitleColor = filled
        ? Colors.white.withValues(alpha: 0.92)
        : AppColors.textSecondary(context);
    final BorderRadius br = BorderRadius.circular(20.r);

    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: filled ? Colors.transparent : AppColors.card(context),
        borderRadius: br,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: filled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: g,
                  )
                : null,
            borderRadius: br,
            border: filled
                ? null
                : Border.all(color: tint.withValues(alpha: 0.45), width: 1.4),
          ),
          child: InkWell(
            borderRadius: br,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(8.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                          child: PoppinsText(
                            text: title,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        ArrowNudge(
                          child: Container(
                            width: 22.w,
                            height: 22.w,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: filled
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : tint.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 15.sp,
                              color: filled ? Colors.white : tint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Padding(
                    padding:
                        EdgeInsets.only(left: 4.w, right: 4.w, bottom: 4.h),
                    child: InterText(
                      text: subtitle,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton « Continuer avec Apple / Google » du bloc « Créer mon compte ».
///
/// v569 — le logo Google officiel remplace l'icône Material `g_mobiledata`
/// (un « G » générique qui ne respecte pas la marque). Les deux libellés sont
/// longs et les boutons se partagent la largeur : le texte est réduit plutôt
/// que coupé.
class _SmallAuthButton extends StatelessWidget {
  const _SmallAuthButton({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.imagePath,
    this.border = false,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  final String? imagePath;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(14.r);
    return Material(
      color: bg,
      borderRadius: br,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: br,
        onTap: onTap,
        child: Container(
          height: 46.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            borderRadius: br,
            border: border
                ? Border.all(color: AppColors.divider(context), width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (imagePath != null)
                Image.asset(imagePath!,
                    width: 18.sp, height: 18.sp, fit: BoxFit.contain)
              else
                Icon(icon, size: 19.sp, color: fg),
              SizedBox(width: 7.w),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: InterText(
                    text: label,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
