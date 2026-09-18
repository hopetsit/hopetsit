import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/widgets/boost_profile_card.dart';
import 'package:hopetsit/widgets/kyc_status_banner.dart';
import 'package:hopetsit/widgets/my_kyc_verified_badge.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/profile/widgets/my_profiles_card.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/views/profile/widgets/profile_categories.dart';
import 'package:hopetsit/views/profile/widgets/profile_completion_card.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/views/profile/widgets/profile_notification_bell.dart';
import 'package:hopetsit/utils/app_colors.dart';
// v23.1 — Mes cartes (Airwallex saved payment_consents) — walker peut payer un PawSpot/PawFollow.
import 'package:hopetsit/views/pet_sitter/profile/availability_calendar_screen.dart';
import 'package:hopetsit/views/wallet/wallet_screen.dart';
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
  static final Color _accentLight = AppColors.greenColor.withValues(alpha: 0.12);

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
            _buildWalkerHero(context, controller),

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
  // HERO
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildWalkerHero(
    BuildContext context,
    ProfileController controller,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          // v23.1.290 — hauteur MINIMALE : le header s'étend si les badges
          // passent sur 2 lignes au lieu de déborder sous le dégradé.
          // v465/v467/v469 — Daniel : « toujours trop grand » → 100 + padding
          // resserré (hero compact, plus d'espace vide sous les badges).
          // v471 — Daniel : « réduis BEAUCOUP plus, juste sous les badges » → 58
          // + padding/nom resserrés + avatar 72 → hero ultra-compact.
          // v473 — refonte MODERNE (Daniel) : coins inférieurs arrondis + ombre
          // douce verte = en-tête carte HD avec profondeur. Compact conservé.
          clipBehavior: Clip.antiAlias,
          constraints: BoxConstraints(minHeight: 58.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1B5E20), // Dark green
                _accent,
                Color(0xFF66BB6A), // Light green
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30.r)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B5E20).withValues(alpha: 0.32),
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
              // largeur. (Avant : avatar collé en haut à gauche = déséquilibré.)
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                        // v23.1 part 247 — Daniel : "met un badge jolie".
                        // Row contenant la role pill + le badge KYC verifie.
                        Row(
                          children: [
                            // Role badge.
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20.r),
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
                                    text: 'role_pet_walker'.tr,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 6.w),
                            // v247 badge KYC reactive (auto-refresh sur tick).
                            const MyKycVerifiedBadge(large: true),
                            const Spacer(),
                            // v441 — cloche de notifications (demandes / amis /
                            // paiements) en haut à droite du hero.
                            const ProfileNotificationBell(role: 'walker'),
                          ],
                        ),
                        SizedBox(height: 14.h),
                        // v486b — avatar CENTRÉ verticalement avec le nom +
                        // pastille statut (comme owner).
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildWalkerAvatar(controller),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Obx(() => PoppinsText(
                                        text: controller.userName.value.isEmpty
                                            ? 'walker_profile_title'.tr
                                            : controller.userName.value,
                                        fontSize: 26.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )),
                                  SizedBox(height: 8.h),
                                  _heroStatusPill(
                                      'profile_status_available_walk'.tr),
                                  // v493 — Daniel : badges d'abonnement
                                  // (PawFollow/PawSpot/Premium) aussi chez le
                                  // promeneur (avant : owner uniquement).
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
                  color: Color(0xFF9AF0B4), shape: BoxShape.circle),
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

  /// 🐾 filigrane + cercle déco (maquette Daniel — profondeur HD).
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

  Widget _buildWalkerAvatar(ProfileController controller) {
    return Stack(
      children: [
        Obx(() {
          final imageUrl = controller.profileImageUrl.value;
          final isUploading = controller.isUploadingImage.value;
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(42.r),
              child: SizedBox(
                // v477 — maquette v2 : avatar agrandi (84) à anneau + caméra.
                width: 84.w,
                height: 84.w,
                child: isUploading
                    ? Container(
                        color: AppColors.lightGrey,
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(_accent),
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : (imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            memCacheWidth: 720, // v23.1 part 250 perf (cover header)
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppColors.lightGrey),
                            errorWidget: (_, __, ___) => Container(
                              color: _accentLight,
                              child: Icon(
                                Icons.directions_walk_rounded,
                                size: 36.sp,
                                color: _accent,
                              ),
                            ),
                          )
                        : Container(
                            color: _accentLight,
                            child: Icon(
                              Icons.directions_walk_rounded,
                              size: 36.sp,
                              color: _accent,
                            ),
                          )),
              ),
            ),
          );
        }),
        // Session v3.3 — camera edit button overlay (parity with sitter hero).
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: controller.pickAndUploadProfilePicture,
            child: Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                color: _accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: 13.sp,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildQuickActions(BuildContext context) {
    // v446 — Daniel : juste 2 boutons rectangle arrondi GRIS — Calendrier
    // (gauche) + Mon portefeuille (droite). Boost reste dans la carte PawBoost
    // plus bas ; l'IBAN reste accessible via Mon portefeuille (retrait).
    return Row(
      children: [
        _wideAction(
          context,
          emoji: '📅',
          label: 'profile_quick_calendar'.tr,
          onTap: () =>
              Get.to(() => const AvailabilityCalendarScreen(role: 'walker')),
        ),
        SizedBox(width: 12.w),
        _wideAction(
          context,
          emoji: '💼',
          label: 'wallet_menu_title'.tr,
          onTap: () => Get.to(() => const WalletScreen()),
        ),
      ],
    );
  }

  /// v448 — Daniel : « walker les boutons vers pâle ». Rectangle arrondi VERT
  /// PÂLE (au lieu de gris), texte/emoji vert promeneur ; emoji + label 1 ligne.
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
