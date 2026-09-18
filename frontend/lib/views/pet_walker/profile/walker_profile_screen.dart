import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/widgets/boost_profile_card.dart';
import 'package:hopetsit/widgets/kyc_status_banner.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/profile/widgets/my_profiles_card.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/views/profile/widgets/profile_categories.dart';
import 'package:hopetsit/views/profile/widgets/profile_completion_card.dart';
import 'package:hopetsit/views/profile/widgets/profile_hero.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/utils/app_colors.dart';
// v23.1 — Mes cartes (Airwallex saved payment_consents) — walker peut payer un PawSpot/PawFollow.
// v565 — le calendrier et le portefeuille sont ouverts par ProviderQuickActions.
import 'package:hopetsit/views/shared/provider_quick_actions.dart';
import 'package:hopetsit/views/pet_walker/profile/edit_walker_profile_screen.dart';
// v23.1.332 — parrainage RÉACTIVÉ pour walker (récompense -10% PawFollow/Family).
import 'package:hopetsit/widgets/app_text.dart';

/// Walker profile screen — full redesign (session avril 2026).
///
/// Previous iteration embedded the PawMap fullscreen + a gear bottom-sheet.
/// Feedback from Daniel: the profile tab should show a *real profile* with
/// all the action buttons visible inline. PawMap stays on the bottom-nav
/// center button where it belongs.
///
/// Layout mirrors [SitterProfileScreen]:
///   1. Green-gradient hero with avatar, name, email, walker role badge
///   2. Quick actions row (Revenues / Calendar / Boost / IBAN)
///   3. Switch-role cards (toward Owner and Sitter)
///   4. Settings list grouped in sections (Account / Payments / Preferences
///      / Security / Legal / Danger zone)
///   5. Logout button
///
/// Walker-specific data (rate manager, coverage zones, insurance) will land
/// in a later session; for now the header reuses ProfileController's generic
/// name/email/avatar fields, which are populated for every logged-in user.
class WalkerProfileScreen extends StatelessWidget {
  const WalkerProfileScreen({super.key});

  // Walker accent = green. Light variant used for icon chip backgrounds.
  static const Color _accent = AppColors.greenColor;

  ProfileController _profileController() {
    return Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _profileController();

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Walker hero ───────────────────────────────────
            // v565 — en-tête PARTAGÉ par les 3 rôles (ProfileHero) : même
            // structure, dégradé vert promeneur.
            ProfileHero(
              role: 'walker',
              userName: controller.userName,
              profileImageUrl: controller.profileImageUrl,
              profile: controller.profile,
              isUploadingImage: controller.isUploadingImage,
              onCamera: controller.pickAndUploadProfilePicture,
            ),

            Padding(
              // v468 — dégage le bas au-dessus du menu pleine largeur
              padding: EdgeInsets.fromLTRB(
                  // v488 — Daniel : « Se déconnecter toujours trop bas » → on
                  // dégage davantage le bas pour passer au-dessus du menu.
                  16.w, 0, 16.w, 140.h + MediaQuery.of(context).viewPadding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),

                  // v565 — point 25 : barre « profil complété à X % ».
                  Obx(() => ProfileCompletionCard(
                        profile: controller.profile.value,
                        role: 'walker',
                        accent: _accent,
                        onEditProfile: () => Get.to(() => const EditWalkerProfileScreen()),
                        onPhoto: controller.pickAndUploadProfilePicture,
                      )),

                  // Quick Actions: revenues, calendar, boost, iban.
                  _buildQuickActions(context),
                  SizedBox(height: 20.h),

                  // v23.1 part 115 — banner KYC (CTA "Vérifier mon identité").
                  const KycStatusBanner(),

                  // v18.6 — Booster mon profil (vert walker).
                  BoostProfileCard(role: 'walker'),
                  SizedBox(height: 20.h),

                  // Switch role cards — one per role the walker can move to.
                  const MyProfilesCard(),
                  SizedBox(height: 20.h),

                  // v565 — points 26/33 : catégories claires partagées.
                  ProfileCategories(
                    role: 'walker',
                    accent: _accent,
                    host: controller,
                    onEditProfile: () => Get.to(() => const EditWalkerProfileScreen()),
                  ),

                  SizedBox(height: 24.h),

                  // Logout button.
                  ProfileSecondaryButton(
                    label: 'button_logout'.tr,
                    accent: _accent,
                    icon: Icons.logout_rounded,
                    onTap: () => controller.showLogoutDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildQuickActions(BuildContext context) {
    // v446 — Daniel : juste 2 boutons rectangle arrondi GRIS — Calendrier
    // (gauche) + Mon portefeuille (droite). Boost reste dans la carte PawBoost
    // plus bas ; l'IBAN reste accessible via Mon portefeuille (retrait).
    // v565 — Daniel (18/09) : « améliore les boutons » → cartes blanches
    // partagées `ProviderQuickActions` (emoji sur carré teinté vert promeneur
    // #16A34A, sous-titres réels : jours dispo ce mois, solde, IBAN manquant).
    return const ProviderQuickActions(
      role: 'walker',
      accent: AppColors.walkerAccent,
    );
  }

  /// v448 — Daniel : « walker les boutons vers pâle ». Rectangle arrondi VERT
  /// PÂLE (au lieu de gris), texte/emoji vert promeneur ; emoji + label 1 ligne.
  /// v565 — conservé (aucune fonction retirée) mais plus appelé : remplacé par
  /// `ProviderQuickActions`. Ancien usage : `_wideAction(context, emoji: '📅',
  /// label: 'profile_quick_calendar'.tr, onTap: () => Get.to(() => const
  /// AvailabilityCalendarScreen(role: 'walker')))` et `_wideAction(context,
  /// emoji: '💼', label: 'wallet_menu_title'.tr, onTap: () => Get.to(() =>
  /// const WalletScreen()))`.
  // ignore: unused_element
  Widget _wideAction(
    BuildContext context, {
    required String emoji,
    required String label,
    required VoidCallback onTap,
  }) {
    const walkerGreen = Color(0xFF16A34A);
    final labelColor = Get.isDarkMode ? AppColors.textPrimary(context) : walkerGreen;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 10.w),
          decoration: BoxDecoration(
            color: Get.isDarkMode
                ? const Color(0xFF1F2A22)
                : const Color(0xFFE6F6EC),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              // vert promeneur translucide (≈0.30 clair / ≈0.35 sombre) en ARGB
              // const → pas de withOpacity déprécié.
              color: Get.isDarkMode
                  ? const Color(0x5916A34A)
                  : const Color(0x4D16A34A),
              width: 1.1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: TextStyle(fontSize: 18.sp)),
              SizedBox(width: 8.w),
              Flexible(
                child: InterText(
                  text: label,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
