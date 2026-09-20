import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/widgets/boost_profile_card.dart';
import 'package:hopetsit/widgets/kyc_status_banner.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/profile/widgets/my_profiles_card.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/views/profile/widgets/profile_categories.dart';
import 'package:hopetsit/views/profile/widgets/profile_completion_card.dart';
import 'package:hopetsit/views/profile/widgets/profile_hero.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
// v23.1 — Mes cartes (Airwallex saved payment_consents) — sitter peut payer un PawSpot/PawFollow.
// v565 — le calendrier et le portefeuille sont ouverts par ProviderQuickActions.
import 'package:hopetsit/views/shared/provider_quick_actions.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
// v23.1.332 — parrainage RÉACTIVÉ pour sitter (récompense -10% PawFollow/Family).

class SitterProfileScreen extends StatelessWidget {
  const SitterProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Safely get or create the controller
    final SitterProfileController controller;
    if (Get.isRegistered<SitterProfileController>()) {
      controller = Get.find<SitterProfileController>();
    } else {
      controller = Get.put(SitterProfileController());
    }

    // Sitter accent color — distinct from owner
    const sitterAccent = Color(0xFF1A73E8);
    const sitterAccentLight = Color(0xFFE8F0FE);

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: PawPatternBackground(
 color: AppColors.activeRoleAccent(),
 child: SingleChildScrollView(
        child: Column(
          children: [
            // ── SITTER HERO HEADER ──────────────────────
            // v565 — en-tête PARTAGÉ par les 3 rôles (ProfileHero) : même
            // structure, dégradé bleu gardien. Caméra = éditer le profil
            // (comportement sitter conservé).
            ProfileHero(
              role: 'sitter',
              userName: controller.userName,
              profileImageUrl: controller.profileImageUrl,
              profile: controller.profile,
              onCamera: controller.editProfile,
            ),

            Padding(
              // v468 — dégage le bas au-dessus du menu pleine largeur
              padding: EdgeInsets.fromLTRB(
                  // v488 — Daniel : « Se déconnecter toujours trop bas » → on
                  // dégage davantage le bas pour passer au-dessus du menu.
                  16.w, 0, 16.w, 140.h + appBottomInset(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),

                  // v480 — maquette « Header v2 » : la carte blanche
                  // « Note / Avis / Services » est MASQUÉE (l'en-tête affiche
                  // déjà « jours actifs + Note » → évite le doublon). Méthode
                  // _buildSitterStatsRow conservée mais plus appelée.

                  // v565 — point 25 : barre « profil complété à X % ».
                  Obx(() => ProfileCompletionCard(
                        profile: controller.profile.value,
                        role: 'sitter',
                        accent: sitterAccent,
                        onEditProfile: controller.navigateToEditProfile,
                      )),

                  // v565 (lot app-calendar-wallet) — 2 grandes cartes d'action :
                  // 📅 Mes disponibilités (N jours dispo ce mois) et 💼 Portefeuille
                  // (solde réel / « Configurer l'IBAN »), bleu gardien #2563EB.
                  _buildSitterQuickActions(controller, sitterAccent, sitterAccentLight),
                  SizedBox(height: 20.h),

                  // v23.1 part 115 — Banner KYC + PawBoost + switch de rôle.
                  const KycStatusBanner(),
                  const BoostProfileCard(role: 'sitter'),
                  SizedBox(height: 16.h),
                  const MyProfilesCard(),
                  SizedBox(height: 8.h),

                  // v565 — points 26/33 : catégories claires partagées.
                  ProfileCategories(
                    role: 'sitter',
                    accent: sitterAccent,
                    host: controller,
                    onEditProfile: controller.navigateToEditProfile,
                  ),

                  SizedBox(height: 24.h),

                  // Logout Button
                  ProfileSecondaryButton(
                    label: 'button_logout'.tr,
                    accent: sitterAccent,
                    icon: Icons.logout_rounded,
                    onTap: () => controller.showLogoutDialog(context),
                  ),

                  SizedBox(height: 20.h),
            ],
          ),
        ),
          ],
        ),
      ),
),
    );
  }

  // v480 — maquette « Header v2 » : carte « Note / Avis / Services » retirée
  // (doublon avec les stats de l'en-tête). _buildSitterStatsRow + _statItem
  // supprimés. La liste des avis reste accessible ailleurs (avis reçus).

  /// Quick actions: Earnings, Availability, Boost, IBAN.
  /// v23.1 part 144 — Daniel : 'icone tjr diforme' après 4 tentatives
  /// successives (.w/.sp, FittedBox, _outlined, etc.). Material Icons
  /// sont fondamentalement non-uniformes (chaque glyph dessiné à la
  /// main). Switch définitif vers EMOJIS rendus par le système Android :
  /// la fonte emoji du device garantit le même bounding box pour
  /// tous les caractères. Impossible d'être déformé.
  Widget _buildSitterQuickActions(SitterProfileController controller, Color accent, Color accentLight) {
    // v446 — Daniel : 2 boutons rectangle arrondi — Calendrier (gauche) +
    // Mon portefeuille (droite). v449 — Daniel : passés en BLEU PÂLE (au lieu
    // du plein bleu), cohérent avec le pâle par rôle owner/walker.
    // v565 — Daniel (18/09) : « améliore les boutons » → cartes blanches
    // partagées `ProviderQuickActions` (emoji sur carré teinté, sous-titres
    // réels : jours dispo ce mois, solde du portefeuille, IBAN à configurer,
    // pression animée). Bleu gardien officiel #2563EB (AppColors.sitterAccent).
    return const ProviderQuickActions(
      role: 'sitter',
      accent: AppColors.sitterAccent,
    );
  }

  /// v449 — bouton rectangle arrondi BLEU PÂLE (Expanded) : emoji + label
  /// bleu sitter, fond bleu pâle + bordure bleue translucide, 1 ligne.
  /// v565 — conservé (aucune fonction retirée) mais plus appelé : remplacé par
  /// `ProviderQuickActions`. Ancien usage :
  /// `_sitterWideAction('📅', 'profile_my_availability'.tr, accent,
  ///     () => Get.to(() => const AvailabilityCalendarScreen()))` et
  /// `_sitterWideAction('💼', 'wallet_menu_title'.tr, accent,
  ///     () => Get.to(() => const WalletScreen()))`.
  // ignore: unused_element
  Widget _sitterWideAction(
      String emoji, String label, Color accent, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Builder(
          builder: (context) {
            final labelColor =
                Get.isDarkMode ? AppColors.textPrimary(context) : accent;
            return Container(
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 10.w),
              decoration: BoxDecoration(
                color: Get.isDarkMode
                    ? const Color(0xFF1C2530)
                    : AppColors.scaffoldSitterLight,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  // bleu sitter translucide (≈0.30 clair / ≈0.35 sombre) en ARGB
                  color: Get.isDarkMode
                      ? const Color(0x592563EB)
                      : const Color(0x4D2563EB),
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
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
