import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/widgets/boost_profile_card.dart';
import 'package:hopetsit/widgets/kyc_status_banner.dart';
import 'package:hopetsit/widgets/my_kyc_verified_badge.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/profile/widgets/my_profiles_card.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/views/profile/widgets/profile_categories.dart';
import 'package:hopetsit/views/profile/widgets/profile_completion_card.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/views/profile/widgets/profile_notification_bell.dart';
// v23.1 — Mes cartes (Airwallex saved payment_consents) — sitter peut payer un PawSpot/PawFollow.
import 'package:hopetsit/views/pet_sitter/profile/availability_calendar_screen.dart';
import 'package:hopetsit/views/wallet/wallet_screen.dart';
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── SITTER HERO HEADER ──────────────────────
            _buildSitterHero(controller, sitterAccent),

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

                  // Quick Pro Actions
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
    );
  }

  /// Sitter-specific hero: blue/professional gradient.
  Widget _buildSitterHero(SitterProfileController controller, Color accent) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          // v23.1.290 — hauteur MINIMALE : le header s'étend si les badges
          // passent sur 2 lignes au lieu de déborder sous le dégradé.
          // v471 — Daniel : « réduis BEAUCOUP plus, juste sous les badges » → 58
          // + padding/nom resserrés + avatar radius 36 → hero ultra-compact.
          // v473 — refonte MODERNE (Daniel) : coins inférieurs arrondis + ombre
          // douce bleue = en-tête carte HD avec profondeur. Compact conservé.
          clipBehavior: Clip.antiAlias,
          constraints: BoxConstraints(minHeight: 58.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0D47A1),
                accent,
                const Color(0xFF42A5F5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30.r)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.32),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              _heroPaw(),
              _heroDecoCircle(),
              SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 3.h),
              // v486b — Daniel : « centrer photo + texte comme owner ».
              // Structure owner-style : rangée du haut (chip rôle + cloche),
              // puis avatar CENTRÉ verticalement avec le nom, puis stats pleine
              // largeur.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // v443 — logo de l'app à côté du rôle.
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3.r),
                                    child: Image.asset(
                                      'assets/brand/png/ic_launcher.png',
                                      width: 14.w,
                                      height: 14.w,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  InterText(
                                    text: 'role_pet_sitter'.tr,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            // v23.1 part 247 — Daniel : "met un badge jolie".
                            // Badge KYC verifie a cote de la role pill. Le widget
                            // s'auto-update via /users/me/benefits + tick worker
                            // declenche par notifyChanged() en fin de KYC.
                            SizedBox(width: 6.w),
                            const MyKycVerifiedBadge(large: true),
                            const Spacer(),
                            // v441 — cloche de notifications (demandes / amis /
                            // paiements) en haut à droite du hero.
                            const ProfileNotificationBell(role: 'sitter'),
                          ],
                        ),
                        SizedBox(height: 14.h),
                        // v486b — avatar CENTRÉ verticalement avec le nom +
                        // pastille statut (comme owner).
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildSitterAvatar(controller, accent),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Obx(() => PoppinsText(
                                        text: controller.userName.value,
                                        fontSize: 26.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      )),
                                  SizedBox(height: 8.h),
                                  _heroStatusPill(
                                      'profile_status_available_sit'.tr),
                                  // v493 — Daniel : les badges d'abonnement
                                  // (PawFollow/PawSpot/Premium, jours restants)
                                  // n'apparaissaient QUE chez l'owner. On les
                                  // ajoute aussi au gardien : ActiveBenefitsRow
                                  // lit /benefits (valable pour les 3 rôles).
                                  SizedBox(height: 8.h),
                                  const ActiveBenefitsRow(compact: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Obx(() => Row(
                              children: [
                                _heroStat(
                                    '${_daysActive(controller.profile.value?.createdAt)}',
                                    'profile_days_active'.tr),
                                SizedBox(width: 8.w),
                                _heroStat(
                                    '⭐ ${(controller.profile.value?.rating ?? 0).toStringAsFixed(1)}',
                                    'stat_rating'.tr),
                              ],
                            )),
                ],
              ),
            ),
          ),
              ],
            ),
        ),
      ],
    );
  }

  /// 🐾 filigrane + cercle déco (maquette Daniel — profondeur HD).
  /// v477 — jours actifs RÉELS depuis l'inscription (createdAt → aujourd'hui).
  int _daysActive(String? createdAt) {
    if (createdAt == null || createdAt.trim().isEmpty) return 0;
    final d = DateTime.tryParse(createdAt);
    if (d == null) return 0;
    final n = DateTime.now().difference(d).inDays;
    return n < 0 ? 0 : n;
  }

  /// Pastille statut « Disponible · … » (verre dépoli blanc).
  Widget _heroStatusPill(String label) => Container(
        padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8.w,
              height: 8.w,
              decoration: const BoxDecoration(
                  color: Color(0xFFBFE0FF), shape: BoxShape.circle),
            ),
            SizedBox(width: 7.w),
            InterText(
              text: label,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ],
        ),
      );

  /// Carte stat (valeur + libellé) du header (verre dépoli).
  Widget _heroStat(String value, String label) => Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 11.h, horizontal: 4.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InterText(
                text: value,
                fontSize: 19.sp,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              SizedBox(height: 2.h),
              InterText(
                text: label,
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ],
          ),
        ),
      );

  Widget _heroPaw() => Positioned(
        right: -26.w,
        top: -24.h,
        child: Transform.rotate(
          angle: 0.31,
          child: Text('🐾',
              style: TextStyle(
                  fontSize: 150.sp, color: Colors.white.withValues(alpha: 0.10))),
        ),
      );

  Widget _heroDecoCircle() => Positioned(
        left: -34.w,
        bottom: -56.h,
        child: Container(
          width: 150.w,
          height: 150.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
      );

  Widget _buildSitterAvatar(SitterProfileController controller, Color accent) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Obx(
            () => CircleAvatar(
              // v477 — maquette v2 : avatar agrandi (~84px) à anneau + caméra.
              radius: 41.r,
              backgroundColor: AppColors.grey300Color,
              backgroundImage: controller.profileImageUrl.value.isNotEmpty
                  ? CachedNetworkImageProvider(controller.profileImageUrl.value)
                  : null,
              child: controller.profileImageUrl.value.isEmpty
                  ? Icon(Icons.person, size: 30.sp, color: AppColors.greyColor)
                  : null,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: controller.editProfile,
            child: Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.camera_alt_rounded, size: 13.sp, color: Colors.white),
            ),
          ),
        ),
      ],
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
    return Row(
      children: [
        _sitterWideAction('📅', 'profile_my_availability'.tr, accent,
            () => Get.to(() => const AvailabilityCalendarScreen())),
        SizedBox(width: 12.w),
        _sitterWideAction('💼', 'wallet_menu_title'.tr, accent,
            () => Get.to(() => const WalletScreen())),
      ],
    );
  }

  /// v449 — bouton rectangle arrondi BLEU PÂLE (Expanded) : emoji + label
  /// bleu sitter, fond bleu pâle + bordure bleue translucide, 1 ligne.
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
