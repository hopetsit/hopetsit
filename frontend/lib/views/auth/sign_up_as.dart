import 'package:flutter/material.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/signup_wizard_screen.dart';
import 'package:hopetsit/views/auth/social_city_screen.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/guest/guest_landing_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

/// Sign-up role selector.
///
/// Displays the 3 available roles — Pet Owner, Pet Sitter, Pet Walker — as
/// distinct cards with their own color tone:
///   • Owner  → primary (warm orange)
///   • Sitter → blue (`#2F6FD6 → #1E4FB0`)
///   • Walker → green (`#2FAE4E → #15803D`)
///
/// v573 — les 3 cartes étaient illustrées par des PNG marketing hérités
/// (`AppImages.petOwner/petSitter/petWalker`) : photos recadrées, lourdes,
/// impossibles à teinter proprement et hors du langage visuel des builds
/// 567-571. Elles laissent place à une illustration VECTORIELLE sobre —
/// grand rond en dégradé à la couleur du rôle + icône Material arrondie —
/// qui rend pareil en clair et en sombre. Rendu seulement : `_openRole`, la
/// navigation et les clés i18n sont inchangés.
class SignUpAsScreen extends StatelessWidget {
  const SignUpAsScreen({super.key});

  /// v565 audit-inscription — si on arrive ici après un 400 ROLE_REQUIRED de
  /// Google/Apple, le rôle choisi doit relancer CE fournisseur (avec la ville,
  /// obligatoire) et non ouvrir le wizard e-mail + mot de passe.
  void _openRole(String userType) {
    String? provider;
    if (Get.isRegistered<AuthController>()) {
      provider = Get.find<AuthController>().pendingSocialProvider;
    }
    if (provider == 'google' || provider == 'apple') {
      Get.to(() => SocialCityScreen(provider: provider!, userType: userType));
      return;
    }
    Get.to(() => SignupWizardScreen(userType: userType));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            // v585 (lot D) — Samsung : SafeArea ne protège pas le bas → complément.
            padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, appBottomInsetInsideSafeArea(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.h),
                BackButton(
                  color: AppColors.textPrimary(context),
                  // v502 — arrivée via Get.offAll (nouvel utilisateur
                  // Apple/Google) = pile vide → le retour par défaut ne faisait
                  // rien. On revient si possible, sinon on ouvre la connexion.
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      // v537 — Daniel : « je suis bloqué sur cette page ».
                      // Pile vide → on revient à la DÉCOUVERTE invité (avant :
                      // LoginScreen, qui repartait ici = ping-pong sans sortie).
                      Get.offAll(() => const GuestLandingScreen());
                    }
                  },
                ),
                SizedBox(height: 16.h),
                // v23.1 part 138 — badge "Inscription" pour matcher le
                // badge "Connexion" du LoginScreen et bien distinguer
                // les 2 flows.
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: PoppinsText(
                      text: 'sign_up'.tr.toUpperCase(),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Center(
                  child: PoppinsText(
                    text: 'sign_up_as_subtitle'.tr,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 8.h),
                Center(
                  child: InterText(
                    text: 'signup_as_subtitle'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary(context),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 28.h),
                SignUpRoleCard(
                  titleKey: 'role_pet_owner',
                  subtitleKey: 'role_pet_owner_desc',
                  icon: Icons.pets_rounded,
                  badgeIcon: Icons.home_rounded,
                  gradient: kSignUpOwnerGradient,
                  onTap: () => _openRole('pet_owner'),
                ),
                SizedBox(height: 16.h),
                SignUpRoleCard(
                  titleKey: 'role_pet_sitter',
                  subtitleKey: 'role_pet_sitter_desc',
                  icon: Icons.night_shelter_rounded,
                  badgeIcon: Icons.verified_rounded,
                  gradient: kSignUpSitterGradient,
                  onTap: () => _openRole('pet_sitter'),
                ),
                SizedBox(height: 16.h),
                SignUpRoleCard(
                  titleKey: 'role_pet_walker',
                  subtitleKey: 'role_pet_walker_desc',
                  icon: Icons.directions_walk_rounded,
                  badgeIcon: Icons.near_me_rounded,
                  gradient: kSignUpWalkerGradient,
                  onTap: () => _openRole('pet_walker'),
                ),
                SizedBox(height: 24.h),
                // v23.1 part 138 — lien vers login si l'utilisateur arrive
                // ici par erreur (avait déjà un compte).
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InterText(
                        text: 'guest_already'.tr,
                        fontSize: 13.sp,
                        color: AppColors.textSecondary(context),
                      ),
                      SizedBox(width: 6.w),
                      GestureDetector(
                        // v502 — "Se connecter" : on arrive souvent ici via
                        // Get.offAll (ex : nouvel utilisateur Apple/Google) donc
                        // la pile de navigation est VIDE → Get.back() ne faisait
                        // rien (bouton mort). On ouvre explicitement l'écran de
                        // connexion.
                        onTap: () => Get.offAll(() => const LoginScreen()),
                        behavior: HitTestBehavior.opaque,
                        child: PoppinsText(
                          text: 'title_login'.tr,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                // v537 — Daniel : « je ne vois plus le mode invité ». Une
                // sortie claire vers la découverte sans compte.
                Center(
                  child: GestureDetector(
                    onTap: () => Get.offAll(() => const GuestLandingScreen()),
                    behavior: HitTestBehavior.opaque,
                    child: InterText(
                      text: 'guest_continue_without'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
        ),
    );
  }
}

/// Dégradés des 3 rôles (v573). Ceux du gardien et du promeneur sont ceux de
/// l'accueil propriétaire (`owner_home_kit`) et du menu patte : une seule
/// famille de couleurs dans toute l'app.
const List<Color> kSignUpOwnerGradient = <Color>[
  Color(0xFFE25822),
  AppColors.primaryColor,
];
const List<Color> kSignUpSitterGradient = <Color>[
  Color(0xFF2F6FD6),
  Color(0xFF1E4FB0),
];
const List<Color> kSignUpWalkerGradient = <Color>[
  Color(0xFF2FAE4E),
  Color(0xFF15803D),
];

/// Illustration vectorielle d'un rôle : grand rond en dégradé + icône
/// arrondie, plus une pastille secondaire posée en bas à droite.
///
/// Publique pour pouvoir être montée seule dans `test/lot1_573_test.dart`.
class SignUpRoleIllustration extends StatelessWidget {
  const SignUpRoleIllustration({
    super.key,
    required this.gradient,
    required this.icon,
    this.badgeIcon,
    this.size = 84,
  });

  final List<Color> gradient;
  final IconData icon;
  final IconData? badgeIcon;

  /// Diamètre en dp logiques (l'appelant décide s'il le multiplie par `.w`).
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color accent = gradient.last;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.26),
                  blurRadius: 14,
                  spreadRadius: -3,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, size: size * 0.46, color: Colors.white),
          ),
          if (badgeIcon != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.34,
                height: size * 0.34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.card(context),
                  border: Border.all(
                    color: AppColors.divider(context),
                    width: 1,
                  ),
                ),
                child: Icon(
                  badgeIcon,
                  size: size * 0.19,
                  color: AppColors.accentOn(context, accent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Carte de rôle de l'écran « Je m'inscris en tant que… ».
///
/// Illustration vectorielle à gauche, titre à la couleur du rôle, description
/// sur 3 lignes maximum, chevron à droite. Coins 20, surface `AppColors.card`,
/// bord `AppColors.divider` teinté par l'accent, ombre `AppColors.cardShadow`
/// (nulle en mode sombre).
class SignUpRoleCard extends StatelessWidget {
  const SignUpRoleCard({
    super.key,
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.badgeIcon,
  });

  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final IconData? badgeIcon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = AppColors.accentOn(context, gradient.last);
    final BorderRadius br = BorderRadius.circular(20.r);
    return Semantics(
      button: true,
      label: titleKey.tr,
      child: Material(
        color: AppColors.card(context),
        borderRadius: br,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            decoration: BoxDecoration(
              borderRadius: br,
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
                width: 1.4,
              ),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Row(
              children: <Widget>[
                SignUpRoleIllustration(
                  gradient: gradient,
                  icon: icon,
                  badgeIcon: badgeIcon,
                  size: 76.w,
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PoppinsText(
                        text: titleKey.tr,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6.h),
                      InterText(
                        text: subtitleKey.tr,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary(context),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22.sp,
                  color: accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
